---
type: concept
tags: [embedded, ipc, multicore, amp, shared-memory, wq7036a]
aliases: [多核通信, IPC, 核间通信, 共享内存]
---

# 多核通信与 IPC

## 一句话结论

多核通信就是两个或多个 CPU 之间要交换数据，IPC（Inter-Process Communication，进程间通信）就是它们之间的"传话筒"。核心手段是**共享内存 + 中断通知**——一个核往共享区域写数据，然后发软中断告诉另一个核"有消息了"。

## 30秒先看懂

- 多核通信的基本模式是：发送方把数据写入共享内存，然后通过软中断通知接收方来取。WQ7036A 是典型的 AMP（不对称多处理）架构——ACORE 跑 FreeRTOS（应用逻辑），BCORE 跑蓝牙专用 RTOS（蓝牙协议栈），DCORE 跑 DSP 固件（音频算法），三个核完全独立，通过 IPC 模块通信。IPC 的核心概念是端口（Port）——发送方和接收方通过端口名建立连接，消息格式包含 magic（0x57514943 "WQIC"）、端口号、长度和载荷。多核通信需要特别注意内存屏障（防止指令重排导致接收方看到不完整的数据）、Cache 一致性（一个核的 Cache 与另一个核的 RAM 数据不一致）和自旋锁（多核互斥）。

## 学完以后应该能做什么

**第一遍看完后可以：**
- 理解 WQ7036A 三核分工和通信方式
- 知道共享内存 + 软中断的 IPC 基本流程
- 理解 AMP 和 SMP 的区别
- 知道为什么多核通信需要内存屏障和 volatile

**进阶后可以：**
- 使用 WQ SDK 的 IPC API 编写跨核通信代码
- 实现无锁 SPSC 队列用于核间数据传输
- 分析和解决 Cache 一致性问题
- 设计多核系统的消息协议

## 前置知识

- 中断的基本概念（软中断、中断处理函数）
- 内存管理基础（共享内存、Cache 的工作原理）
- 并发编程基础（数据竞争、原子操作）

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 进程间通信 | IPC | Inter-Process Communication，多核/多进程间的数据交换机制 |
| 不对称多处理 | AMP | Asymmetric Multi-Processing，各核跑不同的 OS/裸机 |
| 对称多处理 | SMP | Symmetric Multi-Processing，所有核跑同一个 OS |
| 共享内存 | Shared Memory | 多核都能访问的同一块 RAM 区域 |
| 软中断 | Soft Interrupt / IPI | 一个核主动发送给另一个核的中断信号 |
| 自旋锁 | Spinlock | 多核互斥锁，忙等待直到锁可用 |
| 内存屏障 | Memory Barrier | 防止编译器和 CPU 重排指令的指令 |
| 缓存一致性 | Cache Coherency | 保证多核 Cache 中的数据与主存一致 |
| 邮箱 | Mailbox | 一种简化的 IPC 机制，像邮箱一样投递和收取消息 |

## 第一层：费曼心智模型

### 类比：公司里的部门协作

多核系统就像公司里的多个部门：

- **共享内存**：大家共用一块公告板。A 部门把文件贴在公告板上，B 部门去取。
- **软中断/门铃**：A 部门贴完文件后，按一下 B 部门的门铃——"有新文件了，快来看"。
- **自旋锁**：同时只能有一个人用公告板——其他人只能在旁边等着（忙等待）。
- **内存屏障**：确保文件全部贴好后，再按门铃。防止门铃响了但文件还没贴完。

```
ACORE 写数据到共享内存
   ↓
ACORE 发软中断给 BCORE
   ↓
BCORE 收到中断
   ↓
BCORE 从共享内存读数据
   ↓
BCORE 处理完，发软中断回复 ACORE
```

**边界：**
- 共享内存不是"自动同步"的——一个核修改了数据，另一个核未必立即看到
- 自旋锁适合短时间等待，长时间持有应该用信号量
- IPC 不是免费的——每次 IPC 有延迟（中断响应 + 上下文切换），不适合高频小数据

### 场景演练：ACORE 发蓝牙命令给 BCORE

1. ACORE 调用 `wq_ipc_send_msg(BCORE, PORT_BT_CMD, PORT_APP, cmd_data, len)`
2. 内部：把消息写入共享内存的 mailbox 区域
3. 写入完成后，执行内存屏障（`__sync_synchronize()`）
4. 发送软中断给 BCORE
5. BCORE 收到中断，进入 ISR
6. ISR 调用注册的回调函数 `bt_cmd_handler()`
7. 回调函数从共享内存读取消息内容
8. BCORE 处理蓝牙命令，将结果通过 IPC 回复 ACORE

