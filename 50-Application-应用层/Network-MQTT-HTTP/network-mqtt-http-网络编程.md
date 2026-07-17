---
type: concept
tags: [网络编程, MQTT, HTTP, Socket, TCP, UDP, 物联网]
aliases: [网络编程, MQTT, HTTP, 网络协议]
---

# 网络编程：Socket / MQTT / HTTP

## 一句话结论

Socket 是网络通信的底层 API（TCP 可靠但慢，UDP 快但不可靠），MQTT 是物联网发布/订阅协议（轻量级，适合窄带宽），HTTP 是 Web 标准协议（REST API + 文件下载）。V881 用 Socket 推 RTSP 视频流，用 MQTT 连云端上报状态，用 HTTP 做 OTA 固件下载。

## 30秒先看懂

1. TCP 像寄挂号信——可靠但慢（三次握手、确认重传），UDP 像对讲机——快但不可靠（发出去不管）。
2. MQTT 是物联网的事实标准——二进制协议，头部最小 2 字节，支持发布/订阅模式，比 HTTP 轻量 100 倍。
3. HTTP 是 Web 标准——请求-响应模式，适合 REST API 和文件下载，但头部大（几百字节），不适合实时推送。
4. TCP 是流协议没有消息边界，应用层需要自己处理粘包（加长度前缀或分隔符）。
5. V881 用三种协议：UDP 推视频流（允许丢帧），MQTT 连云端上报状态，HTTP 下载 OTA 固件。

## 学完以后应该能做什么

### 第一遍
- 写出正确的 TCP Client/Server 代码（socket → connect/bind → send/recv）
- 理解 TCP 和 UDP 的差异，为不同场景选择正确的协议
- 使用 MQTT 客户端库实现设备上云
- 用 HTTP 下载文件和处理 REST API

### 进阶
- 处理 TCP 粘包问题（长度前缀法）
- 理解 MQTT QoS 级别和遗嘱消息
- 设计高并发网络服务（epoll + 非阻塞 IO）
- 在嵌入式 Linux 上优化网络带宽使用

## 前置知识

- 基本的计算机网络概念（IP 地址、端口、协议栈）
- 进程间通信概念
- 文件描述符（Socket 也是 fd）

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 套接字 | Socket | 网络通信的端点，由 IP 地址和端口号标识 |
| 三次握手 | Three-way Handshake | TCP 建立连接的过程：SYN → SYN-ACK → ACK |
| 粘包 | TCP Sticky Packet | TCP 是流协议，多次 send 可能被合并成一次 recv 接收 |
| 发布/订阅 | Pub/Sub | 消息发送者（发布者）和接收者（订阅者）通过 Broker 解耦 |
| 服务质量 | QoS (Quality of Service) | MQTT 中消息送达的保证级别（0/1/2） |
| 心跳 | Keepalive | 定期发送的探测包，检测连接是否存活 |
| 网络字节序 | Network Byte Order | 大端模式，TCP/IP 协议中多字节整数的标准编码 |

## 第一层：费曼心智模型

### 类比：寄信 vs 对讲机 vs 广播

- **TCP** = 寄挂号信：有回执、序号保证不丢、按顺序到达。慢但可靠。
- **UDP** = 对讲机：喊一嗓子，对方听没听到不管。快但不可靠。
- **MQTT** = 订阅公众号：你订阅了"home/temp"，有更新就推送给你。中间有个 Broker（公众号平台）中转。
- **HTTP** = 去图书馆借书：你主动请求（GET），图书馆给你返回（200 OK）。请求-响应模式。

### 边界

- TCP 不是所有场景都适用：实时视频通话用 UDP（因为少量丢帧比延迟更重要），大量传感器数据上报用 UDP（丢几条数据无所谓）。
- MQTT 不适合传输大文件（视频、图片），因为 Broker 需要存储转发，效率低。大文件用 HTTP 直接下载。
- HTTP 不适合实时推送，因为需要客户端轮询或使用 WebSocket 升级。
- 嵌入式设备和云端通信，首选 MQTT（窄带宽、低功耗、长连接）。

### 场景推演：远程查看摄像头画面

用户在手机上打开 APP 查看 Glasses 的实时画面。

1. APP 通过 MQTT 发送指令 `cmd/reglasses/camera/start` 到云端
2. 云端通过 MQTT 转发给 Glasses 的 WiFi 服务
3. WiFi 服务收到指令，启动摄像头和 RTSP 服务器
4. 视频流通过 UDP/RTP 推送到手机（低延迟，允许少量丢帧）
5. 用户看到画面后，通过 MQTT 发送 `cmd/reglasses/record/start` 开始录制
6. 录制完成后，视频文件通过 HTTP 下载到手机本地

