---
type: concept
created: 2026-07-16
updated: 2026-07-17
tags: [dataflow, command, ble, uart-cmd, 数据流, 指令转发, routing]
aliases: [指令数据流, 手机到V881, 命令转发流程]
---

# 数据流：手机指令到 V881

**一句话结论**：手机 APP 发出的指令（如"开始录制"）经过 BLE 空中传输、WQ7036AX 解包路由、UART 转发三个阶段才能到达 V881；响应沿原路返回。WQ7036AX 在中间担任"翻译官"角色。

---

## 30 秒先看懂

- 手机 APP 用 WQ Protocol 格式打包指令，通过 BLE GATT Write 发送到 WQ7036AX。
- WQ7036AX 收到后解包，根据 service_type 判断是本地执行还是转发 V881。
- 需要转发的指令重新打包为 UART CMD 帧，通过 UART 发送到 V881。
- V881 处理完成后，响应沿原路逆向返回：UART 响应 → WQ7036AX 打包为 WQ Protocol → BLE Notify 发送给手机。
- 完整端到端延迟大约 100-250ms，其中主要耗时在 V881 处理（如语音识别 50-500ms）。

---

## 学完以后应该能做什么

**第一遍学完**：
- 能画出手机指令到 V881 的完整路径和每个阶段使用的协议
- 能说出路由规则：什么命令在 WQ7036AX 本地执行，什么命令转发 V881
- 能在 SDK 中找到 `write_callback` 和 `app_uart_cmd.c` 中的关键函数

**进阶目标**：
- 能分析端到端延迟，找出瓶颈环节
- 能新增一条命令并在 WQ7036AX 上实现路由逻辑
- 能阅读 WQ Protocol 帧结构，手动构造一帧数据

---

## 前置知识

- [[wq-audio-protocol-WQ-Audio-Protocol]] — BLE 侧的帧格式
- [[uart-basics-UART基础]] — UART 通信原理
- [[ble-gatt-BLE-GATT]] — BLE 数据通道
- [[reglasses-architecture-reGlasses协议架构]] — 全局拓扑

---

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 协议帧 | Protocol Frame | 应用层定义的数据包格式，包含帧头、消息头、载荷 |
| 同步字 | Sync Word | 帧起始标志，用于接收端识别帧开始位置 |
| 服务类型 | Service Type | 区分指令/音频/遥测等不同业务类型 |
| 命令 ID | Command ID | 具体指令的编号，如 RECORD_START、TAKE_PHOTO |
| 通知 | Notify | BLE GATT 的一种通信方式，服务器主动推送数据给客户端 |
| 连接句柄 | Connection Handle | BLE 连接的唯一标识符 |
| 序列号 | Sequence Number | 帧序号，用于去重和排序 |

---

## 第一层：费曼心智模型

### 类比：国际快递转运

手机指令到 V881 的旅程就像寄国际快递：

| 阶段 | 类比 | 说明 |
|------|------|------|
| Step 1 手机打包 | 发件人填写国际快递单 | 手机 APP 按照 WQ Protocol 格式打包指令 |
| Step 2 BLE 发送 | 快递从发件人送到中转站 | BLE 空中传输数据到 WQ7036AX |
| Step 3 解包路由 | 中转站分拣中心 | WQ7036AX 拆包，判断目的地是本地还是国外 |
| Step 4 UART 转发 | 中转站转运到当地配送站 | 从 WQ7036AX 通过 UART 发送到 V881 |
| Step 5 处理返回 | 当地配送站签收并发回回执 | V881 处理完，响应原路返回 |

### 边界

- 只有控制类指令（SERVICE_TYPE_CONTROL）才需要路由判断
- 音频上行数据（SERVICE_TYPE_TRANS_UP）由 WQ7036AX 本地处理，不转发
- 响应走 Notify 通道（C2: Device Status），不是 Write 通道

### 场景推演

**场景：手机 APP 发送"开始录制"指令**

1. 手机 APP 构造 WQ Protocol 帧：sync_word=0x5751, frame_type=REQ, service_type=CONTROL, command_id=CTRL_RECORD_START_REQ
2. 通过 BLE GATT Write（C1 Characteristic）发送 15 字节数据
3. WQ7036AX 的 `write_callback` 收到数据，调用 `wq_proto_pkt_unpack` 解包
4. 判断 service_type=CONTROL → 需要转发 V881
5. 重新打包为 UART CMD 帧（0xAA 开头），通过 UART TX 发送到 V881
6. V881 启动摄像头，返回响应
7. WQ7036AX 收到 UART 响应，打包为 WQ Protocol RSP 帧
8. 通过 BLE GATT Notify（C2 Characteristic）发送给手机
9. 手机 APP 收到 EVT_RECORD_STARTED，UI 显示"录制中"

---

## 第二层：原理、时序与约束

### 完整时序图

