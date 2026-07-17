# 串口与 JTAG/SWD 调试

**一句话结论（20% 核心）**：串口是最常用、最简单的调试手段（printf 输出，2 根线）。JTAG/SWD 是最强大的调试手段（暂停 CPU、单步执行、读写所有寄存器和内存，4-5 根线）。嵌入式开发中，串口是"眼睛"（80% 的问题用它），JTAG 是"显微镜"（排查 HardFault 和疑难 bug 的终极手段）。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：日记 vs 监控摄像头

- **串口调试** = 你在代码里写日记（printf），运行时通过串口远程读日记。你只能看到你**主动记录**的内容。日记写得少，线索就少；日记太多，影响性能。
- **JTAG/SWD 调试** = 你在房间里装了监控摄像头。你可以随时暂停、回放（单步执行）、看任何角落（所有寄存器和内存）、修改任何东西（改变量值）。**完全控制，但需要硬件支持。**

### 1.2 JTAG vs SWD：两种调试协议

| | JTAG | SWD |
|---|---|---|
| 引脚数 | 4-5 (TMS/TCK/TDI/TDO/TRST) | **2 (SWDIO/SWCLK)** |
| 速度 | 较慢 | 较快 |
| 复杂度 | 高 | 低 |
| 多核支持 | 一个调试器管多个核 | 同样支持 |
| 调试器 | J-Link, OpenOCD | J-Link, OpenOCD, ST-Link |
| 典型芯片 | 传统 ARM | **ARM Cortex-M 系列** |
| WQ7036AX | 支持 JTAG (RISC-V) | 不适用（RISC-V 用 JTAG） |

**WQ7036AX 是 RISC-V 架构，用 JTAG 调试**（不是 SWD）。ARM Cortex-M 芯片（如 STM32）通常用 SWD（更简单，2 根线）。

### 1.3 调试器硬件选型

| 调试器 | 价格 | 支持芯片 | 特点 |
|--------|------|---------|------|
| **J-Link EDU** | ~$60 | ARM + RISC-V | 行业标准，软件生态最好 |
| **FTDI FT2232H** | ~$30 | 通用（通过 OpenOCD） | WQ7036AX 常用，便宜够用 |
| **ST-Link** | ~$5 | STM32（ARM） | 最便宜，但只支持 STM32 |
| **DAP-Link** | ~$10 | ARM Cortex-M | 开源，ARM 官方推荐 |

### 1.4 如果只记得一件事

> 串口 = printf 输出，最简单的日常调试。JTAG/SWD = 暂停 CPU 看一切，排查 HardFault 的终极手段。WQ7036AX 用 JTAG（RISC-V），STM32 用 SWD（ARM）。日常开发 80% 用串口，遇到崩溃用 JTAG。

---

## 第二层：实战理解

### 2.1 WQ7036AX 的调试硬件连接

```
WQ7036AX 调试接口 (JTAG):
  TMS  ──→  模式选择
  TCK  ──→  时钟（由调试器提供）
  TDI  ──→  数据输入（调试器→芯片）
  TDO  ←──  数据输出（芯片→调试器）
  GND  ──  共地（必须接！）

FTDI FT2232H:
  ADBUS0 → TCK
  ADBUS1 → TDI
  ADBUS2 → TDO
  ADBUS3 → TMS

连接顺序：
  1. 先接 GND
  2. 再接 JTAG 信号线
  3. 最后给芯片上电（或先上电也行，JTAG 支持热插拔）
```

### 2.2 OpenOCD 配置

```tcl
# openocd.cfg for WQ7036AX
interface ftdi
ftdi_vid_pid 0x0403 0x6010
ftdi_channel 0

adapter speed 1000

transport select jtag

# RISC-V target
set _CHIPNAME wq7036
jtag newtap $_CHIPNAME cpu -irlen 5 -expected-id 0x??????

target create $_CHIPNAME.cpu riscv -chain-position $_CHIPNAME/cpu
init
reset halt
```

