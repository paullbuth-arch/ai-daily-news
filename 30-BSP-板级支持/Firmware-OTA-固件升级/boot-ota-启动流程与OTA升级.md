---
type: concept
tags: [BSP, BootROM, Bootloader, OTA, 固件升级, 安全启动, WQ7036A, A/B分区]
aliases: [启动流程, OTA升级, 固件升级, 空中升级, boot, ota, bootloader]
---

# 启动流程与 OTA 升级

## 一句话结论

启动流程是芯片从复位到 main() 的全过程——BootROM → Bootloader → APP，每一级验证下一级的合法性再跳转；OTA（Over-The-Air，空中升级）是不插线通过无线方式更新固件，核心要解决"安全下载、完整写入、断电回滚"三个问题。

## 30秒先看懂

- 芯片上电后从 BootROM 开始执行，这是芯片内置不可修改的代码，只信任有合法签名的 Bootloader。
- Bootloader 是 Flash 中可更新的程序，负责选择启动哪个 APP 版本，并执行 OTA 升级逻辑。
- OTA 升级的核心生命周期：下载固件 → 校验完整性 → 写入新分区 → 更新启动标记 → 重启切换。
- 最关键的原则是"永远不能覆盖正在运行的固件"，否则升级失败就没有回滚能力。
- WQ7036A 是三核 SoC，ACORE 先启动，然后通过 IPC 启动 BCORE 和 DCORE。

## 学完以后应该能做什么

**第一遍**
- 能画出从芯片上电到 main() 的完整启动链路
- 能说清楚 OTA 升级的完整流程和每个步骤的作用
- 能理解 A/B 双分区升级的工作原理和为什么它能防止断电变砖

**进阶**
- 能读懂 Bootloader 跳转到 APP 的汇编/C 代码
- 能设计一个支持断电保护的 OTA 升级方案
- 能分析 WQ7036A 的 WPK 固件包结构和三核启动顺序

## 前置知识

- 计算机组成基础：复位向量、中断向量表、栈指针
- Flash 存储基础：分区、擦除、写入、寿命
- 嵌入式系统基础：MCU 的启动流程、链接脚本

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|----------|
| 引导 ROM | BootROM | 芯片出厂时固化在 ROM 中的代码，不可修改，是安全启动的信任根 |
| 引导加载器 | Bootloader | Flash 中的第一段程序，负责验证和加载 APP，可以更新 |
| 二级引导加载器 | SBL (Secondary Bootloader) | WQ7036A 中的 Bootloader，初始化硬件后加载三核固件 |
| 空中升级 | OTA (Over-The-Air) | 通过无线方式（蓝牙/WiFi）更新固件，不插线 |
| A/B 分区 | A/B Partition | 双分区交替升级方案，一个运行一个升级，保证回滚能力 |
| 安全启动 | Secure Boot | 从 BootROM 开始每一级都用数字签名验证下一级，防止运行未授权固件 |
| 回滚 | Rollback | 升级失败时恢复旧版本，需要留有完好的旧固件分区 |
| 差分升级 | Delta OTA | 只下载新旧固件的差异部分，减少下载量 |
| 磨损均衡 | Wear Leveling | 分散 Flash 擦写操作到不同扇区，延长 Flash 寿命 |
| 固件包 | WPK | WQ7036A 的固件打包格式，本质是 ZIP 压缩包 |

## 第一层：费曼心智模型

### 类比：公司门禁与远程更新

启动流程就像公司门禁：
1. **BootROM** = 大门保安——只认有工牌（签名）的人进
2. **Bootloader** = 前台——检查来访者预约信息，决定带你去哪个会议室
3. **APP** = 会议室里的实际工作

OTA 升级就像远程更新会议室里的资料：
1. 从云端下载新版资料（下载固件）
2. 检查资料是否完整（校验固件）
3. 放到备用会议室（写入新分区，不能覆盖正在使用的会议室）
4. 通知前台下次带人去新会议室（更新启动标记）
5. 如果新会议室有问题，还能回到旧会议室（回滚机制）

