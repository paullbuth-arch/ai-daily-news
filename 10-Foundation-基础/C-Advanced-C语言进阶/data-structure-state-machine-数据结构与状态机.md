---
type: concept
tags: [embedded, c, data-structure, state-machine, ring-buffer, linked-list]
aliases: [数据结构与状态机, FSM, 环形缓冲区]
---

# 数据结构与状态机

## 一句话结论

嵌入式里 80% 的业务逻辑都可以用**数组、链表、队列（环形缓冲区）、状态机**这四种结构表达清楚。其中状态机是嵌入式最重要的设计模式——协议解析、按键处理、设备管理，全靠它。

## 30秒先看懂

- 嵌入式数据结构的选择取决于场景：UART 收数据用环形缓冲区，任务间通信用队列，设备管理用链表，协议解析用状态机。环形缓冲区是 ISR（中断服务程序）与任务之间传递数据最安全的方式，因为它天然支持单生产者单消费者的无锁访问。状态机的核心是"在什么状态下，收到什么事件，跳转到什么状态"，用 switch-case 或函数指针表都能实现。侵入式链表把节点嵌入业务结构体，省掉了动态内存分配，是嵌入式中最常用的链表形式。

## 学完以后应该能做什么

**第一遍看完后可以：**
- 在项目中正确选用环形缓冲区处理 UART/SPI 数据收发
- 用 switch-case 实现一个按键状态机（去抖、短按、长按）
- 用函数指针表实现可扩展的状态机框架
- 理解侵入式链表和普通链表的区别，知道何时用哪种

**进阶后可以：**
- 实现分层状态机（HSM）处理复杂协议解析
- 设计无锁 SPSC 环形缓冲区，在 ISR 和任务间安全传递数据
- 用有序链表管理定时器任务
- 实现 DMA 双缓冲与 CPU 交替处理音频数据

## 前置知识

- C 语言指针、结构体、枚举、函数指针
- 中断的基本概念（ISR 的约束）
- 栈和队列的基本概念

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 环形缓冲区 | Ring Buffer / Circular Buffer | 首尾相接的固定大小数组，用 head/tail 指针管理读写位置 |
| 状态机 | State Machine / FSM | 有限状态自动机，由状态、事件、跳转三要素组成 |
| 侵入式链表 | Intrusive Linked List | 链表节点直接嵌入业务结构体内部，不需要额外分配节点内存 |
| 队列 | Queue | FIFO（先进先出）的数据结构，常用于任务间消息传递 |
| 分层状态机 | HSM / Hierarchical State Machine | 带父子层次的状态机，子状态未处理的事件自动冒泡到父状态 |
| 生产者/消费者 | Producer / Consumer | 写数据和读数据的两个角色，环形缓冲区中 ISR 是生产者，任务是消费者 |
| 内存池 | Memory Pool | 预分配的固定大小内存块集合，用于替代动态内存分配 |
| 描述符链 | Descriptor Chain | DMA 多段传输的配置链表，自动按顺序执行多个传输任务 |

## 第一层：费曼心智模型

### 类比：环形缓冲区就像旋转寿司台

寿司台是一个环形传送带，师傅（生产者/ISR）把寿司放在传送带上，你（消费者/任务）从传送带上取寿司。传送带是固定长度的——如果师傅放得太快，寿司堆满一圈，新寿司放不上去（缓冲区满）。如果你取得太慢，寿司在传送带上转很多圈（数据被覆盖）。

**状态机就像自动售货机**

你投币（事件）→ 售货机根据当前状态（等待投币/已投币/出货中）决定下一步动作。投 2 元在"等待投币"状态会跳转到"已投币"，但如果在"出货中"状态投币则无效。状态机明确定义了每种情况下应该做什么，不会出现"未定义行为"。

**边界：**
- 环形缓冲区不是万能的——多生产者多消费者场景需要锁保护
- 状态机不适合纯数据流处理（比如音频编解码），那里流水线更合适
- 侵入式链表不能跨平台序列化（节点指针只在当前内存布局有效）

### 场景演练：UART 接收数据

1. UART 硬件收到一个字节，触发接收中断
2. ISR（中断服务程序）中调用 `rbuf_put()` 把字节写入环形缓冲区——这是生产者
3. ISR 退出，CPU 回到任务上下文
4. 任务循环中调用 `rbuf_get()` 取出字节——这是消费者
5. 取出的字节送入协议解析状态机，逐字节解析帧格式
6. 一帧完整的协议解析完成后，触发上层业务逻辑

