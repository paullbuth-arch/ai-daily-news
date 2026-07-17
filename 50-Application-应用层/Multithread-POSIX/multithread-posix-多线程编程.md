---
type: concept
tags: [POSIX, 多线程, pthread, 并发, 同步, Linux]
aliases: [多线程, POSIX Threads, pthread编程]
---

# 多线程编程（POSIX Threads）

## 一句话结论

pthread 是 Linux 应用层多线程的标准 API。创建线程 `pthread_create`，同步用互斥量（锁）和条件变量（等待/通知），线程池管理线程生命周期。线程之间共享地址空间，所以同步是核心难点——死锁、竞态、假唤醒，都是写多线程代码的必经之路。

## 30秒先看懂

1. 线程是进程内的执行单元，同一进程的线程共享地址空间（全局变量、堆内存），但各有独立的栈和寄存器。
2. 互斥量（mutex）保护共享数据——同一时间只有一个线程能持有锁。条件变量（cond）实现等待/通知模式。
3. 死锁 = 两个线程互相等待对方持有的锁，谁也跑不了。避免方法：固定加锁顺序 + trylock 超时回退。
4. 条件变量必须用 `while` 而不是 `if` 检查条件——因为存在"假唤醒"（spurious wakeup）。
5. 线程池 = 预创建 N 个线程 + 任务队列，避免频繁创建/销毁线程的开销。

## 学完以后应该能做什么

### 第一遍
- 用 `pthread_create` 创建线程，用 `pthread_join` 等待线程结束
- 用互斥量保护共享数据，避免数据竞争
- 用条件变量实现生产者-消费者模型
- 识别和避免死锁

### 进阶
- 设计高效的线程池，管理线程生命周期
- 使用读写锁优化读多写少场景
- 理解内存序（memory order）和原子操作
- 在嵌入式 Linux 上设计多线程服务架构

## 前置知识

- C 语言指针和结构体
- 理解进程地址空间布局（栈、堆、全局区）
- 基本的并发概念（串行 vs 并行 vs 并发）

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 线程 | Thread | 进程内的独立执行流，共享地址空间，独立栈和寄存器 |
| 互斥量 | Mutex | 保证同一时间只有一个线程访问共享数据的锁机制 |
| 条件变量 | Condition Variable | 线程间等待/通知机制，配合互斥量使用 |
| 数据竞争 | Data Race | 多个线程同时访问同一内存，至少一个是写操作，未加同步 |
| 死锁 | Deadlock | 两个线程互相等待对方持有的锁，永远无法继续执行 |
| 假唤醒 | Spurious Wakeup | 条件变量等待的线程被无故唤醒，条件不一定满足 |
| 读写锁 | Rwlock | 读锁可共享，写锁独占，适合读多写少场景 |
| 线程安全 | Thread-Safe | 函数在多线程环境中被调用时行为正确 |

## 第一层：费曼心智模型

### 类比：厨房里的多个厨师

- **单线程** = 一个厨师做所有菜：洗菜→切菜→炒菜→装盘，一道一道来。简单但慢。
- **多线程** = 三个厨师同时做菜：A 洗菜，B 切菜，C 炒菜。但要协调——B 不能动 A 正在洗的菜（**互斥**），C 必须等 B 切完才能炒（**同步**）。
- **互斥量** = 案板上的"使用中"牌子。谁拿到牌子谁用案板，用完放回。其他人只能等。
- **条件变量** = C 厨师对 B 说"切好了叫我"——C 去睡觉，B 切完后叫醒 C。

**线程 vs 进程的关键区别**：线程共享厨房（地址空间），所以能看到彼此的食材（变量）。进程各有各的厨房（独立地址空间），只能通过 IPC 传递食材。

### 边界

多线程不是万能的：
- 计算密集型任务在多核 CPU 上才能提速，单核上多线程反而因上下文切换变慢
- IO 密集型任务用多线程有用（IO 等待时让出 CPU）
- 不是所有代码都适合多线程——状态复杂、共享变量多的逻辑容易出错
- 嵌入式系统（如 FreeRTOS）上线程（任务）数量有限，不能随意创建

### 场景推演：摄像头服务的数据流

V881 摄像头服务的典型架构：采集线程不断从 sensor 获取帧，编码线程处理帧，推流线程发送。三个线程之间用队列连接。

