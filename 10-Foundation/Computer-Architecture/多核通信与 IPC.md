# 多核通信与 IPC

**一句话结论（20% 核心）**：多核通信就是两个或多个 CPU 之间要交换数据，IPC（Inter-Process Communication，进程间通信）就是它们之间的"传话筒"。核心手段是**共享内存 + 中断通知**——一个核往共享区域写数据，然后发软中断告诉另一个核"有消息了"。

---

## 第一层：核心认知

### 1.1 为什么需要多核？

单个 CPU 越来越快，但总有极限。多核的思路是"分工合作"：

| 场景 | 为什么用多核 |
|---|---|
| 音频处理 | DSP 做音频算法比通用 CPU 快 10 倍以上 |
| 蓝牙协议栈 | 对实时性要求极高，不能被应用层任务打断 |
| 功耗管理 | 不需要某个核时可以完全关闭它 |
| 功能隔离 | 一个核崩溃不影响其他核 |

### 1.2 费曼类比

多核系统就像公司里的多个部门：

- **共享内存**：大家共用一块公告板。A 部门把文件贴在公告板上，B 部门去取。
- **软中断/信箱**：A 部门贴完文件后，按一下 B 部门的门铃——"有新文件了，快来看"。
- **消息队列**：通过前台（中间人）转交文件，按顺序处理。

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

### 1.3 核心概念速查表

| 术语 | 中文 | 含义 |
|---|---|---|
| IPC | 进程间通信 | Inter-Process Communication |
| Shared Memory | 共享内存 | 多核都能访问的 RAM 区域 |
| Soft Interrupt | 软中断 | 一个核发送给另一个核的中断信号 |
| Message Queue | 消息队列 | 按顺序传递的消息管道 |
| Spinlock | 自旋锁 | 多核互斥锁（忙等待） |
| AMP | 不对称多处理 | Asymmetric Multi-Processing，每个核跑不同的 OS |
| SMP | 对称多处理 | Symmetric Multi-Processing，所有核跑同一个 OS |
| Cache Coherency | 缓存一致性 | 保证多核看到的内存数据一致 |

### 1.4 WQ7036A 三核分工

| 核 | 架构 | 职责 | 启动顺序 |
|---|---|---|---|
| **ACORE** | RISC-V (rv32imac) | 应用逻辑、FreeRTOS、按键、LED | 第 1 个启动 |
| **BCORE** | RISC-V | 蓝牙协议栈（BT/BLE） | ACORE 启动后拉起 |
| **DCORE** | Xtensa HiFi5 (DSP) | 音频编解码、KWS、降噪 | ACORE 启动后拉起 |

**启动顺序**：

```
上电 → ACORE 启动 → 初始化硬件和 IPC → ACORE 发命令启动 BCORE
                                        → ACORE 发命令启动 DCORE
```

### 1.5 最小代码示例

```c
// 最简单的多核通信：共享内存 + 轮询（不推荐，但最容易理解）

// 共享内存区域（在两个核的链接脚本中都要映射到同一地址）
#define SHARED_BASE  0x20080000
#define SHARED_FLAG  (*(volatile uint32_t *)(SHARED_BASE + 0))
#define SHARED_DATA  (*(volatile uint32_t *)(SHARED_BASE + 4))

// --- ACORE 侧（发送方）---
SHARED_DATA = 0x12345678;    // 写入数据
SHARED_FLAG = 1;             // 设置标志位，告诉 BCORE "有数据了"

// --- BCORE 侧（接收方）---
while (SHARED_FLAG != 1);    // 等待标志位（轮询，浪费 CPU）
uint32_t data = SHARED_DATA; // 读取数据
SHARED_FLAG = 0;             // 清除标志位
```

**这个例子的问题**：BCORE 一直在轮询等待，浪费 CPU 时间。实际中用**中断通知**替代轮询。

### 1.6 如果只记得一件事

> 多核通信 = 共享内存（数据放哪里） + 中断通知（怎么告诉对方有新数据）。WQ7036A 用软中断 + 共享内存实现 ACORE/BCORE/DCORE 之间的 IPC。

---

## 第二层：实战理解

### 2.1 共享内存 + 中断通知的经典流程

```
发送方（如 ACORE）:
1. 把消息写入共享内存
2. 发软中断（Soft IRQ）给接收方

接收方（如 BCORE）:
3. 收到中断，进入 ISR
4. 从共享内存读取消息
5. 处理消息
6. （可选）写回复到共享内存，发软中断回复
```

