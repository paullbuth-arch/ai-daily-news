# GDB 与 ftrace

**一句话结论（20% 核心）**：GDB 是嵌入式调试的"手术刀"——断点、单步、查看变量、栈回溯。ftrace 是 Linux 内核的"追踪器"——追踪函数调用链、中断延迟、调度行为。GDB 看"现在这一瞬间"，ftrace 看"过去发生了什么"。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：GDB = 暂停键，ftrace = 行车记录仪

- **GDB** = 视频播放器的暂停键：暂停 → 看当前画面 → 逐帧播放 → 修改参数 → 继续播放
- **ftrace** = 行车记录仪：记录过去一段时间发生的所有事情，事故后回放看是谁的责任

### 1.2 GDB 核心命令

```gdb
# 连接远程调试（OpenOCD）
target remote :3333

# 断点
break main                  # 在 main 函数设置断点
break uart.c:42             # 在 uart.c 第 42 行
watch counter               # 监视 counter 变量，值变化时暂停

# 运行控制
continue         # 继续运行
step             # 单步（进入函数）
next             # 单步（不进入函数）
finish           # 运行到当前函数返回

# 查看状态
print variable   # 打印变量值
backtrace        # 栈回溯（看谁调用了当前函数）
info registers   # 查看所有寄存器
info locals      # 查看局部变量
x/10x $sp        # 查看栈内存（10 个 word，十六进制）
```

### 1.3 ftrace 常用追踪

```bash
# 追踪函数调用
echo function > /sys/kernel/debug/tracing/current_tracer
echo "my_driver_*" > /sys/kernel/debug/tracing/set_ftrace_filter
cat /sys/kernel/debug/tracing/trace

# 追踪中断延迟
echo irqsoff > /sys/kernel/debug/tracing/current_tracer
```

### 1.4 如果只记得一件事

> GDB 用于暂停程序看状态（断点、单步、变量、栈回溯）。ftrace 用于追踪 Linux 内核行为（函数调用、中断延迟）。GDB 看现在，ftrace 看过往。

---

## 第二层：实战理解

### 2.1 HardFault 排查（GDB 最常用的场景）

```gdb
# 当 HardFault 发生时，GDB 自动停在异常入口
(gdb) backtrace
#0  HardFault_Handler () at startup.S:120
#1  <signal handler called>
#2  my_buggy_function () at app.c:42
#3  main () at main.c:15

(gdb) frame 2                  # 跳到 buggy 函数
(gdb) info locals              # 看局部变量
# ptr = 0x00000000              # 空指针！
```

### 2.2 常见坑

| 问题 | 现象 | 根因 |
|------|------|------|
| 优化后变量不可见 | `<optimized out>` | 编译时开了 `-O2`，调试用 `-O0 -g` |
| 断点不命中 | 程序跑飞了 | 代码被优化掉了，或者地址不对 |
| GDB 连不上 | connection refused | OpenOCD 没启动或端口不对 |

### 2.3 在 reGlasses 项目中怎么用

WQ7036AX 支持 JTAG 调试（通过 OpenOCD + GDB）。V881 支持 GDB 调试（通过 ADB 或串口）。GDB 主要用于排查 HardFault 和难以复现的 bug。

---

## 第三层：延伸阅读

- [[serial-jtag-swd-串口与JTAG调试]] — JTAG 硬件连接和 OpenOCD 配置
- [[debug-methodology-嵌入式调试方法论]] — 系统化调试流程