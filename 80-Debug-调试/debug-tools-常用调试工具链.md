---
type: concept
created: 2026-07-17
tags: [debug, tools, gdb, openocd, logic analyzer, oscilloscope, 调试工具]
aliases: [调试工具链, Debug Tools, GDB, OpenOCD, JTAG, SWD]
---

# 常用调试工具链

## 一句话结论

嵌入式调试三件套是"串口日志（看软件流程）、GDB + JTAG/SWD（看代码和寄存器）、逻辑分析仪/示波器（看硬件信号）"，三种工具由粗到细覆盖了 95% 的嵌入式问题。WQ7036A 使用 cJTAG（Compact JTAG，2 线 JTAG）作为调试接口，通过 OpenOCD + GDB 进行断点调试，通过板载 UART 串口（115200 baud）输出日志。

## 30秒先看懂

- 串口打印是最基础也最常用的调试手段，通过 printf 输出到 PC 终端，查流程和变量值，几乎每个项目都用。
- GDB + OpenOCD 通过 JTAG/SWD 接口连接到芯片，支持断点、单步、查看寄存器/内存/调用栈，是精确定位问题的核心工具。
- 逻辑分析仪抓数字信号时序，适合排查 I2C/SPI/UART 等通信协议问题；示波器看模拟信号波形，适合排查电源纹波、时钟信号完整性。
- WQ7036A 使用 cJTAG（2 线）调试接口，编译时加 `-g -O0` 生成调试信息，通过 OpenOCD 连接 GDB。
- 三层工具由粗到细：先用串口日志缩小范围，再用 GDB 精确定位代码行，最后用逻辑分析仪/示波器验证硬件信号。

## 学完以后应该能做什么

### 第一遍
- 配置 OpenOCD + GDB 连接到 WQ7036A 芯片并设置断点
- 用串口打印输出调试信息，加时间戳和文件名行号
- 正确选择逻辑分析仪或示波器排查通信问题

### 进阶
- 使用 GDB 的 watchpoint、info threads 等高级功能排查死锁和并发问题
- 配置 CoreSight ITM 实现无侵入式日志输出
- 结合 FreeRTOS 的 GDB 脚本实现 RTOS 感知调试，查看所有任务状态

## 前置知识

- [[debug-methodology-嵌入式调试方法论]]：系统化的调试思路
- [[c-core-C语言核心]]：指针、内存布局相关概念
- [[interrupt-concurrency-中断并发同步]]：并发问题的排查
- [[wq7036ax-chip-WQ7036AX芯片]]：芯片的调试接口（cJTAG）和调试 UART 引脚

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| GNU 调试器 | GDB (GNU Debugger) | 开源的源代码级调试器，支持断点、单步、查看变量 |
| 开源片上调试器 | OpenOCD (Open On-Chip Debugger) | 开源的 JTAG/SWD 调试服务器，桥接 GDB 和目标芯片 |
| 联合测试行动组 | JTAG (Joint Test Action Group) | 5 线调试接口标准（TCK/TMS/TDI/TDO/TRST） |
| 串行线调试 | SWD (Serial Wire Debug) | ARM 的 2 线调试协议（SWDIO/SWCLK） |
| 紧凑型 JTAG | cJTAG (Compact JTAG) | 2 线 JTAG 标准，WQ7036A 使用的调试接口 |
| 断点 | Breakpoint | 程序执行到指定位置时暂停，最多 4-8 个硬件断点 |
| 监视点 | Watchpoint | 变量被读/写时暂停，追踪变量变化 |
| 仪表跟踪宏单元 | ITM (Instrumentation Trace Macrocell) | ARM CoreSight 调试组件，支持无侵入式日志输出 |
| 串行线输出 | SWO (Serial Wire Output) | SWD 的附加引脚，用于输出 ITM 跟踪数据 |
| 逻辑分析仪 | Logic Analyzer | 多通道数字信号分析工具，适合协议解码 |
| 示波器 | Oscilloscope | 模拟电压波形显示工具，适合信号质量分析 |

## 第一层费曼心智模型

### 类比：看病

排查程序问题就像看病，需要用不同的检查手段：

| 医疗手段 | 调试工具 | 能查什么 |
|---------|---------|---------|
| 病人口述症状 | **串口打印/日志** | 程序跑到哪了、变量值是多少、错误码是什么 |
| B 超/CT 扫描 | **GDB + JTAG/SWD** | 寄存器值、内存内容、调用栈、任务状态 |
| 心电图/脑电图 | **逻辑分析仪/示波器** | 信号波形、时序关系、电平质量 |

### 边界

