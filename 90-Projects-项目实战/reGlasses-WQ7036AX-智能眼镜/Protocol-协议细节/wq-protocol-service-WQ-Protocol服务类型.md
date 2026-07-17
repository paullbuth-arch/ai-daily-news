---
type: concept
created: 2026-07-16
tags: [protocol, wq-protocol, service, command]
aliases: [WQ 服务类型, WQ 命令列表]
---

# WQ Protocol 服务类型

## 30 秒先看懂

本文列出 WQ Audio Protocol 中所有服务类型和命令 ID 的完整清单，分为 SDK 内置的 4 类和 reGlasses 新增的 4 类，适合开发时查阅。命令 ID 的编码规则是：0x00-0x7F 为请求类（REQ/IND），0x80-0xFF 为响应类（RSP/ACK），响应 ID = 请求 ID + 0x80。初学者先记住：SDK 内置 4 类（UTILS、TRANS_DOWN、TRANS_UP、RECORD），reGlasses 新增 4 类（CONTROL、CONFIG、TELEMETRY、IMU）。

## 学完以后应该能做什么

1. 能说出 SDK 内置 4 类 Service 的编号和用途。
2. 能说出 reGlasses 新增 4 类 Service 的编号和用途。
3. 能解释命令 ID 编码规则。
4. 能在开发时快速查阅命令 ID 并构造正确的帧。

## 前置知识

- 理解 WQ Audio Protocol 的基本帧格式；可先看 [[wq-audio-protocol-WQ-Audio-Protocol]]。
- 了解 reGlasses 的扩展命令集；可先看 [[reglasses-ext-commands-reGlasses扩展命令集]]。
- 知道 reGlasses 的跨芯片转发机制；可先看 [[reglasses-cross-chip-reGlasses跨芯片转发]]。

## 术语先讲清楚

| 术语 | 英文 | 在服务类型中具体指什么 |
|---|---|---|
| 服务类型 | service_type | 帧头中的字段，标识命令属于哪个服务类别。SDK 内置 4 类（0x00-0x03），reGlasses 新增 4 类（0x04-0x07） |
| 命令 ID | command_id | 每个服务类型下的具体命令编号。0x00-0x7F 为请求，0x80-0xFF 为响应 |
| 帧类型 | frame_type | 标识帧的角色：REQ（请求）、RSP（响应）、IND（通知）、ACK（确认） |

## 是什么

[[wq-audio-protocol-WQ-Audio-Protocol 中 `service_type` 字段定义的所有服务及其命令 ID]]。分为 SDK 内置和 reGlasses 新增两部分。

## SDK 内置 Service

### UTILS (0x00) — 工具类

| 命令 | ID | 方向 | 帧类型 |
|------|----|------|--------|
| PROTO_UTILS_GET_REQ | 0x00 | → | REQ |
| PROTO_UTILS_GET_RSP | 0x80 | ← | RSP |

### TRANS_DOWN (0x01) — 音频下行 (眼镜→手机)

| 命令 | ID | 方向 | 帧类型 |
|------|----|------|--------|
| START_REQ | 0x01 | → | REQ |
| START_RSP | 0x81 | ← | RSP |
| STOP_REQ | 0x02 | → | REQ |
| STOP_RSP | 0x82 | ← | RSP |
| DATA_REQ | 0x10 | ← | REQ |
| DATA_ACK | 0x90 | ← | ACK |

### TRANS_UP (0x02) — 音频上行 (手机→眼镜)

| 命令 | ID | 方向 | 帧类型 |
|------|----|------|--------|
| STOP_REQ | 0x00 | → | REQ |
| STOP_RSP | 0x80 | ← | RSP |
| START_REQ | 0x01 | → | REQ |
| START_RSP | 0x81 | ← | RSP |

### RECORD (0x03) — 录制控制

| 命令 | ID | 方向 | 帧类型 |
|------|----|------|--------|
| STOP_REQ | 0x00 | → | REQ |
| STOP_RSP | 0x80 | ← | RSP |
| START_REQ | 0x01 | → | REQ |
| START_RSP | 0x81 | ← | RSP |

## 命令 ID 编码规则

- `0x00-0x7F`：请求类 (REQ/IND)
- `0x80-0xFF`：响应类 (RSP/ACK) = 请求 ID + 0x80

## reGlasses 新增 Service

详见 [[reglasses-ext-commands-reGlasses扩展命令集：]]

| Service | 值 | 命令数 |
|---------|---|--------|
| CONTROL (0x04) | 录制/拍照/切镜头/TOF/语音/状态查询 | 14 |
| CONFIG (0x05) | 配置读写/WiFi 配网 | 6 |
| TELEMETRY (0x06) | 定期遥测 + 告警 | 2 |
| IMU (0x07) | IMU 数据流 | 5 |

## 练习

### 练习一：查找命令 ID

已知需要发送"配置 WiFi"命令，请问它属于哪个 Service？command_id 范围是什么？请求和响应的 ID 分别是什么？

**通过标准**：能根据命令功能找到对应的 Service 和命令 ID。

### 练习二：验证编码规则

给定以下 REQ 的 command_id，写出对应的 RSP 的 command_id：
- 0x01 → ?
- 0x10 → ?
- 0x06 → ?

**通过标准**：能正确应用 RSP_ID = REQ_ID + 0x80 的规则。

## 自测题

1. **WQ Protocol 的命令 ID 编码规则是什么？**
   - 0x00-0x7F 为请求类（REQ/IND），0x80-0xFF 为响应类（RSP/ACK），响应 ID = 请求 ID + 0x80。

2. **SDK 内置了几个 Service？分别是？**
   - 4 个：UTILS(0x00)、TRANS_DOWN(0x01)、TRANS_UP(0x02)、RECORD(0x03)。

3. **reGlasses 新增了几个 Service？分别是？**
   - 4 个：CONTROL(0x04)、CONFIG(0x05)、TELEMETRY(0x06)、IMU(0x07)。

## 关联概念

- [[wq-audio-protocol-WQ-Audio-Protocol]] — 帧协议总览
- [[wq-protocol-frame-WQ-Protocol帧结构]] — 帧头中 service_type 字段的位置
- [[reglasses-ext-commands-reGlasses扩展命令集]] — 新增命令的 payload 结构体定义
- [[reglasses-cross-chip-reGlasses跨芯片转发]] — 命令如何路由到本地或 V881

#flashcard
问：WQ Protocol 的命令 ID 编码规则是什么？
答：0x00-0x7F 为请求类（REQ/IND），0x80-0xFF 为响应类（RSP/ACK），响应 ID = 请求 ID + 0x80。

问：SDK 内置了几个 Service？分别是？
答：4 个：UTILS(0x00)、TRANS_DOWN(0x01)、TRANS_UP(0x02)、RECORD(0x03)