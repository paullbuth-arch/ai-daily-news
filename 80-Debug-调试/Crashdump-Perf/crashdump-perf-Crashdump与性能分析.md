---
type: concept
tags: [debug, crashdump, perf, performance, analysis, linux, embedded]
aliases: [Crashdump, 性能分析, 崩溃分析]
---

# Crashdump 与性能分析

## 一句话结论

crashdump（core dump）是程序崩溃时的"死亡快照"——保存崩溃瞬间的内存、寄存器、调用栈，用于事后分析。perf 是 Linux 性能分析工具——看 CPU 时间花在哪、cache miss 在哪、哪些函数最慢。

## 30秒先看懂

- crashdump 包含崩溃时的所有寄存器值（PC、SP、LR）、调用栈（哪个函数调用了哪个函数）、内存内容（变量值）和崩溃原因（HardFault/MemManage/BusFault/UsageFault）。在嵌入式 MCU 中（如 WQ7036AX），crashdump 通常由 HardFault_Handler 保存到 .noinit 段（复位后不丢失），复位后可以通过串口或 GDB 读取。perf 是 Linux 性能分析工具，核心功能包括：perf top（实时查看最耗 CPU 的函数）、perf record/perf report（记录并分析性能数据）、perf stat（统计 cache miss 等硬件事件）。crashdump 回答"为什么崩溃"，perf 回答"为什么慢"。

## 学完以后应该能做什么

**第一遍看完后可以：**
- 实现 HardFault_Handler 保存崩溃现场
- 复位后读取崩溃信息，定位崩溃代码行
- 使用 perf top 查看 CPU 热点函数
- 理解 crashdump 和 perf 的适用场景

**进阶后可以：**
- 生成 perf 火焰图，直观分析性能瓶颈
- 使用 perf 分析 cache miss 和分支预测失败
- 实现更完善的 crashdump 系统（保存完整栈内容）
- 使用 perf 进行实时系统的延迟分析

## 前置知识

- 栈和栈帧的概念
- 函数调用约定（参数传递、返回值）
- Linux 基本命令行操作

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 崩溃转储 | Crashdump / Core Dump | 崩溃时保存的内存、寄存器、调用栈快照 |
| 性能分析 | perf | Linux 性能分析工具，基于性能监控单元（PMU） |
| 程序计数器 | PC | Program Counter，崩溃时的指令地址 |
| 栈回溯 | Backtrace | 从崩溃点到 main() 的完整调用链 |
| 火焰图 | Flame Graph | 可视化 CPU 时间分布的金字塔图 |
| 硬件事件 | Hardware Event | CPU 内置的性能事件（cache miss、分支预测失败） |
| PMU | Performance Monitoring Unit | CPU 内部的性能监控硬件单元 |
| 热点函数 | Hotspot Function | 占用 CPU 时间最多的函数 |
| 采样 | Sampling | perf 周期性采样程序计数器，统计函数执行时间 |
| 调用链 | Call Chain | 函数调用关系链 |

## 第一层：费曼心智模型

### 类比：飞机黑匣子 vs 油耗记录仪

- **crashdump** = 飞机黑匣子：坠毁后打开，看失事前最后几秒发生了什么
- **perf** = 油耗记录仪：记录每段路程的油耗，找出最费油的路线

**边界：**
- crashdump 需要提前设计好保存机制——崩溃后没有机会再输出信息
- .noinit 段在复位后保留，但掉电后会丢失——需要保存到 Flash 才能持久化
- perf 采样会影响程序性能——但影响很小（通常 < 2%）

### 场景演练：系统崩溃后分析

1. 嵌入式设备运行 2 小时后崩溃
2. 看门狗复位系统
3. 启动代码检测到复位原因是 HardFault
4. 读取 .noinit 段中保存的 crashdump 信息
5. 串口输出：`PC=0x00001234, LR=0x00005678`
6. 用 `addr2line -e app.elf 0x00001234` 定位到 `audio.c:89`
7. 查看 89 行附近代码，发现 `memcpy(buf, src, len)` 中 `buf` 可能为空
8. 修复代码：在调用 `memcpy` 前检查 `buf != NULL`

