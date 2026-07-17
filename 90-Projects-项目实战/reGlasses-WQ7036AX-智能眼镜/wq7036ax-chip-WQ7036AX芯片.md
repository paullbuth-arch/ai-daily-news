---
type: concept
created: 2026-07-16
updated: 2026-07-17
tags: [mcu, wq7036ax, chip, 芯片, 三核, soc]
aliases: [WQ7036AX, 物奇芯片, WQ7036A, 三核异构SoC]
---

# WQ7036AX 芯片

**一句话结论**：WQ7036AX 是一颗三核异构音频 SoC——ACORE（RISC-V）跑应用逻辑和 FreeRTOS，BCORE（RISC-V）专管蓝牙射频，DCORE（Xtensa HiFi5）做音频 DSP 加速。你写的代码 95% 跑在 ACORE 上。

---

## 30 秒先看懂

- WQ7036AX 不是单核芯片，而是三个不同专业分工的核封装在一起，通过共享内存和软中断通信。
- ACORE 是主控核，跑 FreeRTOS，负责应用逻辑、外设管理、与 V881 主控通信。
- BCORE 是蓝牙专用核，运行蓝牙控制器固件，处理基带和链路层时序。
- DCORE 是 Xtensa HiFi5 DSP 核，专职音频算法（AEC、降噪、波束成形等），无需你写 DSP 代码。
- 硬件连在谁身上谁就负责——麦克风、扬声器、传感器归 WQ7036AX，摄像头、WiFi、屏幕归 V881。

---

## 学完以后应该能做什么

**第一遍学完**：
- 能说出 WQ7036AX 三个核的名称、架构、各自职责
- 能画出 WQ7036AX 与 V881、手机的三方拓扑图
- 能在 SDK 中找到 `cores.h` 并识别 ACORE/BCORE/DCORE 的宏定义
- 能判断一条命令是本地执行还是转发 V881

**进阶目标**：
- 能阅读 `chip_reg_base.h` 理解外设寄存器的基地址映射
- 能根据原理图引脚编号在 datasheet 中查到对应功能
- 能理解 IPC 通信的共享内存模型和软中断触发流程

---

## 前置知识

- [[computer-arch-mcu-计算机组成与MCU架构]] — 理解 CPU、Flash、SRAM、总线的基本概念
- [[gpio-config-GPIO配置]] — 理解 GPIO 引脚的功能复用
- [[interrupt-concurrency-中断并发同步]] — 理解中断和任务调度的基础

---

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 三核异构 | Triple-core Heterogeneous | 三个不同架构的核协同工作，各司其职 |
| 应用核 | ACORE (Application Core) | RISC-V 架构，跑 FreeRTOS 和应用逻辑，主控核 |
| 蓝牙核 | BCORE (Bluetooth Core) | RISC-V 架构，专跑蓝牙控制器固件 |
| DSP 核 | DCORE (DSP Core) | Xtensa HiFi5 架构，专职音频数字信号处理 |
| 核间通信 | IPC (Inter-Processor Communication) | 通过共享内存和软中断实现三核数据交换 |
| 引脚复用 | Pin Mux (Pin Multiplexing) | 一个 GPIO 引脚可配置为多种功能，需避免冲突 |
| 电源域 | Power Domain | 一组由同一电源供电的电路模块，需按序使能 |

---

## 第一层：费曼心智模型

### 类比：三个专业员工

WQ7036AX 就像一家小公司里的三个员工：

| 角色 | 类比 | 职责 |
|------|------|------|
| **ACORE** | CEO | 做决策、管外设、协调全局，95% 的代码归他写 |
| **BCORE** | 专职翻译 | 只负责和手机蓝牙通信，能在微秒级响应 |
| **DCORE** | 专业调音师 | 只做音频算法——降噪、回声消除、波束成形 |

**为什么分三个核？** 蓝牙协议栈需要在微秒级响应射频中断，音频 DSP 需要大量乘加运算。如果全挤在一个核上，一个卡顿就会导致蓝牙断连或音频爆音。分核让每个核专注自己的领域，同时降低功耗。

### 边界

- WQ7036AX **负责**：BLE 连接、4 路 PDM 麦采集、DSP 音频处理、双扬声器 I2S 输出、光传感器/充电 IC（I2C）、按键/LED（GPIO）、UART 与 V881 通信
- WQ7036AX **不负责**：WiFi、摄像头/TOF（飞行时间传感器）、eMMC 存储、USB Type-C、视频编码、显示屏——这些都在 V881 上

### 场景推演

**场景：用户按下眼镜上的录制按钮**

1. 按键 GPIO 中断触发 ACORE
2. ACORE 判断：摄像头在 V881 上，不能本地处理
3. ACORE 通过 UART 转发"开始录制"命令给 V881
4. V881 启动摄像头，同时 ACORE 启动麦克风采集
5. 音频数据通过 I2S 传给 V881 混入视频

**判断原则**：硬件连在谁身上，谁就负责。这是判断命令该本地执行还是转发 V881 的唯一标准。