如果采集线程往队列放数据时，推流线程正在取数据，没有锁保护会导致队列损坏。正确的做法是：放数据和取数据都要加锁，队列满时采集线程等待（条件变量），队列空时推流线程等待（条件变量）。

## 第二层：原理/时序/约束

### 数据竞争：为什么共享变量需要保护？

```c
// 这个 counter++ 不是原子操作！
// 它被编译成三条指令：
//   ① LOAD  counter → R0  (读)
//   ② ADD   R0, 1         (改)
//   ③ STORE R0 → counter  (写)

int counter = 0;  // 全局变量，线程 A 和 B 都访问

// 线程 A: counter++    // 读了 0，加了 1，准备写 1
// 线程 B: counter++    // 在线程 A 写之前读了 0，也加了 1，也准备写 1
// 结果: counter = 1    // 应该等于 2！丢了一次更新！
// 这就是数据竞争（Data Race）
```

### 生产者-消费者（线程安全队列）

```c
#include <pthread.h>
#include <stdbool.h>

#define Q_SIZE 32

typedef struct {
    int data[Q_SIZE];
    int head, tail, count;
    pthread_mutex_t lock;
    pthread_cond_t  not_empty;  // 队列非空时通知消费者
    pthread_cond_t  not_full;   // 队列非满时通知生产者
} thread_safe_queue_t;

void queue_init(thread_safe_queue_t *q) {
    q->head = q->tail = q->count = 0;
    pthread_mutex_init(&q->lock, NULL);
    pthread_cond_init(&q->not_empty, NULL);
    pthread_cond_init(&q->not_full, NULL);
}

bool queue_put(thread_safe_queue_t *q, int item) {
    pthread_mutex_lock(&q->lock);
    while (q->count == Q_SIZE) {                    // 队列满，等待
        pthread_cond_wait(&q->not_full, &q->lock);  // 原子：释放锁+睡眠
    }                                               // 被唤醒后自动重新获取锁
    q->data[q->tail] = item;
    q->tail = (q->tail + 1) % Q_SIZE;
    q->count++;
    pthread_cond_signal(&q->not_empty);  // 通知消费者：有数据了
    pthread_mutex_unlock(&q->lock);
    return true;
}

bool queue_get(thread_safe_queue_t *q, int *item) {
    pthread_mutex_lock(&q->lock);
    while (q->count == 0) {                         // 队列空，等待
        pthread_cond_wait(&q->not_empty, &q->lock); // 原子：释放锁+睡眠
    }
    *item = q->data[q->head];
    q->head = (q->head + 1) % Q_SIZE;
    q->count--;
    pthread_cond_signal(&q->not_full);   // 通知生产者：有空位了
    pthread_mutex_unlock(&q->lock);
    return true;
}
```

**关键细节**：`pthread_cond_wait` 内部做了三件事——①原子地释放 mutex ②线程进入睡眠 ③被唤醒后原子地重新获取 mutex。这是条件变量最精妙的设计。

### 死锁：为什么发生、怎么避免

```c
// 经典死锁场景：两个线程以相反顺序获取两个锁
pthread_mutex_t lock_A, lock_B;

// 线程 1                        // 线程 2
pthread_mutex_lock(&lock_A);     pthread_mutex_lock(&lock_B);
pthread_mutex_lock(&lock_B);     pthread_mutex_lock(&lock_A);
// 等 lock_B（线程 2 拿着）       // 等 lock_A（线程 1 拿着）
// → 死锁！谁也等不到谁

// 解决方案 1：固定加锁顺序（总是先锁 A 再锁 B）
// 解决方案 2：使用 trylock + 超时回退
if (pthread_mutex_trylock(&lock_B) != 0) {
    pthread_mutex_unlock(&lock_A);  // 拿不到第二个锁，释放第一个
    usleep(1000);                   // 等一会再试
    goto retry;
}
```

### 线程池：管理线程生命周期