```
手机 APP            WQ7036AX              V881
  │                    │                    │
  │── BLE Write ──────→│                    │
  │  WQ Protocol       │                    │
  │  CTRL_RECORD_START │                    │
  │  (15 bytes)        │                    │
  │                    │                    │
  │                    │ wq_proto_pkt_unpack()
  │                    │ → service=CONTROL
  │                    │ → 需要转发
  │                    │                    │
  │                    │── UART CMD ───────→│
  │                    │  VOICE_START       │
  │                    │  session_id=42     │
  │                    │                    │
  │                    │   (V881 启动摄像头  │
  │                    │    开始录制)        │
  │                    │                    │
  │                    │←─ UART CMD ACK ───│
  │                    │  cmd=0x7F          │
  │                    │                    │
  │                    │ wq_proto_pkt_pack()
  │                    │ → RSP + EVT_RECORD_STARTED
  │                    │                    │
  │← BLE Notify ──────│                    │
  │  Device Status     │                    │
  │  EVT_RECORD_STARTED│                    │
  │                    │                    │
  │  UI: "录制中"      │                    │
```

### 每一步的延迟

| 阶段 | 延迟 | 说明 |
|------|------|------|
| BLE Write（空中） | ~15ms | 取决于连接间隔和距离 |
| WQ7036AX 解包 | <1ms | CPU 处理，几乎无延迟 |
| UART CMD 发送 | <1ms | UART 1Mbps，几十字节瞬间完成 |
| V881 处理（ASR 等） | 50-500ms | 语音识别或图像处理，主要瓶颈 |
| UART CMD 响应 | <1ms | 响应返回 |
| BLE Notify | ~15ms | 空中传输 |
| **总计** | **~100-250ms** | 大部分耗时在 V881 处理 |

### 路由规则

| 命令 | 执行位置 | 原因 |
|------|----------|------|
| RECORD_START | V881 | 摄像头在 V881 上 |
| TAKE_PHOTO | V881 | 同上 |
| TOF_ON/OFF | V881 | TOF 在 V881 上 |
| VOICE_ON/OFF | WQ 本地 | 麦克风在 WQ7036AX 上 |
| STATUS_QUERY | WQ + V881 | 合并两端状态 |

---

## 第三层：真实 SDK 代码

### Step 1：手机 APP 构造 WQ Protocol 帧

手机 APP 用 WQ Protocol 格式打包指令：

```
Frame Header (7B):
  sync_word = 0x5751
  frame_type = REQ (1)
  need_ack = 1
  seq_number = 42

Message Header (4B):
  service_type = SERVICE_TYPE_CONTROL (0x04)
  command_id = CTRL_RECORD_START_REQ (0x01)
  payload_len = 4

Payload (4B):
  camera_mask = 0x07 (广角+长焦+TOF)
  max_duration_s = 0 (不限)
  audio_enable = 1
```

总帧大小 = 7 + 4 + 4 = 15 字节。

### Step 2：BLE GATT Write

手机通过 BLE GATT 的 **C1 Device Control Characteristic** 写入这 15 字节。

**文件路径**：`wq-adk/components/apps/acore/ota/src/ota_transport_ble.c`

### Step 3：WQ7036AX 解包 + 路由

```c
// write_callback 被调用
static void write_callback(uint8_t index, const uint8_t *data, uint16_t len)
{
    // ① 解包 WQ Protocol 帧
    wq_proto_pkt_t pkt;
    wq_proto_pkt_unpack(&pkt, data, len);

    // ② 根据 service_type 路由
    switch (pkt.msg_header.service_type) {
    case SERVICE_TYPE_CONTROL:
        // CTRL_RECORD_START → 转发给 V881
        forward_to_v881_via_sttp(&pkt);
        break;
    case SERVICE_TYPE_TRANS_UP:
        // 音频上行 → 本地处理
        handle_audio_up(&pkt);
        break;
    }
}
```

### Step 4：UART CMD 帧格式

**文件路径**：`wq-adk/examples/glass/acore/app/app_customer_ext_trans/app_uart_cmd.c`

```c
// UART CMD 帧结构
// [0xAA] [len] [cmd=VOICE_START] [seq] [session_id 4B] [xor_crc]
// (2+1+4+1 = 8 bytes total)
```

通过 UART TX (GPIO50) 发出。

---

## 第四层：正常与异常路径

### 正常路径

手机构造帧 → BLE Write 成功 → WQ7036AX 解包 → 路由判断正确 → UART 发送成功 → V881 处理 → UART 响应返回 → WQ7036AX 打包 → BLE Notify 成功 → 手机收到

### 异常路径

| 问题 | 现象 | 根因 | 处理 |
|------|------|------|------|
| BLE Write 失败 | 指令无响应 | 蓝牙断连或连接间隔超时 | 重试或重新连接 |
| UART 发送超时 | V881 无响应 | V881 未开机或 UART 配置错误 | 超时重试，上报错误 |
| WQ Protocol 解析失败 | 无效帧 | 帧格式错误或 CRC 校验失败 | 丢弃帧，记录日志 |
| 路由错误 | 命令执行错位 | service_type 判断错误 | 检查路由表配置 |
| 响应超时 | 手机等待超时 | V881 处理时间过长 | 设置超时阈值，超时上报 |
| 帧序列号乱序 | 手机收到重复或丢失帧 | BLE 丢包或重传 | 序列号去重机制 |

