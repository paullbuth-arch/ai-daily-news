# 嵌入式调试方法论

**一句话结论（20% 核心）**：嵌入式调试不是"猜"，而是先定位问题属于哪一类（硬件 / 软件 / 时序 / 资源 / 并发），再用对应的工具和方法证明你的假设。系统化流程：**复现 → 分类 → 假设 → 验证 → 归档**。

---

## 第一层：核心认知

### 1.1 费曼类比：侦探破案

调试就像侦探破案：

1. **复现问题**：找到案发现场——问题在什么条件下出现？
2. **缩小范围**：是硬件问题还是软件问题？是某个模块的问题还是全局问题？
3. **收集证据**：日志、波形、寄存器值、内存 dump。
4. **验证假设**：改了代码后问题是否消失？消失的原因和你假设的一致吗？
5. **总结归档**：下次遇到类似问题怎么查？

**关键原则**：**不要瞎改代码看能不能"碰巧"好。** 每一个修改都应该基于一个明确的假设，并且修改后你能解释为什么好了。

### 1.2 问题分类表

| 问题类型 | 常见现象 | 第一排查工具 | 关键证据 |
|---|---|---|---|
| **逻辑错误** | 结果不对但程序没崩 | 日志 + 断点 | 变量值、分支走向 |
| **内存错误** | HardFault、死机、数据错乱 | GDB + map 文件 | 崩溃地址、栈溢出标记 |
| **时序错误** | 通信失败、数据丢失、偶发异常 | 逻辑分析仪 + 示波器 | 波形、时钟、信号边沿 |
| **资源耗尽** | 运行一段时间后崩溃 | map 文件 + 栈水位线 | 栈溢出、堆碎片、队列满 |
| **并发错误** | 偶发死机、数据不一致 | 代码审查 + 断点 | 共享变量、临界区缺失 |
| **硬件问题** | 换了板子就好了/坏了 | 示波器 + 万用表 | 电源电压、焊接、引脚连通 |

### 1.3 如果只记得一件事

> 调试 = 先分类（哪种问题）→ 再假设（哪个原因）→ 再验证（用什么工具证明）。永远不要"猜着改"。

---

## 第二层：实战理解

### 2.1 HardFault 定位：嵌入式最常见的崩溃

HardFault（硬件错误）= CPU 访问了不该访问的地址、执行了非法指令、栈溢出导致跑飞。

**定位步骤**：

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

**GDB 实操**：

```bash
# 连接到目标
$ riscv64-unknown-elf-gdb build/acore/acore.elf
(gdb) target remote :3333

# 在 HardFault 处理函数设断点
(gdb) b HardFault_Handler
(gdb) c

# 崩溃后查看寄存器
(gdb) info registers
pc    = 0x00012345   ← 崩溃地址
lr    = 0x00010abc   ← 调用者
sp    = 0x20000010   ← 栈指针（看是否异常）

# 把地址翻译成源代码行号
$ riscv64-unknown-elf-addr2line -e build/acore/acore.elf 0x00012345
src/main.c:87        ← 第 87 行出了问题
```

**常见 HardFault 原因**：

| 原因 | 怎么确认 | 解决方法 |
|---|---|---|
| 空指针解引用 | PC 指向地址 0 附近 | 加 NULL 检查 |
| 栈溢出 | SP 超出栈范围 | 增大栈、减小局部变量 |
| 数组越界 | 变量值异常 | 检查数组边界 |
| 未对齐访问 | 访问了非对齐地址 | 加 `__attribute__((packed))` 或对齐 |
| 执行了数据区域 | PC 指向 .data/.bss | 函数指针未初始化 |

### 2.2 死锁排查

**现象**：程序卡住不动，但没崩。

**排查步骤**：

1. **GDB 暂停程序**，查看所有任务的状态：

```bash
(gdb) info threads           # 列出所有任务
(gdb) thread 2               # 切到第 2 个任务
(gdb) bt                     # 看调用栈
```

2. **检查每个任务在等什么**：
   - 如果任务 A 停在 `xSemaphoreTake(mutex, portMAX_DELAY)`
   - 任务 B 也停在 `xSemaphoreTake(mutex, portMAX_DELAY)`
   - 说明两个任务在抢同一把锁 → 死锁

3. **检查是否有优先级反转**：低优先级任务持有锁但得不到 CPU。

### 2.3 通信故障排查（UART/I2C/SPI）

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

**常用检查项**：

| 协议 | 常查 |
|---|---|
| UART | 波特率是否一致、TX/RX 是否交叉连接、共地 |
| I2C | 上拉电阻、从机地址、ACK/NACK |
| SPI | CPOL/CPHA 模式、CS 控制、时钟频率 |

### 2.4 内存问题排查

**栈溢出**：
```c
// 启动时把栈区域填充为 0xA5A5A5A5
// 运行一段时间后查看还有多少 0xA5 没被覆盖
UBaseType_t watermark = uxTaskGetStackHighWaterMark(NULL);
printf("Stack high water mark: %lu words\n", watermark);
// watermark < 10 就很危险了
```

**堆碎片化**：
```c
// 查看 FreeRTOS 堆剩余
size_t free_heap = xPortGetFreeHeapSize();
size_t min_ever = xPortGetMinimumEverFreeHeapSize();
printf("Free heap: %zu, Min ever: %zu\n", free_heap, min_ever);
```

**内存踩踏**：
- 在关键变量前后加"哨兵值"（如 `0xDEADBEEF`），定期检查是否被改写。
- 用 MPU（Memory Protection Unit）保护关键内存区域。

