---
type: concept
tags: [信号, Linux, 进程通信, 异步通知, 异常处理]
aliases: [信号处理, Signal, Linux信号]
---

# 信号处理

## 一句话结论

信号是 Linux 内核发给进程的"紧急通知"——SIGTERM（请优雅退出）、SIGKILL（立刻杀掉）、SIGSEGV（你访问了非法内存）。信号处理就是注册回调函数，当信号到达时执行清理工作。

## 30秒先看懂

1. 信号是异步事件通知机制——内核或另一个进程可以随时向进程发送信号，进程在收到信号后中断当前执行流去处理。
2. SIGTERM（15）是礼貌的终止请求，进程可以捕获后做清理；SIGKILL（9）是强制杀死，无法捕获也无法忽略。
3. 信号处理函数应该尽量简单——通常只设置一个 `volatile sig_atomic_t` 标志位，不做复杂操作。
4. 守护进程必须注册 SIGTERM 处理函数，确保 `systemctl stop` 时能优雅退出（释放资源、保存状态）。
5. SIGPIPE（管道破裂）在 Socket 编程中很常见，通常直接忽略（`SIG_IGN`）或检查 `write` 返回值。

## 学完以后应该能做什么

### 第一遍
- 为守护进程注册 SIGTERM 处理函数，实现优雅退出
- 区分可捕获信号（SIGTERM、SIGINT）和不可捕获信号（SIGKILL、SIGSTOP）
- 正确处理 SIGPIPE 避免程序被意外杀死
- 用 `volatile sig_atomic_t` 保证信号处理函数中的数据安全

### 进阶
- 理解可靠信号和实时信号的区别
- 使用 `sigaction` 替代 `signal` 获得更精确的信号控制
- 理解信号掩码（sigprocmask）和线程信号处理
- 在嵌入式 Linux 上设计信号驱动的守护进程

## 前置知识

- 进程和进程状态
- 基本的 C 语言编程
- Linux 守护进程的概念

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 信号 | Signal | 内核发给进程的异步通知，表示某事件发生 |
| 信号处理函数 | Signal Handler | 进程注册的、收到信号时自动调用的函数 |
| 信号掩码 | Signal Mask | 进程阻塞（暂时不递送）的信号集合 |
| 可靠信号 | Reliable Signal | POSIX 标准信号（SIGRTMIN+），支持排队和附加数据 |
| 不可靠信号 | Unreliable Signal | 标准信号（1-31），不排队，相同信号多次发送可能只收到一次 |
| 异步信号安全 | Async-Signal-Safe | 可以在信号处理函数中安全调用的函数集合 |
| 段错误 | Segmentation Fault | 访问非法内存地址时触发的 SIGSEGV 信号 |

## 第一层：费曼心智模型

### 类比：手机通知

信号 = 手机通知栏的弹窗：
- **SIGTERM** = "系统升级，请保存工作并退出"（可以忽略，但最好处理）
- **SIGKILL** = "强制关机"（无法忽略，立刻结束，数据来不及保存）
- **SIGSEGV** = "你访问了不存在的内存地址"（程序 bug，调试用，通常 core dump）
- **SIGINT** = Ctrl+C（用户中断，可以捕获做清理）
- **SIGPIPE** = "对方已挂断电话，你还在对着话筒说话"（Socket 对端关闭后写入）

### 边界

- 信号处理函数中不是所有函数都能调用——只能调用"异步信号安全"（async-signal-safe）的函数，如 `write`（不是 `printf`）、`signal`、`_exit`
- 标准信号（1-31）不排队——如果多次发送相同信号，可能只收到一次
- 多线程中信号的行为复杂——默认发送到任意一个未被阻塞的线程
- 嵌入式 RTOS 通常没有信号概念（如 FreeRTOS 用事件标志组或消息队列替代）

### 场景推演：systemd 停止服务

当执行 `systemctl stop cam-service` 时：
1. systemd 向摄像头服务进程发送 SIGTERM 信号
2. 进程的信号处理函数被调用，设置 `running = 0`
3. 主循环检测到 `running == 0`，退出循环
4. 执行清理：关闭摄像头设备、释放内存、保存状态
5. 进程退出
6. systemd 确认进程已退出，标记服务为 inactive