## 第二层：原理/时序/约束

### 环形缓冲区的无锁原理

```c
#define RBUF_SIZE 256          // 必须是 2 的幂
#define RBUF_MASK (RBUF_SIZE - 1)

typedef struct {
    uint8_t  buf[RBUF_SIZE];
    volatile uint32_t head;    // 写入方（ISR）修改
    volatile uint32_t tail;    // 读取方（任务）修改
} rbuf_t;

static inline bool rbuf_is_empty(rbuf_t *rb) {
    return rb->head == rb->tail;
}

static inline bool rbuf_is_full(rbuf_t *rb) {
    return ((rb->head - rb->tail) & RBUF_MASK) == 0
           && rb->head != rb->tail;
}

bool rbuf_put(rbuf_t *rb, uint8_t data) {
    if (rbuf_is_full(rb)) return false;
    rb->buf[rb->head & RBUF_MASK] = data;
    rb->head++;
    return true;
}

bool rbuf_get(rbuf_t *rb, uint8_t *data) {
    if (rbuf_is_empty(rb)) return false;
    *data = rb->buf[rb->tail & RBUF_MASK];
    rb->tail++;
    return true;
}
```

**为什么无锁安全？** `head` 只由 ISR 写入（单生产者），`tail` 只由任务写入（单消费者），双方都只做一次 32 位原子写入。前提是 `head` 和 `tail` 都是 32 位整数（在 32 位 CPU 上对齐读写是原子的）。

### 函数指针状态机表

```c
typedef void (*state_handler_t)(event_t ev);

static void state_idle(event_t ev) {
    if (ev == EV_START) {
        current_state = STATE_BUSY;
        start_work();
    }
}

static state_handler_t state_table[] = {
    [STATE_IDLE] = state_idle,
    [STATE_BUSY] = state_busy,
    [STATE_DONE] = state_done,
};

void fsm_dispatch(event_t ev) {
    state_table[current_state](ev);
}
```

### 侵入式链表

```c
typedef struct list_node {
    struct list_node *next;
    struct list_node *prev;
} list_node_t;

typedef struct {
    list_node_t node;
    uint32_t    id;
    char        name[32];
} device_t;
```

## 第三层：真实 SDK 代码

### WQ SDK 中的队列实现

WQ SDK 在 `wqcore/components/utils/inc/ring_fifo.h` 中提供了一个通用队列实现，用于核间和任务间通信：

```c
struct queue {
    uint32_t unit_size;
    uint32_t capacity;
    uint8_t *data;
    uint32_t reader;
    uint32_t writer;
};

int32_t init_queue(struct queue *q, uint32_t len, uint32_t unit_size);
int32_t enqueue(struct queue *q, const void *data);
int32_t dequeue(struct queue *q, void *data);
```

参考文件：`/home/ys/wq7036a/wq-audio/wqcore/components/utils/inc/ring_fifo.h`

### FreeRTOS 链表实现

FreeRTOS 内核使用侵入式链表管理任务状态，实现在 `list.h` 中：

```c
// /home/ys/wq7036a/wq-audio/wqcore/os/freertos_10_2_1/freertos/include/list.h
struct list_head {
    struct list_head *next;
    struct list_head *prev;
};
```

### WQ 协议解析状态机

在 WQ7036AX 的 UART 驱动中，协议帧解析使用状态机实现，典型的状态跳转为：`WAIT_HEADER → READ_LEN → READ_DATA → CHECK_CRC → HANDLE_FRAME`。参考 `wqcore/driver/periph/` 下的 UART 相关代码。

## 第四层：正常/异常路径

### 正常路径

环形缓冲区：UART ISR 写入字节 → 任务定期取出 → 数据完整交付
状态机：收到合法帧头 → 读长度 → 读数据 → 校验通过 → 交付完整帧

### 异常路径

| 异常场景 | 现象 | 原因 | 处理方式 |
|---------|------|------|---------|
| 环形缓冲区满 | 数据丢失 | ISR 写入速度 > 任务读取速度 | 增大缓冲区 / 提高任务优先级 |
| 状态机收到非法字节 | 帧解析失败 | 通信干扰或协议错误 | 回到初始状态等待下一个帧头 |
| 链表节点重复释放 | 野指针崩溃 | 逻辑错误导致 double free | 释放后置 NULL |
| 环形缓冲区 head/tail 不同步 | 读到脏数据 | 多生产者同时写入 | 保证单生产者单消费者 |

## 第五层：调试方法