### 边界在哪里

- BootROM 不可修改，是安全信任的根——如果 BootROM 有 bug，只能换芯片
- Bootloader 本身不可 OTA——如果 Bootloader 出 bug，只能通过有线方式（如 SWD/JTAG）重刷
- OTA 只能更新 APP 分区，不能更新 Bootloader 分区
- A/B 分区需要两倍 Flash 空间，这是最高安全等级的成本

### 场景演练：WQ7036A 蓝牙耳机 OTA 升级

1. 手机 App 检测到耳机固件版本 1.0，云端有版本 2.0
2. 手机下载 .wpk 固件包，通过蓝牙传输给耳机
3. 耳机收到后，解包 .wpk，校验 SHA256 哈希，确认固件完整
4. 将新固件写入 B 分区（当前运行在 A 分区）
5. 写入完成后，更新启动标记为"下次从 B 启动"
6. 耳机重启，Bootloader 读取启动标记，从 B 分区加载固件
7. 新固件启动后自检，调用"确认成功"API，标记 B 分区为已确认
8. 如果新固件启动失败（如死机、panic），看门狗复位，Bootloader 检测到"启动失败"，回滚到 A 分区

## 第二层：原理/时序/约束

### 启动流程：三级跳转

```
上电/复位
   ↓
[1] BootROM（芯片内置，不可修改）
   │  验证 Bootloader 签名
   ↓
[2] Bootloader（Flash 中的第一段程序）
   │  验证 APP 固件签名，选择启动哪个版本
   ↓
[3] APP（用户应用程序，从 main() 开始）
```

### WQ7036A 三核启动流程

```
上电/复位
   ↓
BootROM 运行（芯片内置）
   ↓
加载 SBL（Secondary Boot Loader）到 ACORE
   ↓
SBL 初始化硬件（时钟、Flash、GPIO）
   ↓
SBL 加载 ACORE APP → ACORE 跳到 main()
   ↓
ACORE main() 初始化 IPC
   ↓
ACORE 通过 IPC 启动 BCORE（加载 BCORE 固件，释放复位）
   ↓
ACORE 通过 IPC 启动 DCORE（加载 DCORE 固件，释放复位）
   ↓
三核全部运行
```

### OTA 升级基本流程

```
1. 下载新固件（通过蓝牙/WiFi/4G）
   ↓
2. 校验完整性（CRC/SHA256/签名验证）
   ↓
3. 写入 Flash 新分区（不能覆盖正在运行的固件）
   ↓
4. 更新启动标记（告诉 Bootloader "下次启动新版本"）
   ↓
5. 复位重启
   ↓
6. Bootloader 读取标记，启动新固件
   ↓
7. 新固件自检验证成功 → 标记为"已确认"
   新固件自检失败 → 回滚到旧版本
```

### A/B 双分区升级

```
当前运行：分区 A（版本 1.0）
OTA 下载：写入分区 B（版本 2.0）
重启后：  从分区 B 启动（版本 2.0）
如果失败：回滚到分区 A（版本 1.0）
下次 OTA：写入分区 A（版本 3.0）
```

### 关键约束

- Flash 有擦写次数限制（通常 10 万次），启动标记写入需要磨损均衡
- 切换标记写入必须是"原子"的——不能写到一半断电导致状态不确定
- 固件版本号比较不能用字符串比较（"1.10" < "1.9" 是个经典 bug）
- OTA 暂存区大小必须 >= 最大固件包大小，否则写入溢出

## 第三层：真实 SDK 代码

### WQ7036A 的 Bootloader 复位实现

文件路径：`/home/ys/wq7036a/wq-audio/wqcore/components/startup/boot/src/boot.c`

```c
static void boot_reason_chip_reset(void)
{
    /* disable interrupt */
    uint32_t mask = cpu_disable_irq();

    boot_reason_set_soft_reset_reason(boot_soft_reset_reason, boot_reset_flag);
    boot_reason_set_soft_reset_magic();

    /* soft reset */
    wq_wdt_global_do_reset(false);

    /* stay here till reset */
    volatile uint32_t forever = 1;
    while (forever) {
    }

    /* Should never be here */
    cpu_restore_irq(mask);
}

void boot_reset_immediately(BOOT_REASON_SOFT_SRC reason, uint8_t flag)
{
    boot_soft_reset_reason = reason;
    boot_reset_flag = flag;
    boot_reason_chip_reset();
}
```

