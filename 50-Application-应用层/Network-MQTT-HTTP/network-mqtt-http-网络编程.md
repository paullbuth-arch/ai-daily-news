# 网络编程：Socket / MQTT / HTTP

**一句话结论（20% 核心）**：Socket 是网络通信的底层 API，TCP 可靠但慢，UDP 快但不可靠。MQTT 是物联网轻量级发布/订阅协议，HTTP 是 Web 标准协议。V881 用 Socket 推视频流，用 MQTT 连云端，用 HTTP 做 OTA 下载。

---

## 第一层：核心认知（必须先看懂）

### 1.1 TCP vs UDP 对比

| | TCP | UDP |
|---|---|---|
| 可靠性 | 可靠（重传、确认） | 不可靠（发出去不管） |
| 速度 | 慢 | 快 |
| 连接 | 需要建立连接 | 无连接 |
| 适用场景 | 文件传输、HTTP | 视频流、VoIP、DNS |
| reGlasses 用途 | OTA 下载 | RTSP 视频流 |

### 1.2 MQTT 发布/订阅模型

```
Publisher (温湿度传感器)          Broker (MQTT 服务器)
    │                                     │
    └── publish("home/temp", "25°C") ────→│
                                           │
    Subscriber (手机 APP)                  │
    │                                     │
    └──── subscribe("home/temp") ────────→│
    │←─── "25°C" ────────────────────────│
```

### 1.3 如果只记得一件事

> Socket = 底层 API，TCP 可靠/UDP 快。MQTT = 物联网发布/订阅，轻量级。HTTP = Web 标准，用于 REST API 和文件下载。V881 用这三个协议分别处理视频流、云端通信、OTA 下载。

---

## 第二层：实战理解

### 2.1 TCP Client 最小代码

```c
int sock = socket(AF_INET, SOCK_STREAM, 0);
struct sockaddr_in addr = {
    .sin_family = AF_INET,
    .sin_port = htons(8080),
};
inet_pton(AF_INET, "192.168.1.100", &addr.sin_addr);
connect(sock, (struct sockaddr *)&addr, sizeof(addr));

const char *msg = "GET /api/status HTTP/1.0\r\n\r\n";
send(sock, msg, strlen(msg), 0);

char buf[4096];
int n = recv(sock, buf, sizeof(buf) - 1, 0);
buf[n] = '\0';
close(sock);
```

### 2.2 常见坑

| 问题 | 现象 | 根因 |
|------|------|------|
| TCP 粘包 | 数据拼在一起 | TCP 是流协议，需要应用层帧分隔 |
| 端口未释放 | bind 失败 | 上次关闭后 TIME_WAIT 状态，用 SO_REUSEADDR |
| 网络字节序 | 端口号不对 | 忘了 htons()，x86 小端 vs 网络大端 |

### 2.3 在 reGlasses 项目中怎么用

V881 的 WiFi 连接云端，通过 MQTT 上报设备状态、接收远程指令，通过 RTSP/UDP 推送视频流。WQ7036AX 不直接连网络，通过 BLE 和手机通信。

---

## 第三层：延伸阅读

- [[ipc-dbus-socket-IPC通信]] — Socket 也可以用于本地 IPC（Unix Socket）
- [[reglasses-bandwidth-reGlasses带宽约束]] — WiFi 和 BLE 的带宽分配