---
type: moc
created: 2026-07-16
tags: [moc, roadmap, 学习路线, 嵌入式入门]
aliases: [嵌入式知识库, 学习路线图, 嵌入式入门指南]
---

# 嵌入式知识库 — 从零到能干活

> 本知识库的目标：让一个只有 C 语言基础的人，在 4-6 个月内能独立在 WQ7036AX 平台上开发、调试、添加新功能。

---

## 先看这个：嵌入式到底是什么？

**一句话**：嵌入式系统就是"装在设备里的专用小电脑"。你的手机是通用计算机，但智能眼镜里的 WQ7036AX 芯片只做三件事：连蓝牙、处理音频、管外设。它没有屏幕、没有键盘、没有操作系统桌面——只有一颗芯片 + 一段固件，上电就跑。

### 费曼类比：通用电脑 vs 嵌入式芯片

把通用电脑想象成**瑞士军刀**——什么都能干，但每样都不精。嵌入式芯片是**专用工具**——比如一把手术刀，只干一件事，但干得极快、极省电。

| | 你的笔记本电脑 | WQ7036AX (嵌入式芯片) |
|---|---|---|
| CPU | x86, 2+ GHz, 多核 | RISC-V, 240 MHz, 三核 |
| 内存 | 8-32 GB | ~1 MB SRAM |
| 操作系统 | Windows/Linux/macOS | FreeRTOS (几 KB) |
| 开机时间 | 30 秒 | 0.1 秒 |
| 功耗 | 15-65 W | <50 mW |
| 程序存储 | 硬盘 | Flash (片上) |

**关键心智模型**：嵌入式的所有约束——小内存、慢 CPU、低功耗——都来自一个事实：芯片必须小到能塞进眼镜腿里，电池必须撑一整天。

---

## 你将在哪个项目里学？

**reGlasses 智能眼镜** = WQ7036AX (蓝牙音频芯片) + V881 (Linux 主控芯片)

```
手机 ──蓝牙──→ WQ7036AX ──UART──→ V881 ──WiFi──→ 云端
                  │
                  ├── 4 颗麦克风 (PDM)
                  ├── 2 个扬声器 (I2S)
                  ├── 光传感器 (I2C)
                  ├── 按键/LED (GPIO)
                  └── 充电 IC (I2C)
```

你写的代码主要跑在 **WQ7036AX 的 ACORE** 上，负责：
- 接收手机指令 → 转发给 V881（翻译官）
- 采集麦克风音频 → DSP 处理 → Opus 编码 → 发给手机（音频管家）
- 读取传感器、响应按键、控制 LED（外设保姆）

---

## 学习路线图（按这个顺序学）

### 阶段 1：地基（第 1-2 周）

先搞懂芯片是怎么工作的，程序是怎么跑起来的。

| 顺序 | 学什么 | 文件 | 为什么先学这个 |
|---|---|---|---|
| 1.1 | 芯片怎么工作 | [[10-Foundation-基础/Computer-Architecture-计算机组成/computer-arch-mcu-计算机组成与MCU架构]] | 不知道 CPU/Flash/RAM 是什么，后面全白学 |
| 1.2 | C 语言在嵌入式里的特殊用法 | [[10-Foundation-基础/C-Advanced-C语言进阶/c-core-C语言核心]] | 指针操作寄存器、volatile、位运算——这是你每天要写的 |
| 1.3 | 程序怎么从源码变成固件 | [[10-Foundation-基础/C-Advanced-C语言进阶/compile-link-startup-编译链接与启动流程]] | 理解编译→链接→烧录→启动的完整链条 |
| 1.4 | 中断是什么 | [[10-Foundation-基础/OS-Concepts-操作系统/interrupt-concurrency-中断并发同步]] | 嵌入式 90% 的 bug 和中断有关 |

### 阶段 2：操作系统（第 3-4 周）

理解多任务是怎么跑的。

| 顺序 | 学什么 | 文件 |
|---|---|---|
| 2.1 | RTOS 任务与调度 | [[10-Foundation-基础/OS-Concepts-操作系统/rtos-freertos-RTOS原理与FreeRTOS]] |
| 2.2 | 内存怎么分配 | [[10-Foundation-基础/OS-Concepts-操作系统/memory-dma-内存管理与DMA]] |
| 2.3 | 多核之间怎么通信 | [[10-Foundation-基础/Computer-Architecture-计算机组成/ipc-multicore-多核通信与IPC]] |

