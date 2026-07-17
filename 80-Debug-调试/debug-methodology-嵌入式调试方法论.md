---
type: concept
created: 2026-07-17
tags: [debug, methodology, troubleshooting, embedded, 调试]
aliases: [调试方法论, 嵌入式调试, Debug Methodology, HardFault定位]
---

# 嵌入式调试方法论

## 一句话结论

嵌入式调试不是"猜着改代码碰运气"，而是系统化的科学排查过程：先定位问题属于哪一类（逻辑错误 / 内存错误 / 时序错误 / 资源耗尽 / 并发错误 / 硬件问题），再用对应的工具和方法证明你的假设。系统化流程是 **复现 → 分类 → 假设 → 验证 → 归档**，每一步都基于明确的假设，而不是随机尝试。

## 30秒先看懂

- 调试的核心原则：每一个修改都应该基于一个明确的假设，修改后你能解释为什么问题解决了。
- 问题分六类（逻辑、内存、时序、资源、并发、硬件），每类有对应的第一排查工具和关键证据。
- HardFault 是嵌入式最常见的崩溃，定位步骤是：在 HardFault_Handler 断住 → 查看 PC 和 LR 寄存器 → 用 addr2line 翻译成源代码行号。
- 偶发问题最难调试，策略包括加日志、压力测试、二分法、代码审查、硬件排除。
- 断言（Assert）是防御式编程的核心工具——在关键位置加断言，出问题立刻崩在原地，而不是带着错误数据继续跑。

## 学完以后应该能做什么

### 第一遍
- 遇到问题能先分类（逻辑/内存/时序/资源/并发/硬件），给出对应的调试策略
- 用 GDB + addr2line 定位 HardFault 的源代码行号
- 用断言和日志改善代码的可调试性

### 进阶
- 排查死锁和优先级反转问题
- 分析栈溢出和堆碎片化问题
- 制定压力测试和稳定性测试方案

## 前置知识

- [[debug-tools-常用调试工具链]]：GDB、逻辑分析仪、示波器、串口打印的具体使用
- [[c-core-C语言核心]]：指针、内存布局、volatile 等 C 语言关键知识
- [[interrupt-concurrency-中断并发同步]]：并发问题的根因分析
- [[reliability-exception-系统可靠性与异常处理]]：看门狗、异常恢复

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 硬件错误 | HardFault | CPU 执行了非法操作（空指针、非法指令、未对齐访问等）触发的异常 |
| 断点 | Breakpoint | 程序执行到指定位置时暂停，用于检查程序状态 |
| 监视点 | Watchpoint | 指定变量被读/写时暂停，用于追踪变量变化 |
| 调用栈 | Call Stack (Backtrace) | 函数调用链，从当前执行函数到 main 的路径 |
| 核心转储 | Core Dump | 崩溃时内存、寄存器等状态的快照 |
| 断言 | Assert | 运行时检查条件，条件不满足时立即触发崩溃 |
| 看门狗 | Watchdog | 程序跑飞时自动复位系统的硬件定时器 |
| 压力测试 | Stress Test | 反复触发目标操作以提高问题复现率 |
| 竞态条件 | Race Condition | 多个任务/中断并发访问共享资源导致的不确定结果 |
| 优先级反转 | Priority Inversion | 低优先级任务持有锁，高优先级任务被阻塞等待 |
| 栈高水位 | Stack High Water Mark | 任务栈使用过的最大深度，用于评估栈大小是否够用 |

## 第一层费曼心智模型

### 类比：侦探破案

调试就像侦探破案，需要系统化的推理：

1. **复现问题** = 找到案发现场——问题在什么条件下出现？输入是什么？操作步骤是什么？
2. **缩小范围** = 确定嫌疑人范围——是硬件问题还是软件问题？是哪个模块？是哪个函数？
3. **收集证据** = 采集物证——日志、寄存器值、内存 dump、波形、信号时序。
4. **验证假设** = 验证推理——改了代码后问题是否消失？消失的原因和你假设的一致吗？
5. **总结归档** = 结案报告——根本原因是什么？下次怎么快速定位？

