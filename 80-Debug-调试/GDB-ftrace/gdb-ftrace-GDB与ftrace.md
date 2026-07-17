---
type: concept
tags: [debug, gdb, ftrace, performance, tracing, linux, embedded]
aliases: [GDB与ftrace, 调试, 追踪, 性能分析]
---

# GDB 与 ftrace

## 一句话结论

GDB 是嵌入式调试的"手术刀"——通过 JTAG/SWD 连接芯片，断点、单步、查看所有寄存器和内存。ftrace 是 Linux 内核的"行车记录仪"——追踪函数调用链、中断延迟、调度行为。GDB 看"现在这一瞬间"，ftrace 看"过去发生了什么"。

## 30秒先看懂

- GDB 远程调试的典型流程是：PC 上运行 GDB 客户端，通过 OpenOCD（GDB Server）连接到目标芯片的 JTAG 接口。GDB 的核心能力包括：断点（函数断点、行号断点、条件断点、变量监视）、单步执行（step/next/finish）、查看状态（print/backtrace/info registers/x）和修改变量。ftrace 是 Linux 内核内置的追踪工具，可以追踪函数调用（function tracer）、中断延迟（irqsoff tracer）、调度延迟（wakeup tracer）等。GDB 改变了程序时序（Heisenbug 现象），ftrace 几乎不影响程序运行。

## 学完以后应该能做什么

**第一遍看完后可以：**
- 使用 GDB 远程调试嵌入式程序（连接、断点、单步、查看变量）
- 在 HardFault 发生时用 GDB 栈回溯定位崩溃原因
- 使用 ftrace 追踪内核函数调用链
- 理解 GDB 和 ftrace 的适用场景差异

**进阶后可以：**
- 编写 GDB 脚本自动化调试流程
- 使用 ftrace 排查内核延迟和调度问题
- 调试 FreeRTOS 多任务系统（查看任务列表、任务栈）
- 使用 perf 做性能分析

## 前置知识

- 编译和调试的关系（-g 选项、符号表）
- 栈的基本概念（栈帧、压栈、出栈）
- Linux 内核基础（sysfs、debugfs）

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| GNU 调试器 | GDB | GNU Debugger，功能强大的源码级调试器 |
| 函数追踪 | ftrace | Function Tracer，Linux 内核函数调用追踪工具 |
| 远程调试 | Remote Debugging | GDB 客户端通过网络连接到目标板的 GDB Server |
| 断点 | Breakpoint | 程序执行到指定位置时暂停 |
| 栈回溯 | Backtrace | 从当前函数到 main() 的调用链 |
| 单步执行 | Step / Next | 逐条语句执行，step 进入函数，next 跳过函数 |
| 程序计数器 | PC | Program Counter，当前执行指令的地址 |
| 符号表 | Symbol Table | ELF 文件中函数名和地址的对应关系 |
| 条件断点 | Conditional Breakpoint | 满足特定条件时才暂停的断点 |
| 海森堡 bug | Heisenbug | 调试时改变程序行为导致 bug 消失或改变的现象 |

## 第一层：费曼心智模型

### 类比：暂停键 vs 行车记录仪

- **GDB** = 视频播放器的暂停键：暂停 → 看当前画面 → 逐帧播放 → 修改变量 → 继续播放。你能完全控制程序的执行。
- **ftrace** = 行车记录仪：自动记录过去一段时间发生的所有事情。事故发生后回放，看是谁的责任、什么时候发生的。

**为什么两个都需要？** GDB 在你大致知道 bug 在哪时用（主动调试）。ftrace 在 bug 随机出现、难以复现时用（被动追踪）。GDB 改变了程序时序（Heisenbug），ftrace 几乎不影响程序运行。

**边界：**
- GDB 不能用于时序敏感的 bug——单步执行会改变中断响应时间
- ftrace 只适用于 Linux 内核——FreeRTOS 上没有 ftrace
- GDB 断点会修改 Flash 中的指令（软件断点）——硬件断点数量有限

### 场景演练：HardFault 排查

1. 程序崩溃，停在 HardFault_Handler
2. GDB 中执行 `backtrace` 查看调用链
3. 看到 `#0 HardFault_Handler` → `#1 signal handler` → `#2 memcpy` → `#3 audio_process`
4. 执行 `frame 3` 切换到 audio_process 的栈帧
5. 执行 `info locals` 查看局部变量，发现 `buf = 0x0`（空指针）
6. 执行 `frame 4` 查看调用者，看谁传了空指针
7. 定位到 bug：某个任务在释放内存后未置 NULL，导致后续使用空指针