如果进程在 90 秒内没有退出，systemd 发送 SIGKILL 强制杀死——此时数据来不及保存。

## 第二层：原理/时序/约束

### 核心 API

```c
#include <signal.h>

// 注册信号处理函数（传统方式，简单但有局限）
void my_handler(int signo) {
    // 收到 SIGTERM，做清理工作
    printf("Received signal %d, cleaning up...\n", signo);
    cleanup();
    exit(0);
}

signal(SIGTERM, my_handler);  // 注册
signal(SIGINT,  my_handler);  // Ctrl+C

// 忽略信号
signal(SIGPIPE, SIG_IGN);     // 忽略管道破裂信号
```

### sigaction：更现代的信号处理

```c
#include <signal.h>

// sigaction 提供更精确的控制
struct sigaction sa;
sa.sa_handler = sig_handler;     // 信号处理函数
sigemptyset(&sa.sa_mask);        // 处理期间阻塞的信号集
sa.sa_flags = SA_RESTART;        // 被信号中断的系统调用自动重启

sigaction(SIGTERM, &sa, NULL);
sigaction(SIGINT, &sa, NULL);
```

### 常见信号

| 信号 | 编号 | 含义 | 能否捕获 | 默认行为 |
|------|------|------|---------|---------|
| SIGINT | 2 | Ctrl+C 中断 | 能 | 终止进程 |
| SIGTERM | 15 | 终止请求 | 能 | 终止进程 |
| SIGKILL | 9 | 强制杀死 | **不能** | 终止进程（无法捕获/忽略/阻塞） |
| SIGSEGV | 11 | 段错误（非法内存访问） | 能（但通常 core dump 更方便调试） | 终止 + core dump |
| SIGPIPE | 13 | 向已关闭的管道写入 | 能（通常忽略） | 终止进程 |
| SIGCHLD | 17 | 子进程状态变化 | 能 | 忽略 |
| SIGUSR1 | 10 | 用户自定义信号 1 | 能 | 终止进程 |
| SIGUSR2 | 12 | 用户自定义信号 2 | 能 | 终止进程 |
| SIGHUP | 1 | 控制终端挂起 | 能 | 终止进程（常用于重载配置） |
| SIGSTOP | 19 | 暂停进程 | **不能** | 暂停进程 |

### 守护进程的标准信号处理

```c
static volatile sig_atomic_t running = 1;
static volatile sig_atomic_t reload_config = 0;

static void sig_handler(int signo) {
    if (signo == SIGTERM || signo == SIGINT) {
        running = 0;  // 通知主循环退出
    } else if (signo == SIGHUP) {
        reload_config = 1;  // 通知主循环重载配置
    }
}

int main() {
    struct sigaction sa;
    sa.sa_handler = sig_handler;
    sigemptyset(&sa.sa_mask);
    sigfillset(&sa.sa_mask);  // 处理信号时阻塞所有其他信号
    sa.sa_flags = SA_RESTART;

    sigaction(SIGTERM, &sa, NULL);
    sigaction(SIGINT, &sa, NULL);
    sigaction(SIGHUP, &sa, NULL);
    signal(SIGPIPE, SIG_IGN);  // 忽略管道破裂

    while (running) {
        if (reload_config) {
            reload_config = 0;
            load_config();
        }
        // 主循环
        do_work();
    }

    // 收到信号后，优雅退出
    cleanup();
    return 0;
}
```

### 信号处理函数中的注意事项

```c
// 错误做法：在信号处理函数中调用 printf/malloc/free
// printf 不是 async-signal-safe 的，可能死锁
// malloc/free 也可能死锁（因为锁可能被主循环持有）
void bad_handler(int signo) {
    printf("Got signal %d\n", signo);  // 危险！
    free(ptr);                          // 危险！
}

// 正确做法：只设置标志位
volatile sig_atomic_t flag = 0;
void good_handler(int signo) {
    flag = 1;  // 安全！sig_atomic_t 的读写是原子的
}
```

