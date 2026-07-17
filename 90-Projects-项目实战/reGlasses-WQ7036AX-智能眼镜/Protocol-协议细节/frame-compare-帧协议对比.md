---
type: concept
created: 2026-07-16
tags: [comparison, uart-cmd, wq-protocol, frame, 对比, 帧协议]
aliases: [帧协议对比]
---

# 帧协议对比：UART 命令协议 vs WQ Protocol

## 为什么要对比

reGlasses 有两套帧协议：[[uart-basics-UART基础 (app_uart_cmd)]] 跑在 UART 上 (WQ7036AX↔V881)，[[wq-audio-protocol-WQ-Audio-Protocol]] 跑在 BLE GATT 上 (WQ7036AX↔手机)。它们都在做"数据打包"这件事，但设计思路完全不同。

## 对比表

| 维度 | [[uart-basics-UART基础 (当前)]] | [[wq-audio-protocol-WQ-Audio-Protocol]] |
|------|--------|--------|
| **同步字** | **0xAA** (帧头) | **0x5751** ("WQ", 帧头) |
| **帧头大小** | **4 字节** (sync+len+cmd+seq) | **11 字节** (7B frame + 4B msg) |
| **序列号** | **8-bit (0-255)** 自增 | 8-bit (0-255) |
| **校验** | **XOR** (全部字节异或) | checksum (字节累加) |
| **最大载荷** | **247 字节** | 233 字节 (BLE MTU-3-帧头) |
| **命令体系** | **5 种固定命令** (VOICE_START/RESULT/PARTIAL/CANCEL/HEARTBEAT) | **service_type + command_id** (可扩展) |
| **帧类型** | 无 (靠 cmd 区分) | **REQ/RSP/IND/ACK** |
| **运行位置** | UART (WQ↔V881) | BLE GATT (WQ↔手机) |
| **连接管理** | **心跳检测 (3s 超时)** | 无 (依赖 BLE 连接) |
| **ACK 超时** | **200ms, 最多重试 5 次** | 500ms (BLE 延迟大) |
| **去重** | **2 秒窗口 (cmd+seq)** | 无 |
| **代码量** | **~350 行** | ~600 行 (SDK 内置) |

> ⚠️ 旧的 [[STTP 协议]] 已被 UART 命令协议替代。STTP 的 256 通道、连接握手等机制对这个项目来说过于复杂。

## 帧格式对比图

```
UART 命令协议 (当前, UART):
┌──────┬──────┬──────┬──────┬─────────────┬──────────┐
│ 0xAA │ len  │ cmd  │ seq  │  payload    │ xor_crc  │
│ (1B) │ (1B) │ (1B) │ (1B) │  (0-247B)   │  (1B)    │
└──────┴──────┴──────┴──────┴─────────────┴──────────┘
最小 5 字节 (无 payload), 最大 252 字节

WQ Protocol 帧 (BLE):
┌───────────────────┬──────────────────┬──────────────────┐
│   Frame Header    │  Message Header  │    Payload       │
│   (7B, 含0x5751)  │  (4B, 含命令ID)  │   (变长)          │
└───────────────────┴──────────────────┴──────────────────┘
最小 11 字节 (无 payload)
```

## 设计差异的原因

### 为什么 UART 命令协议用 0xAA 开头？

UART 是**字节流**，没有"包"的概念。接收方需要一个明确的标记知道"帧从哪里开始"。`0xAA` (10101010) 是一个交替 bit 模式，在随机数据中很少出现，适合作为同步字。

WQ Protocol 也用同步字 (0x5751)，原因相同——但 BLE GATT 自带长度，所以 0x5751 更多是做**校验**而非定位。

### 为什么 UART 命令协议只有 5 种命令？

它面向 **V881 主控**，当前只需要传语音 ASR 相关的指令。不需要通用框架，5 种命令覆盖所有场景。简单 = 少 bug。

WQ Protocol 面向**手机 APP**——APP 需要发各种指令 (录制/拍照/配网/查询状态)，需要 `service_type + command_id` 提供可扩展的命令分类。

### 为什么 UART 命令协议有去重但 WQ Protocol 没有？

UART 命令协议的重传机制 (200ms × 5 次) 可能导致接收方收到重复帧。去重 (2 秒窗口) 防止 VOICE_START 被重复执行。

WQ Protocol 通过 BLE GATT 传输，BLE 链路层本身就有 ACK，应用层不需要额外去重。

## 它们如何协作

在 [[reglasses-cross-chip-reGlasses跨芯片转发 中]]，两条协议串联工作：

```
手机 APP
  │ WQ Protocol 帧 (BLE GATT)
  ↓
WQ7036AX: wq_proto_pkt_unpack() 解析
  │ 取出 service_type + command_id + payload
  │ 重新打包为 UART CMD 帧
  ↓
UART CMD 帧 (app_uart_cmd)
  │
  ↓
V881: 解包处理
```

## 与旧 STTP 的演进

```
STTP (已弃用)                    UART 命令协议 (当前)
─────────────                   ─────────────────
通用透传 (256 通道)        →     专用命令 (5 种)
CRC16 校验                 →     XOR 校验 (更简单)
三次握手建连               →     心跳检测 (更轻量)
~600 行代码                →     ~350 行代码
```

## 关联概念

- [[uart-basics-UART基础]] — UART 上的帧协议 (当前使用)
- [[wq-audio-protocol-WQ-Audio-Protocol]] — BLE 上的帧协议
- [[STTP 协议]] — UART 上的旧帧协议 (已弃用)
- [[reglasses-cross-chip-reGlasses跨芯片转发]] — 两种协议如何串联

#flashcard
问：UART 命令协议和 WQ Protocol 的帧头大小分别是多少？
答：UART 命令协议 4 字节 (0xAA + len + cmd + seq)，WQ Protocol 11 字节 (7B frame_header + 4B msg_header)。

问：为什么 UART 命令协议只有 5 种命令而 WQ Protocol 有完整的命令体系？
答：UART 命令协议面向 V881，当前只需要传 ASR 语音指令，5 种命令够用。WQ Protocol 面向手机 APP，需要处理录制/拍照/配网/查询等各种指令，需要可扩展的 service_type + command_id 体系。