**关键原则：不要瞎改代码看能不能"碰巧"好。** 每一个修改都应该基于一个明确的假设，并且修改后你能解释为什么好了。

### 边界

- 不是所有问题都有明确的"根因"——有些硬件问题（如信号完整性）是渐变的，不是二元的"有/没有"。
- 加日志可能改变程序时序，导致偶发问题不再出现（"Heisenbug"——海森堡 bug）。
- 断言在生产环境中通常被关闭，只在调试版本中启用。
- 压力测试能提高复现率，但 10000 次不崩溃不代表没有 bug——可能只是触发条件不对。

### 场景推演

**场景：程序运行 30 分钟后突然 HardFault**

1. 复现：发现程序在运行 30 分钟后固定崩溃，每次崩溃地址不同
2. 分类：疑似内存问题（栈溢出或堆内存踩踏）
3. 假设：某个任务栈溢出，写到了相邻任务的控制块
4. 验证：用 `uxTaskGetStackHighWaterMark` 检查所有任务的栈水位，发现 audio_task 的 watermark = 0
5. 结论：audio_task 栈溢出，覆盖了相邻任务的内存

## 第二层原理/时序/约束

### 问题分类与排查策略

| 问题类型 | 常见现象 | 第一排查工具 | 关键证据 |
|---------|---------|-------------|---------|
| **逻辑错误** | 结果不对但程序没崩 | 日志 + 断点 | 变量值、分支走向 |
| **内存错误** | HardFault、死机、数据错乱 | GDB + map 文件 | 崩溃地址、栈溢出标记 |
| **时序错误** | 通信失败、数据丢失、偶发异常 | 逻辑分析仪 + 示波器 | 波形、时钟、信号边沿 |
| **资源耗尽** | 运行一段时间后崩溃 | map 文件 + 栈水位线 | 栈溢出、堆碎片、队列满 |
| **并发错误** | 偶发死机、数据不一致 | 代码审查 + 断点 | 共享变量、临界区缺失 |
| **硬件问题** | 换了板子就好了/坏了 | 示波器 + 万用表 | 电源电压、焊接、引脚连通 |

### HardFault 定位标准流程

```
第 1 步：在 HardFault_Handler 中加断点
         ↓
第 2 步：查看 PC（程序计数器）—— 崩溃时正在执行哪条指令
         ↓
第 3 步：查看 LR（链接寄存器）—— 是谁调用到这里的
         ↓
第 4 步：用 addr2line 把地址翻译成源代码行号
         ↓
第 5 步：检查那个位置的代码——是否是空指针？数组越界？栈溢出？
```

### 常见 HardFault 原因

| 原因 | 怎么确认 | 解决方法 |
|-----|---------|---------|
| 空指针解引用 | PC 指向地址 0 附近 | 加 NULL 检查 |
| 栈溢出 | SP 超出栈范围 | 增大栈、减小局部变量 |
| 数组越界 | 变量值异常 | 检查数组边界 |
| 未对齐访问 | 访问了非对齐地址 | 加 `__attribute__((packed))` 或对齐 |
| 执行了数据区域 | PC 指向 .data/.bss 段 | 函数指针未初始化 |
| 野指针 | 随机崩溃 | 指针初始化 = NULL，释放后置 NULL |

### 死锁排查流程

```
现象：程序卡住不动，但没崩

第 1 步：GDB 暂停程序，查看所有任务的状态
  (gdb) info threads
  (gdb) thread 2
  (gdb) bt

第 2 步：检查每个任务在等什么
  - 如果任务 A 停在 xSemaphoreTake(mutex, portMAX_DELAY)
  - 任务 B 也停在 xSemaphoreTake(mutex, portMAX_DELAY)
  - 说明两个任务在抢同一把锁 → 死锁

第 3 步：检查是否有优先级反转
  - 低优先级任务持有锁但得不到 CPU
  - 高优先级任务在等锁
```

## 第三层真实SDK代码

### WQ7036AX 的断言机制

SDK 中的断言实现，用于在调试阶段捕获编程错误：