## 第二层：原理/时序/约束

### GDB 远程调试架构

```
PC (GDB 客户端)                 目标板 (GDB Server)
    │                                │
    │  riscv64-unknown-elf-gdb       │  OpenOCD (GDB Server)
    │  (gdb) target remote :3333 ───→│    │
    │                                │    │ JTAG/SWD
    │                                │  WQ7036AX 芯片
```

### GDB 核心命令

```gdb
# === 连接和加载 ===
target remote :3333           # 连接远程 GDB Server
monitor reset halt             # 复位芯片并暂停
load                           # 下载固件到芯片
file app.elf                   # 加载符号表

# === 断点 ===
break main                     # 函数断点
break uart.c:42                # 文件行号断点
break uart.c:42 if count > 10  # 条件断点
watch counter                  # 监视变量（值变化时暂停）

# === 运行控制 ===
continue                       # 继续运行
step                           # 单步（进入函数调用）
next                           # 单步（跳过函数调用）
finish                         # 运行到当前函数返回

# === 查看状态 ===
print variable                 # 打印变量值
backtrace full                 # 带局部变量的栈回溯
info registers                 # 查看所有 CPU 寄存器
x/10x $sp                      # 查看栈内存（10 个 word，十六进制）
```

### ftrace 常用追踪

```bash
# 追踪函数调用
echo function > /sys/kernel/debug/tracing/current_tracer
echo "my_driver_*" > /sys/kernel/debug/tracing/set_ftrace_filter
echo 1 > /sys/kernel/debug/tracing/tracing_on
cat /sys/kernel/debug/tracing/trace

# 追踪中断延迟（最大关中断时间）
echo irqsoff > /sys/kernel/debug/tracing/current_tracer
echo 100 > /sys/kernel/debug/tracing/tracing_max_latency
cat /sys/kernel/debug/tracing/tracing_max_latency

# 追踪调度延迟
echo wakeup_rt > /sys/kernel/debug/tracing/current_tracer
```

## 第三层：真实 SDK 代码

### WQ7036AX 调试配置

```bash
# 启动 OpenOCD（JTAG 调试服务器）
openocd -f interface/ftdi.cfg -f target/wq7036.cfg

# GDB 连接
riscv64-unknown-elf-gdb build/acore/glass_acore.elf
(gdb) target remote :3333
(gdb) monitor reset halt
(gdb) load       # 下载固件
(gdb) continue   # 开始运行
```

### GDB 脚本化调试

```gdb
# .gdbinit 文件：GDB 启动时自动执行
define dump_task_info
    printf "Current Task: %s\n", pxCurrentTCB->pcTaskName
    printf "Stack High Water: %d\n", uxTaskGetStackHighWaterMark(NULL)
    backtrace
end

# 断点命中时自动执行
break audio_process if buf == 0
commands
    printf "NULL buf detected!\n"
    backtrace
    dump_task_info
end
```

### 用 ftrace 排查卡顿

```bash
# 场景：音频任务偶尔掉帧，但不知道是什么打断了它
# 追踪音频任务的调度延迟
echo wakeup_rt > /sys/kernel/debug/tracing/current_tracer
echo 1 > /sys/kernel/debug/tracing/tracing_on

# 等几分钟，看最大延迟
cat /sys/kernel/debug/tracing/tracing_max_latency
# 输出: 5000 us → 5ms 延迟！

# 看是谁导致的延迟
cat /sys/kernel/debug/tracing/trace
# 发现是 SPI Flash 驱动在执行大块擦除时关了中断 5ms
```

## 第四层：正常/异常路径

### 正常路径

GDB：连接 → 加载符号 → 设断点 → 运行 → 命中断点 → 检查状态 → 继续/单步

### 异常路径

| 异常场景 | 现象 | 原因 | 处理方式 |
|---------|------|------|---------|
| 优化后变量不可见 | `<optimized out>` | 编译器优化把变量放寄存器或优化掉了 | 编译时用 `-O0 -g` |
| 断点不命中 | 程序跑飞了 | 代码被优化或链接到不同地址 | 检查反汇编确认地址 |
| GDB 连不上 | connection refused | OpenOCD 没启动或端口不对 | 检查 OpenOCD 状态 |
| 单步时序异常 | 中断触发时序乱了 | GDB 暂停 CPU 影响中断响应 | 用硬件断点或 printf 替代 |
| ftrace 无输出 | 空文件 | 权限不够或 tracer 不支持 | 检查 debugfs 挂载和权限 |