```c
// 线程池 = 预创建 N 个线程 + 任务队列
// 避免频繁创建/销毁线程的开销

typedef struct {
    void (*func)(void *);
    void *arg;
} task_t;

typedef struct {
    pthread_t threads[4];
    task_t    task_queue[32];
    int       task_count;
    pthread_mutex_t lock;
    pthread_cond_t  task_available;
    bool      running;
} thread_pool_t;

void *worker_thread(void *arg) {
    thread_pool_t *pool = (thread_pool_t *)arg;
    while (pool->running) {
        pthread_mutex_lock(&pool->lock);
        while (pool->task_count == 0 && pool->running) {
            pthread_cond_wait(&pool->task_available, &pool->lock);
        }
        if (pool->task_count > 0) {
            task_t task = pool->task_queue[--pool->task_count];
            pthread_mutex_unlock(&pool->lock);
            task.func(task.arg);  // 执行任务（不持锁）
        } else {
            pthread_mutex_unlock(&pool->lock);
        }
    }
    return NULL;
}
```

## 第三层：真实SDK代码

### V881 摄像头服务中的多线程架构

在 `/home/ys/aiglass/reglasses/services/camera/` 中，摄像头服务使用三个线程构成流水线：

```c
// 伪代码——V881 摄像头服务多线程架构
// 文件路径: reglasses/services/camera/cam_service.c

// 三个线程通过线程安全队列连接
static thread_safe_queue_t raw_frame_queue;   // 采集 → 编码
static thread_safe_queue_t encoded_frame_queue; // 编码 → 推流

// 线程 1：采集线程——从 sensor 获取原始帧
void *capture_thread(void *arg) {
    while (running) {
        frame_t *frame = sensor_capture_frame();  // 阻塞等待帧
        queue_put(&raw_frame_queue, frame);
    }
    return NULL;
}

// 线程 2：编码线程——H.264 编码
void *encode_thread(void *arg) {
    while (running) {
        frame_t *raw;
        queue_get(&raw_frame_queue, &raw);
        frame_t *encoded = h264_encode(raw);
        queue_put(&encoded_frame_queue, encoded);
    }
    return NULL;
}

// 线程 3：推流线程——RTSP 推流
void *stream_thread(void *arg) {
    while (running) {
        frame_t *encoded;
        queue_get(&encoded_frame_queue, &encoded);
        rtsp_send_frame(encoded);
    }
    return NULL;
}
```

### WQ7036AX 上的 FreeRTOS 任务

在 `/home/ys/wq7036a/wq-audio/wqcore/examples/` 中，FreeRTOS 使用 task 和 queue 实现类似的并发模型：

```c
// 伪代码——WQ7036AX FreeRTOS 任务创建
// 文件路径: wqcore/examples/helloworld/acore/main.c
// FreeRTOS 的 task 对应 pthread 的线程，queue 对应线程安全队列

// 创建任务
xTaskCreate(audio_process_task, "audio_task", 2048, NULL, 5, NULL);
xTaskCreate(ble_send_task, "ble_task", 1024, NULL, 4, NULL);

// 创建队列（线程安全）
QueueHandle_t audio_queue = xQueueCreate(10, sizeof(audio_frame_t));

// 发送（类似 queue_put）
xQueueSend(audio_queue, &frame, portMAX_DELAY);

// 接收（类似 queue_get）
xQueueReceive(audio_queue, &frame, portMAX_DELAY);
```

## 第四层：正常/异常路径

### 正常路径

```
pthread_create → 新线程创建 → 执行线程函数
  → 线程函数中：加锁 + 访问共享数据 + 解锁
  → 条件变量等待（若无数据）→ 被通知后处理数据
  → 线程退出 → pthread_join 回收资源
```

### 异常路径

| 异常 | 现象 | 触发条件 | 恢复方式 |
|------|------|---------|---------|
| 死锁 | 程序卡住，CPU 0% | 两个线程互相等待对方持有的锁 | 固定加锁顺序，或使用 trylock |
| 数据竞争 | 结果不符合预期，偶发 | 多个线程未加锁同时访问共享变量 | 加互斥量保护共享数据 |
| 假唤醒 | 条件不满足时处理了数据 | 内核条件变量实现可能产生虚假唤醒 | 用 `while` 而不是 `if` 检查条件 |
| 线程泄漏 | 内存持续增长，线程数增加 | 创建线程后既没 join 也没 detach | 用线程池管理生命周期 |
| 优先级反转 | 低优先级线程阻塞了高优先级线程 | 优先级不同的线程竞争同一锁 | 使用优先级继承协议 |
| 锁粒度过大 | 多核性能不如单核 | 持锁时做了太多计算 | 缩小锁范围，用读写锁优化 |