## 第三层：真实SDK代码

### V881 守护进程的信号处理

在 `/home/ys/aiglass/reglasses/services/` 中，各服务的信号处理模式：

```c
// 伪代码——V881 音频服务的信号处理
// 文件路径: reglasses/services/audio/audio_service.c

#include <signal.h>
#include <systemd/sd-daemon.h>

static volatile sig_atomic_t g_running = 1;
static volatile sig_atomic_t g_reload = 0;

static void signal_handler(int sig) {
    switch (sig) {
    case SIGTERM:
    case SIGINT:
        g_running = 0;
        break;
    case SIGHUP:
        g_reload = 1;  // 重载配置
        break;
    }
}

int main(int argc, char *argv[]) {
    // 注册信号处理
    struct sigaction sa = { .sa_handler = signal_handler };
    sigemptyset(&sa.sa_mask);
    sigaction(SIGTERM, &sa, NULL);
    sigaction(SIGINT, &sa, NULL);
    sigaction(SIGHUP, &sa, NULL);
    signal(SIGPIPE, SIG_IGN);

    // 通知 systemd 服务已就绪
    sd_notify(0, "READY=1");

    while (g_running) {
        if (g_reload) {
            g_reload = 0;
            load_config();
        }
        process_audio();
    }

    // 优雅退出——关闭音频设备、保存状态
    audio_cleanup();
    return 0;
}
```

### WQ7036AX 的中断处理（类比信号）

WQ7036AX 跑 FreeRTOS，没有信号概念。但硬件中断（IRQ）类似于信号——外设发出中断信号，CPU 暂停当前执行，跳转到中断处理函数：

```c
// 伪代码——WQ7036AX 中断处理
// 文件路径: wqcore/components/startup/boot/bbb/irq.c

// 注册中断处理函数（类似 signal）
void irq_register(int irq_num, irq_handler_t handler, void *arg);

// 中断处理函数（类似信号处理函数）
// 限制：不能调用可能导致阻塞的函数，不能调用 printf
void i2s_irq_handler(void *arg) {
    // 从 DMA 缓冲区读取数据
    // 设置标志位通知主循环
    uint32_t *flag = (uint32_t *)arg;
    *flag = 1;
}
```

## 第四层：正常/异常路径

### 正常路径

```
信号发送 → 内核检查目标进程的信号掩码
  → 如果信号未被阻塞 → 内核挂起进程当前执行 → 保存上下文
  → 执行信号处理函数 → 处理函数返回 → 恢复上下文继续执行

信号处理函数模式：
  signal(SIGTERM, handler) → 进程收到 SIGTERM
    → handler 设置 running = 0
    → 主循环检测到 running == 0 → 退出循环 → 清理 → exit
```

### 异常路径

| 异常 | 现象 | 触发条件 | 恢复方式 |
|------|------|---------|---------|
| 信号处理函数死锁 | 程序卡死 | 在信号处理函数中调用了 `printf`/`malloc` 等非安全函数 | 信号处理函数只设置标志位 |
| SIGPIPE 未处理 | 程序被意外杀死 | Socket 对端关闭后继续写入 | `signal(SIGPIPE, SIG_IGN)` 或在 `send` 加 MSG_NOSIGNAL 标志 |
| SIGKILL 后数据丢失 | 文件内容不完整 | SIGKILL 无法捕获，来不及保存 | 定期 fsync 或使用事务性写入 |
| 信号丢失 | 多次发送同一信号只处理一次 | 标准信号（1-31）不排队 | 使用实时信号 SIGRTMIN+ |
| 多线程信号混乱 | 信号被不该处理的线程收到 | 信号发送到任意线程 | 使用 `sigprocmask` 控制线程信号掩码 |

## 第五层：调试方法

### 信号调试