### 阶段 3：硬件协议（第 5-6 周）

学会和外面的芯片"说话"。

| 顺序 | 学什么 | 文件 | 为什么先学这个 |
|---|---|---|---|
| 3.1 | UART 串口 | [[20-HardwareProtocol-硬件协议/UART-I2C-SPI-GPIO-串口总线/uart-basics-UART基础]] | 最简单，WQ7036AX 和 V881 就靠它通信 |
| 3.2 | I2C 总线 | [[20-HardwareProtocol-硬件协议/UART-I2C-SPI-GPIO-串口总线/i2c-basics-I2C基础]] | 传感器、充电 IC 都挂在这上面 |
| 3.3 | GPIO 引脚 | [[20-HardwareProtocol-硬件协议/UART-I2C-SPI-GPIO-串口总线/gpio-config-GPIO配置]] | 按键、LED、电源控制 |
| 3.4 | I2S 音频总线 | [[20-HardwareProtocol-硬件协议/I2S-PDM-Audio-音频接口/i2s-protocol-I2S协议]] | 音频数据进出芯片的管道 |
| 3.5 | PDM 麦克风 | [[20-HardwareProtocol-硬件协议/I2S-PDM-Audio-音频接口/pdm-mic-PDM麦克风]] | 数字麦怎么把声音变成 0/1 |

### 阶段 4：项目实战（第 7-12 周）

把前面学的全部串起来，理解真实的系统。

| 顺序 | 学什么 | 文件 |
|---|---|---|
| 4.1 | 认识你的芯片 | [[90-Projects-项目实战/reGlasses-WQ7036AX-智能眼镜/wq7036ax-chip-WQ7036AX芯片]] |
| 4.2 | 全局架构 | [[90-Projects-项目实战/reGlasses-WQ7036AX-智能眼镜/Architecture-架构设计/reglasses-architecture-reGlasses协议架构]] |
| 4.3 | 音频数据流 | [[90-Projects-项目实战/reGlasses-WQ7036AX-智能眼镜/DataFlow-数据流/dataflow-mic-to-phone-声音从麦到手机]] |
| 4.4 | 指令数据流 | [[90-Projects-项目实战/reGlasses-WQ7036AX-智能眼镜/DataFlow-数据流/dataflow-cmd-to-v881-手机指令到V881]] |
| 4.5 | BLE 蓝牙 | [[70-Bluetooth-蓝牙/BLE-GAP-GATT-低功耗蓝牙/ble-gap-BLE-GAP广播]] → [[70-Bluetooth-蓝牙/BLE-GAP-GATT-低功耗蓝牙/ble-gatt-BLE-GATT]] |
| 4.6 | 音频系统 | [[60-Multimedia-AI-多媒体AI/Audio-Codec-Opus-音频编解码/audio-system-音频系统基础]] → [[60-Multimedia-AI-多媒体AI/Audio-Codec-Opus-音频编解码/opus-codec-Opus编码]] |

### 阶段 5：进阶主题（按需学习）

| 主题 | 文件 | 什么时候学 |
|---|---|---|
| 低功耗设计 | [[10-Foundation-基础/Computer-Architecture-计算机组成/low-power-低功耗设计]] | 需要优化续航时 |
| OTA 升级 | [[30-BSP-板级支持/Firmware-OTA-固件升级/boot-ota-启动流程与OTA升级]] | 需要实现固件更新时 |
| 调试方法 | [[80-Debug-调试/debug-methodology-嵌入式调试方法论]] | 遇到搞不定的 bug 时 |
| BLE 配对 | [[70-Bluetooth-蓝牙/BLE-GAP-GATT-低功耗蓝牙/ble-smp-BLE-SMP配对]] | 需要实现安全连接时 |
| 经典蓝牙 | [[70-Bluetooth-蓝牙/Classic-HFP-A2DP/classic-bluetooth-经典蓝牙]] | 需要通话/音乐功能时 |
| Linux BSP | [[30-BSP-板级支持/DeviceTree/devicetree-DeviceTree设备树]] → [[30-BSP-板级支持/U-Boot/uboot-U-Boot引导程序]] | 需要定制 V881 系统时 |
| Linux 应用 | [[50-Application-应用层/Multithread-POSIX/multithread-posix-多线程编程]] → [[50-Application-应用层/IPC-DBus-Socket/ipc-dbus-socket-IPC通信]] | 需要写 V881 服务时 |
| 嵌入式测试 | [[85-Testing-测试/embedded-testing-嵌入式测试]] | 需要保证代码质量时 |

