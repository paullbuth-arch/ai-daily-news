---
type: concept
tags: [IPC, D-Bus, Socket, 进程间通信, Linux, 共享内存]
aliases: [IPC通信, 进程间通信, D-Bus, Socket通信]
---

# IPC 通信：D-Bus / Socket / 共享内存

## 一句话结论

IPC（进程间通信）让不同的进程之间交换数据。Linux 上有三种主流方式：Socket（网络通信）、D-Bus（桌面/系统服务通信）、共享内存（高性能数据交换）。V881 上各个服务之间大量使用 D-Bus。

## 30秒先看懂

1. IPC 是进程间交换数据的机制，因为进程有独立地址空间，不能直接访问对方的内存。
2. Socket 是最通用的 IPC——同一台机器用 Unix Socket，跨网络用 TCP/UDP Socket。
3. D-Bus 是 Linux 桌面和服务器的标准 IPC 框架——支持方法调用（像 RPC）和信号广播（发布/订阅）。
4. 共享内存是最高性能的 IPC——直接把同一块物理内存映射到多个进程的地址空间，但需要信号量同步。
5. V881 上各系统服务（摄像头、WiFi、音频、OTA）之间通过 D-Bus 通信，WQ7036AX 和 V881 之间通过 UART 通信。

## 学完以后应该能做什么

### 第一遍
- 区分不同 IPC 方式的适用场景（Socket vs D-Bus vs 共享内存）
- 用 Socket 在进程间传输数据（TCP 或 Unix Socket）
- 理解 D-Bus 的基本概念（方法调用、信号、总线）
- 用共享内存 + 信号量实现高效数据交换

### 进阶
- 设计基于 D-Bus 的多服务通信架构
- 分析共享内存的同步性能瓶颈
- 理解 Unix Socket 和 TCP Socket 的差异
- 在嵌入式 Linux 上选择合适的 IPC 方案

## 前置知识

- 进程和地址空间的概念
- 基本的网络编程知识（TCP/IP）
- 多线程同步机制（互斥量、信号量）

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 进程间通信 | IPC (Inter-Process Communication) | 不同进程之间交换数据或信号的机制 |
| 套接字 | Socket | 网络通信的端点，可用于同一主机或跨网络通信 |
| D-Bus | D-Bus | Linux 桌面环境的标准 IPC 框架，支持方法调用和信号广播 |
| 共享内存 | Shared Memory | 多个进程共享同一块物理内存的机制 |
| 信号量 | Semaphore | 用于同步共享内存访问的计数器 |
| Unix Socket | Unix Domain Socket | 同一主机上进程间通信的 Socket，比 TCP Socket 快 |
| 总线 | Bus | D-Bus 中的通信通道，system bus（系统服务）和 session bus（用户会话） |

## 第一层：费曼心智模型

### 类比：公司内部的沟通方式

| IPC 方式 | 类比 | 适用场景 |
|----------|------|---------|
| **Socket (TCP)** | 寄信——写地址、贴邮票、邮寄，对方收到回信 | 跨网络通信，远程服务调用 |
| **Unix Socket** | 公司内部对讲机——直接喊，不用写地址 | 同一台机器上的进程通信 |
| **D-Bus** | 公司内部广播——你广播一条消息，所有订阅的人都能收到 | 系统服务间通信，方法调用+信号广播 |
| **共享内存** | 公告板——所有人在上面贴信息，其他人直接看 | 大量数据交换，最快但需要同步协议 |
| **管道 (Pipe)** | 传纸条——A 传给 B，B 传给 C，单向 | 父子进程，命令行管道 |

### 边界

IPC 不是万能的：
- 如果两个进程在同一台机器上，Unix Socket 比 TCP Socket 快 2-3 倍（不走网络协议栈）
- 共享内存虽然快，但需要复杂的同步机制，容易出错
- D-Bus 适合低频控制消息，不适合高吞吐量数据（如视频帧）
- 进程间通信比线程间通信慢（因为要经过内核或复制数据）

### 场景推演：V881 服务启动流程

V881 启动时，systemd 启动各服务：D-Bus 守护进程先启动，然后摄像头服务、WiFi 服务、音频服务通过 D-Bus 注册到系统总线。

用户通过手机 APP 发出"开始录制"指令：WiFi 服务收到 MQTT 消息 → 通过 D-Bus 调用摄像头服务的 `StartRecording()` 方法 → 摄像头服务开始采集和编码。此时如果用户想查看实时画面，视频流通过 Socket（RTSP/UDP）直接传输，不经过 D-Bus（因为视频数据量大，D-Bus 不适合）。

## 第二层：原理/时序/约束

### 三种 IPC 的代码骨架

