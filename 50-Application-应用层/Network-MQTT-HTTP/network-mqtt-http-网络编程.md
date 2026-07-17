# 网络编程：Socket / MQTT / HTTP

**一句话结论（20% 核心）**：Socket 是网络通信的底层 API（TCP 可靠但慢，UDP 快但不可靠），MQTT 是物联网发布/订阅协议（轻量级，适合窄带宽），HTTP 是 Web 标准协议（REST API + 文件下载）。V881 用 Socket 推 RTSP 视频流，用 MQTT 连云端上报状态，用 HTTP 做 OTA 固件下载。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：寄信 vs 对讲机 vs 广播

- **TCP** = 寄挂号信：有回执、序号保证不丢、按顺序到达。慢但可靠。
- **UDP** = 对讲机：喊一嗓子，对方听没听到不管。快但不可靠。
- **MQTT** = 订阅公众号：你订阅了"home/temp"，有更新就推送给你。中间有个 Broker（公众号平台）中转。
- **HTTP** = 去图书馆借书：你主动请求（GET），图书馆给你返回（200 OK）。请求-响应模式。

### 1.2 TCP vs UDP 深度对比

| | TCP | UDP |
|---|---|---|
| 连接 | 三次握手建立连接 | 无连接，直接发 |
| 可靠性 | 确认+重传+序号保证 | 不保证（发出去不管） |
| 顺序 | 保证有序 | 不保证（后发的可能先到） |
| 流控 | 有（滑动窗口） | 无 |
| 拥塞控制 | 有（慢启动/拥塞避免） | 无 |
| 头部开销 | 20 字节 | **8 字节** |
| 适用场景 | 文件传输、HTTP、MQTT | 视频流、VoIP、DNS、在线游戏 |
| reGlasses | OTA 下载、MQTT 连接 | RTSP 视频流 |

### 1.3 MQTT：物联网的事实标准

```
MQTT 发布/订阅模型：

Publisher (温湿度传感器)          Broker (MQTT 服务器)         Subscriber (手机 APP)
    │                                     │                         │
    │── publish("home/temp", "25°C") ──→│                         │
    │                                     │←── subscribe("home/temp")
    │                                     │── publish → "25°C" ──→│
    │                                     │                         │
    │                                     │←── subscribe("home/#") (订阅所有 home 下的)
    │                                     │── publish → "25°C" ──→│ (匹配通配符)
```

**MQTT 为什么适合物联网？**
- 二进制协议，头部最小只有 **2 字节**（HTTP 头部几百字节）
- 支持 QoS 0/1/2（最多一次/至少一次/精确一次）
- 支持遗嘱消息（设备离线时自动通知）
- 支持保持连接（心跳包，30 秒一次，极省电）

### 1.4 如果只记得一件事

> Socket = 底层 API（TCP 可靠/UDP 快），MQTT = 物联网发布/订阅（轻量），HTTP = Web 标准（REST API + 下载）。V881 用这三个协议：UDP 推视频流，MQTT 连云端，HTTP 下载固件。

---

## 第二层：实战理解

### 2.1 TCP Client 完整实现

```c
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>

int tcp_connect(const char *host, int port) {
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) return -1;

    struct sockaddr_in addr = {
        .sin_family = AF_INET,
        .sin_port   = htons(port),          // 必须 htons！网络字节序=大端
    };
    inet_pton(AF_INET, host, &addr.sin_addr);

    if (connect(sock, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        close(sock);
        return -1;
    }
    return sock;
}

int tcp_send_all(int sock, const void *data, int len) {
    int sent = 0;
    while (sent < len) {
        int n = send(sock, data + sent, len - sent, 0);
        if (n <= 0) return -1;
        sent += n;
    }
    return sent;
}

int tcp_recv_all(int sock, void *buf, int len) {
    int received = 0;
    while (received < len) {
        int n = recv(sock, buf + received, len - received, 0);
        if (n <= 0) return n;  // 0 = 对端关闭, -1 = 错误
        received += n;
    }
    return received;
}
```

