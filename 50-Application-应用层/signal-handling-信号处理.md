# 信号处理

**一句话结论（20% 核心）**：信号是 Linux 内核发给进程的"紧急通知"——SIGTERM（请优雅退出）、SIGKILL（立刻杀掉）、SIGSEGV（你访问了非法内存）。信号处理就是注册回调函数，当信号到达时执行清理工作。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：手机通知

信号 = 手机通知栏的弹窗：
- **SIGTERM** = "系统升级，请保存工作并退出"（可以忽略，但最好处理）
- **SIGKILL** = "强制关机"（无法忽略，立刻结束）
- **SIGSEGV** = "你访问了不存在的内存地址"（bug，调试用）
- **SIGINT** = Ctrl+C（用户中断）

### 1.2 核心 API

```c
#include <signal.h>

// 注册信号处理函数
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

### 1.3 常见信号

| 信号 | 编号 | 含义 | 能否捕获 |
|------|------|------|---------|
| SIGINT | 2 | Ctrl+C 中断 | 能 |
| SIGTERM | 15 | 终止请求 | 能 |
| SIGKILL | 9 | 强制杀死 | **不能** |
| SIGSEGV | 11 | 段错误（非法内存访问） | 能（但一般让它 core dump） |
| SIGPIPE | 13 | 向已关闭的管道写入 | 能（通常忽略） |
| SIGCHLD | 17 | 子进程状态变化 | 能 |

### 1.4 如果只记得一件事

> 信号 = 内核发给进程的通知。SIGTERM 是礼貌的"请退出"，SIGKILL 是暴力的"立刻杀掉"。注册信号处理函数来优雅关闭（释放资源、保存状态）。

---

## 第二层：实战理解

### 2.1 守护进程的标准信号处理

```c
static volatile sig_atomic_t running = 1;

static void sig_handler(int signo) {
    if (signo == SIGTERM || signo == SIGINT) {
        running = 0;  // 通知主循环退出
    }
}

int main() {
    signal(SIGTERM, sig_handler);
    signal(SIGINT,  sig_handler);

    while (running) {
        // 主循环
    }

    // 收到信号后，优雅退出
    cleanup();
    return 0;
}
```

### 2.2 常见坑

| 问题 | 现象 | 根因 |
|------|------|------|
| 信号处理函数中做太多事 | 不可预测的行为 | 信号处理函数应尽量简单（只设置标志位） |
| 忘处理 SIGPIPE | 程序被 SIGPIPE 杀死 | Socket 对端关闭时写入会触发 SIGPIPE |
| SIGKILL 后数据丢失 | 文件内容不完整 | SIGKILL 无法捕获，来不及保存 |

### 2.3 在 reGlasses 项目中怎么用

V881 上的守护进程（摄像头服务、WiFi 服务）都注册了 SIGTERM 处理函数，确保在系统关机时优雅关闭——保存当前状态、释放资源。WQ7036AX 跑 FreeRTOS，没有信号概念。

---

## 第三层：延伸阅读

- [[systemd-daemon-Systemd守护进程]] — systemd 通过信号管理守护进程
- [[multithread-posix-多线程编程]] — 多线程中信号的处理更复杂（哪个线程收到信号？）