**为什么需要中断通知而不是轮询？**

- 轮询：接收方一直在查"有没有新消息"，浪费 CPU、浪费功耗。
- 中断：没有消息时接收方可以做其他事或休眠，有消息时被中断唤醒。

### 2.2 多核之间的数据一致性问题

当 ACORE 和 BCORE 同时读写同一块共享内存时，会遇到和中断并发类似的问题，但更复杂：

| 问题 | 说明 |
|---|---|
| 数据竞争 | 两个核同时修改同一变量 |
| Cache 不一致 | ACORE 的 Cache 里是新数据，BCORE 看到的还是旧数据 |
| 内存序 | 编译器/CPU 可能重排指令，导致对方看到不完整的写入 |

**解决方法**：

```c
// 1. 自旋锁（Spinlock）保护共享数据
spinlock_t lock;

void acore_write(void) {
    spin_lock(&lock);
    shared_data = new_value;
    spin_unlock(&lock);
}

void bcore_read(void) {
    spin_lock(&lock);
    value = shared_data;
    spin_unlock(&lock);
}
```

```c
// 2. 内存屏障（Memory Barrier）防止指令重排
shared_buf[0] = data_0;
shared_buf[1] = data_1;
__sync_synchronize();     // 内存屏障：确保上面的写入在下面的标志位写入之前完成
shared_flag = 1;          // 标志位必须最后写
```

### 2.3 WQ7036A IPC 的实际机制

WQ7036A 的 IPC 模块位于 `wqcore/components/amp/ipc/`，核心概念：

| 概念 | 说明 |
|---|---|
| Port（端口） | 命名通道，发送方和接收方通过端口名建立连接 |
| Message（消息） | 有固定格式的数据包，包含端口号、长度、载荷 |
| Magic | 消息标识 `0x57514943`（"WQIC"），用于校验消息有效性 |

**通信流程**：

```
ACORE                          BCORE
  │                              │
  ├─ 注册端口 "BT_CMD" ──────────→
  │                              ├─ 注册端口 "BT_EVT"
  │                              │
  ├─ 发送消息到 "BT_CMD" ───────→│
  │                              ├─ 收到消息，处理
  │←───── 回复到 "BT_EVT" ──────┤
  ├─ 收到回复                    │
```

**ACORE 是主控**：管理共享内存区域，负责启动其他核，协调通信。

### 2.4 AMP vs SMP

| 特性 | AMP（不对称多处理） | SMP（对称多处理） |
|---|---|---|
| 各核 OS | 可以不同（FreeRTOS / 裸机 / DSP 固件） | 相同（如 Linux SMP） |
| 调度 | 各核独立调度 | 统一调度 |
| 共享资源 | 需要明确的共享内存协议 | 操作系统统一管理 |
| 典型场景 | MCU 多核（WQ7036A） | 手机/PC 多核 CPU |

WQ7036A 是典型的 **AMP**：ACORE 跑 FreeRTOS，BCORE 跑蓝牙专用 RTOS，DCORE 跑 DSP 固件。三者完全独立，通过 IPC 通信。

### 2.5 常见坑

1. **忘记加 volatile**：共享内存的指针/变量必须加 `volatile`，否则编译器优化后另一个核的修改看不到。
2. **忘记内存屏障**：写完数据再写标志位，编译器可能把标志位写入重排到前面。
3. **Cache 不一致**：一个核的 Cache 里缓存了共享内存的旧数据。
4. **两端同时写**：没有锁保护，两个核同时修改同一个变量导致数据损坏。

### 2.6 项目中的应用

- [[UART 命令协议]]：MCU（ACORE）通过 UART 与外部 V881 芯片通信，虽然不是 IPC 但思路类似（帧格式 + ACK 重传）。
- [[reGlasses 跨芯片指令转发]]：ACORE 收到手机端命令 → 通过 IPC 转发给 BCORE → BCORE 执行蓝牙操作。
- [[WQ7036AX 音频管道]]：ACORE 通过 IPC 控制 DCORE 的音频算法参数。

---

## 第三层：深入扩展

### 3.1 WQ7036A IPC 源码关键结构

```c
// IPC 消息头（简化）
typedef struct {
    uint32_t magic;      // 0x57514943 ("WQIC")
    uint16_t port;       // 目标端口号
    uint16_t length;     // 消息长度
    uint32_t reserved;
} ipc_msg_hdr_t;

// IPC 端口注册
ipc_port_t *port = ipc_port_register("BT_CMD", callback_fn, arg);

// 发送消息
ipc_send(port, data, len, timeout_ms);

// 接收回调
void callback_fn(ipc_port_t *port, void *data, uint32_t len, void *arg) {
    // 处理收到的消息
}
```