### 2.2 MQTT 客户端示例

```c
// 使用 mosquitto 库（V881 上常用）
#include <mosquitto.h>

void on_connect(struct mosquitto *mqtt, void *obj, int rc) {
    if (rc == 0) {
        mosquitto_subscribe(mqtt, NULL, "cmd/reglasses/#", 1);  // QoS 1
        mosquitto_subscribe(mqtt, NULL, "ota/update", 2);       // QoS 2
    }
}

void on_message(struct mosquitto *mqtt, void *obj,
                const struct mosquitto_message *msg) {
    if (strcmp(msg->topic, "cmd/reglasses/record") == 0) {
        start_recording();                                    // 收到录制指令
    }
}

int main() {
    mosquitto_lib_init();
    struct mosquitto *mqtt = mosquitto_new("reglasses_001", true, NULL);
    mosquitto_connect_callback_set(mqtt, on_connect);
    mosquitto_message_callback_set(mqtt, on_message);

    mosquitto_connect(mqtt, "mqtt.reglasses.com", 1883, 60); // keepalive 60s
    mosquitto_loop_forever(mqtt, -1, 1);                      // 阻塞循环
}
```

### 2.3 常见坑

| 问题 | 现象 | 排查方法 | 根因 |
|------|------|---------|------|
| TCP 粘包 | 两次发送的数据被当成一次接收 | 应用层加帧分隔符（如\r\n）或长度前缀 | TCP 是流协议，没有消息边界 |
| 网络字节序 | 端口号 8080 变成 25360 | 检查是否用了 htons() | x86 小端，网络大端，必须转换 |
| TIME_WAIT | bind 失败 "Address in use" | `netstat -anp | grep TIME_WAIT` | 关闭连接后等 2MSL(~60s)，用 SO_REUSEADDR |
| MQTT 断连 | 设备离线，云端收不到数据 | 检查 keepalive 和网络状态 | 心跳超时，Broker 认为设备离线 |

### 2.4 在 reGlasses 项目中怎么用

V881 的 WiFi 连接云端，使用三种协议：
- **UDP/RTSP**：推送视频流到手机（低延迟，允许丢帧）
- **MQTT**：上报设备状态（电量、温度、佩戴状态）、接收远程指令（拍照、录像）
- **HTTP**：下载 OTA 固件包（需要可靠传输，用 TCP）

WQ7036AX 不直接连网络——它通过 BLE 和手机通信，手机作为网络的中转站。

---

## 第三层：深入扩展

### 3.1 MQTT QoS 级别

| QoS | 含义 | 保证 | 适用场景 |
|-----|------|------|---------|
| **0** | 最多一次 | 不保证到达 | 传感器数据上报（丢一两条无所谓） |
| **1** | 至少一次 | 保证到达，但可能重复 | 设备状态上报 |
| **2** | 精确一次 | 保证到达且不重复 | 关键指令（如"开始录制"） |

### 3.2 常见问题

- **TCP 为什么需要三次握手？** 确认双方都能收发。第一次：A→B（A 能发），第二次：B→A（B 能收发），第三次：A→B（A 能收）。两次握手不够（B 不知道 A 能收），四次太多。
- **MQTT 和 HTTP 怎么选？** 物联网上报数据 → MQTT（轻量、推送）。文件下载、REST API → HTTP（标准、工具多）。微信小程序控制设备 → MQTT over WebSocket。
- **Socket 的阻塞和非阻塞模式？** 阻塞模式：recv 没数据时一直等。非阻塞模式：recv 没数据立即返回 -1（errno=EAGAIN）。实时应用通常用非阻塞 + epoll/select。

### 3.3 延伸阅读

- [[ipc-dbus-socket-IPC通信]] — Socket 也可以用于本地 IPC（Unix Socket）
- [[reglasses-bandwidth-reGlasses带宽约束]] — WiFi 和 BLE 的带宽分配
- [[systemd-daemon-Systemd守护进程]] — 网络服务作为 systemd 守护进程运行