整个过程混合使用了三种协议，各司其职。

## 第二层：原理/时序/约束

### TCP vs UDP 深度对比

| | TCP | UDP |
|---|---|---|
| 连接 | 三次握手建立连接 | 无连接，直接发 |
| 可靠性 | 确认+重传+序号保证 | 不保证（发出去不管） |
| 顺序 | 保证有序 | 不保证（后发的可能先到） |
| 流控 | 有（滑动窗口） | 无 |
| 拥塞控制 | 有（慢启动/拥塞避免） | 无 |
| 头部开销 | 20 字节 | **8 字节** |
| 适用场景 | 文件传输、HTTP、MQTT | 视频流、VoIP、DNS、在线游戏 |

### TCP Client 完整实现

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

### TCP 粘包问题

TCP 是流协议，没有消息边界。应用层需要自己界定消息边界：

```c
// 方法一：长度前缀法（推荐）
// 发送：4 字节长度 + 数据
uint32_t len = htonl(data_len);
send(sock, &len, 4, 0);
send(sock, data, data_len, 0);

// 接收：先读 4 字节长度，再读数据
uint32_t len;
recv_all(sock, &len, 4);
len = ntohl(len);
recv_all(sock, buf, len);

// 方法二：分隔符法（适合文本协议）
// 每个消息以 \r\n 结尾
// 例如 HTTP 头部用 \r\n 分隔行
```

### MQTT 客户端示例

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

### MQTT QoS 级别

| QoS | 含义 | 保证 | 适用场景 |
|-----|------|------|---------|
| **0** | 最多一次 | 不保证到达 | 传感器数据上报（丢一两条无所谓） |
| **1** | 至少一次 | 保证到达，但可能重复 | 设备状态上报 |
| **2** | 精确一次 | 保证到达且不重复 | 关键指令（如"开始录制"） |

## 第三层：真实SDK代码

### WQ7036AX 的 BLE 协议封装

WQ7036AX 不直接连网络，通过 BLE 与手机通信。在 `/home/ys/wq7036a/wq-audio/wqcore/components/bluetooth/` 中，BLE 协议封装了类似 MQTT 的发布/订阅模式：

```c
// 伪代码——WQ7036AX BLE 协议数据包封装
// 文件路径: wqcore/components/bluetooth/host/bbb/inc/wq_bth_api.h

// BLE 音频数据传输协议
// 封装了类似 MQTT 的消息类型和 ID
typedef struct {
    uint8_t  service_type;    // 服务类型: 音频/控制/OTA
    uint8_t  msg_type;        // 消息类型: 请求/响应/通知
    uint16_t msg_id;          // 消息 ID
    uint16_t seq_num;         // 序列号（类似 TCP 的序号）
    uint16_t total_len;       // 数据总长度
    uint8_t  data[];          // 数据
} wq_proto_pkt_t;
```

### V881 的 MQTT 服务

在 `/home/ys/aiglass/reglasses/services/wifi/` 中，WiFi 服务通过 MQTT 与云端通信：

```c
// 伪代码——V881 MQTT 消息处理
// 文件路径: reglasses/services/wifi/mqtt_client.c

// 上报设备状态
void report_device_status(void) {
    json_t *status = json_object();
    json_object_set(status, "battery", json_integer(get_battery_level()));
    json_object_set(status, "wearing", json_boolean(is_wearing()));
    json_object_set(status, "temperature", json_real(get_temperature()));

    char *msg = json_dumps(status, 0);
    mosquitto_publish(mqtt_client, NULL,
                      "status/reglasses/001",
                      strlen(msg), msg, 1, false);  // QoS 1
    free(msg);
}
```

## 第四层：正常/异常路径

### 正常路径

```
TCP 连接: socket → connect (三次握手) → 连接建立 → 数据交换 → close (四次挥手)
MQTT 连接: connect → CONNACK → subscribe → PUBLISH → 心跳 keepalive → disconnect
HTTP 请求: TCP 连接 → 发送 HTTP 请求 → 服务器处理 → 返回 HTTP 响应 → 关闭连接
```

### 异常路径