---

## 第二层：原理、时序与约束

### 启动顺序

```
上电 → ACORE 先启动 software_init() → 初始化硬件、PMP、Cache
         │
         ├→ 初始化 IPC 共享内存
         ├→ 通过 IPC 启动 BCORE（加载蓝牙固件）
         └→ 通过 IPC 启动 DCORE（加载 DSP 固件）
                  │
            FreeRTOS 调度器启动 → app_entry 任务开始运行
```

ACORE 是主控，负责拉起其他两个核。启动代码在 `wqcore/components/startup/` 下。

### 核心约束

| 约束 | 数值 | 说明 |
|------|------|------|
| ACORE 主频 | 240 MHz | RISC-V 最高频率 |
| 片上 SRAM | ~1 MB | 三核共享，需合理分配 |
| Flash | 外挂 | 通过 SPI Flash 控制器访问 |
| IPC 通信延迟 | ~微秒级 | 共享内存 + 软中断 |
| 工作功耗 | <50 mW | 典型音频场景 |

### 引脚功能速查（reGlasses 用到的）

**通信接口：**

| 协议 | 引脚 | 对端 | 用途 |
|------|------|------|------|
| UART TX | GPIO50 (C17) | V881 RX | 所有跨芯片命令和数据 |
| UART RX | GPIO51 (A16) | V881 TX | |
| I2C #1 | A10/A9 | ELM2713 光传感器 | 环境光 + 佩戴检测 |
| I2C #2 | B8/B7 | 充电 IC | 充电状态、电量 |
| I2S #1 | A17/B15/B16/D17 | V881 | 双向音频数据 |
| I2S #2 | AMP_I2S_* | MAX98357A 功放 | 扬声器输出 |

**控制与状态：**

| 功能 | 引脚 | 类型 |
|------|------|------|
| KEY_1 (功能键A) | M14 | 输入，上拉 |
| KEY_2 (功能键B) | M5 | 输入，上拉 |
| KEY_3 (电源键) | N6 | 输入，上拉 |
| LED_R/G/B | N10/M10/N11 | 输出 |
| LS_INT（光感中断） | M12 | 输入中断 |
| PS_EN（电源使能） | J9 | 输出 |
| BT-WK-V881（唤醒V881） | M13 | 输出 |

---

## 第三层：真实 SDK 代码

### 核定义：`cores.h`

在 SDK 中，三个核通过枚举和宏定义区分。

**文件路径**：`wqcore/chipset/bbb/include/cores.h`

```c
typedef enum {
    WQ_CORES_ACORE,   // 应用核
    WQ_CORES_BCORE,   // 蓝牙核
    WQ_CORES_BCORE2,  // 第二蓝牙核（部分芯片）
    WQ_CORES_ACORE2,  // 第二应用核（部分芯片）
    WQ_CORES_DCORE,   // DSP 核
    WQ_CORES_MAX,
} WQ_CORES;

// 编译时确定当前编译的是哪个核
#if defined(CONFIG_BUILD_ACORE)
#define WQ_CORES_SELF WQ_CORES_ACORE
#elif defined(CONFIG_BUILD_BCORE)
#define WQ_CORES_SELF WQ_CORES_BCORE
#elif defined(CONFIG_BUILD_DCORE)
#define WQ_CORES_SELF WQ_CORES_DCORE
#endif
```

`CORE_NAME()` 函数将核编号映射为字符串，用于日志输出。

### 寄存器基地址：`chip_reg_base.h`

**文件路径**：`wqcore/chipset/bbb/include/chip_reg_base.h`

该文件定义了所有外设模块的基地址，例如 UART、I2C、I2S、GPIO 等。当需要直接操作寄存器时，从这里查找基地址。

### 启动流程：`startup/`

**文件路径**：`wqcore/components/startup/`

包含 ACORE 的启动代码、BCORE 和 DCORE 的加载逻辑。`boot/` 子目录下是核心的启动流程实现。

### 内存映射：`memory_config.h`

**文件路径**：`wqcore/chipset/bbb/include/memory_config.h`

定义了三核各自的 SRAM 分区、Flash 地址映射。

---

## 第四层：正常与异常路径

### 正常路径

1. 上电 -> ACORE 启动 -> 初始化硬件 -> IPC 初始化 -> 启动 BCORE/DCORE -> FreeRTOS 调度 -> app_entry 运行
2. 应用代码通过标准 API 调用外设功能，无需关心核间通信细节
3. 音频数据自动经 IPC 送往 DCORE 处理，处理完成后返回 ACORE

### 异常路径

| 问题 | 现象 | 根因 |
|------|------|------|
| 引脚复用冲突 | 某个外设不工作 | 两个外设分配到了同一个 GPIO 引脚，功能配置冲突 |
| 电源域未使能 | 外设无法访问，寄存器写入无效 | 外设对应的电源域没打开，模块处于掉电状态 |
| 时钟未配置 | 外设通信乱码或超时 | 外设模块的时钟门控未打开，无法工作 |
| 核间 IPC 超时 | DCORE 音频处理无响应 | DCORE 固件未正常加载或崩溃 |
| BCORE 启动失败 | 蓝牙无法广播 | 蓝牙固件加载失败或射频校准参数异常 |