## 第五层：调试方法

### 使用 GDB 调试多线程

```bash
# 查看所有线程
gdb -p <PID>
(gdb) info threads

# 切换到指定线程
(gdb) thread 2

# 查看所有线程的调用栈
(gdb) thread apply all bt

# 查看锁状态
(gdb) print mutex
```

### Valgrind 检测数据竞争

```bash
# 使用 DRD 或 Helgrind 工具检测数据竞争
valgrind --tool=drd ./my_program
valgrind --tool=helgrind ./my_program
```

### 性能分析

```bash
# 查看线程 CPU 使用率
top -H -p <PID>

# 锁竞争分析
perf lock record -p <PID>
perf lock report

# 查看线程创建情况
strace -e clone -p <PID>

# 使用 strace 追踪锁操作
strace -e trace=futex -p <PID>
```

## 第六层：实战练习

### 练习1：修复数据竞争

下面的代码存在数据竞争，请找出问题并修复：

```c
int counter = 0;
pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;

void *worker(void *arg) {
    for (int i = 0; i < 100000; i++) {
        counter++;  // 问题在这里！
    }
    return NULL;
}

int main() {
    pthread_t t1, t2;
    pthread_create(&t1, NULL, worker, NULL);
    pthread_create(&t2, NULL, worker, NULL);
    pthread_join(t1, NULL);
    pthread_join(t2, NULL);
    printf("counter = %d (expected 200000)\n", counter);
}
```

### 练习2：实现读写锁保护的缓存

设计一个简单的缓存系统，多个线程可以同时读，但写线程必须独占。使用 `pthread_rwlock_t` 实现。

```c
// 提示：读多写少场景，读锁可共享，写锁独占
typedef struct {
    int cache[1024];
    pthread_rwlock_t rwlock;
} simple_cache_t;
```

### 练习3：阅读真实源码——V881 摄像头服务的线程模型

阅读 `/home/ys/aiglass/reglasses/services/camera/` 目录下的源码，分析摄像头服务的线程模型：
- 有几个线程？各自做什么？
- 线程之间如何同步？（用队列还是条件变量？）
- 如果采集线程比编码线程快，会发生什么？如何处理？

## 自测与验收

1. 线程和进程的核心区别是什么？什么时候应该用线程而不是进程？
2. 什么是数据竞争？counter++ 为什么不是原子操作？
3. 为什么 `pthread_cond_wait` 必须传入一个已经加锁的 mutex？它在内部做了什么？
4. 死锁产生的四个必要条件是什么？如何打破？
5. 条件变量为什么要用 `while` 而不是 `if` 检查条件？
6. 线程池解决了什么问题？设计线程池需要考虑哪些因素？

## 延伸阅读

- [[rtos-freertos-RTOS原理与FreeRTOS]] — FreeRTOS 任务 vs pthread 线程的对比
- [[ipc-dbus-socket-IPC通信]] — 进程间通信（线程是进程内共享内存）
- [[interrupt-concurrency-中断并发同步]] — 并发的底层原理，同样适用于多线程
- [[file-io-文件IO]] — 多线程写入文件时的原子性和同步

## #flashcard

Q: pthread 中线程和进程的核心区别是什么？
A: 线程共享地址空间（全局变量、堆），进程有独立地址空间。线程间通信直接读写共享变量，进程间通信需要 IPC 机制。

Q: 什么是数据竞争？
A: 多个线程同时访问同一内存地址，至少一个是写操作，且没有使用同步机制（锁）。counter++ 是三指令操作，不是原子的。

Q: 为什么条件变量必须用 while 而不是 if？
A: 因为存在假唤醒（spurious wakeup），线程被唤醒后条件可能仍未满足。while 循环确保唤醒后重新检查条件。

Q: 死锁的四个必要条件？
A: 互斥（资源只能一个线程持有）、持有并等待（持有一个资源等待另一个）、不可剥夺（资源只能主动释放）、循环等待（每个线程都在等另一个线程持有的资源）。

Q: 线程池的核心思想是什么？
A: 预创建 N 个线程，从任务队列中取任务执行。避免频繁创建/销毁线程的开销，控制并发线程数量。