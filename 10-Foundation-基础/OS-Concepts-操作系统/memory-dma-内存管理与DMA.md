---
type: concept
tags: [embedded, memory, dma, heap, stack, cache, wq7036a]
aliases: [内存管理, DMA, 直接内存访问, 栈, 堆]
---

# 内存管理与 DMA

## 一句话结论

内存管理就是决定数据放哪里、怎么放、怎么搬；DMA（Direct Memory Access，直接内存访问）就是让外设自己搬数据，不用 CPU 一件件搬——CPU 只需发号施令，DMA 控制器负责搬运，搬完中断通知 CPU。

## 30秒先看懂

- 嵌入式程序的内存布局从低地址到高地址依次是：.text（代码段）、.rodata（只读数据）、.data（已初始化全局变量）、.bss（未初始化全局变量）、heap（堆，向高地址增长）、stack（栈，向低地址增长）。栈溢出是嵌入式最常见的内存问题——递归太深、局部变量太大、调用链太深都会导致栈溢出。嵌入式里尽量少用 malloc，因为碎片化、执行时间不确定、没有 MMU 保护。DMA 让外设自己搬运数据，不占用 CPU 时间，有三种传输模式：内存到内存、内存到外设、外设到内存。DMA 双缓冲（Double Buffer）是音频场景的标准模式——DMA 写缓冲区 A 时 CPU 处理缓冲区 B，交替进行避免冲突。

## 学完以后应该能做什么

**第一遍看完后可以：**
- 理解嵌入式程序的内存布局和各段的作用
- 检测和预防栈溢出
- 知道为什么嵌入式里尽量少用 malloc
- 理解 DMA 的基本工作原理和三种传输模式

**进阶后可以：**
- 实现内存池（Memory Pool）替代动态分配
- 配置 DMA 双缓冲处理音频数据流
- 解决 DMA 的 Cache 一致性问题
- 使用 MPU 保护关键内存区域

## 前置知识

- C 语言的变量存储类型（全局、静态、局部）
- 指针和地址的概念
- 中断的基本工作原理

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 直接内存访问 | DMA | Direct Memory Access，硬件在外设和内存之间直接搬运数据 |
| 堆 | Heap | 运行时动态分配的内存区域，由 malloc/free 管理 |
| 栈 | Stack | 函数调用时自动分配和释放的临时存储区域 |
| 栈溢出 | Stack Overflow | 栈空间不足，覆盖了相邻的内存区域 |
| 双缓冲 | Double Buffer | 两个缓冲区交替使用，DMA 写一个 CPU 处理另一个 |
| 内存池 | Memory Pool | 预分配固定大小的内存块，避免动态分配碎片 |
| 缓存一致性 | Cache Coherency | Cache 和 RAM 数据保持同步，避免读到旧数据 |
| 内存保护单元 | MPU | Memory Protection Unit，给内存区域设置访问权限 |
| 描述符链 | Descriptor Chain | DMA 多段传输的配置链表 |
| 内存碎片 | Memory Fragmentation | 频繁分配释放导致的内存空洞 |

## 第一层：费曼心智模型

### 类比：大办公楼

把 MCU 的内存想象成一个大办公楼：

- **Flash（仓库）**：存放设计图纸（程序代码），不常改，但掉电不丢。
- **SRAM（办公桌区）**：员工工作的地方，每个人有自己的桌面空间（变量），下班清空（掉电丢失）。
- **堆（公共储物柜）**：需要的时候申请一个柜子（malloc），不用了还回去（free）。
- **栈（每人的背包）**：进函数时打开背包装东西（局部变量），出函数时合上背包（自动释放）。
- **DMA（快递小哥）**：你告诉他"从 A 搬到 B，搬 N 件"，他就自己搬，搬完打电话通知你。

**边界：**
- 堆和栈是相向增长的——堆向上，栈向下，相遇时内存耗尽
- DMA 不是万能的——小数据量（几十字节）用 CPU 搬反而更快（DMA 初始化开销大）
- 内存池不是随处可用——固定大小在某些场景浪费空间

### 场景演练：DMA 搬运音频数据

1. I2S 接口收到音频数据，触发 DMA 请求
2. DMA 控制器自动把数据从 I2S 的 RX 寄存器搬到内存缓冲区 A
3. CPU 在 DMA 搬运期间处理其他任务
4. 缓冲区 A 写满，DMA 触发半传输中断
5. ISR 中交换缓冲区指针：DMA 写入缓冲区 B，CPU 处理缓冲区 A
6. CPU 对缓冲区 A 中的音频数据进行算法处理
7. 缓冲区 B 写满，DMA 触发全传输中断，再次交换

## 第二层：原理/时序/约束

### 内存布局