这段代码展示了 WQ7036A 的软件复位实现：先设置复位原因，然后通过看门狗触发全局复位。复位后 BootROM 重新执行，Bootloader 读取复位原因判断是正常启动还是 OTA 后重启。

### WQ7036A ACORE main() 中的三核启动

文件路径：`/home/ys/wq7036a/wq-audio/wqcore/components/startup/bbb/acore/main.c`

```c
#include "loader.h"
#include "ipc.h"

static inline void ram_text_init(void)
{
    uint32_t *start = (uint32_t *)&_iram_text_start;
    uint32_t *end = (uint32_t *)&_iram_text_end;
    uint32_t *load = (uint32_t *)&_iram_text_load_addr;

    while (start != end) {
        *start = *load;
        start++;
        load++;
    }
}

static inline void data_section_init(void)
{
    uint8_t *start = (uint8_t *)&_data_start;
    uint8_t *end = (uint8_t *)&_data_end;
    uint8_t *load = (uint8_t *)&_data_load_addr;
    size_t len = (size_t)(end - start);
    memcpy(start, load, len);
}

static inline void bss_section_init(void)
{
    uint8_t *start = (uint8_t *)&_bss_start;
    // ...
}
```

ACORE 的 main() 函数是 WQ7036A 启动的核心：先初始化 RAM 中的代码段（从 Flash 拷贝到 IRAM）、初始化 data 段和 bss 段，然后初始化 IPC 通信，最后通过 IPC 启动 BCORE 和 DCORE。

### 启动标记原子的正确做法

```c
// 安全的两阶段写入

// 第 1 步：清除旧标记所在扇区
flash_erase(BOOT_FLAG_SECTOR);

// 第 2 步：写入新标记（一次写入，不擦除）
struct boot_flag { uint32_t magic; uint32_t version; };
struct boot_flag flag = { BOOT_MAGIC, 0x20001 };
flash_write(BOOT_FLAG_ADDR, &flag, sizeof(flag));

// 如果第 1 步后断电：标记无效，Bootloader 启动默认分区
// 如果第 2 步完成：标记有效，Bootloader 启动新分区
```

## 第四层：正常/异常路径

### 正常路径

1. BootROM 检查 Bootloader 签名 → 通过
2. Bootloader 检查 APP 签名 → 通过，启动 APP
3. APP 正常运行
4. OTA 时：下载完整 → 校验通过 → 写入成功 → 标记成功 → 重启后新固件运行正常 → 确认标记

### 异常路径

| 异常 | 现象 | 原因 | 解决方法 |
|------|------|------|----------|
| 下载中断 | 新固件不完整 | 蓝牙/WiFi 信号不稳定 | 校验失败后不切换，继续用旧版本 |
| 写入 Flash 中断 | 新分区数据损坏 | OTA 过程中断电 | CRC 校验失败，回滚旧分区 |
| 切换标记写入中断 | 启动标记不确定 | 写入标记时断电 | 两阶段写入（先擦除再写入），确保状态可恢复 |
| 新固件启动死机 | 设备反复重启 | 新固件有 bug | 看门狗超时 → Bootloader 检测到异常 → 回滚旧版本 |
| 分区大小不够 | 写入溢出 | 新固件比旧的大 | 预留足够空间，或启用差分升级 |
| Bootloader 损坏 | 无法启动 | 意外写入 Bootloader 区 | 只能通过 SWD/JTAG 有线重刷 |

## 第五层：调试方法

### 查看启动原因

```c
// 在 Bootloader 中读取复位原因
BOOT_REASON boot_reason_get_hard_reset_reason();
// 返回：上电复位、看门狗复位、软件复位、休眠唤醒等

// 判断是否是 OTA 后重启
bool boot_is_ota_reset();
```