### 2.5 偶发问题排查

偶发问题（偶尔才出现的 bug）是最难调试的：

| 策略 | 说明 |
|---|---|
| 加日志 | 在可疑位置打印关键变量值 |
| 压力测试 | 反复触发问题条件，提高复现率 |
| 二分法 | 注释掉一半代码，看问题是否消失 |
| 代码审查 | 仔细检查并发、临界区、未初始化变量 |
| 硬件排除 | 换板子、换线缆，排除硬件问题 |

### 2.6 断言（Assert）与防御式编程

在关键位置加断言，出问题立刻崩在原地，而不是带着错误数据继续跑：

```c
#include <assert.h>

void process_packet(uint8_t *buf, uint32_t len)
{
    assert(buf != NULL);       // 空指针就崩在这里
    assert(len <= MAX_PKT);    // 超长就崩在这里
    assert(state != INVALID);  // 非法状态就崩在这里

    // 正常处理...
}
```

**好处**：问题在发生的第一时间被发现，而不是等到下游出了莫名其妙的错误才去追。

### 2.7 项目中的调试实例

在 WQ7036A 项目中常见的调试场景：

- **I2S 音频无声**：逻辑分析仪抓 BCLK/LRCK/SD 波形 → 确认时钟是否正常 → 检查 I2S 寄存器配置。
- **UART 丢数据**：检查接收 ISR 是否及时响应 → 检查环形缓冲区是否溢出。
- **多核 IPC 超时**：检查目标核是否启动、共享内存地址是否一致、Cache 是否同步。

详见 [[debug-tools-常用调试工具链 中各工具的具体使用方法]]。

---

## 第三层：深入扩展

### 3.1 日志系统设计

好的日志系统是嵌入式调试最重要的工具：

```c
// 分级日志
#define LOG_ERROR(fmt, ...) printf("[E] %s: " fmt "\n", __func__, ##__VA_ARGS__)
#define LOG_WARN(fmt, ...)  printf("[W] %s: " fmt "\n", __func__, ##__VA_ARGS__)
#define LOG_INFO(fmt, ...)  printf("[I] %s: " fmt "\n", __func__, ##__VA_ARGS__)
#define LOG_DEBUG(fmt, ...) printf("[D] %s: " fmt "\n", __func__, ##__VA_ARGS__)

// 使用
LOG_INFO("UART init: baud=%d", 115200);
LOG_ERROR("I2C timeout: addr=0x%02X", slave_addr);
```

**高级技巧**：
- **条件编译**：Release 版本去掉 DEBUG 日志，减小代码体积。
- **环形日志缓冲**：把日志写到 RAM 中的环形缓冲区，崩溃后用 GDB dump 出来。
- **远程日志**：通过 UART/蓝牙把日志传到 PC 或手机。

### 3.2 压力测试与稳定性测试

```c
// 压力测试示例：反复初始化和使用外设
for (int i = 0; i < 10000; i++) {
    uart_init(UART1, 115200, 8, NONE, 1);
    uart_send(UART1, test_data, len);
    vTaskDelay(pdMS_TO_TICKS(10));
    uart_deinit(UART1);
}

// 稳定性测试：长时间运行，记录关键指标
while (1) {
    run_normal_operation();
    log_heap_usage();
    log_stack_watermark();
    log_error_count();
    vTaskDelay(pdMS_TO_TICKS(60000));  // 每分钟记录一次
}
```

### 3.3 Watchdog 与自动恢复

详见 [[reliability-exception-系统可靠性与异常处理]]，这里只提调试相关的：

- 开发阶段**关闭看门狗**，方便 GDB 断点调试（否则断点停太久会触发复位）。
- 生产版本**开启看门狗**，并在复位后读取复位原因寄存器，记录"上次是看门狗复位"。

### 3.4 常见问题

- **HardFault 发生时第一件事做什么？** 查看 PC 和 LR 寄存器，定位崩溃的代码行。
- **偶发 bug 怎么调试？** 加日志、压力测试、二分法排除、代码审查并发问题。
- **怎么判断是硬件问题还是软件问题？** 换板子/换线缆看问题是否跟过去；用示波器看信号质量。
- **断言和错误处理的区别？** 断言用于捕获"不应该发生"的编程错误，错误处理用于处理"可能发生"的运行时异常。

### 3.5 核心术语表

| 英文 | 中文 | 说明 |
|---|---|---|
| HardFault | 硬件错误 | CPU 执行了非法操作 |
| Breakpoint | 断点 | GDB 暂停程序的位置 |
| Watchpoint | 监视点 | 变量被修改时暂停 |
| Call Stack | 调用栈 | 函数调用链 |
| Core Dump | 核心转储 | 崩溃时的内存快照 |
| Assert | 断言 | 运行时条件检查 |
| Watchdog | 看门狗 | 程序跑飞时自动复位 |
| Stress Test | 压力测试 | 反复触发以提高复现率 |
| Race Condition | 竞态条件 | 并发访问导致的不确定结果 |

### 3.6 延伸阅读

- [[debug-tools-常用调试工具链]] —— GDB、逻辑分析仪、示波器的具体使用
- [[c-core-C语言核心]] —— volatile、指针错误的理解
- [[interrupt-concurrency-中断并发同步]] —— 并发问题的根因
- [[reliability-exception-系统可靠性与异常处理]] —— 看门狗与异常恢复
