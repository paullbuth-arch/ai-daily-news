# 串口与 JTAG/SWD 调试

**一句话结论（20% 核心）**：串口是最简单、最常用的调试手段（printf 输出到串口）。JTAG/SWD 是更强大的调试方式（可以暂停 CPU、单步执行、查看所有寄存器和内存）。嵌入式开发中，串口是"眼睛"，JTAG 是"显微镜"。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：串口 = 日记，JTAG = 监控摄像头

- **串口调试** = 你在代码里写日记（printf），运行时通过串口读日记。你只能看到你主动记录的内容。
- **JTAG/SWD 调试** = 你在房间里装了监控摄像头。你可以暂停程序、看每个寄存器的值、单步执行、修改内存——完全控制。

### 1.2 串口 vs JTAG/SWD 对比

| | 串口 (UART) | JTAG/SWD |
|---|---|---|
| 连接方式 | 2 线 (TX/RX) | 4-5 线 (JTAG) / 2 线 (SWD) |
| 能做什么 | 输出日志、输入命令 | 暂停/单步/断点/读写所有内存和寄存器 |
| 对程序的影响 | 轻微（printf 耗时） | 暂停时完全停止 |
| 硬件要求 | 任何芯片都有 | 需要芯片支持调试接口 |
| 典型用途 | 日常调试、日志输出 | 排查 HardFault、性能分析、Flash 烧录 |

### 1.3 如果只记得一件事

> 串口 = printf 输出到终端，最简单的调试方式。JTAG/SWD = 可以暂停 CPU 看一切，排查 HardFault 的终极手段。

---

## 第二层：实战理解

### 2.1 WQ7036AX 的串口调试

WQ7036AX 的调试串口使用 UART1（GPIO50/51，115200-8N1），通过 USB 转串口连接 PC。SDK 的 debug log 系统通过这个串口输出。

```bash
# PC 端连接串口
minicom -D /dev/ttyUSB0 -b 115200
# 或
screen /dev/ttyUSB0 115200
```

### 2.2 JTAG 调试 WQ7036AX

```bash
# 启动 OpenOCD（JTAG 调试服务器）
openocd -f interface/ftdi.cfg -f target/wq7036.cfg

# 另开终端，GDB 连接
riscv64-unknown-elf-gdb build/acore/app.elf
(gdb) target remote :3333
(gdb) monitor reset halt
(gdb) break main
(gdb) continue
```

### 2.3 常见坑

| 问题 | 现象 | 根因 |
|------|------|------|
| 串口乱码 | 输出全是乱码 | 波特率不匹配 |
| JTAG 连不上 | OpenOCD 报错 | 接线错误、芯片未上电、复位脚被拉低 |
| printf 影响时序 | 加日志后 bug 消失 | printf 耗时改变了时序（Heisenbug） |

### 2.4 在 reGlasses 项目中怎么用

WQ7036AX 的调试串口是 UART1（GPIO50/51），和 V881 通信的 UART 是同一个——调试时不能同时用。日常开发用串口输出日志，遇到 HardFault 时用 JTAG 定位崩溃点。

---

## 第三层：延伸阅读

- [[debug-methodology-嵌入式调试方法论]] — 系统化的调试流程
- [[gdb-ftrace-GDB与ftrace]] — GDB 远程调试的详细用法