```c
// 位于 wq_debug.h 或类似头文件中
#define ASSERT(cond) \
    do { \
        if (!(cond)) { \
            /* 打印断言失败信息 */ \
            dbg_printf("ASSERT failed: %s, file %s, line %d\n", \
                       #cond, __FILE__, __LINE__); \
            /* 进入死循环，停在原地 */ \
            while (1); \
        } \
    } while (0)
```

### 栈水位检测（FreeRTOS）

```c
// 使用 FreeRTOS 的 API 检测任务栈使用情况
// 在 WQ7036AX 项目中定期检查所有任务的栈水位

void check_stack_watermarks(void) {
    TaskStatus_t *task_status_array;
    UBaseType_t task_count, i;

    task_count = uxTaskGetNumberOfTasks();
    task_status_array = pvPortMalloc(task_count * sizeof(TaskStatus_t));

    if (task_status_array != NULL) {
        uxTaskGetSystemState(task_status_array, task_count, NULL);
        for (i = 0; i < task_count; i++) {
            LOGI("Task %s: stack high water mark = %lu words",
                 task_status_array[i].pcTaskName,
                 task_status_array[i].usStackHighWaterMark);
        }
        vPortFree(task_status_array);
    }
}
```

### 堆监控

```c
// 使用 FreeRTOS 的堆监控 API
// 在 WQ7036AX 项目中定期检查堆使用情况

void check_heap_usage(void) {
    size_t free_heap = xPortGetFreeHeapSize();
    size_t min_ever = xPortGetMinimumEverFreeHeapSize();
    LOGI("Free heap: %zu, Min ever: %zu", free_heap, min_ever);
    if (min_ever < 1024) {  // 小于 1KB 就报警
        LOGW("Heap is running low!");
    }
}
```

## 第四层正常/异常路径

### 调试流程

```
正常路径：发现问题 → 分类 → 假设 → 验证 → 修复 → 确认 → 归档
异常路径：偶发问题 → 加日志/压力测试提高复现率 → 分类 → 假设 → 验证
           → 如果是硬件问题 → 换板子/换线缆排除
           → 如果是时序问题 → 逻辑分析仪抓波形
```

### 通信故障排查

```
第 1 步：确认硬件连通
         └─ 万用表测通断、测电压
              ↓
第 2 步：确认电气信号
         └─ 示波器/逻辑分析仪抓波形
              ├─ 有波形？ → 软件问题
              └─ 没波形？ → 硬件问题（引脚配错、时钟没开）
              ↓
第 3 步：确认协议参数
         └─ 波特率/地址/模式是否匹配
              ↓
第 4 步：确认软件逻辑
         └─ 日志打印收发数据，对比预期
```

| 协议 | 常查 |
|-----|------|
| UART | 波特率是否一致、TX/RX 是否交叉连接、共地 |
| I2C | 上拉电阻、从机地址、ACK/NACK |
| SPI | CPOL/CPHA 模式、CS 控制、时钟频率 |

## 第五层调试方法

### GDB 调试 HardFault

```bash
# 1. 启动 OpenOCD 和 GDB
$ riscv64-unknown-elf-gdb build/acore/acore.elf
(gdb) target remote :3333

# 2. 在 HardFault 处理函数设断点
(gdb) b HardFault_Handler
(gdb) c

# 3. 崩溃后查看寄存器
(gdb) info registers
pc    = 0x00012345   ← 崩溃地址
lr    = 0x00010abc   ← 调用者
sp    = 0x20000010   ← 栈指针（看是否异常）

# 4. 把地址翻译成源代码行号（在终端执行）
$ riscv64-unknown-elf-addr2line -e build/acore/acore.elf 0x00012345
src/main.c:87        ← 第 87 行出了问题
```

### 死锁排查

```bash
# 1. 暂停程序，查看所有任务
(gdb) info threads
(gdb) thread apply all bt

# 2. 检查每个任务在等什么
# 如果多个任务都停在 xSemaphoreTake 上，可能是死锁

# 3. 查看 FreeRTOS 的 uxListRemove 和队列状态
```

### 内存踩踏检测