## 第二层：原理/时序/约束

### 共享内存 + 中断通知的时序

```
发送方（ACORE）:               接收方（BCORE）:
    │                              │
    ├─ 写数据到共享内存             │
    ├─ 内存屏障（确保数据写完）      │
    ├─ 写标志位                     │
    ├─ 发软中断 ─────────────────→ │
    │                              ├─ 进入 ISR
    │                              ├─ 读共享内存
    │                              ├─ 处理消息
    │←──── 软中断回复 ─────────────┤
    │                              │
```

### 数据一致性问题

| 问题 | 说明 | 解决方法 |
|------|------|---------|
| 数据竞争 | 两个核同时修改同一变量 | 自旋锁保护 |
| Cache 不一致 | 一个核的 Cache 里是新数据，另一个核看到的是旧数据 | Cache Clean/Invalidate |
| 内存序重排 | 编译器/CPU 重排指令，对方看到不完整的写入 | 内存屏障 |

### 自旋锁实现

```c
// RISC-V 原子操作实现自旋锁
void spin_lock(spinlock_t *lock) {
    while (__sync_lock_test_and_set(lock, 1)) {
        // 忙等待（spin）
    }
}

void spin_unlock(spinlock_t *lock) {
    __sync_lock_release(lock);
}
```

### 无锁 SPSC 队列

```c
typedef struct {
    uint8_t  buf[256];
    volatile uint32_t head;  // 写入方修改
    volatile uint32_t tail;  // 读取方修改
} spsc_queue_t;

bool spsc_put(spsc_queue_t *q, uint8_t data) {
    uint32_t next = (q->head + 1) & 0xFF;
    if (next == q->tail) return false;
    q->buf[q->head] = data;
    __sync_synchronize();     // 内存屏障
    q->head = next;
    return true;
}
```

## 第三层：真实 SDK 代码

### WQ7036A IPC 实现

IPC 模块位于 `/home/ys/wq7036a/wq-audio/wqcore/components/amp/ipc/`，包含 `ipc.h` 和 `ipc.c`。

核心数据结构：

```c
// IPC 消息头
typedef struct mailbox {
    uint32_t size;       /* mailbox 大小 */
    uint16_t w;          /* 写索引 */
    uint16_t r;          /* 读索引 */
    uint8_t data[];      /* 环形数据缓冲区 */
} wq_ipc_mailbox_t;

// IPC 控制块
typedef struct ipc_ctrl {
    uint32_t magic;      /* 有效性校验标识 */
    volatile wq_ipc_mailbox_t
        *mailbox[WQ_CORES_EN_MAX][WQ_CORES_EN_MAX - 1];
    volatile struct list_head ipc_named_port_list;
} wq_ipc_ctrl_t;
```

核心 API：

```c
// 发送消息到其他核
WQ_RET wq_ipc_send_msg(WQ_CORES dst_core, uint16_t dst_port,
                        uint16_t src_port, const void *payload, uint16_t len);

// 注册端口（其他核可以搜索到这个端口）
uint16_t wq_ipc_register_port(const char *name, wq_ipc_handler handler);

// 注册本地端口（仅本地使用）
uint16_t wq_ipc_register_local_port(wq_ipc_handler handler);

// 按名称搜索端口
WQ_RET wq_ipc_search_port(const char *name, WQ_CORES *core,
                           uint16_t *port, uint32_t timeout);
```

### IPC 通信流程

```
ACORE                          BCORE
  │                              │
  ├─ 注册端口 "BT_CMD" ──────────→  (wq_ipc_register_port)
  │                              ├─ 注册端口 "BT_EVT"
  │                              │
  ├─ 搜索端口 "BT_EVT" ─────────→│
  │←──── 返回端口号 ──────────────┤
  │                              │
  ├─ 发送消息到 "BT_CMD" ───────→│  (wq_ipc_send_msg)
  │                              ├─ 收到消息，处理
  │←──── 回复到 "BT_EVT" ───────┤
  ├─ 收到回复                    │
```

## 第四层：正常/异常路径

### 正常路径

端口注册 → 端口发现 → 消息发送（写入共享内存 → 内存屏障 → 软中断）→ 消息接收（ISR → 回调处理）→ 回复

### 异常路径