```bash
# 向进程发送信号
kill -TERM <PID>     # 发送 SIGTERM
kill -INT <PID>      # 发送 SIGINT
kill -HUP <PID>      # 发送 SIGHUP（重载配置）
kill -KILL <PID>     # 发送 SIGKILL（强制杀死）

# 查看进程的信号处理
ls -la /proc/<PID>/fd/  # 查看打开的 fd
cat /proc/<PID>/status | grep -i sig  # 信号相关信息

# 使用 strace 追踪信号
strace -e trace=signal -p <PID>
strace -e signal -p <PID>  # 显示所有信号相关操作

# 使用 gdb 调试信号
gdb -p <PID>
(gdb) handle SIGTERM pass noprint  # 让 GDB 不拦截 SIGTERM
(gdb) signal SIGTERM                # 向被调试进程发送信号
```

### Core Dump 分析

```bash
# 开启 core dump
ulimit -c unlimited
echo "/tmp/core.%p" > /proc/sys/kernel/core_pattern

# 使用 GDB 分析 core dump
gdb /usr/bin/cam_service /tmp/core.1234
(gdb) bt                    # 看崩溃时的调用栈
(gdb) info registers       # 看寄存器
(gdb) list                  # 看源代码
```

## 第六层：实战练习

### 练习1：实现优雅退出的守护进程

编写一个守护进程，它每秒打印一条日志。注册 SIGTERM 和 SIGINT 的处理函数，收到信号后打印"Shutting down..."并退出。

```c
// 提示：
// 1. 使用 volatile sig_atomic_t running 标志
// 2. 信号处理函数设置 running = 0
// 3. 主循环检测 running 决定是否退出
```

### 练习2：实现 SIGHUP 配置重载

扩展练习1，让它支持 SIGHUP（`kill -HUP <PID>`）触发配置重载。在信号处理函数中设置 `reload = 1`，主循环检测到后重新加载配置。

### 练习3：阅读真实源码——V881 服务的信号处理

在 `/home/ys/aiglass/reglasses/services/` 目录下，找一个服务的源码，分析：
1. 注册了哪些信号的处理函数？
2. 信号处理函数中做了什么？（只设标志位还是做了其他操作？）
3. 如何配合 systemd 的 SIGTERM 实现优雅关闭？

## 自测与验收

1. SIGTERM 和 SIGKILL 的区别是什么？为什么守护进程需要处理 SIGTERM？
2. 信号处理函数中为什么不能调用 `printf` 或 `malloc`？
3. 什么是 `volatile sig_atomic_t`？为什么信号处理函数中的标志位要用这个类型？
4. 为什么标准信号（如 SIGINT）可能丢失？如何保证信号不丢失？
5. 什么是 SIGPIPE？什么情况下会触发？如何避免？
6. 在守护进程的主循环中，如何实现"收到 SIGHUP 后重载配置"？

## 延伸阅读

- [[systemd-daemon-Systemd守护进程]] — systemd 通过信号管理守护进程
- [[multithread-posix-多线程编程]] — 多线程中信号的处理更复杂（哪个线程收到信号？）
- [[file-io-文件IO]] — 信号处理后的文件写入和 fsync
- [[interrupt-concurrency-中断并发同步]] — 中断和信号的类比（硬件 vs 软件中断）

## #flashcard

Q: SIGTERM 和 SIGKILL 的区别？
A: SIGTERM (15) 可捕获，进程可以优雅退出；SIGKILL (9) 不可捕获，强制杀死进程，数据无法保存。

Q: 信号处理函数中为什么不能调 printf？
A: printf 不是 async-signal-safe 的，可能和主循环中的 printf 竞争锁，导致死锁。

Q: volatile sig_atomic_t 的作用？
A: sig_atomic_t 保证读写是原子的，volatile 防止编译器优化（缓存寄存器值，不读内存）。

Q: 标准信号为什么可能丢失？
A: 标准信号（1-31）不排队，同一种信号多次发送，内核只递送一次。实时信号（SIGRTMIN+）支持排队。

Q: SIGPIPE 什么时候触发？
A: 向已关闭的 Socket 或管道写入数据时触发。默认行为是终止进程，通常通过 signal(SIGPIPE, SIG_IGN) 忽略。