## 第二层：原理/时序/约束

### WQ7036AX 的 HardFault 保存

```c
// HardFault Handler 中保存 crash 信息
void HardFault_Handler(void) {
    // 把栈帧保存到 .noinit 段（复位后不丢失）
    crash_info_t *crash = (crash_info_t *)CRASH_INFO_ADDR;
    crash->r0  = __get_R0();   // 或从栈帧中提取
    crash->pc  = __get_PC();   // 崩溃时的程序计数器
    crash->lr  = __get_LR();   // 返回地址
    crash->sp  = __get_SP();   // 栈指针
    crash->cfsr = __get_CFSR(); // 可配置故障状态寄存器（ARM 特有）

    // 保存完成后复位
    NVIC_SystemReset();
}

// 复位后读取崩溃信息
void main(void) {
    // 检查是否有上次的崩溃记录
    if (is_watchdog_reset() || is_hardfault_reset()) {
        crash_info_t *info = (crash_info_t *)CRASH_INFO_ADDR;
        if (info && info->pc != 0xFFFFFFFF) {
            log_error("Previous crash: PC=0x%08X, LR=0x%08X",
                      info->pc, info->lr);
        }
    }
    // ... 正常启动 ...
}
```

### Linux perf 常用命令

```bash
# 查看 CPU 热点（哪些函数最耗时）
perf top

# 记录性能数据
perf record -g ./my_app

# 查看性能报告
perf report

# 生成火焰图
perf script | FlameGraph/stackcollapse-perf.pl | FlameGraph/flamegraph.pl > flame.svg

# 统计硬件事件
perf stat -e cache-misses,branch-misses,cycles,instructions ./my_app

# 统计系统级性能
perf stat -a sleep 10
```

## 第三层：真实 SDK 代码

### 复位原因分析

参考 `/home/ys/wq7036a/wq-audio/wqcore/components/startup/boot/src/boot_reason.c`：

```c
void check_reset_reason(void) {
    uint32_t reason = read_reset_reason();

    if (reason & RESET_REASON_WDT) {
        LOG_WARN("Watchdog timeout reset");
    } else if (reason & RESET_REASON_SOFT) {
        LOG_INFO("Software reset");
    } else if (reason & RESET_REASON_HARDFAULT) {
        LOG_ERROR("HardFault crash!");
        dump_crash_info();
    }
}
```

### GDB 分析 crashdump

```bash
# 用 GDB 加载 crashdump 分析
riscv64-unknown-elf-gdb build/acore/app_acore.elf

# 如果 crashdump 保存了完整的栈内容，可以直接加载
(gdb) target remote :3333
(gdb) monitor reset halt
(gdb) # 读取 crashdump 中的 PC 值
(gdb) print *(uint32_t *)CRASH_INFO_ADDR
(gdb) # 查看崩溃地址附近的代码
(gdb) x/10i 崩溃PC地址
```

## 第四层：正常/异常路径

### 正常路径

crashdump：HardFault → 保存关键寄存器到 .noinit → 复位 → 读取复位原因 → 输出崩溃信息 → 正常启动

### 异常路径

| 异常场景 | 现象 | 原因 | 处理方式 |
|---------|------|------|---------|
| crashdump 被覆盖 | 第二次崩溃后第一次的信息丢失 | 每次都写到同一个地址 | 保存到 Flash 的不同区域 |
| 优化后栈回溯不准 | GDB 显示错误调用链 | 编译优化省略了栈帧指针 | 用 `-fno-omit-frame-pointer` |
| perf 数据不完整 | 看不到某些函数 | 符号表被 strip 了 | 编译时加 `-g`，保留符号 |
| .noinit 段被清零 | 复位后丢失 crash 信息 | 启动代码中清除了 noinit 段 | 确保启动代码跳过 .noinit 段 |
| 栈指针被破坏 | crashdump 保存失败 | 栈指针本身已经损坏 | 使用专用的 crash 寄存器保存 |