| 异常 | 现象 | 触发条件 | 恢复方式 |
|------|------|---------|---------|
| TCP 粘包 | 两次发送合并成一次接收 | 应用层无消息边界，Nagle 算法合并小包 | 加长度前缀或分隔符 |
| 网络字节序错 | 端口号 8080 变成 25360 | 忘了调 `htons()` | 发送端 htons，接收端 ntohs |
| TIME_WAIT | bind 失败 "Address in use" | 连接关闭后端口进入 2MSL 等待 | 设置 `SO_REUSEADDR` |
| MQTT 断连 | 设备离线 | 心跳超时或网络中断 | 自动重连 + 遗嘱消息通知 |
| HTTP 超时 | 请求无响应 | 服务器不可达或处理慢 | 设置超时时间 + 重试机制 |
| DNS 解析失败 | connect 返回 -1 (EAI_NONAME) | 域名不存在或 DNS 服务器不可达 | 检查网络连接，使用 IP 地址作为后备 |

## 第五层：调试方法

### 网络排查工具

```bash
# 查看网络连接状态
netstat -anp | grep ESTABLISHED
ss -tunp

# DNS 解析测试
nslookup mqtt.reglasses.com
dig mqtt.reglasses.com

# 检查端口连通性
telnet mqtt.reglasses.com 1883
nc -zv mqtt.reglasses.com 1883

# 抓包分析
tcpdump -i wlan0 port 1883 -X   # MQTT 包
tcpdump -i wlan0 port 80 -X     # HTTP 包
tcpdump -i wlan0 port 554 -X    # RTSP 包

# 使用 Wireshark 分析抓包文件
# tcpdump 保存为 pcap 后导入 Wireshark
tcpdump -i wlan0 -w capture.pcap
```

### MQTT 调试工具

```bash
# 订阅测试（mosquitto 客户端）
mosquitto_sub -h mqtt.reglasses.com -t "status/reglasses/#" -v

# 发布测试
mosquitto_pub -h mqtt.reglasses.com -t "cmd/reglasses/record" -m "start"
```

## 第六层：实战练习

### 练习1：实现一个简单的 TCP Echo Server

编写一个 TCP echo server，使用 `fork()` 为每个客户端创建一个子进程处理。客户端连接后，服务器将收到的数据原样返回。

```c
// 提示：socket → bind → listen → accept → (fork → read/write/close)
```

### 练习2：处理 TCP 粘包

修改练习1的 echo server，让它能正确处理粘包。使用长度前缀法（4 字节网络字节序长度 + 数据体）来界定消息边界。

### 练习3：阅读真实源码——V881 MQTT 消息处理

阅读 `/home/ys/aiglass/reglasses/services/wifi/` 目录下的源码，分析：
1. MQTT 连接是怎么建立的（参数配置、回调注册）？
2. 设备状态是如何上报的（上报频率、数据格式）？
3. 断连后如何重连（重连逻辑、退避策略）？

## 自测与验收

1. TCP 和 UDP 的核心区别是什么？为什么视频流用 UDP 而 OTA 下载用 TCP？
2. 什么是 TCP 粘包？如何解决？
3. MQTT 的 QoS 0/1/2 有什么区别？在什么场景下用哪个？
4. 为什么 MQTT 比 HTTP 更适合物联网场景？
5. `htons()` 和 `htonl()` 的作用是什么？如果忘记调用会怎样？
6. 什么是 MQTT 的遗嘱消息（Last Will）？在设备异常断连时有什么作用？

## 延伸阅读

- [[ipc-dbus-socket-IPC通信]] — Socket 也可以用于本地 IPC（Unix Socket）
- [[reglasses-bandwidth-reGlasses带宽约束]] — WiFi 和 BLE 的带宽分配
- [[systemd-daemon-Systemd守护进程]] — 网络服务作为 systemd 守护进程运行
- [[file-io-文件IO]] — 网络数据接收后的文件写入

## #flashcard

Q: TCP 和 UDP 的核心区别？
A: TCP 面向连接、可靠（确认重传）、有序、有流控拥塞控制；UDP 无连接、不可靠、无序、无流控。

Q: 什么是 TCP 粘包？如何解决？
A: TCP 是流协议，多次 send 可能合并接收。解决方法：长度前缀法（4 字节长度+数据）或分隔符法（如 \r\n）。

Q: MQTT 的 QoS 0/1/2 的区别？
A: QoS 0 = 最多一次（不保证到达），QoS 1 = 至少一次（可能重复），QoS 2 = 精确一次（不重不漏）。

Q: 为什么 htons 是必须的？
A: x86 是小端，网络协议规定大端字节序。不调用 htons 会导致端口号/地址解析错误。

Q: MQTT 相比 HTTP 在物联网场景的优势？
A: 头部最小 2 字节（HTTP 几百字节），支持发布/订阅（非请求-响应），支持心跳保活（省电），支持 QoS 和遗嘱消息。