### OTA 调试的关键日志

```
[D] OTA: download complete, size=524288, sha256=OK
[D] OTA: write to partition B at offset 0x200000
[D] OTA: write done, crc=0xA5B6C7D8
[D] OTA: update boot flag to B
[D] OTA: reset in 1s...
```

### 常见调试手段

```bash
# 通过串口查看 Bootloader 打印的启动信息
# BootROM 阶段通常没有输出（串口还没初始化）
# SBL 阶段开始有串口输出

# 查看 Flash 分区布局
cat /sys/kernel/debug/flash_layout  # Linux 系统
# 或查看 memory_config.json 中的分区定义
```

## 第六层：实战练习

### 练习 1：分析 WQ7036A 的启动代码

阅读 `/home/ys/wq7036a/wq-audio/wqcore/components/startup/bbb/acore/main.c`，回答：
- main() 函数中初始化了哪些关键模块？
- 调用了哪些函数来启动 BCORE 和 DCORE？
- 在 main() 之前，start.S 做了哪些工作（如何找到 start.S 文件）？

### 练习 2：设计一个 OTA 状态机

画出一个 OTA 升级的状态机，包含以下状态：IDLE, DOWNLOADING, DOWNLOADED, VERIFYING, WRITING, WRITTEN, MARKING, MARKED, REBOOTING。每个状态需要说明进入条件和退出条件。

### 练习 3：实现原子标记写入

假设你的 Flash 驱动支持 `flash_erase(sector)` 和 `flash_write(addr, data, len)`，写一个 `ota_commit()` 函数，实现原子化的启动标记写入。要求：任何时刻断电都不会导致系统变砖。

### 练习 4：版本号比较

写一个 C 函数 `int version_compare(const char *v1, const char *v2)`，支持形如 "1.2.3" 的版本号比较。要求：`"1.10" > "1.9"`，`"2.0.0" > "1.99.99"`。

## 自测与验收

1. 为什么 BootROM 不可修改？它对安全启动有什么意义？
2. A/B 双分区和单分区升级方案各自的优缺点是什么？什么场景下应该选哪个？
3. OTA 升级中最重要的是哪三个保护机制？分别保护什么？
4. Bootloader 跳转到 APP 之前为什么要关中断、关外设？
5. 什么是差分升级（Delta OTA）？它的优点和适用场景是什么？

## 延伸阅读

- [[compile-link-startup-编译链接与启动流程]] — 启动文件、链接脚本详解
- [[computer-arch-mcu-计算机组成与MCU架构]] — Flash 布局、地址映射
- [[ipc-multicore-多核通信与IPC]] — WQ7036A 三核启动顺序
- [[reliability-exception-系统可靠性与异常处理]] — OTA 失败时的恢复策略

## #flashcard

Q: 芯片启动的三级跳转是哪三级？每级的作用是什么？
A: BootROM（芯片内置，验证 Bootloader 签名）→ Bootloader（Flash 中，验证 APP 签名，选择启动版本）→ APP（用户应用程序，从 main() 执行）。

Q: OTA 升级的核心原则是什么？
A: 永远不能覆盖正在运行的固件，升级失败必须能回滚。这是 OTA 安全设计的最高原则。

Q: A/B 双分区升级的优点和缺点是什么？
A: 优点：回滚可靠，不怕断电，新固件启动失败自动回滚。缺点：需要两倍 Flash 空间。

Q: 为什么 Bootloader 本身不能通过 OTA 更新？
A: 因为 Bootloader 负责选择启动哪个 APP 版本，如果 OTA 更新 Bootloader 失败，芯片将无法启动。Bootloader 更新必须在有安全回滚机制的条件下进行，通常需要有线方式（SWD/JTAG）。

Q: WQ7036A 的三核启动顺序是什么？
A: BootROM 启动 → SBL 加载到 ACORE → ACORE main() 初始化 IPC → ACORE 通过 IPC 启动 BCORE → ACORE 通过 IPC 启动 DCORE。