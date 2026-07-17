# IPC 通信：D-Bus / Socket / 共享内存

**一句话结论（20% 核心）**：IPC（进程间通信）让不同的进程之间交换数据。Linux 上有三种主流方式：Socket（网络通信）、D-Bus（桌面/系统服务通信）、共享内存（高性能数据交换）。V881 上各个服务之间大量使用 D-Bus。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：公司内部的沟通方式

| IPC 方式 | 类比 | 适用场景 |
|----------|------|---------|
| **Socket** | 发邮件 | 跨网络通信，TCP/UDP |
| **D-Bus** | 公司内部广播 | 系统服务间通信，方法调用+信号广播 |
| **共享内存** | 公告板 | 大量数据交换，最快但需要同步 |
| **管道/Unix Socket** | 对讲机 | 同一台机器上父子进程通信 |

### 1.2 三种 IPC 的代码骨架

```c
// === Socket (TCP) ===
int sock = socket(AF_INET, SOCK_STREAM, 0);
connect(sock, &addr, sizeof(addr));
send(sock, data, len, 0);
recv(sock, buf, size, 0);

// === D-Bus (高层 API) ===
// 方法调用
proxy = g_dbus_proxy_new_sync(conn, ...);
g_dbus_proxy_call_sync(proxy, "MethodName", params, ...);

// 信号监听
g_dbus_connection_signal_subscribe(conn, "sender", "interface",
                                   "SignalName", path, NULL,
                                   callback, NULL, NULL);

// === 共享内存 ===
int shm_fd = shm_open("/my_shm", O_CREAT | O_RDWR, 0666);
ftruncate(shm_fd, size);
void *ptr = mmap(NULL, size, PROT_READ | PROT_WRITE,
                 MAP_SHARED, shm_fd, 0);
// ptr 指向的内存可以被其他进程看到
```

### 1.3 如果只记得一件事

> IPC 三种主流：Socket（跨网络）、D-Bus（系统服务间）、共享内存（高性能）。V881 上摄像头服务、音频服务、WiFi 服务之间通过 D-Bus 通信。

---

## 第二层：实战理解

### 2.1 D-Bus 在 V881 上的典型用法

```
摄像头服务 (cam_service)
  │
  ├── D-Bus 方法: StartRecording()
  ├── D-Bus 信号: RecordingStarted
  └── D-Bus 属性: RecordingState

WiFi 服务 (wifi_service)
  │
  ├── D-Bus 方法: Connect(ssid, password)
  └── D-Bus 信号: ConnectionStateChanged
```

### 2.2 常见坑

| 问题 | 现象 | 根因 |
|------|------|------|
| Socket 端口冲突 | bind 失败 | 端口已被占用 |
| D-Bus 服务未启动 | 方法调用超时 | 被调用的服务还没启动 |
| 共享内存忘同步 | 数据损坏 | 两个进程同时写，需要信号量保护 |

### 2.3 在 reGlasses 项目中怎么用

V881 上的各个系统服务（摄像头、音频、WiFi、OTA）通过 D-Bus 通信。WQ7036AX 和 V881 之间通过 UART 通信（不是 IPC，是芯片间通信）。

---

## 第三层：延伸阅读

- [[multithread-posix-多线程编程]] — 线程间同步（同一进程内）
- [[uart-basics-UART基础]] — WQ7036AX↔V881 的芯片间通信