### 诊断方法

- 外设不工作：先查 GPIO 复用表确认引脚未被占用
- 寄存器写入无效：查芯片手册确认该模块的电源域和时钟门控
- IPC 超时：检查 DCORE/BCORE 固件是否已正确烧录到 Flash

---

## 第五层：调试方法

### 1. 确认当前编译的核

在启动日志中搜索 `CORE_NAME` 的输出，确认当前固件是为哪个核编译的：
```
[INFO] CORE_NAME: ACORE
```

### 2. 检查引脚功能配置

在 `gpio_config.c` 或 Kconfig 中搜索对应引脚，确认功能复用配置正确。

### 3. 验证外设时钟和电源

对应 Kconfig 配置项：
- `CONFIG_POWER_DOMAIN_*` — 电源域使能
- `CONFIG_CLOCK_*` — 时钟使能

### 4. 使用 IPC 调试

IPC 超时日志通常包含目标核 ID 和消息序列号，据此判断是哪个核无响应。

### 5. 逻辑分析仪抓波形

对于 UART、I2C、I2S 等外设通信问题，用逻辑分析仪抓取引脚波形，对比协议时序图。

---

## 第六层：实战练习

### 练习 1：在 SDK 中定位三个核的定义

在 `wqcore/chipset/bbb/include/cores.h` 中找到 `WQ_CORES` 枚举定义和 `CORE_NAME()` 函数。写出三个核的枚举值名称和对应的字符串。

### 练习 2：画拓扑图并判断命令路由

画出 WQ7036AX、V881、手机三方的拓扑图，标出每条链路的物理接口。然后判断以下命令应该本地执行还是转发 V881：
- 打开 LED 指示灯
- 启动摄像头录制
- 读取光传感器数据
- 切换 WiFi 频道

### 练习 3：跟踪启动流程代码

在 `wqcore/components/startup/boot/` 下找到 ACORE 的启动入口代码，画出从 `software_init()` 到 `app_entry` 的函数调用链。识别出其中初始化 BCORE 和 DCORE 的调用位置。

### 练习 4：阅读真实源代码

打开 `wqcore/chipset/bbb/include/chip_reg_base.h`，找出 UART0、I2C0、I2S0 的基地址，并写出它们的地址值。

---

## 自测与验收

1. WQ7036AX 的三个核分别是什么架构？各自的职责是什么？
2. 为什么 WQ7036AX 要采用三核异构设计，而不是用一个高性能单核？
3. 一条"开始录制"命令，WQ7036AX 收到后是本地执行还是转发 V881？为什么？
4. 在 SDK 的哪个文件中可以找到三个核的枚举定义？
5. 如果某个外设不工作，应该按什么顺序排查（列出至少 3 个检查点）？
6. ACORE 和 DCORE 之间如何通信？
7. 启动顺序中，ACORE 先启动还是 BCORE 先启动？为什么？
8. 硬件连在谁身上谁就负责——请举例说明哪些外设归 WQ7036AX，哪些归 V881？

---

## 延伸阅读

- [[computer-arch-mcu-计算机组成与MCU架构]] — 理解 CPU/Flash/SRAM/总线的底层原理
- [[ipc-multicore-多核通信与IPC]] — 三核之间如何通过共享内存 + 软中断通信
- [[reglasses-architecture-reGlasses协议架构]] — WQ7036AX 在系统中的位置
- [[gpio-config-GPIO配置]] — 所有 GPIO 引脚的详细配置
- [[wq7036ax-audio-pipeline-WQ7036AX音频管道]] — 音频处理完整链路
- [[dataflow-cmd-to-v881-手机指令到V881]] — 指令跨芯片转发的完整数据流

#flashcard
问：WQ7036AX 的三个核分别是什么架构和职责？
答：ACORE（RISC-V）跑应用逻辑和 FreeRTOS；BCORE（RISC-V）专管蓝牙射频；DCORE（Xtensa HiFi5）做音频 DSP 处理。

问：如何判断一条命令是本地执行还是转发 V881？
答：硬件连在谁身上谁就负责。摄像头、WiFi、屏幕在 V881 上，对应命令转发；麦克风、扬声器、传感器、GPIO 在 WQ7036AX 上，本地执行。

问：ACORE 的启动顺序是什么？
答：上电 → ACORE software_init()（硬件初始化、PMP、Cache）→ IPC 初始化 → 启动 BCORE → 启动 DCORE → FreeRTOS 调度器启动 → app_entry 任务。

问：在 SDK 中三个核的枚举定义在哪里？
答：`wqcore/chipset/bbb/include/cores.h`，定义了 `WQ_CORES_ACORE`、`WQ_CORES_BCORE`、`WQ_CORES_DCORE` 等。

问：WQ7036AX 的典型工作功耗是多少？
答：<50 mW（典型音频场景）。