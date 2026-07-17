# Crashdump 与性能分析

**一句话结论（20% 核心）**：crashdump（core dump）是程序崩溃时的"死亡快照"——保存崩溃瞬间的内存、寄存器、调用栈，用于事后分析。perf 是 Linux 性能分析工具——看 CPU 时间花在哪、cache miss 在哪、哪些函数最慢。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：飞机黑匣子 vs 油耗记录仪

- **crashdump** = 飞机黑匣子：坠毁后打开，看失事前最后几秒发生了什么
- **perf** = 油耗记录仪：记录每段路程的油耗，找出最费油的路线

### 1.2 crashdump 的核心信息

```
crashdump 包含:
  ├── 所有寄存器的值（PC、SP、LR、通用寄存器）
  ├── 调用栈（哪个函数调用了哪个函数）
  ├── 内存内容（变量值）
  └── 崩溃原因（HardFault / MemManage / BusFault / UsageFault）
```

### 1.3 如果只记得一件事

> crashdump = 崩溃时的快照，事后分析用。perf = 性能分析工具，找 CPU 热点和瓶颈。crashdump 回答"为什么崩溃"，perf 回答"为什么慢"。

---

## 第二层：实战理解

### 2.1 WQ7036AX 的 HardFault 分析

```c
// HardFault Handler 中保存 crash 信息
void HardFault_Handler(void) {
    // 把栈帧保存到 .noinit 段（复位后不丢失）
    crash_info_t *crash = (crash_info_t *)CRASH_INFO_ADDR;
    crash->r0  = __get_R0();   // 或从栈帧中提取
    crash->pc  = __get_PC();   // 崩溃时的程序计数器
    crash->lr  = __get_LR();   // 返回地址
    crash->sp  = __get_SP();   // 栈指针

    // 复位后通过 GDB 或串口读取 crash_info
    NVIC_SystemReset();
}
```

### 2.2 Linux perf 常用命令

```bash
# 查看 CPU 热点（哪些函数最耗时）
perf top

# 记录性能数据
perf record -g ./my_app

# 生成火焰图
perf script | FlameGraph/stackcollapse-perf.pl | FlameGraph/flamegraph.pl > flame.svg

# 查看 cache miss
perf stat -e cache-misses ./my_app
```

### 2.3 常见坑

| 问题 | 现象 | 根因 |
|------|------|------|
| crashdump 被覆盖 | 第二次崩溃后第一次的信息丢失 | 没保存到 .noinit 段或 Flash |
| 优化后栈回溯不准 | GDB 栈回溯显示错误 | 编译优化导致栈帧被省略，用 `-fno-omit-frame-pointer` |
| perf 数据不完整 | 看不到某些函数 | 符号表被 strip 了，编译时加 `-g` |

### 2.4 在 reGlasses 项目中怎么用

WQ7036AX 的 HardFault 分析是排查崩溃的主要手段。V881 侧用 Linux 的 coredump 和 perf 做性能分析。SDK 的 debug log 系统在 crash 时会尝试输出最后的日志。

---

## 第三层：延伸阅读

- [[gdb-ftrace-GDB与ftrace]] — 用 GDB 分析 crashdump
- [[debug-methodology-嵌入式调试方法论]] — 系统化的崩溃排查流程