| 异常场景 | 现象 | 原因 | 处理方式 |
|---------|------|------|---------|
| IPC 超时 | 消息发送返回超时错误 | 接收方未及时响应或端口未注册 | 增加超时时间或重试 |
| 共享内存溢出 | 消息发送失败 | mailbox 满了，接收方处理太慢 | 增大 mailbox 或优化接收方处理速度 |
| 数据错乱 | 收到的消息内容不对 | 忘记加内存屏障，写入顺序被重排 | 在写标志位前加 `__sync_synchronize()` |
| 死锁 | 两个核互相等待对方的锁 | 自旋锁顺序不一致 | 规范锁的获取顺序 |
| 端口未注册 | 消息无响应 | 接收方还没注册端口，发送方就发了消息 | 先搜索端口确认已注册再发送 |

## 第五层：调试方法

### IPC 通信调试

```c
// 打印 IPC 状态
void ipc_dump_status(void) {
    wq_ipc_ctrl_t *ctrl = wq_ipc_get_ctrl();
    printf("IPC magic: 0x%08X\n", ctrl->magic);
    if (ctrl->magic != 0x57514943) {
        printf("WARNING: IPC magic mismatch!\n");
    }
}

// 打印 mailbox 使用情况
void ipc_mailbox_dump(wq_ipc_mailbox_t *mb) {
    uint32_t used = (mb->w - mb->r) & (mb->size - 1);
    printf("Mailbox: size=%lu, w=%u, r=%u, used=%lu\n",
           mb->size, mb->w, mb->r, used);
}
```

### 内存屏障问题排查

```bash
# 方法 1：在关键位置加 GPIO 翻转，用逻辑分析仪看时序
# 发送方：GPIO 拉高 → 写数据 → GPIO 拉低
# 接收方：GPIO 拉高 → 读数据 → GPIO 拉低

# 方法 2：用 GDB 读取共享内存内容
(gdb) x/32x 0x20080000  # 查看共享内存区域
```

## 第六层：实战练习

### 练习 1：实现简单的轮询 IPC（基础）

用共享内存 + 轮询实现两个核之间的通信：
1. 在链接脚本中定义共享内存区域
2. ACORE 往共享内存写数据，设置标志位
3. BCORE 轮询标志位，检测到数据后读取
4. 验证数据正确传输

### 练习 2：使用 SDK IPC API（进阶）

在 WQ7036AX SDK 中使用 IPC API 实现 ACORE 和 BCORE 的通信：
1. 在 ACORE 上注册一个端口
2. 在 BCORE 上搜索并连接该端口
3. 发送一条消息，验证接收方正确收到
4. 实现双向通信（发送和回复）

### 练习 3：阅读 IPC 源码（深入）

阅读 `/home/ys/wq7036a/wq-audio/wqcore/components/amp/ipc/ipc.c`，回答：
1. `wq_ipc_send_msg` 内部如何把消息写入 mailbox？
2. 软中断是如何触发的（写哪个寄存器）？
3. mailbox 的读写索引是如何回绕的？
4. 消息发送和接收之间的内存屏障在哪里？

## 自测与验收

1. AMP 和 SMP 的区别是什么？WQ7036A 属于哪种？
2. 为什么多核通信需要内存屏障？
3. 自旋锁和互斥量（Mutex）的区别是什么？在什么场景下用自旋锁？
4. 什么是 Cache 一致性问题？如何解决？
5. WQ7036A 的 IPC 消息格式包含哪些字段？
6. 为什么共享内存的变量需要加 `volatile` 关键字？
7. 什么是无锁队列？它在什么条件下可以安全使用？

## 延伸阅读

- [[computer-arch-mcu-计算机组成与MCU架构]] — 总线、Cache、多核概念基础
- [[interrupt-concurrency-中断并发同步]] — 临界区、数据竞争、同步原语
- [[memory-dma-内存管理与DMA]] — 共享内存的物理实现、Cache 一致性
- [[audio-system-音频系统基础]] — DCORE 与 ACORE 之间的音频数据流

## #flashcard

**Q: 多核通信的两个核心手段是什么？**
A: 共享内存（数据放哪里）+ 中断通知（怎么告诉对方）。

**Q: AMP 和 SMP 的区别？**
A: AMP 各核跑不同 OS（WQ7036A 用），SMP 所有核跑同一个 OS（手机/PC 用）。

**Q: 为什么需要内存屏障？**
A: 防止编译器和 CPU 重排指令，导致接收方看到不完整的数据（比如标志位先写但数据后写）。

**Q: WQ7036A 的 IPC Magic 是什么？**
A: 0x57514943（"WQIC"），用于校验消息有效性。

**Q: 自旋锁适合什么场景？**
A: 多核之间短时间互斥（微秒级），不适合长时间持有（会浪费 CPU）。