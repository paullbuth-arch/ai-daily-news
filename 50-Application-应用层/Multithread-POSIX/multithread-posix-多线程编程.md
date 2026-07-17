# 多线程编程（POSIX Threads）

**一句话结论（20% 核心）**：pthread 是 Linux 应用层多线程的标准 API。创建线程 `pthread_create`，同步用互斥量 `pthread_mutex` 和条件变量 `pthread_cond`。线程之间共享地址空间，所以同步是核心问题。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：厨房里的多个厨师

- **单线程** = 一个厨师做所有菜：洗菜→切菜→炒菜→装盘，一道一道来
- **多线程** = 多个厨师同时做菜：A 洗菜，B 切菜，C 炒菜。但要协调好——B 不能动 A 正在洗的菜（互斥）

### 1.2 核心 API

```c
#include <pthread.h>

// 创建线程
pthread_t thread;
pthread_create(&thread, NULL, thread_func, arg);

// 互斥量（锁）
pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_lock(&mutex);
// 临界区：同一时刻只有一个线程能执行这里
pthread_mutex_unlock(&mutex);

// 条件变量（等待+通知）
pthread_cond_t cond = PTHREAD_COND_INITIALIZER;
pthread_cond_wait(&cond, &mutex);   // 等待条件，释放锁
pthread_cond_signal(&cond);          // 唤醒一个等待者

// 等待线程结束
pthread_join(thread, NULL);
```

### 1.3 如果只记得一件事

> pthread = 线程创建 + 互斥量(锁) + 条件变量(等待通知)。锁保护共享数据，条件变量协调线程的先后顺序。

---

## 第二层：实战理解

### 2.1 生产者-消费者模型

```c
// 生产者线程：往队列里放数据
void *producer(void *arg) {
    for (int i = 0; i < 100; i++) {
        pthread_mutex_lock(&mutex);
        queue_push(i);
        pthread_cond_signal(&cond);  // 通知消费者
        pthread_mutex_unlock(&mutex);
        usleep(10000);
    }
    return NULL;
}

// 消费者线程：从队列里取数据
void *consumer(void *arg) {
    while (1) {
        pthread_mutex_lock(&mutex);
        while (queue_is_empty()) {
            pthread_cond_wait(&cond, &mutex);  // 等数据
        }
        int data = queue_pop();
        pthread_mutex_unlock(&mutex);
        process(data);
    }
    return NULL;
}
```

### 2.2 常见坑

| 问题 | 现象 | 根因 |
|------|------|------|
| 死锁 | 程序卡住 | 两个线程各持一个锁，互相等对方的锁 |
| 条件变量假唤醒 | 处理了不该处理的数据 | wait 返回后要重新检查条件，用 while 而不是 if |
| 忘记 join | 线程资源泄漏 | 线程退出后 pthread_join 回收资源 |

### 2.3 在 reGlasses 项目中怎么用

V881 侧的应用层（摄像头控制、视频流推送、WiFi 通信）大量使用多线程。WQ7036AX 侧跑 FreeRTOS，用 task 而不是 pthread，但概念一致。

---

## 第三层：延伸阅读

- [[rtos-freertos-RTOS原理与FreeRTOS]] — FreeRTOS 任务 vs pthread 线程的对比
- [[ipc-dbus-socket-IPC通信]] — 线程间通信的替代方案