- 串口打印会改变程序时序——加了日志后 bug 消失是常见坑（Heisenbug）。
- 硬件断点有数量限制（通常 4-8 个），这是由芯片内部比较器资源决定的。
- 逻辑分析仪只能看数字信号的高低电平，不能看模拟信号质量（如振铃、过冲）。
- 示波器通道少（通常 2-4 个），不适合同时抓多路信号做协议解码。
- 断点调试会影响实时性——音频处理等实时任务中设断点可能导致音频卡顿或溢出。

### 场景推演

**场景：I2C 通信失败，外设无响应**

1. 先看串口日志：打印了 I2C 初始化成功，但读写超时——确定是通信层面的问题
2. 用逻辑分析仪抓 SDA/SCL 波形：
   - 看到有 Start 条件，地址发出去了
   - 但 SDA 在第 9 个时钟高电平期间没有被拉低（没有 ACK）
   - 说明外设没有响应
3. 用示波器看 SCL 信号质量：
   - 发现 SCL 上升沿很慢，有振铃
   - 说明上拉电阻可能太大或 PCB 走线有问题
4. 结论：硬件问题（上拉电阻或 PCB 走线），不是软件问题

## 第二层原理/时序/约束

### 三层工具由粗到细

```
问题现象
   ↓
① 串口日志 ─────────── 缩小范围（哪个模块？哪个函数？什么条件下？）
   ↓
② GDB + JTAG/SWD ──── 精确定位（代码行、变量值、寄存器、调用栈）
   ↓
③ 逻辑分析仪/示波器 ── 验证硬件（信号波形、时序、电平）
   ↓
根因确认 → 修复 → 验证
```

### 工具对比

| 工具 | 用途 | 适合查什么 | 对程序影响 | 成本 |
|-----|------|-----------|-----------|------|
| **串口打印** | printf 输出到 PC | 流程、变量值、错误码 | 有时序影响 | 极低（USB 转串口） |
| **GDB + OpenOCD** | 断点、单步、查看寄存器/内存 | 崩溃、死循环、变量异常 | 暂停程序执行 | 低（JTAG/SWD 调试器） |
| **逻辑分析仪** | 抓数字信号时序 | I2C/SPI/UART 波形、协议解码 | 无影响 | 中（几百~几千元） |
| **示波器** | 看模拟信号波形 | 电源纹波、时钟信号、信号质量 | 无影响 | 高（几千~几万元） |
| **万用表** | 测电压、电流、通断 | 电源、焊接、引脚连通性 | 无影响 | 极低 |

### JTAG vs SWD vs cJTAG

| 特性 | JTAG (标准) | SWD (ARM) | cJTAG (WQ7036A) |
|------|------------|-----------|-----------------|
| 线数 | 5 根（TCK/TMS/TDI/TDO/TRST） | 2 根（SWDIO/SWCLK） | 2 根（TCK/TMS） |
| 速度 | 快 | 略慢 | 中 |
| 功能 | 完整（边界扫描、多核调试） | 够用（断点、读写） | 完整（兼容 JTAG 协议） |
| 适用 | 复杂 SoC、FPGA | ARM MCU | 非 ARM 芯片（如 RISC-V） |

### CoreSight 调试架构（ARM Cortex-M）

| 组件 | 功能 | 用途 |
|-----|------|------|
| **FPB** (Flash Patch and Breakpoint) | 硬件断点 | 最多 4-8 个硬件断点 |
| **DWT** (Data Watchpoint and Trace) | 数据监视点 + 周期计数器 | 变量变化追踪、性能计数 |
| **ITM** (Instrumentation Trace Macrocell) | 无侵入式日志输出 | 通过 SWO 引脚输出日志 |
| **ETM** (Embedded Trace Macrocell) | 指令流跟踪 | 记录 CPU 执行过的每条指令 |

## 第三层真实SDK代码

### WQ7036A 调试配置

```bash
# 编译时加 -g 生成调试信息，-O0 关闭优化
./build.sh --chip=7036AX --config-file=defconfig.stereo.i2s --debug

# 启动 OpenOCD（连接调试器到芯片）
openocd -f interface/jlink.cfg -f target/wq7036a.cfg
# 输出：Listening on port 3333 for gdb connections

# 启动 GDB，连接到 OpenOCD
riscv64-unknown-elf-gdb build/acore/acore.elf
(gdb) target remote :3333
(gdb) load          # 把 ELF 下载到芯片
(gdb) b main        # 在 main 函数设断点
(gdb) c             # 继续运行
```

### 串口打印实现

