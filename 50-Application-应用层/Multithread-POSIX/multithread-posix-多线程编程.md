# 多线程编程（POSIX Threads）

**一句话结论（20% 核心）**：pthread 是 Linux 应用层多线程的标准 API。创建线程 `pthread_create`，同步用互斥量（锁）和条件变量（等待/通知），线程池管理线程生命周期。线程之间共享地址空间，所以同步是核心难点——死锁、竞态、假唤醒，都是写多线程代码的必经之路。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：厨房里的多个厨师

- **单线程** = 一个厨师做所有菜：洗菜→切菜→炒菜→装盘，一道一道来。简单但慢。
- **多线程** = 三个厨师同时做菜：A 洗菜，B 切菜，C 炒菜。但要协调——B 不能动 A 正在洗的菜（**互斥**），C 必须等 B 切完才能炒（**同步**）

**线程 vs 进程的关键区别**：线程共享厨房（地址空间），所以能看到彼此的食材（变量）。进程各有各的厨房（独立地址空间），只能通过 IPC 传递食材。

### 1.2 核心 API 全景

```c
#include <pthread.h>

// === 线程管理 ===
pthread_t thread;
pthread_create(&thread, NULL, thread_func, arg);  // 创建线程
pthread_join(thread, NULL);                        // 等待线程结束
pthread_detach(thread);                            // 分离线程（不等待，自动回收）
pthread_exit(NULL);                                // 退出当前线程

// === 互斥量（锁）===
pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_lock(&mutex);       // 加锁（阻塞等待）
pthread_mutex_trylock(&mutex);    // 尝试加锁（不阻塞，失败立即返回）
pthread_mutex_unlock(&mutex);     // 解锁

// === 条件变量（等待/通知）===
pthread_cond_t cond = PTHREAD_COND_INITIALIZER;
pthread_cond_wait(&cond, &mutex);     // 等待条件（原子：释放锁+睡眠）
pthread_cond_timedwait(&cond, &mutex, &abstime); // 带超时的等待
pthread_cond_signal(&cond);           // 唤醒一个等待者
pthread_cond_broadcast(&cond);        // 唤醒所有等待者

// === 读写锁（读多写少场景）===
pthread_rwlock_t rwlock = PTHREAD_RWLOCK_INITIALIZER;
pthread_rwlock_rdlock(&rwlock);   // 读锁（多个线程可以同时持有）
pthread_rwlock_wrlock(&rwlock);   // 写锁（独占，等所有读锁释放）
pthread_rwlock_unlock(&rwlock);
```

### 1.3 线程安全：为什么共享变量需要保护？

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

### 1.4 如果只记得一件事

> pthread = 线程创建 + 互斥量（保护共享数据）+ 条件变量（等待和通知）。锁要尽量短，条件变量要用 while 而不是 if，避免死锁的两个原则：固定加锁顺序 + 超时机制。

---

## 第二层：实战理解

### 2.1 完整的生产者-消费者（线程安全队列）

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

### 2.2 死锁：为什么发生、怎么避免

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

### 2.3 线程池：管理线程生命周期

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

### 2.4 常见坑（附排查方法）

| 问题 | 现象 | 排查方法 | 根因 |
|------|------|---------|------|
| 死锁 | 程序卡住，CPU 0% | `gdb attach` → `thread apply all bt` 看所有线程栈 | 两个线程互相等待对方的锁 |
| 条件变量假唤醒 | 处理了不该处理的数据 | 条件变量用 `while` 而不是 `if` | 内核可能虚假唤醒等待的线程 |
| 忘记 join/detach | 线程资源泄漏，内存持续增长 | `top -H` 看线程数是否持续增长 | 线程退出后未被回收 |
| 锁粒度过大 | 多线程性能不如单线程 | `perf lock` 分析锁竞争 | 一个线程持锁时做了太多事 |
| 信号处理不当 | 多线程中信号行为不确定 | 避免在多线程中用 signal() | 信号发送给哪个线程是不确定的 |

### 2.5 在 reGlasses 项目中怎么用

V881 侧的应用层大量使用多线程：
- **摄像头服务**：采集线程 + 编码线程 + 推流线程，用队列连接
- **WiFi 服务**：接收线程 + 发送线程，用条件变量同步
- **OTA 服务**：下载线程 + 校验线程，下载完成后通知校验

WQ7036AX 侧跑 FreeRTOS，用 task 和 queue 而不是 pthread，但概念完全对应——task 对应线程，queue 对应线程安全队列，semaphore 对应条件变量。

---

## 第三层：深入扩展

### 3.1 常见问题

- **pthread_join 和 pthread_detach 的区别？** join 会阻塞等待线程结束并回收资源，detach 不等待，线程结束时自动回收。不能对一个已 detach 的线程调用 join。
- **互斥量和自旋锁的区别？** 互斥量在等待时会让出 CPU（阻塞），自旋锁不会（忙等待）。用户空间用互斥量，内核和中断上下文用自旋锁。
- **读写锁什么时候用？** 读多写少的场景。读锁可以多个线程同时持有（共享），写锁独占。适合缓存、配置表等场景。

### 3.2 延伸阅读

- [[rtos-freertos-RTOS原理与FreeRTOS]] — FreeRTOS 任务 vs pthread 线程的对比
- [[ipc-dbus-socket-IPC通信]] — 进程间通信（线程是进程内共享内存）
- [[interrupt-concurrency-中断并发同步]] — 并发的底层原理，同样适用于多线程