---
type: concept
created: 2026-07-16
tags: [protocol, wq-protocol, service, command]
aliases: [WQ 服务类型, WQ 命令列表]
---

# WQ Protocol 服务类型

## 是什么

[[WQ Audio Protocol]] 中 `service_type` 字段定义的所有服务及其命令 ID。分为 SDK 内置和 reGlasses 新增两部分。

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

详见 [[reGlasses 扩展命令集]]：

| Service | 值 | 命令数 |
|---------|---|--------|
| CONTROL (0x04) | 录制/拍照/切镜头/TOF/语音/状态查询 | 14 |
| CONFIG (0x05) | 配置读写/WiFi 配网 | 6 |
| TELEMETRY (0x06) | 定期遥测 + 告警 | 2 |
| IMU (0x07) | IMU 数据流 | 5 |

## 关联概念

- [[WQ Audio Protocol]] — 帧协议总览
- [[WQ Protocol 帧结构]] — 帧头中 service_type 字段的位置
- [[reGlasses 扩展命令集]] — 新增命令的 payload 结构体定义
- [[reGlasses 跨芯片指令转发]] — 命令如何路由到本地或 V881

#flashcard
问：WQ Protocol 的命令 ID 编码规则是什么？
答：0x00-0x7F 为请求类（REQ/IND），0x80-0xFF 为响应类（RSP/ACK），响应 ID = 请求 ID + 0x80。

问：SDK 内置了几个 Service？分别是？
答：4 个：UTILS(0x00)、TRANS_DOWN(0x01)、TRANS_UP(0x02)、RECORD(0x03)
