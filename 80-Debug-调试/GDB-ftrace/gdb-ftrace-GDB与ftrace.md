# GDB 与 ftrace

**一句话结论（20% 核心）**：GDB 是嵌入式调试的"手术刀"——通过 JTAG/SWD 连接芯片，断点、单步、查看所有寄存器和内存。ftrace 是 Linux 内核的"行车记录仪"——追踪函数调用链、中断延迟、调度行为。GDB 看"现在这一瞬间"，ftrace 看"过去发生了什么"。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：暂停键 vs 行车记录仪

- **GDB** = 视频播放器的暂停键：暂停 → 看当前画面 → 逐帧播放 → 修改变量 → 继续播放。你能完全控制程序的执行。
- **ftrace** = 行车记录仪：自动记录过去一段时间发生的所有事情。事故发生后回放，看是谁的责任、什么时候发生的。

**为什么两个都需要？** GDB 在你大致知道 bug 在哪时用（主动调试）。ftrace 在 bug 随机出现、难以复现时用（被动追踪）。GDB 改变了程序时序（Heisenbug），ftrace 几乎不影响程序运行。

### 1.2 GDB 远程调试的完整流程

```
PC (GDB 客户端)                 目标板 (GDB Server)
    │                                │
    │  riscv64-unknown-elf-gdb       │  OpenOCD (GDB Server)
    │  (gdb) target remote :3333 ───→│    │
    │                                │    │ JTAG/SWD
    │                                │  WQ7036AX 芯片
```

### 1.3 GDB 核心命令速查

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
info breakpoints               # 查看所有断点

# === 运行控制 ===
continue                       # 继续运行
step                           # 单步（进入函数调用）
next                           # 单步（跳过函数调用）
finish                         # 运行到当前函数返回
until 50                       # 运行到第 50 行

# === 查看状态 ===
print variable                 # 打印变量值
print /x variable              # 十六进制打印
backtrace                      # 栈回溯（谁调用了谁）
backtrace full                 # 带局部变量的栈回溯
info registers                 # 查看所有 CPU 寄存器
info frame                     # 查看当前栈帧信息
x/10x $sp                      # 查看栈内存（10 个 word，十六进制）

# === 修改变量 ===
set variable count = 0         # 修改内存中的变量值
set {int}0x20000000 = 42       # 修改任意地址的值
```

### 1.4 ftrace 常用追踪

```bash
# 追踪函数调用（看谁调用了谁）
echo function > /sys/kernel/debug/tracing/current_tracer
echo "my_driver_*" > /sys/kernel/debug/tracing/set_ftrace_filter
echo 1 > /sys/kernel/debug/tracing/tracing_on
cat /sys/kernel/debug/tracing/trace
# 输出:
# <...>-1234  [001]  123.456: my_driver_read <- vfs_read
# <...>-1234  [001]  123.457: my_driver_irq  <- __handle_irq

# 追踪中断延迟（最大关中断时间）
echo irqsoff > /sys/kernel/debug/tracing/current_tracer
echo 100 > /sys/kernel/debug/tracing/tracing_max_latency
cat /sys/kernel/debug/tracing/tracing_max_latency
# 单位: 微秒

# 追踪调度延迟
echo wakeup_rt > /sys/kernel/debug/tracing/current_tracer
```

### 1.5 如果只记得一件事

> GDB 通过 JTAG/SWD 控制芯片（断点、单步、读写所有内存和寄存器）。ftrace 追踪 Linux 内核的函数调用和延迟。GDB 看现在，ftrace 看过往。

---

## 第二层：实战理解

### 2.1 HardFault 排查完整流程（GDB 最核心的应用）

```gdb
# 场景：程序运行一段时间后崩溃，停在 HardFault_Handler

# Step 1: 看栈回溯，找到崩溃前的调用链
(gdb) backtrace
#0  HardFault_Handler () at startup.S:120
#1  <signal handler called>
#2  memcpy () at .../memcpy.S:12
#3  audio_process (buf=0x0, len=256) at audio.c:89
#4  audio_task (arg=0x0) at audio.c:120
#5  vTaskStartScheduler () at tasks.c:...