```c
// 在关键变量前后加"哨兵值"
#define SENTINEL_VALUE 0xDEADBEEF

typedef struct {
    uint32_t sentinel_start;  // 哨兵（前）
    uint8_t  data[64];        // 关键数据
    uint32_t sentinel_end;    // 哨兵（后）
} protected_buffer_t;

void check_sentinel(protected_buffer_t *buf) {
    if (buf->sentinel_start != SENTINEL_VALUE) {
        LOGE("Buffer underflow detected!");
    }
    if (buf->sentinel_end != SENTINEL_VALUE) {
        LOGE("Buffer overflow detected!");
    }
}
```

## 第六层实战练习

### 练习1：模拟 HardFault 并定位

编写一段会导致 HardFault 的代码，然后用 GDB 和 addr2line 定位到源代码行：

```c
// 生成一个 HardFault（空指针解引用）
void trigger_hardfault(void) {
    uint32_t *ptr = NULL;
    *ptr = 0x12345678;  // 这会触发 HardFault
}

// 请完成以下步骤：
// 1. 编译并运行这段代码
// 2. 在 GDB 中设置 HardFault_Handler 断点
// 3. 崩溃后查看 PC 和 LR 寄存器
// 4. 用 addr2line 翻译成源代码行号
// 5. 修改代码，在解引用前加 NULL 检查
```

### 练习2：阅读 SDK 源码分析崩溃处理

在 `/home/ys/wq7036a/wq-audio/wqcore/components/startup/` 目录下搜索 HardFault_Handler 的实现，分析：
- WQ7036AX 的 HardFault_Handler 做了什么？
- 是否有打印崩溃信息的机制？
- 是否支持在 HardFault 后自动重启系统？

### 练习3：实现栈溢出检测

编写代码，在系统启动时用特殊值填充所有任务的栈空间，定期检查栈水位：

```c
// 启动时用 0xA5A5A5A5 填充栈空间
// 运行一段时间后检查还有多少 0xA5 没被覆盖
// 如果水位低于阈值（如 10 words），打印警告日志

void check_all_task_stacks(void) {
    // 使用 uxTaskGetSystemState 获取所有任务状态
    // 对每个任务调用 uxTaskGetStackHighWaterMark
    // 如果 watermark < 20，打印警告
    // 请补全
}
```

## 自测与验收

1. 调试六步流程是什么？每一步的核心目标是什么？
2. HardFault 发生时，查看哪两个寄存器最关键？为什么？
3. 偶发问题（Heisenbug）为什么难调试？有哪些应对策略？
4. 断言和错误处理有什么区别？什么时候应该用断言？
5. 怎么判断一个问题是硬件问题还是软件问题？第一排查步骤是什么？

## 延伸阅读

- [[debug-tools-常用调试工具链]] — GDB、逻辑分析仪、示波器的具体使用
- [[c-core-C语言核心]] — volatile、指针错误的理解
- [[interrupt-concurrency-中断并发同步]] — 并发问题的根因
- [[reliability-exception-系统可靠性与异常处理]] — 看门狗与异常恢复
- [[logging-design-日志系统设计]] — 日志系统在调试中的作用
- [[embedded-testing-嵌入式测试]] — 测试与调试的互补关系

#flashcard
问：HardFault 发生时第一件事做什么？
答：查看 PC 和 LR 寄存器。PC 指向崩溃时的指令地址，LR 指向调用者。然后用 addr2line 翻译成源代码行号。

问：偶发 bug 怎么调试？
答：加日志、压力测试提高复现率、二分法排除、代码审查并发问题、换硬件排除硬件问题。

问：怎么判断是硬件问题还是软件问题？
答：换板子/换线缆看问题是否跟过去；用示波器看信号质量。如果换了硬件问题消失，很可能是硬件问题。

问：断言和错误处理的区别？
答：断言用于捕获"不应该发生"的编程错误（如空指针），在调试阶段发现。错误处理用于处理"可能发生"的运行时异常（如通信超时）。

问：栈溢出如何检测？
答：启动时用特殊值填充栈空间，运行后用 uxTaskGetStackHighWaterMark 检查还有多少剩余空间未被使用。