```c
// === Socket (TCP) ===
int sock = socket(AF_INET, SOCK_STREAM, 0);
connect(sock, &addr, sizeof(addr));
send(sock, data, len, 0);
recv(sock, buf, size, 0);

// === Unix Socket（同一主机，比 TCP 快）===
int sock = socket(AF_UNIX, SOCK_STREAM, 0);
struct sockaddr_un addr = { .sun_family = AF_UNIX };
strcpy(addr.sun_path, "/tmp/my_socket");  // 路径名
connect(sock, (struct sockaddr *)&addr, sizeof(addr));

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

### D-Bus 在 V881 上的典型用法

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

音频服务 (audio_service)
  │
  ├── D-Bus 方法: SetVolume(level)
  └── D-Bus 信号: AudioRouteChanged
```

### IPC 性能对比

| IPC 方式 | 延迟 (同机) | 吞吐量 | 适用数据量 | 是否跨网络 |
|----------|------------|--------|-----------|-----------|
| TCP Socket | ~10μs | ~1 Gbps | 任意 | 是 |
| Unix Socket | ~3μs | ~2 Gbps | 任意 | 否 |
| 共享内存 | ~0.1μs | 内存带宽 | 大块数据 | 否 |
| D-Bus | ~100μs | ~10 Mbps | 小消息(<1MB) | 否 |
| 管道 | ~5μs | ~1 Gbps | 流数据 | 否 |

## 第三层：真实SDK代码

### WQ7036AX 的 IPC 实现

在 `/home/ys/wq7036a/wq-audio/wqcore/components/amp/ipc/` 中，WQ7036AX 用软中断 + 共享内存实现核间通信（ACORE ↔ BCORE ↔ DCORE）：

```c
// 伪代码——WQ7036AX IPC 核间通信
// 文件路径: wqcore/components/amp/ipc/ipc.h

// IPC 消息结构
typedef struct {
    uint32_t magic;      // 魔数: 0x57514943 ("WQIC")
    uint32_t src_core;   // 源核 (ACORE=0, BCORE=1, DCORE=2)
    uint32_t dst_core;   // 目标核
    uint32_t msg_id;     // 消息 ID
    uint32_t len;        // 数据长度
    uint8_t  data[];     // 数据
} ipc_msg_t;

// 发送 IPC 消息
// 使用软中断通知目标核，共享内存传递数据
int ipc_send(uint32_t dst_core, uint32_t msg_id,
             const void *data, uint32_t len);

// 注册 IPC 消息处理回调
void ipc_register_handler(uint32_t msg_id,
                          ipc_handler_t handler, void *ctx);
```

### V881 的 D-Bus 服务定义

在 `/home/ys/aiglass/reglasses/services/` 中，各服务通过 D-Bus 通信：

```c
// 伪代码——V881 D-Bus 服务接口定义
// 文件路径: reglasses/services/camera/cam_dbus.c

// 注册 D-Bus 方法
static const gchar *cam_introspection_xml =
    "<node>"
    "  <interface name='com.reglasses.Camera'>"
    "    <method name='StartRecording'>"
    "      <arg type='s' name='filename' direction='in'/>"
    "    </method>"
    "    <method name='StopRecording'/>"
    "    <signal name='RecordingStarted'>"
    "      <arg type='s' name='filename'/>"
    "    </signal>"
    "  </interface>"
    "</node>";

// 方法调用处理
static void handle_start_recording(GDBusMethodInvocation *inv,
                                   const char *filename,
                                   gpointer user_data) {
    // 启动录制...
    g_dbus_method_invocation_return_value(inv, NULL);

    // 广播信号
    g_dbus_connection_emit_signal(connection,
        NULL, "/com/reglasses/Camera",
        "com.reglasses.Camera", "RecordingStarted",
        g_variant_new("(s)", filename), NULL);
}
```

## 第四层：正常/异常路径

### 正常路径

```
D-Bus 方法调用：
  Client → g_dbus_proxy_call_sync("StartRecording")
    → D-Bus 守护进程路由消息
    → Camera 服务处理请求
    → 返回结果给 Client

共享内存数据交换：
  进程 A: shm_open + mmap → 写入数据 → 信号量通知
  进程 B: shm_open + mmap → 信号量等待 → 读取数据
```

### 异常路径

