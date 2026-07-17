---
type: concept
tags: [debug, serial, jtag, swd, openocd, gdb, embedded]
aliases: [串口调试, JTAG, SWD, OpenOCD, 调试接口]
---

# 串口与 JTAG/SWD 调试

## 一句话结论

串口是最常用、最简单的调试手段（printf 输出，2 根线）。JTAG/SWD 是最强大的调试手段（暂停 CPU、单步执行、读写所有寄存器和内存，4-5 根线）。嵌入式开发中，串口是"眼睛"（80% 的问题用它），JTAG 是"显微镜"（排查 HardFault 和疑难 bug 的终极手段）。

## 30秒先看懂

- 串口调试是嵌入式开发最基本的调试手段——通过 UART 输出 printf 日志，只需要 TX/RX/GND 三根线。JTAG 使用 4-5 根信号线（TMS/TCK/TDI/TDO），SWD 是 ARM Cortex-M 的简化版本只用 2 根线（SWDIO/SWCLK）。WQ7036AX 是 RISC-V 架构，使用 JTAG 调试（不是 SWD）。日常开发 80% 的问题用串口 printf 就能定位，遇到 HardFault 和死锁等疑难 bug 才用 JTAG。printf 有副作用——每条日志约 7ms（115200 波特率下），大量日志会改变程序时序。WQ7036AX 的调试串口（UART1）和与 V881 通信的 UART 是同一个物理接口，调试和通信不能同时进行。

## 学完以后应该能做什么

**第一遍看完后可以：**
- 连接串口，使用 printf 输出调试信息
- 连接 JTAG 调试器，启动 OpenOCD 和 GDB
- 区分 JTAG 和 SWD 的适用场景
- 选择合适的调试器硬件

**进阶后可以：**
- 配置 OpenOCD 调试多核系统
- 实现轻量级日志系统（不阻塞、适合 ISR）
- 使用调试器测量程序执行时间
- 调试低功耗模式下的系统

## 前置知识

- UART 通信协议基础（波特率、数据位、停止位）
- GDB 基本使用
- 基本电路知识（电平、共地）

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 联合测试行动组 | JTAG | Joint Test Action Group，IEEE 1149.1 标准调试接口 |
| 串行线调试 | SWD | Serial Wire Debug，ARM 的 2 线调试接口 |
| 开放片上调试器 | OpenOCD | Open On-Chip Debugger，开源调试服务器软件 |
| 测试模式选择 | TMS | JTAG 的模式选择信号 |
| 测试时钟 | TCK | JTAG 的时钟信号（由调试器提供） |
| 测试数据输入 | TDI | JTAG 的数据输入（调试器到芯片） |
| 测试数据输出 | TDO | JTAG 的数据输出（芯片到调试器） |
| 通用异步收发器 | UART | Universal Asynchronous Receiver/Transmitter，串口通信 |
| 波特率 | Baud Rate | 串口通信速率，单位 bit/s |
| 轮询/中断 | Polling/Interrupt | 串口收发的两种方式 |

## 第一层：费曼心智模型

### 类比：日记 vs 监控摄像头

- **串口调试** = 你在代码里写日记（printf），运行时通过串口远程读日记。你只能看到你主动记录的内容。日记写得少，线索就少；日记太多，影响性能。
- **JTAG/SWD 调试** = 你在房间里装了监控摄像头。你可以随时暂停、回放（单步执行）、看任何角落（所有寄存器和内存）、修改任何东西（改变量值）。完全控制，但需要硬件支持。

**边界：**
- printf 影响时序——加日志后 bug 消失或移位是常见现象
- JTAG 不能调试低功耗模式——芯片进入深度睡眠后 JTAG 接口可能断开
- 串口输出不是免费的——每条日志约 7ms 的耗时

### 场景演练：程序崩溃后分析

1. 程序运行几分钟后崩溃，没有串口日志输出
2. 连接 JTAG 调试器，启动 OpenOCD
3. GDB 连接，发现停在 HardFault_Handler
4. 执行 `backtrace` 查看调用链
5. 发现崩溃在 `memcpy` 函数中
6. 查看调用者的局部变量，发现空指针
7. 定位到 bug：某个内存释放后未置 NULL
8. 修复后重新编译、下载、验证

## 第二层：原理/时序/约束

### JTAG vs SWD 对比

| 对比项 | JTAG | SWD |
|--------|------|-----|
| 引脚数 | 4-5 (TMS/TCK/TDI/TDO/TRST) | 2 (SWDIO/SWCLK) |
| 速度 | 较慢 | 较快 |
| 复杂度 | 高 | 低 |
| 多核支持 | 一个调试器管多个核 | 同样支持 |
| 典型芯片 | 传统 ARM、RISC-V（WQ7036AX） | ARM Cortex-M 系列 |

### WQ7036AX 的 JTAG 连接

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
```

### OpenOCD 配置

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

## 第三层：真实 SDK 代码

### 轻量级串口日志

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
```

### JTAG 多核调试

WQ7036AX 有三个核，JTAG 链可以同时访问：

```tcl
# OpenOCD 多核配置
target create acore riscv -chain-position wq7036/cpu0
target create bcore riscv -chain-position wq7036/cpu1
target create dcore xtensa -chain-position wq7036/cpu2
```

