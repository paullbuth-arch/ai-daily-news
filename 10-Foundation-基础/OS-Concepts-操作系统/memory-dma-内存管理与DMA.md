# 内存管理与 DMA

**一句话结论（20% 核心）**：内存管理就是决定数据放哪里、怎么放、怎么搬；DMA（Direct Memory Access，直接内存访问）就是让外设自己搬数据，不用 CPU 一件件搬——CPU 只需发号施令，DMA 控制器负责搬运，搬完中断通知 CPU。

---

## 第一层：核心认知

### 1.1 费曼类比

把 MCU 的内存想象成一个大办公楼：

- **Flash（仓库）**：存放设计图纸（程序代码），不常改，但掉电不丢。
- **SRAM（办公桌区）**：员工工作的地方，每个人有自己的桌面空间（变量），下班清空（掉电丢失）。
- **堆（公共储物柜）**：需要的时候申请一个柜子（malloc），不用了还回去（free）。
- **栈（每人的背包）**：进函数时打开背包装东西（局部变量），出函数时合上背包（自动释放）。
- **DMA（快递小哥）**：你告诉他"从 A 搬到 B，搬 N 件"，他就自己搬，搬完打电话通知你。

### 1.2 内存分区详解

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

| 区域 | 分配方式 | 生命周期 | 典型内容 |
|---|---|---|---|
| .text | 编译时固定 | 永久 | 函数代码 |
| .rodata | 编译时固定 | 永久 | 字符串常量、const 数组 |
| .data | 编译时固定 | 程序运行期间 | 有初值的全局变量 |
| .bss | 编译时固定 | 程序运行期间 | 无初值的全局变量 |
| heap | 运行时 malloc/free | 手动管理 | 动态缓冲区 |
| stack | 进入/退出函数自动 | 函数生命周期 | 局部变量、返回地址 |

### 1.3 DMA 是什么？

**没有 DMA 的情况**（CPU 搬运）：

```c
// CPU 一个字节一个字节地从 UART 搬到内存
for (int i = 0; i < 1024; i++) {
    buf[i] = UART_DR;  // 每次都要 CPU 参与
}
```

**有 DMA 的情况**（DMA 搬运）：

```c
// 配置 DMA：从 UART 数据寄存器搬到 buf，搬 1024 字节
dma_config(DMA_CH1,
           .src  = &UART_DR,       // 源地址（UART 数据寄存器）
           .dst  = buf,            // 目标地址（内存缓冲区）
           .size = 1024,           // 搬运数量
           .src_inc = false,       // 源地址不自增（始终是同一个寄存器）
           .dst_inc = true);       // 目标地址自增
dma_start(DMA_CH1);

// CPU 去做别的事，DMA 搬完后触发中断通知 CPU
```

### 1.4 最小代码示例

```c
uint8_t src[64] = {1, 2, 3, 4, 5};
uint8_t dst[64] = {0};

// 配置 DMA 通道 1：从 src 搬到 dst，64 字节
dma_config_t cfg = {
    .src_addr  = (uint32_t)src,
    .dst_addr  = (uint32_t)dst,
    .size      = 64,
    .direction = DMA_MEM_TO_MEM,
    .src_inc   = true,
    .dst_inc   = true,
};
dma_init(DMA_CH1, &cfg);
dma_start(DMA_CH1);

// CPU 可以做其他事情
// ...

// 等待 DMA 完成（轮询方式）
while (!dma_is_done(DMA_CH1));

// 或者等待 DMA 完成中断（中断方式）
// DMA 完成后会触发 dma_isr()
```

### 1.5 如果只记得一件事

> CPU 搬数据慢且占用 CPU 时间，DMA 搬数据快且不占 CPU。音频、UART、ADC 等需要大量搬运数据的场景，优先用 DMA。

---

## 第二层：实战理解

### 2.1 栈溢出：最常见的内存问题

**栈溢出**发生在任务使用的栈空间超过了分配的大小，会覆盖相邻的内存（堆、其他任务的栈、全局变量），导致不可预测的崩溃。

**常见原因**：

1. **递归太深**：每层递归都在栈上分配空间。
2. **局部变量太大**：`char buf[4096]` 这种大数组直接定义在函数里。
3. **调用链太深**：A → B → C → D → E，每层都有局部变量。
4. **中断嵌套**：ISR 里又调用了很多函数。

**检测方法**：

```c
// 方法 1：启动时把栈区域填充为特定值（如 0xA5）
// 运行一段时间后检查还有多少 0xA5 没被覆盖

// 方法 2：FreeRTOS 提供的高水位线检测
UBaseType_t watermark = uxTaskGetStackHighWaterMark(NULL);
// watermark = 运行以来栈剩余的最小值（word），接近 0 就危险了
printf("Stack watermark: %lu words\n", watermark);
```