```
低地址
├─ .text ──── 代码段（程序指令，只读）
├─ .rodata ── 只读数据（常量字符串、const 全局变量）
├─ .data ──── 已初始化的全局/静态变量（从 Flash 拷贝到 RAM）
├─ .bss ───── 未初始化的全局/静态变量（启动时清零）
├─ heap ───── 堆（malloc 分配，向高地址增长）
│              ↓
│              ↑
├─ stack ──── 栈（局部变量，向低地址增长）
└─ 栈顶 = RAM 最高地址
```

### 栈溢出检测

```c
// FreeRTOS 高水位线检测
UBaseType_t watermark = uxTaskGetStackHighWaterMark(NULL);
// watermark = 运行以来栈剩余的最小值（word），接近 0 就危险了
printf("Stack watermark: %lu words\n", watermark);
```

### DMA 配置示例

```c
// 配置 DMA：从 UART 数据寄存器搬到 buf，搬 1024 字节
dma_config(DMA_CH1,
           .src  = &UART_DR,       // 源地址（UART 数据寄存器）
           .dst  = buf,            // 目标地址（内存缓冲区）
           .size = 1024,           // 搬运数量
           .src_inc = false,       // 源地址不自增
           .dst_inc = true);       // 目标地址自增
dma_start(DMA_CH1);
// CPU 去做别的事，DMA 搬完后触发中断通知 CPU
```

### DMA 双缓冲

```c
uint8_t buf_a[512];
uint8_t buf_b[512];

volatile uint8_t *dma_buf  = buf_a;   // DMA 正在写这个
volatile uint8_t *proc_buf = buf_b;   // CPU 正在处理这个

void dma_half_complete_isr(void) {
    swap(dma_buf, proc_buf);
    xSemaphoreGiveFromISR(sem, NULL);
}
```

## 第三层：真实 SDK 代码

### DMA 硬件寄存器

WQ7036A 的 DMA 控制器寄存器定义在 `/home/ys/wq7036a/wq-audio/wqcore/chipset/bbb/regs/dma_reg.h`：

```c
// DMA 通道控制寄存器
#define DMA_CH_CTRL(ch)      (DMA_BASE + 0x00 + (ch) * 0x20)
#define DMA_CH_SRC(ch)       (DMA_BASE + 0x04 + (ch) * 0x20)
#define DMA_CH_DST(ch)       (DMA_BASE + 0x08 + (ch) * 0x20)
#define DMA_CH_SIZE(ch)      (DMA_BASE + 0x0C + (ch) * 0x20)

// DMA 控制位
#define DMA_CTRL_START       (1 << 0)
#define DMA_CTRL_CIRCULAR    (1 << 1)
#define DMA_CTRL_SRC_INC     (1 << 2)
#define DMA_CTRL_DST_INC     (1 << 3)
```

### DMA 驱动接口

DMA 驱动接口在 `/home/ys/wq7036a/wq-audio/wqcore/driver/periph/bbb/hw/dma.h`：

```c
// DMA 初始化
void dma_init(uint8_t ch, dma_config_t *cfg);

// 启动 DMA 传输
void dma_start(uint8_t ch);

// 停止 DMA 传输
void dma_stop(uint8_t ch);

// 检查 DMA 完成
bool dma_is_done(uint8_t ch);

// 注册 DMA 完成中断回调
void dma_register_callback(uint8_t ch, dma_callback_t cb, void *arg);
```

### 内存池替代方案

```c
// 固定大小内存池
#define POOL_BLOCK_SIZE 256
#define POOL_BLOCK_COUNT 16

static uint8_t pool[POOL_BLOCK_COUNT][POOL_BLOCK_SIZE];
static uint32_t pool_used = 0;  // 位图

void *pool_alloc(void) {
    for (int i = 0; i < POOL_BLOCK_COUNT; i++) {
        if (!(pool_used & BIT(i))) {
            pool_used |= BIT(i);
            return pool[i];
        }
    }
    return NULL;  // 池空了
}

void pool_free(void *ptr) {
    int idx = ((uint8_t *)ptr - pool[0]) / POOL_BLOCK_SIZE;
    pool_used &= ~BIT(idx);
}
```

## 第四层：正常/异常路径

### 正常路径

DMA：配置传输参数 → 启动 DMA → DMA 自行搬运 → 完成中断通知 CPU

### 异常路径

| 异常场景 | 现象 | 原因 | 处理方式 |
|---------|------|------|---------|
| 栈溢出 | 变量被意外覆盖，程序崩溃 | 递归太深或局部变量太大 | 增大栈或检查递归 |
| 堆碎片化 | malloc 返回 NULL | 频繁分配释放导致碎片 | 改用内存池 |
| DMA 地址未对齐 | 传输错误或效率低 | 源/目标地址不是 DMA 对齐要求 | 检查地址对齐 |
| Cache 不一致 | DMA 读到旧数据 | CPU Cache 中的修改未写回 RAM | DMA 前 Clean，DMA 后 Invalidate |
| DMA 缓冲溢出 | 数据丢失 | 搬运速度超过处理速度 | 增大缓冲区或提高处理速度 |