## 第五层：调试方法

```bash
# 分析 crashdump
# 方法 1：用 addr2line 定位
riscv64-unknown-elf-addr2line -e build/acore/app_acore.elf -f 崩溃PC地址

# 方法 2：用 objdump 反汇编
riscv64-unknown-elf-objdump -d build/acore/app_acore.elf | grep -A10 "崩溃PC地址:"

# 方法 3：用 GDB 加载 crashdump
(gdb) target remote :3333
(gdb) monitor reset halt
(gdb) x/16x CRASH_INFO_ADDR  # 查看 crashdump 原始内容
```

```bash
# perf 分析
# 生成火焰图
perf record -g -F 99 ./my_app  # 99Hz 采样
perf script > out.perf
FlameGraph/stackcollapse-perf.pl out.perf > out.folded
FlameGraph/flamegraph.pl out.folded > flame.svg

# 实时分析
perf top -p $(pidof my_app)

# 统计 cache 性能
perf stat -e cache-misses,cache-references ./my_app
```

## 第六层：实战练习

### 练习 1：实现 crashdump 保存（基础）

在 WQ7036AX 上实现崩溃信息保存：
1. 在链接脚本中定义 .noinit 段
2. 在 HardFault_Handler 中保存 PC、LR、SP 到 .noinit 段
3. 复位后在 main() 中读取并输出崩溃信息
4. 故意触发一个崩溃（如空指针解引用）
5. 验证复位后能正确读取崩溃信息

### 练习 2：使用 perf 分析性能（进阶）

使用 perf 分析一个程序的性能：
1. 运行 perf top 观察系统热点
2. 用 perf record -g 记录性能数据
3. 用 perf report 查看报告
4. 生成火焰图并分析
5. 根据分析结果优化热点函数

### 练习 3：阅读复位原因源码（深入）

阅读 `/home/ys/wq7036a/wq-audio/wqcore/components/startup/boot/src/boot_reason.c`，回答：
1. WQ7036A 支持哪些复位原因？
2. 复位原因寄存器如何读取？
3. 不同复位原因对应的处理策略是什么？
4. 如何区分上电复位和看门狗复位？

## 自测与验收

1. crashdump 包含哪些信息？
2. HardFault 发生后，最重要的事是什么？
3. 为什么 crashdump 要保存在 .noinit 段？
4. perf top 和 perf record 的区别是什么？
5. 什么是火焰图？它如何帮助性能分析？
6. 编译优化为什么会影响栈回溯的准确性？
7. 如何防止第二次 crashdump 覆盖第一次的信息？

## 延伸阅读

- [[gdb-ftrace-GDB与ftrace]] — 用 GDB 分析 crashdump
- [[debug-methodology-嵌入式调试方法论]] — 系统化的崩溃排查流程
- [[serial-jtag-swd-串口与JTAG调试]] — 通过 JTAG 读取崩溃信息

## #flashcard

**Q: crashdump 包含哪些信息？**
A: 寄存器值（PC、SP、LR）、调用栈、内存内容、崩溃原因。

**Q: crashdump 为什么要保存在 .noinit 段？**
A: .noinit 段在系统复位后不会被清零，可以保留崩溃信息供后续分析。

**Q: perf 回答什么问题？**
A: "为什么慢"——找出 CPU 热点、cache miss 等性能瓶颈。

**Q: crashdump 回答什么问题？**
A: "为什么崩溃"——定位崩溃的代码行和函数调用链。

**Q: 生成火焰图需要哪几步？**
A: perf record -g → perf script → stackcollapse → flamegraph.pl → flame.svg。