| 异常 | 现象 | 触发条件 | 恢复方式 |
|------|------|---------|---------|
| D-Bus 服务未启动 | 方法调用超时（默认 30s） | 被调用的服务尚未注册到总线 | 检查服务启动顺序，使用 `After=` 和 `Requires=` |
| Socket 端口冲突 | bind 返回 -1，Address in use | 端口已被其他进程占用 | 使用 `SO_REUSEADDR` 或在 `/tmp/` 下用 Unix Socket |
| 共享内存同步失败 | 读取到不完整的数据 | 忘记加信号量保护 | 使用 POSIX 信号量或互斥量保护 |
| 共享内存泄漏 | 系统共享内存持续增长 | 进程退出时未 `shm_unlink` | 在进程退出时清理共享内存对象 |
| Unix Socket 文件残留 | bind 失败 | 上次进程异常退出，Socket 文件未删除 | bind 前 `unlink` 路径 |

## 第五层：调试方法

### Socket 调试

```bash
# 查看所有监听端口
netstat -anp | grep LISTEN

# 查看已建立的连接
netstat -anp | grep ESTABLISHED

# 使用 ss（更快的替代）
ss -tuln

# 抓包分析
tcpdump -i lo port 8080  # 本地回环
tcpdump -i wlan0 port 8080  # 无线接口
```

### D-Bus 调试

```bash
# 查看 D-Bus 上的所有服务
dbus-send --system --dest=org.freedesktop.DBus \
  --type=method_call --print-reply \
  /org/freedesktop/DBus org.freedesktop.DBus.ListNames

# 监控 D-Bus 消息
dbus-monitor --system

# 查看特定服务的接口
gdbus introspect --system \
  --dest=com.reglasses.Camera --object-path=/com/reglasses/Camera
```

### 共享内存调试

```bash
# 查看系统共享内存段
ipcs -m

# 查看共享内存详细信息
ipcs -m -i <shmid>

# 删除共享内存段
ipcrm -m <shmid>
```

## 第六层：实战练习

### 练习1：用 Unix Socket 实现本地 Echo 服务

实现一个简单的 echo 服务端和客户端，使用 Unix Socket（`AF_UNIX`）在同一台机器上通信。服务端接收客户端消息并原样返回。

```c
// 提示：
// 服务端: socket(AF_UNIX, SOCK_STREAM, 0) → bind → listen → accept → read/write
// 客户端: socket(AF_UNIX, SOCK_STREAM, 0) → connect → send/recv
```

### 练习2：用共享内存实现双进程计数器

创建两个进程，通过共享内存共享一个计数器。进程 A 递增，进程 B 读取并打印。使用 POSIX 信号量（`sem_t`）保护共享内存的并发访问。

### 练习3：阅读真实源码——WQ7036AX IPC 核间通信

阅读 `/home/ys/wq7036a/wq-audio/wqcore/components/amp/ipc/ipc.c` 和 `ipc.h` 的源码，分析：
1. IPC 消息的格式（magic number、消息 ID 的分配）
2. 软中断是如何触发的？目标核怎样知道有新消息？
3. 共享内存区域是如何划分和保护的？

## 自测与验收

1. Socket、D-Bus、共享内存三种 IPC 方式分别适用于什么场景？为什么视频流不通过 D-Bus 传输？
2. Unix Socket 和 TCP Socket 在本地通信时有什么区别？性能差异有多大？
3. D-Bus 的方法调用和信号有什么区别？分别对应什么场景？
4. 共享内存为什么需要信号量保护？如果两个进程同时写共享内存会怎样？
5. WQ7036AX 的 IPC 和 Linux 上的 IPC 有什么不同？（提示：软中断 vs Socket）
6. 什么是 D-Bus 的 system bus 和 session bus？V881 上的服务应该用哪个？

## 延伸阅读

- [[multithread-posix-多线程编程]] — 线程间同步（同一进程内）
- [[uart-basics-UART基础]] — WQ7036AX↔V881 的芯片间通信
- [[network-mqtt-http-网络编程]] — 网络通信（跨设备的 IPC）
- [[systemd-daemon-Systemd守护进程]] — systemd 管理 D-Bus 服务

## #flashcard

Q: 三种主流 IPC 方式（Socket、D-Bus、共享内存）的适用场景？
A: Socket 跨网络通用，D-Bus 系统服务间方法调用+信号广播，共享内存大量数据高速交换。

Q: Unix Socket 和 TCP Socket 的主要区别？
A: Unix Socket 用路径名寻址，不走 TCP/IP 协议栈，本地通信比 TCP Socket 快 2-3 倍。

Q: D-Bus 的方法调用和信号分别对应什么通信模式？
A: 方法调用 = 请求-响应（一对一），信号 = 发布-订阅（一对多广播）。

Q: 共享内存为什么需要同步？
A: 多个进程同时读写同一块内存会导致数据不一致，需要信号量或互斥量保护。

Q: WQ7036AX 的 IPC 实现方式？
A: 使用软中断 + 共享内存，消息格式含魔数 0x57514943 ("WQIC")，核间通信通过中断通知。