**解决方法**：
- 增大队栈大小。
- 把大的局部变量改为 `static` 或放到堆上。
- 减少递归，改用循环。

### 2.2 堆管理：为什么嵌入式里尽量少用 malloc？

| 问题 | 说明 |
|---|---|
| 碎片化 | 频繁 malloc/free 导致内存碎片，大块连续内存分配失败 |
| 不确定性 | malloc 的执行时间不可预测（需要搜索空闲块） |
| 无 MMU 保护 | 嵌入式通常没有虚拟内存，堆溢出直接踩坏其他数据 |
| 忘记 free | 内存泄漏在长时间运行的嵌入式设备中是致命的 |

**替代方案**：

```c
// 方案 1：静态分配（推荐）
static uint8_t buffer[1024];  // 编译时固定大小

// 方案 2：内存池（固定大小的块）
typedef struct {
    uint8_t pool[16][256];     // 16 个 256 字节的块
    uint32_t used;             // 位图标记哪些块被占用
} mem_pool_t;

void *pool_alloc(mem_pool_t *p) {
    for (int i = 0; i < 16; i++) {
        if (!(p->used & (1U << i))) {
            p->used |= (1U << i);
            return p->pool[i];
        }
    }
    return NULL;
}

void pool_free(mem_pool_t *p, void *ptr) {
    int idx = ((uint8_t *)ptr - p->pool[0]) / 256;
    p->used &= ~(1U << idx);
}
```

### 2.3 DMA 双缓冲：音频场景的标准模式

当 DMA 在往缓冲区 A 写数据时，CPU 处理缓冲区 B 的数据。DMA 写完 A 后切换到 B，CPU 开始处理 A。这样 DMA 和 CPU 永远不会同时操作同一块缓冲区。

```c
uint8_t buf_a[512];
uint8_t buf_b[512];

volatile uint8_t *dma_buf  = buf_a;   // DMA 正在写这个
volatile uint8_t *proc_buf = buf_b;   // CPU 正在处理这个

// DMA 完成中断
void dma_half_complete_isr(void) {
    // buf_a 写完了，交换
    swap(dma_buf, proc_buf);
    // 通知处理任务
    xSemaphoreGiveFromISR(sem, NULL);
}

void dma_full_complete_isr(void) {
    // buf_b 写完了，交换
    swap(dma_buf, proc_buf);
    xSemaphoreGiveFromISR(sem, NULL);
}

// 处理任务
void process_task(void *p) {
    for (;;) {
        xSemaphoreTake(sem, portMAX_DELAY);
        // 安全处理 proc_buf 中的数据
        audio_process(proc_buf, 512);
    }
}
```

### 2.4 DMA 缓存一致性问题

当 MCU 有 Cache（L1/L2）时，CPU 写数据到 Cache 而不直接写 RAM。如果此时 DMA 从 RAM 读数据，读到的是旧数据（Cache 里的修改还没写回 RAM）。

```
CPU 写数据 → Cache（还没写回 RAM）
DMA 从 RAM 读 → 读到旧数据！
```

**解决方法**：

```c
// 在启动 DMA 之前，把 Cache 中的修改写回 RAM（Clean）
cache_clean_range(src, size);

// DMA 写完后，让 Cache 中的旧数据失效（Invalidate）
// 这样 CPU 下次读会从 RAM 重新取
cache_invalidate_range(dst, size);
```

**什么时候会遇到这个问题？**
- WQ7036A 的 DCORE（DSP）通过 DMA 搬运音频数据到共享 RAM。
- ACORE 的 CPU 在 Cache 中缓存了这段 RAM。
- DSP 的 DMA 修改了 RAM 数据，但 ACORE 的 Cache 还是旧的。

### 2.5 DMA 循环模式

对于持续不断的音频流，DMA 可以配置为**循环模式（Circular Mode）**：搬到末尾后自动回到开头继续搬，不需要 CPU 重新配置。

```c
dma_config_t cfg = {
    .mode = DMA_CIRCULAR,  // 循环模式
    .size = 1024,          // 缓冲区总大小
    // DMA 会在搬到 512 和 1024 时各触发一次中断（半传输 / 全传输）
};
```

### 2.6 项目中的应用

WQ7036A 音频管道中 DMA 的典型使用：

```
PDM 麦克风 → [DMA] → PCM 缓冲区 → DSP 处理（KWS/降噪）
                                          ↓
                                    [DMA] → I2S 输出 → 功放 → 扬声器
```

详见 [[audio-system-音频系统基础]] 和 [[wq7036ax-audio-pipeline-WQ7036AX音频管道]]。