```c
// 在 WQ7036AX SDK 中，串口打印的初始化
void debug_init(void) {
    uart_init(DEBUG_UART, 115200, 8, NONE, 1);
}

// 带文件名和行号的日志宏
#define LOG(fmt, ...) \
    debug_print("%s:%d " fmt, __FILE__, __LINE__, ##__VA_ARGS__)

// 带时间戳的日志
#define LOG_TS(fmt, ...) \
    debug_print("[%lu] " fmt, xTaskGetTickCount(), ##__VA_ARGS__)

// 使用示例
LOG_TS("Task started, free_heap=%zu", xPortGetFreeHeapSize());
LOG_TS("I2C read: addr=0x%02X, val=0x%04X", addr, value);
```

### GDB 调试 FreeRTOS 任务

```bash
# 查看所有任务状态
(gdb) info threads
  1  Thread "idle"       (running)
  2  Thread "audio_task" (blocked on semaphore)
  3  Thread "bt_task"    (running)
  4  Thread "app_task"   (delayed 100ms)

# 切换到指定任务查看调用栈
(gdb) thread 2
(gdb) bt
#0  xQueueReceive (queue=0x20001234, buffer=0x20002000, timeout=0xffffffff)
#1  audio_task (p=0x0) at src/audio.c:45

# 查看变量的值
(gdb) p queue
(gdb) p *queue

# 查看内存内容（16 字节，十六进制）
(gdb) x/16xb 0x20000000
```

### ITM 无侵入日志（ARM Cortex-M 参考）

```c
// 通过 ITM 输出日志，不影响程序执行，不需要 UART
// 适用于 WQ7036A 的 DCORE（Xtensa HiFi5，如果支持 CoreSight）

void itm_putchar(char c) {
    // 等待 ITM 的 FIFO 就绪
    while ((ITM_STIM0 & ITM_STIM_FIFOREADY) == 0);
    ITM_STIM0 = c;
}

void itm_printf(const char *fmt, ...) {
    char buf[128];
    va_list args;
    va_start(args, fmt);
    vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);
    for (char *p = buf; *p; p++) {
        itm_putchar(*p);
    }
}
```

## 第四层正常/异常路径

### 调试连接故障排查

| 问题 | 现象 | 原因 | 解决方法 |
|------|------|------|---------|
| OpenOCD 连不上 | "Error: JTAG scan chain interrogation failed" | 调试器与芯片连接不良 | 检查 cJTAG 接线、电压、复位 |
| GDB 无法连接 | "Connection refused" | OpenOCD 未启动或端口错误 | 确认 OpenOCD 已启动，端口 3333 |
| 断点无效 | 断点没触发 | 代码被优化（-O2 以上） | 用 -O0 重新编译 |
| 断点数量超限 | "Cannot insert breakpoint" | 硬件断点用完了（最多 4-8 个） | 删除不必要的断点，或用软件断点 |
| 串口无输出 | 终端空白 | 波特率不对或 TX/RX 接反 | 检查波特率（115200）和接线 |
| 加了日志 bug 消失 | 问题不再出现 | 日志改变了程序时序 | 减少日志量，或用 ITM 无侵入日志 |

### 各工具使用时机

| 场景 | 工具 | 原因 |
|------|------|------|
| 程序崩溃（HardFault） | GDB + addr2line | 需查看 PC、LR 寄存器并翻译成源代码行号 |
| 程序卡死（死锁） | GDB info threads + bt | 需查看所有任务状态和调用栈 |
| I2C 通信失败 | 逻辑分析仪 | 需看 SDA/SCL 波形和时序 |
| 电源不稳定 | 示波器 | 需看电压波形和纹波 |
| 流程走不通 | 串口日志 | 最快速，加几行 printf 即可 |
| 变量值异常 | GDB watchpoint | 变量被修改时自动暂停 |

## 第五层调试方法

### GDB 常用命令速查

| 命令 | 作用 | 示例 |
|------|------|------|
| `b` (break) | 设断点 | `b main` / `b file.c:42` |
| `c` (continue) | 继续运行 | `c` |
| `n` (next) | 单步（不进入函数） | `n` |
| `s` (step) | 单步（进入函数） | `s` |
| `p` (print) | 打印变量值 | `p counter` / `p *ptr` |
| `bt` (backtrace) | 查看调用栈 | `bt` |
| `info registers` | 查看所有寄存器 | `info registers` |
| `info threads` | 查看所有任务 | `info threads` |
| `x` (examine) | 查看内存内容 | `x/16xb 0x20000000` |
| `watch` | 监视点（变量被改时暂停） | `watch counter` |
| `delete` | 删除断点 | `delete 1` |
| `list` | 显示源代码 | `list` / `list *0x12345` |
| `frame` | 切换调用栈帧 | `frame 1` |

### 逻辑分析仪使用步骤