```gdb
# GDB 中切换核
(gdb) target remote :3333
(gdb) info threads       # 查看所有核
(gdb) thread 2            # 切换到 BCORE
```

### WQ7036AX 调试串口注意事项

WQ7036AX 的调试串口（UART1，GPIO50/51）和与 V881 通信的 UART 是同一个物理接口：
- 调试时不能同时用 UART 和 V881 通信（引脚冲突）
- 日常开发：串口输出日志（通过 USB 转串口接 PC）
- 发布版本：UART 用于和 V881 通信，日志关闭或只输出 ERROR 级别
- 遇到 HardFault：用 JTAG 连接调试器（不需要 UART）

## 第四层：正常/异常路径

### 正常路径

串口：初始化 UART → printf 输出 → 终端查看
JTAG：连接调试器 → 启动 OpenOCD → GDB 连接 → 调试

### 异常路径

| 异常场景 | 现象 | 原因 | 处理方式 |
|---------|------|------|---------|
| 串口乱码 | 全是乱码或没输出 | 波特率不匹配 | 换波特率试（57600/115200/230400） |
| JTAG 连不上 | "Error: init failed" | 接线错误或芯片未上电 | 检查接线和引脚电压 |
| printf 影响时序 | 加日志后 bug 消失 | printf 耗时改变了时序 | 用 GPIO 翻转代替 printf |
| OpenOCD 找不到芯片 | "unable to find target" | irlen 参数不对或芯片在低功耗模式 | 检查芯片配置和功耗状态 |
| 调试器驱动问题 | "libusb error" | 权限不够或驱动未安装 | 配置 udev 规则 |

## 第五层：调试方法

```c
// 用 GPIO 翻转代替 printf 测量时序
#define MEASURE_START()   GPIO_SET(HIGH)
#define MEASURE_END()     GPIO_SET(LOW)
// 用示波器或逻辑分析仪看 GPIO 高电平宽度

// 调试宏
#define DEBUG_PRINT(fmt, ...) \
    do { \
        printf("[%s:%d] " fmt "\n", __func__, __LINE__, ##__VA_ARGS__); \
    } while(0)
```

```bash
# 串口调试工具
screen /dev/ttyUSB0 115200
minicom -b 115200 -D /dev/ttyUSB0
picocom -b 115200 /dev/ttyUSB0

# 查看串口设备
ls -la /dev/ttyUSB*
dmesg | grep tty
```

## 第六层：实战练习

### 练习 1：串口输出（基础）

实现一个串口调试程序：
1. 初始化 UART（115200 波特率）
2. 实现 `printf` 重定向到 UART
3. 输出 "Hello World" 到串口
4. 实现 `hex_dump` 函数打印内存内容
5. 用串口终端软件接收并验证

### 练习 2：JTAG 调试（进阶）

使用 JTAG 调试器连接 WQ7036AX：
1. 连接 FTDI 调试器到 WQ7036AX 的 JTAG 接口
2. 启动 OpenOCD
3. 用 GDB 连接，复位芯片，加载固件
4. 设置断点，单步执行
5. 查看寄存器值和内存内容

### 练习 3：阅读 OpenOCD 配置（深入）

阅读 WQ7036AX 的 OpenOCD 配置文件，回答：
1. `adapter speed` 参数的单位是什么？如何选择合适的速度？
2. `irlen` 参数的含义是什么？如何确定正确的值？
3. 如何配置 JTAG 链上的多个 target？
4. 如何实现复位后暂停（halt）？

## 自测与验收

1. JTAG 和 SWD 的区别是什么？WQ7036AX 用哪种？
2. 串口调试的优缺点是什么？
3. printf 在 115200 波特率下，一行 80 字符的日志需要多少时间？
4. OpenOCD 的作用是什么？
5. 为什么 JTAG 连接不上时首先要检查 GND 是否共地？
6. 调试串口和通信串口共用引脚时，有什么设计约束？
7. 如何用 GPIO 翻转代替 printf 测量代码执行时间？

## 延伸阅读

- [[gdb-ftrace-GDB与ftrace]] — GDB 远程调试的详细用法
- [[debug-methodology-嵌入式调试方法论]] — 系统化调试流程
- [[uart-basics-UART基础]] — UART 协议基础

## #flashcard

**Q: JTAG 和 SWD 的区别？**
A: JTAG 用 4-5 根线（TMS/TCK/TDI/TDO），SWD 用 2 根线（SWDIO/SWCLK）。WQ7036AX（RISC-V）用 JTAG，ARM Cortex-M 用 SWD。

**Q: 串口调试的缺点？**
A: 只能看到主动记录的内容，printf 耗时影响时序（~7ms/行 @115200）。

**Q: OpenOCD 的作用？**
A: 作为 GDB Server，将 GDB 的调试命令通过 JTAG/SWD 协议发送到目标芯片。

**Q: printf 在多快的波特率下约 7ms/行？**
A: 115200 波特率下，一行 80 字符的日志约 7ms。

**Q: 为什么调试串口和通信串口共用引脚是设计约束？**
A: 调试和通信不能同时进行，发布版本需要关闭调试日志以释放 UART 给通信使用。