---

## 第三层：深入扩展

### 3.1 DMA 传输模式详解

| 模式 | 说明 | 典型场景 |
|---|---|---|
| Memory → Memory | 内存拷贝 | 大块数据拷贝 |
| Memory → Peripheral | 内存到外设 | UART 发送、I2S 播放 |
| Peripheral → Memory | 外设到内存 | UART 接收、ADC 采样 |
| Peripheral → Peripheral | 外设到外设 | 少见 |

### 3.2 DMA 描述符链与 Scatter-Gather

高级 DMA 控制器支持**描述符链（Descriptor Chain）**：一次配置多个传输任务，DMA 自动按链执行。

```c
// 描述符链示例
dma_desc_t desc[3] = {
    { .src = buf1, .dst = UART_DR, .size = 100, .next = &desc[1] },
    { .src = buf2, .dst = UART_DR, .size = 200, .next = &desc[2] },
    { .src = buf3, .dst = UART_DR, .size = 50,  .next = NULL },
};
dma_start_chain(DMA_CH1, &desc[0]);
// DMA 会自动依次传输三段数据
```

### 3.3 内存保护单元（MPU）

MPU（Memory Protection Unit，内存保护单元）可以给内存区域设置访问权限：

| 权限 | 说明 |
|---|---|
| 可读 / 可写 / 可执行 | 基本权限 |
| 特权级访问 | 只有内核模式才能访问 |
| 禁止执行 | .data/.bss 区域不可执行代码（防栈溢出攻击） |

**FreeRTOS 中 MPU 的典型用法**：

```c
// 给任务栈设置"栈溢出保护区"
// 栈底部 32 字节设为不可读写
// 如果任务栈溢出踩到这块区域，触发 MemFault 异常
MPU_Region_Config(0, stack_bottom, 32, MPU_NO_ACCESS);
```

### 3.4 动态内存分配器的设计

如果确实需要动态分配，嵌入式中常用的简单分配器：

**首次适配（First Fit）**：
```c
typedef struct block {
    size_t size;
    bool   free;
    struct block *next;
} block_t;

void *my_malloc(size_t size) {
    block_t *b = heap_start;
    while (b) {
        if (b->free && b->size >= size) {
            b->free = false;
            return (void *)(b + 1);  // 返回 block 头之后的空间
        }
        b = b->next;
    }
    return NULL;
}
```

**最佳实践**：嵌入式中优先用静态分配或固定大小内存池，避免通用 malloc。

### 3.5 常见问题

- **栈和堆的区别？** 栈自动管理、速度快、空间小；堆手动管理、速度慢、空间大。
- **DMA 传输期间 CPU 能做什么？** 可以执行不访问 DMA 正在使用的 RAM 区域的代码。如果 CPU 访问同一块 RAM，会被总线仲裁器挂起。
- **为什么 DMA 要求地址对齐？** 很多 DMA 控制器要求传输地址按 4 字节或更大边界对齐，否则传输效率下降或报错。
- **Cache 一致性问题怎么解决？** 在 DMA 启动前 Clean Cache（写回），DMA 完成后 Invalidate Cache（失效）。
- **什么是 Scatter-Gather DMA？** 用描述符链让 DMA 自动执行多段不连续的传输。

### 3.6 核心术语表

| 英文 | 中文 | 说明 |
|---|---|---|
| DMA | 直接内存访问 | Direct Memory Access |
| Heap | 堆 | 动态分配的内存区域 |
| Stack | 栈 | 函数调用的临时存储 |
| Stack Overflow | 栈溢出 | 栈空间不足 |
| Memory Fragmentation | 内存碎片 | 频繁分配/释放导致的不连续空闲块 |
| Memory Pool | 内存池 | 固定大小的预分配块 |
| Double Buffer | 双缓冲 | DMA 和 CPU 交替使用两块内存 |
| Circular Buffer | 循环缓冲 | 首尾相接的缓冲区 |
| Cache Coherency | 缓存一致性 | Cache 和 RAM 数据保持同步 |
| MPU | 内存保护单元 | Memory Protection Unit |
| Descriptor Chain | 描述符链 | DMA 的多段传输配置 |

### 3.7 延伸阅读

- [[c-core-C语言核心]] —— 内存布局、指针
- [[compile-link-startup-编译链接与启动流程]] —— .data/.bss 的拷贝和清零
- [[interrupt-concurrency-中断并发同步]] —— DMA 中断与任务的同步
- [[audio-system-音频系统基础]] —— 音频 DMA 的实际应用
- [[ring-buffer-环形缓冲区]] —— ISR 与任务间的数据缓冲