## 第五层：调试方法

### HardFault 排查完整流程

```gdb
# Step 1: 看栈回溯
(gdb) backtrace

# Step 2: 跳到崩溃的函数
(gdb) frame 3

# Step 3: 看局部变量
(gdb) info locals

# Step 4: 看调用者
(gdb) frame 4
(gdb) info locals

# Step 5: 检查内存
(gdb) x/16x 0x20001000
```

### FreeRTOS 多任务调试

```gdb
# 查看任务列表
(gdb) print pxCurrentTCB
(gdb) print *pxCurrentTCB

# 查看当前任务的栈使用情况
(gdb) print uxTaskGetStackHighWaterMark(NULL)

# 切换到另一个任务的上下文
(gdb) set $sp = pxCurrentTCB->pxTopOfStack
(gdb) backtrace
```

### ftrace 调试技巧

```bash
# 只追踪特定函数
echo function > current_tracer
echo "my_driver_*" > set_ftrace_filter

# 不追踪某些函数（减少噪音）
echo "rcu*" > set_ftrace_notrace

# 追踪特定进程
echo 1234 > set_ftrace_pid

# 查看追踪结果
cat trace
# 或使用 trace-cmd 保存到文件
trace-cmd record -p function -l "my_driver_*"
```

## 第六层：实战练习

### 练习 1：GDB 断点调试（基础）

用 GDB 调试一个简单的程序：
1. 编译一个带 `-g` 选项的简单 C 程序
2. 设置函数断点、行号断点、条件断点
3. 单步执行，观察变量变化
4. 使用 `backtrace` 查看调用栈
5. 使用 `info registers` 查看寄存器

### 练习 2：HardFault 模拟与排查（进阶）

故意触发一个 HardFault，然后用 GDB 排查：
1. 写一个空指针解引用的函数
2. 编译运行，触发 HardFault
3. 用 GDB 连接，执行 `backtrace`
4. 定位到崩溃的函数和行号
5. 分析为什么传入了空指针

### 练习 3：阅读调试配置（深入）

阅读 WQ7036AX 的 OpenOCD 配置文件，回答：
1. OpenOCD 配置文件中的 `adapter speed` 参数的作用是什么？
2. JTAG 链中 `irlen` 参数的含义是什么？
3. RISC-V target 的创建命令是什么？
4. 如何配置同时调试三个核（ACORE/BCORE/DCORE）？

## 自测与验收

1. GDB 和 ftrace 的适用场景有什么不同？
2. 为什么 GDB 单步调试时中断行为不可靠？
3. 什么是 Heisenbug？在调试中如何避免？
4. ftrace 的 `function` 和 `irqsoff` tracer 分别用来追踪什么？
5. 编译优化（`-O2`）对 GDB 调试有什么影响？
6. 如何用 GDB 查看 FreeRTOS 的任务栈使用情况？
7. 什么是条件断点？在什么场景下使用？

## 延伸阅读

- [[serial-jtag-swd-串口与JTAG调试]] — JTAG 硬件连接和 OpenOCD 配置
- [[debug-methodology-嵌入式调试方法论]] — 系统化调试流程
- [[crashdump-perf-Crashdump与性能分析]] — crashdump 和 perf 性能分析

## #flashcard

**Q: GDB 和 ftrace 的区别？**
A: GDB 看"现在这一瞬间"（断点/单步），ftrace 看"过去发生了什么"（函数调用记录）。

**Q: 什么是 Heisenbug？**
A: 调试行为改变了程序原本的时序和行为，导致 bug 消失或改变。

**Q: GDB 远程调试的三个组件是什么？**
A: GDB 客户端（PC）、GDB Server（OpenOCD）、目标芯片（通过 JTAG 连接）。

**Q: 为什么 GDB 单步调试时中断不触发？**
A: GDB 暂停了 CPU，中断控制器虽然收到信号但 CPU 没有响应。

**Q: ftrace 的 irqsoff tracer 追踪什么？**
A: 追踪最大关中断时间，用来排查中断延迟导致的实时性问题。