---

## 这个知识库怎么用

### 每篇笔记的结构

每篇笔记按三层递进：

```
第一层：核心认知 (20%)  ← 必须先看，用生活类比讲清楚"是什么"
  一句话结论 + 费曼类比 + 核心概念表 + 最小代码
第二层：实战理解 (30%)  ← 建议看，能写代码能调试
  代码模板 + 常见错误 + 项目中的实际应用
第三层：深入扩展 (50%)  ← 按需看，遇到问题时再查
  源码细节 + 常见问题 + 延伸阅读
```

### 学习方法

1. **第一遍（1 周）**：只读每篇笔记的"第一层：核心认知"。不用记住所有细节，只要能用一句话给别人讲清楚每个概念。
2. **第二遍（2-3 周）**：精读重点笔记的第二层，打开 SDK 代码对照着看，动手写最小示例。
3. **第三遍（持续）**：遇到 bug 或要做新功能时，回到对应笔记看第三层。

### 验收标准

学完一个知识点后，问自己三个问题：
- 能用一句话给外行讲清楚这是什么吗？
- 能不看笔记写出最简单的代码示例吗？
- 能说出 3 个常见的坑吗？

---

## 全知识库索引

### [[10-Foundation-基础/moc-基础目录]] — C 语言 / 操作系统 / 计算机组成

嵌入式开发的地基。C 语言精确控制内存，OS 概念理解并发与调度，计算机组成理解硬件行为。

### [[20-HardwareProtocol-硬件协议/moc-硬件协议目录]] — 硬件协议

嵌入式工程师的"语言"——UART、I2C、SPI、I2S、PDM，你得看得懂时序图，能配置寄存器让外设跑起来。

### [[30-BSP-板级支持/moc-BSP目录]] — 板级支持包 (Linux)

让 Linux 在你的板子上跑起来——DeviceTree、U-Boot、Kernel、Buildroot。

### [[40-LinuxDriver-Linux驱动/moc-Linux驱动目录]] — Linux 驱动

外设驱动框架、I2C/SPI 子系统、ALSA 音频、V4L2 摄像头。

### [[50-Application-应用层/moc-应用层目录]] — Linux 应用层

多线程、IPC、Socket、systemd 守护进程。

### [[60-Multimedia-AI-多媒体AI/moc-多媒体AI目录]] — 多媒体与 AI

音频系统、Opus 编码、GStreamer、AI 推理。

### [[70-Bluetooth-蓝牙/moc-蓝牙目录]] — 蓝牙协议栈

BLE GAP/GATT/SMP、经典蓝牙 HFP/A2DP。

### [[80-Debug-调试/moc-调试目录]] — 调试方法论

串口/JTAG、GDB、逻辑分析仪、日志系统。

### [[90-Projects-项目实战/reGlasses-WQ7036AX-智能眼镜/moc-智能眼镜目录]] — reGlasses 项目

协议架构、数据流追踪、硬件外设、代码片段。

### [[95-Bugs-踩坑日志/moc-踩坑日志目录]] — 踩坑日志

每次调试的问题→原因→解决→预防，按时间记录。

---

## 开始学习

**如果你是零基础**：从 [[10-Foundation-基础/Computer-Architecture-计算机组成/computer-arch-mcu-计算机组成与MCU架构]] 开始，这是所有概念的起点。

**如果你有 MCU 基础但不熟悉这个项目**：直接跳到 [[90-Projects-项目实战/reGlasses-WQ7036AX-智能眼镜/Architecture-架构设计/reglasses-architecture-reGlasses协议架构]]，然后按需回溯基础概念。

**如果你在 Debug 中迷路了**：去 [[80-Debug-调试/debug-methodology-嵌入式调试方法论]] 找方法论，去 [[95-Bugs-踩坑日志/moc-踩坑日志目录]] 找类似问题。