# Step 2: 跳到崩溃的函数
(gdb) frame 3
#3  audio_process (buf=0x0, len=256) at audio.c:89
# → buf 是空指针！这就是崩溃原因

# Step 3: 看局部变量确认
(gdb) info locals
# buf = 0x0           ← 空指针！
# len = 256
# i = 0

# Step 4: 看调用者是谁传了空指针
(gdb) frame 4
#4  audio_task (arg=0x0) at audio.c:120
(gdb) info locals
# local_buf = 0x20001000  ← 这里不是空指针，说明在传递过程中出问题

# Step 5: 检查内存（看 local_buf 地址的内容是否被破坏）
(gdb) x/16x 0x20001000
# 如果全 0 或全 0xFF，说明被 DMA 或其他任务覆盖了
```

### 2.2 用 GDB 调试多任务（FreeRTOS）

```gdb
# FreeRTOS 中每个任务有独立的 TCB（任务控制块）
# 查看任务列表
(gdb) print pxCurrentTCB
(gdb) print *pxCurrentTCB

# 查看当前任务的栈使用情况
(gdb) print uxTaskGetStackHighWaterMark(NULL)

# 切换到另一个任务的上下文（高级技巧）
# 需要知道任务的栈指针
(gdb) set $sp = pxCurrentTCB->pxTopOfStack
(gdb) backtrace  # 现在看到的是另一个任务的栈
```

### 2.3 用 ftrace 排查"某个任务偶尔卡顿"

```bash
# 场景：音频任务偶尔掉帧，但不知道是什么打断了它

# 追踪音频任务的调度延迟
echo wakeup_rt > /sys/kernel/debug/tracing/current_tracer
echo 1 > /sys/kernel/debug/tracing/tracing_on

# 等几分钟，看最大延迟
cat /sys/kernel/debug/tracing/tracing_max_latency
# 输出: 5000 us → 5ms 延迟！音频任务没及时唤醒

# 看是谁导致的延迟
cat /sys/kernel/debug/tracing/trace
# 发现是 SPI Flash 驱动在执行大块擦除时关了中断 5ms
```

### 2.4 常见坑（附排查方法）

| 问题 | 现象 | 排查方法 | 根因 |
|------|------|---------|------|
| 优化后变量不可见 | `<optimized out>` | 编译时用 `-O0 -g` 调试 | 编译器优化掉了变量或放到了寄存器 |
| 断点不命中 | 程序跑飞了 | 检查地址是否正确 | 代码被优化掉，或被链接到了不同的地址 |
| GDB 连不上 | connection refused | `ps aux | grep openocd` | OpenOCD 没启动或端口不对 |
| 单步时程序行为异常 | 中断触发时序乱了 | 用硬件断点代替软件断点 | GDB 用软件断点修改了 Flash/内存 |

### 2.5 在 reGlasses 项目中怎么用

**WQ7036AX 调试**：
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

**V881 调试**：
```bash
# V881 通常通过 ADB 或串口调试
adb shell
# 或
gdbserver :1234 --attach $(pidof cam_service)
```

---

## 第三层：深入扩展

### 3.1 GDB 脚本化：自动化调试

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

### 3.2 常见问题

- **为什么 GDB 单步调试时中断不触发？** 因为 GDB 暂停了 CPU，中断控制器虽然收到了中断信号，但 CPU 没有响应。单步调试时中断行为不可靠，要用日志或硬件断点代替。
- **ftrace 和 perf 的区别？** ftrace 追踪内核函数调用和延迟，perf 做性能分析和统计（CPU 热点、cache miss）。ftrace 看"谁调用了谁"，perf 看"谁最慢"。
- **GDB 和 printf 调试的选择？** 时序敏感的 bug 用 printf（GDB 改变时序），crash 和逻辑 bug 用 GDB。实际开发中 80% 的问题用 printf 就能定位。

### 3.3 延伸阅读

- [[serial-jtag-swd-串口与JTAG调试]] — JTAG 硬件连接和 OpenOCD 配置
- [[debug-methodology-嵌入式调试方法论]] — 系统化调试流程
- [[crashdump-perf-Crashdump与性能分析]] — crashdump 和 perf 性能分析