### 3.2 缓存一致性协议（MESI）

在有多级 Cache 的多核系统中，硬件通过 MESI 协议自动维护缓存一致性：

| 状态 | 含义 |
|---|---|
| **M**odified | 本核修改了，还没写回内存 |
| **E**xclusive | 独占且与内存一致 |
| **S**hared | 多核共享且与内存一致 |
| **I**nvalid | 无效（其他核修改了，本核需要重新从内存取） |

**注意**：WQ7036A 的三核之间不一定有硬件 Cache 一致性支持。共享内存区域可能需要软件手动管理 Cache（Clean/Invalidate）。

### 3.3 原子操作与锁

**自旋锁（Spinlock）**：适合多核互斥，但不适合长时间持有。

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

**互斥量 vs 自旋锁**：

| 特性 | 互斥量（Mutex） | 自旋锁（Spinlock） |
|---|---|---|
| 等待方式 | 阻塞（让出 CPU） | 忙等待（不停循环） |
| 适用场景 | 单核 RTOS 任务间 | 多核之间 |
| 持有时间 | 可以较长 | 必须很短 |
| 中断中使用 | 不能 | 可以（但要小心） |

### 3.4 无锁队列（Lock-Free Queue）

对于单生产者单消费者（SPSC）的场景，可以用无锁队列避免锁的开销：

```c
// 无锁 SPSC 队列（适合一个核写、一个核读）
typedef struct {
    uint8_t  buf[256];
    volatile uint32_t head;  // 写入方修改
    volatile uint32_t tail;  // 读取方修改
} spsc_queue_t;

bool spsc_put(spsc_queue_t *q, uint8_t data) {
    uint32_t next = (q->head + 1) & 0xFF;
    if (next == q->tail) return false;  // 满了
    q->buf[q->head] = data;
    __sync_synchronize();   // 内存屏障：确保数据先写入
    q->head = next;         // 再更新 head
    return true;
}

bool spsc_get(spsc_queue_t *q, uint8_t *data) {
    if (q->tail == q->head) return false;  // 空的
    *data = q->buf[q->tail];
    __sync_synchronize();   // 内存屏障
    q->tail = (q->tail + 1) & 0xFF;
    return true;
}
```

### 3.5 常见面试题

- **AMP 和 SMP 的区别？** AMP 每个核跑不同 OS，SMP 所有核跑同一个 OS。
- **为什么多核通信要用内存屏障？** 编译器和 CPU 可能重排指令，导致标志位写入先于数据写入，接收方读到不完整的数据。
- **共享内存和消息队列的优缺点？** 共享内存快但需要自己管理同步，消息队列慢但自带同步机制。
- **Cache 一致性问题在什么情况下出现？** 当一个核通过 Cache 访问共享内存，另一个核（或 DMA）直接修改了 RAM 中的数据。
- **WQ7036A 的 IPC 用的什么机制？** 共享内存 + 软中断，消息格式包含 magic/port/length。

### 3.6 核心术语表

| 英文 | 中文 | 说明 |
|---|---|---|
| IPC | 进程间通信 | Inter-Process Communication |
| AMP | 不对称多处理 | 各核跑不同 OS |
| SMP | 对称多处理 | 各核跑同一 OS |
| Shared Memory | 共享内存 | 多核共用的 RAM 区域 |
| Soft Interrupt | 软中断 | 核间中断信号 |
| Spinlock | 自旋锁 | 忙等待的多核互斥锁 |
| Memory Barrier | 内存屏障 | 防止指令重排 |
| Cache Coherency | 缓存一致性 | 多核 Cache 数据同步 |
| MESI | MESI 协议 | 缓存一致性硬件协议 |
| SPSC | 单生产者单消费者 | Single Producer Single Consumer |
| Lock-Free | 无锁 | 不使用锁的并发数据结构 |

### 3.7 延伸阅读

- [[计算机组成与 MCU 架构]] —— 总线、Cache、多核概念基础
- [[中断 并发与同步机制]] —— 临界区、数据竞争、同步原语
- [[内存管理与 DMA]] —— 共享内存的物理实现、Cache 一致性
- [[音频系统基础]] —— DCORE 与 ACORE 之间的音频数据流