```bash
# 启动 OpenOCD
openocd -f openocd.cfg
# 另开终端
riscv64-unknown-elf-gdb build/acore/app.elf
(gdb) target remote :3333
```

### 2.3 串口调试的进阶技巧

```c
// 轻量级日志宏（不阻塞，适合中断中使用）
#define DBG_UART(ch) \
    do { while (!(UART_SR & UART_SR_TXE)); UART_DR = (ch); } while(0)

// 十六进制 dump
void hex_dump(const uint8_t *data, int len) {
    for (int i = 0; i < len; i++) {
        DBG_UART("0123456789ABCDEF"[data[i] >> 4]);
        DBG_UART("0123456789ABCDEF"[data[i] & 0xF]);
        DBG_UART(' ');
    }
    DBG_UART('\n');
}

// 打印寄存器值
#define DUMP_REG(name) printf("%s = 0x%08lx\n", #name, (uint32_t)name)
```

### 2.4 常见坑

| 问题 | 现象 | 排查方法 | 根因 |
|------|------|---------|------|
| 串口乱码 | 全是乱码或没输出 | 换波特率试（57600/115200/230400） | 波特率不匹配 |
| JTAG 连不上 | "Error: init failed" | 检查接线，测量各引脚电压 | 接线错误、芯片未上电、复位脚被拉低 |
| printf 影响时序 | 加日志后 bug 消失或移位 | 用 GPIO 翻转代替 printf | printf 耗时（~1ms/条）改变了时序 |
| OpenOCD 找不到芯片 | "Error: unable to find target" | 检查 JTAG 接口的 irlen 参数 | 芯片配置不对，或芯片处于低功耗模式 |

### 2.5 在 reGlasses 项目中怎么用

WQ7036AX 的调试串口（UART1，GPIO50/51）和 V881 通信的 UART 是**同一个物理接口**。这意味着：
- **调试时不能同时用 UART 和 V881 通信**（引脚冲突）
- 日常开发：串口输出日志（通过 USB 转串口接 PC）
- 发布版本：UART 用于和 V881 通信，日志关闭或只输出 ERROR 级别
- 遇到 HardFault：用 JTAG 连接调试器（不需要 UART）

---

## 第三层：深入扩展

### 3.1 JTAG 链和多核调试

```
WQ7036AX 有三个核，JTAG 链可以同时访问：
  TDI → ACORE (RISC-V) → BCORE (RISC-V) → DCORE (Xtensa) → TDO

OpenOCD 可以同时调试多个核：
  target create acore riscv -chain-position wq7036/cpu0
  target create bcore riscv -chain-position wq7036/cpu1
  target create dcore xtensa -chain-position wq7036/cpu2

GDB 中切换：
  (gdb) target remote :3333
  (gdb) info threads       # 查看所有核
  (gdb) thread 2            # 切换到 BCORE
```

### 3.2 常见问题

- **JTAG 和 SWD 电气上兼容吗？** 不兼容。JTAG 用 4-5 根线，SWD 用 2 根线。但 SWD 可以复用 JTAG 的引脚（SWDIO 用 TMS，SWCLK 用 TCK）。
- **为什么 WQ7036AX 的 UART 和 V881 通信共用引脚？** 硬件设计时为了节省引脚。这是 reGlasses 的一个设计约束——调试和通信不能同时进行。
- **printf 到底有多慢？** 115200 波特率下，一个字符约 86μs。一行 80 字符的日志约 7ms。如果每秒打 10 行日志，CPU 7% 时间花在日志上。

### 3.3 延伸阅读

- [[gdb-ftrace-GDB与ftrace]] — GDB 远程调试的详细用法
- [[debug-methodology-嵌入式调试方法论]] — 系统化调试流程
- [[uart-basics-UART基础]] — UART 协议基础