### 环形缓冲区调试

```c
// 打印缓冲区状态
void rbuf_dump_status(rbuf_t *rb) {
    printf("RBUF: head=%lu, tail=%lu, avail=%lu\n",
           rb->head, rb->tail, rb->head - rb->tail);
}

// 检查是否配置为 2 的幂
void rbuf_sanity_check(void) {
    if (RBUF_SIZE & (RBUF_SIZE - 1)) {
        printf("ERROR: RBUF_SIZE=%d is not power of 2!\n", RBUF_SIZE);
    }
}
```

### 状态机调试

```c
// 状态机日志打印
#define FSM_DEBUG(fmt, ...) \
    printf("[FSM] state=%d event=%d " fmt "\n", current_state, ev, ##__VA_ARGS__)

void fsm_dispatch_debug(event_t ev) {
    FSM_DEBUG("transition started");
    state_table[current_state](ev);
    FSM_DEBUG("transition done, new_state=%d", current_state);
}
```

### 通用调试技巧

- 用 GPIO 翻转测量环形缓冲区处理延迟：ISR 入口拉高 GPIO，出口拉低
- 用逻辑分析仪抓 UART 信号，对比发送和接收数据
- 在环形缓冲区满时打印告警，帮助判断缓冲区大小是否合适

## 第六层：实战练习

### 练习 1：实现按键状态机（基础）

用 switch-case 实现一个按键去抖状态机：
- 初始状态 IDLE
- 检测到按下（低电平超过 5ms）→ PRESSED
- PRESSED 状态下释放 → IDLE（触发短按事件）
- PRESSED 状态下持续按住超过 1s → LONG_PRESS（触发长按事件）
- LONG_PRESS 状态下释放 → IDLE（触发长按释放事件）

### 练习 2：实现环形缓冲区包裹 `printf`（进阶）

将标准 `printf` 的输出重定向到一个环形缓冲区，然后通过 DMA 或中断方式异步发送出去。要求：
- 实现 `rbuf_put_str()` 批量写入字符串
- 实现 `rbuf_send_task()` 任务循环读取缓冲区数据并通过 UART 发送
- 验证 ISR 写入和任务读取之间没有数据竞争

### 练习 3：阅读真实源码（深入）

阅读 `/home/ys/wq7036a/wq-audio/wqcore/components/utils/inc/ring_fifo.h` 中的队列实现，回答以下问题：
1. 这个队列的容量是如何计算的？(`capacity = len / unit_size - 1` 中为什么减 1)
2. reader 和 writer 字段是如何回绕的？
3. 这个队列是线程安全的吗？在什么条件下可以无锁使用？

## 自测与验收

1. 环形缓冲区的大小为什么必须是 2 的幂？
2. 单生产者单消费者场景下，环形缓冲区为什么不需要加锁？
3. 状态机和普通的 if-else 语句有什么区别？状态机有什么优势？
4. 侵入式链表如何做到"一个结构体可以同时挂在多个链表"？
5. 分层状态机（HSM）中，子状态未处理的事件如何传递？
6. 在 ISR 中调用 `printf` 打印日志有什么风险？应该用什么替代方案？
7. 描述 DMA 双缓冲的工作流程，以及为什么它可以避免 CPU 和 DMA 同时操作同一块内存。

## 延伸阅读

- [[ring-buffer-环形缓冲区]] —— 完整代码片段
- [[interrupt-concurrency-中断并发同步]] —— ISR 与任务间的数据同步
- [[memory-dma-内存管理与DMA]] —— DMA 双缓冲与环形缓冲区结合使用
- [[platform-driver-外设驱动框架]] —— UART/I2C 驱动中的数据缓冲
- [[c-core-C语言核心]] —— 指针、结构体、函数指针

## #flashcard

**Q: 环形缓冲区 size 为什么必须是 2 的幂？**
A: 为了用位掩膜 `& MASK` 代替取模 `% SIZE`，因为 `&` 操作比 `%` 快得多（一个时钟周期 vs 几十个时钟周期）。

**Q: 状态机三要素是什么？**
A: 状态（State）、事件（Event）、跳转（Transition）。

**Q: 侵入式链表 vs 普通链表的区别？**
A: 侵入式把链表节点嵌入业务结构体，不需要额外 malloc 分配节点；普通链表节点包含指向数据的指针，需要单独分配数据和节点内存。

**Q: 什么是 SPSC？**
A: Single Producer Single Consumer（单生产者单消费者），环形缓冲区在这种模式下可以无锁运行。