---

## 第五层：调试方法

### 1. BLE 层调试

使用 nRF Connect 手机 APP：
- 扫描确认眼镜广播
- 连接后查看 GATT Service 列表
- 直接向 C1 Characteristic 写入测试数据
- 观察 C2 Characteristic 的 Notify 是否正常返回

### 2. UART 层调试

使用串口工具（如 Putty、minicom）监听 WQ7036AX 的 UART TX 引脚：
- 确认发送的帧格式正确（0xAA 开头）
- 确认波特率匹配（1Mbps）
- 观察 V881 是否回复 ACK

### 3. 日志追踪

在 `ota_transport_ble.c` 和 `app_uart_cmd.c` 的以下位置添加日志：
- `write_callback` 入口：打印收到的数据长度和内容
- 路由判断后：打印路由结果（本地/转发）
- `uart_cmd_send` 前后：打印发送的 UART 帧

### 4. 延迟分析

在关键节点添加时间戳打印：
- BLE Write 收到时刻
- UART CMD 发出时刻
- UART 响应收到时刻
- BLE Notify 发出时刻

---

## 第六层：实战练习

### 练习 1：追踪一条指令的完整代码路径

在 SDK 中，从 `ota_transport_ble.c` 的 `write_callback` 开始，跟踪到 `app_uart_cmd.c` 的 UART 发送函数，画出完整的函数调用链。

### 练习 2：分析"拍照"指令的数据流

假设手机发送"TAKE_PHOTO"指令，payload 包含拍照参数（分辨率、曝光时间）。请画出 WQ Protocol 帧结构，说明它应该转发还是本地执行，并写出 UART CMD 帧的格式。

### 练习 3：模拟 BLE 丢包恢复

在 `ota_transport_ble.c` 中找到序列号（seq_number）的处理逻辑，说明如果 BLE 丢包导致序列号不连续，WQ7036AX 会如何处理。如果当前代码没有处理，请设计一个去重方案。

### 练习 4：阅读真实源代码

打开 `wq-adk/examples/glass/acore/app/app_customer_ext_trans/app_uart_cmd.c`，找到其中的 `uart_cmd_send` 函数，分析它如何构造 UART 帧（帧头、长度、命令字、校验）。写出 UART CMD 帧的完整结构定义。

---

## 自测与验收

1. 手机指令到 V881 经过哪几个阶段？请按顺序写出。
2. `SERVICE_TYPE_CONTROL` 和 `SERVICE_TYPE_TRANS_UP` 分别对应什么路由？
3. 一条"开始录制"指令，从手机发出到收到响应，总延迟大约多少？
4. 在 SDK 中，`write_callback` 函数在哪个文件中？
5. UART CMD 帧的起始标志是什么？帧结构包含哪些字段？
6. 如果 V881 长时间无响应，WQ7036AX 应该怎么做？
7. BLE Notify 和 BLE Write 有什么区别？
8. 为什么音频上行数据不需要转发给 V881？
9. 如何确认 UART 通信是否正常？
10. 序列号（seq_number）的作用是什么？

---

## 延伸阅读

- [[reglasses-cross-chip-reGlasses跨芯片转发]] — 命令路由表
- [[wq-audio-protocol-WQ-Audio-Protocol]] — BLE 侧的帧格式
- [[STTP 协议]] — UART 侧的帧格式
- [[ble-gatt-BLE-GATT]] — BLE 传输层
- [[reglasses-ext-commands-reGlasses扩展命令集]] — 所有命令定义
- [[帧协议对比：STTP vs WQ Protocol]] — 两种帧的差异
- [[ext-trans-Ext-Trans框架]] — UART 通过 Ext Trans 框架集成

#flashcard
问：一条"开始录制"指令从手机到 V881 经过哪几个阶段？
答：① 手机打包 WQ Protocol 帧 ② BLE Write 发送 ③ WQ7036AX 解包+路由 ④ 重新打包 UART CMD 帧 ⑤ UART 发送到 V881。响应沿原路返回。

问：WQ7036AX 收到 CTRL_RECORD_START 后是本地执行还是转发 V881？为什么？
答：转发 V881。因为摄像头硬件连接在 V881 上，WQ7036AX 没有摄像头驱动，必须让 V881 来启动录制。

问：在 SDK 中指令路由的代码在哪个文件？
答：`ota_transport_ble.c` 中的 `write_callback` 函数，以及 `app_uart_cmd.c` 中的 UART 命令发送函数。

问：手机指令到 V881 的完整端到端延迟大约多少？
答：约 100-250ms，主要瓶颈在 V881 处理（如语音识别 50-500ms）。

问：SERVICE_TYPE_TRANS_UP 类型的帧需要转发给 V881 吗？
答：不需要。TRANS_UP 是音频上行数据，由 WQ7036AX 本地处理，不转发。