```
1. 把逻辑分析仪的探头夹到目标信号线上
2. 设置采样率（至少是信号频率的 10 倍）
3. 设置触发条件（如 UART 起始位下降沿）
4. 采集 → 查看波形 → 用协议解码器解析数据
```

### 示波器使用场景

| 检查项 | 示波器能看到什么 |
|-------|---------------|
| 电源纹波 | 3.3V 电源上有多少 mV 的波动，是否在允许范围内 |
| 时钟信号 | 时钟波形是否干净、频率是否准确（如 16MHz） |
| 信号完整性 | 信号上升/下降沿是否陡峭、有没有振铃、过冲 |
| I2C 电平 | SDA/SCL 的高低电平是否达标（Vih 和 Vil） |

## 第六层实战练习

### 练习1：用 GDB 定位 HardFault

模拟一个 HardFault 场景，用 GDB + addr2line 定位到源代码行：

```bash
# 1. 编译含调试信息的固件
./build.sh --chip=7036AX --config-file=defconfig.stereo.i2s --debug

# 2. 启动 OpenOCD 和 GDB
# 3. 设置 HardFault_Handler 断点
# 4. 触发 HardFault（如空指针解引用）
# 5. 查看 PC 和 LR 寄存器
# 6. 用 addr2line 翻译地址到源代码行号
# 请写出每一步的 GDB 命令
```

### 练习2：阅读 SDK 源码分析调试配置

在 `/home/ys/wq7036a/wq-audio/wqcore/components/startup/` 目录下搜索芯片的调试接口配置，分析：
- WQ7036A 的调试 UART 使用哪个引脚？
- cJTAG 接口的引脚定义在哪里？
- OpenOCD 的配置文件（target 配置文件）定义了哪些调试特性？

### 练习3：设计串口日志系统

编写一个完整的串口日志模块，包含以下功能：

```c
// 要求：
// 1. 支持四级日志（ERROR/WARNING/INFO/DEBUG）
// 2. 编译时控制日志等级（Release 版本关闭 DEBUG 日志）
// 3. 日志自动添加时间戳、文件名、行号
// 4. 支持环形缓冲区，崩溃后可通过 GDB 导出最后 100 条日志
// 请补全
typedef enum {
    LOG_LEVEL_ERROR = 0,
    LOG_LEVEL_WARN  = 1,
    LOG_LEVEL_INFO  = 2,
    LOG_LEVEL_DEBUG = 3,
} log_level_t;

#define LOG_DEBUG(fmt, ...) \
    log_output(LOG_LEVEL_DEBUG, __FILE__, __LINE__, fmt, ##__VA_ARGS__)

void log_output(log_level_t level, const char *file, int line,
                const char *fmt, ...) {
    // 请补全：根据 level 决定是否输出
    // 添加时间戳
    // 写入环形缓冲区
}
```

## 自测与验收

1. WQ7036A 使用什么调试接口？JTAG、SWD、cJTAG 有什么区别？
2. GDB 的硬件断点为什么有数量限制？最多能用几个？
3. 逻辑分析仪和示波器的核心区别是什么？什么场景应该用逻辑分析仪而不是示波器？
4. 什么是 ITM？它相比串口打印有什么优势？
5. 串口打印的调试方式有什么局限？什么情况下应该避免使用？

## 延伸阅读

- [[debug-methodology-嵌入式调试方法论]] — 系统化的调试思路
- [[c-core-C语言核心]] — 指针和内存相关的常见 bug
- [[interrupt-concurrency-中断并发同步]] — 并发问题的排查
- [[reliability-exception-系统可靠性与异常处理]] — HardFault 和看门狗
- [[logging-design-日志系统设计]] — 日志系统设计
- `/home/ys/wq7036a/wq-audio/wqcore/components/startup/` — 启动代码中的调试接口配置

#flashcard
问：WQ7036A 使用什么调试接口？
答：cJTAG（Compact JTAG，2 线 JTAG），通过 TCK 和 TMS 两根线实现完整的 JTAG 调试功能。

问：GDB 硬件断点为什么有数量限制？
答：硬件断点需要 CPU 内部的比较器资源，数量有限（通常 4-8 个）。软件断点无数量限制但需要修改 Flash 中的指令。

问：逻辑分析仪和示波器的区别？
答：逻辑分析仪只看高低电平（数字信号），通道多（8-32 通道），适合协议解码。示波器看电压波形（模拟信号），精度高，适合信号质量分析。

问：什么是 ITM？
答：ARM CoreSight 的 Instrumentation Trace Macrocell，可以通过 SWO 引脚无侵入地输出日志，不占用 UART、不影响程序时序。

问：串口打印的局限是什么？
答：会改变程序时序（Heisenbug），中断里不能调用（可能阻塞），大量日志影响性能，Release 版本需要关闭。