## 第五层：调试方法

### 内存检测

```c
// 栈高水位线检测
void check_stack_usage(void) {
    UBaseType_t watermark = uxTaskGetStackHighWaterMark(NULL);
    if (watermark < 50) {
        printf("WARNING: Stack low! Only %lu words remaining\n", watermark);
    }
}

// 堆使用量检测
void check_heap_usage(void) {
    printf("Free heap: %lu\n", xPortGetFreeHeapSize());
    printf("Min free heap: %lu\n", xPortGetMinimumEverFreeHeapSize());
}
```

### DMA 调试

```c
// 打印 DMA 通道状态
void dma_dump_channel(uint8_t ch) {
    printf("DMA CH%u:\n", ch);
    printf("  SRC: 0x%08lX\n", dma_get_src(ch));
    printf("  DST: 0x%08lX\n", dma_get_dst(ch));
    printf("  SIZE: %lu\n", dma_get_size(ch));
    printf("  DONE: %s\n", dma_is_done(ch) ? "YES" : "NO");
}

// 用 GPIO 翻转测量 DMA 传输时间
void dma_measure_time(void) {
    GPIO_SET(HIGH);  // 开始
    dma_start(DMA_CH1);
    while (!dma_is_done(DMA_CH1));
    GPIO_SET(LOW);   // 结束
    // 用示波器看 GPIO 高电平宽度
}
```

## 第六层：实战练习

### 练习 1：栈溢出检测（基础）

编写一个程序故意触发栈溢出，然后检测：
1. 写一个递归函数，递归深度逐渐增加
2. 每层递归在栈上分配 256 字节的局部数组
3. 用 `uxTaskGetStackHighWaterMark` 监测栈使用量
4. 观察栈溢出时程序的崩溃现象
5. 调整栈大小，找到安全阈值

### 练习 2：实现 DMA 内存拷贝（进阶）

使用 DMA 实现内存到内存的拷贝，对比 CPU 拷贝的性能：
1. 分配两个 1024 字节的缓冲区
2. 使用 DMA 从源缓冲区搬运到目标缓冲区
3. 使用 `memcpy` 做同样的拷贝
4. 用 GPIO 翻转测量两者耗时
5. 测试不同数据量（64/256/1024/4096 字节）的耗时对比

### 练习 3：阅读 DMA 驱动源码（深入）

阅读 `/home/ys/wq7036a/wq-audio/wqcore/driver/periph/bbb/hw/dma.h` 和相关实现，回答：
1. WQ7036A 有几个 DMA 通道？
2. DMA 支持哪些传输模式（内存到内存、内存到外设、外设到内存）？
3. 循环模式（Circular Mode）是如何配置的？
4. DMA 完成中断是如何触发的？

## 自测与验收

1. 嵌入式程序的内存布局从低到高依次是什么？
2. 栈和堆的区别是什么？（至少 3 点）
3. 为什么嵌入式里尽量少用 malloc？
4. DMA 的三种传输模式是什么？各用在什么场景？
5. 什么是 DMA 双缓冲？它解决了什么问题？
6. 什么是 Cache 一致性问题？如何解决？
7. 什么是内存池？它比 malloc 好在哪里？

## 延伸阅读

- [[c-core-C语言核心]] — 内存布局、指针
- [[compile-link-startup-编译链接与启动流程]] — .data/.bss 的拷贝和清零
- [[interrupt-concurrency-中断并发同步]] — DMA 中断与任务的同步
- [[audio-system-音频系统基础]] — 音频 DMA 的实际应用
- [[ring-buffer-环形缓冲区]] — ISR 与任务间的数据缓冲

## #flashcard

**Q: 嵌入式内存布局从低到高依次是什么？**
A: .text → .rodata → .data → .bss → heap → stack（堆向上增长，栈向下增长）。

**Q: 为什么嵌入式里尽量少用 malloc？**
A: 碎片化、执行时间不确定、无 MMU 保护、忘记 free 导致泄漏。

**Q: DMA 双缓冲解决了什么问题？**
A: 避免 CPU 和 DMA 同时操作同一块内存，CPU 处理一块时 DMA 写另一块，交替进行。

**Q: 什么是 Cache 一致性问题？**
A: CPU 写数据到 Cache 但还没写回 RAM，DMA 从 RAM 读数据时读到旧数据。

**Q: 如何解决 DMA 的 Cache 一致性问题？**
A: DMA 启动前 Clean Cache（写回 RAM），DMA 完成后 Invalidate Cache（让 CPU 重新从 RAM 读）。