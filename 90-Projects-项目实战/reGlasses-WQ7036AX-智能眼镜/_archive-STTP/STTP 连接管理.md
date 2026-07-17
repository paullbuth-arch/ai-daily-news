---
type: concept
created: 2026-07-16
tags: [protocol, sttp, connection, state-machine, deprecated]
aliases: [STTP 连接, STTP 握手]
---

# STTP 连接管理

> ⚠️ **已弃用**：STTP 因项目只需要传语音指令，其三次握手连接和 100ms 超时重传机制过于复杂，已被更轻量的 [[uart-basics-UART基础 (app_uart_cmd)]] 替代。当前协议使用心跳检测（3 秒超时）代替三次握手。本笔记保留作为历史参考。

## 是什么

[[STTP 协议]] 的连接生命周期管理，类似 TCP 的三次握手和四次挥手，但更简化。

## 连接建立（三次握手）

```
Client (WQ7036AX)                      Server (V881)
     │                                       │
     │──── SYN (syn=1, seqNum=N) ───────────→│
     │                                       │
     │←─── SYN+ACK (syn=1, ack=1, ──────────│
     │     seqNum=M, ackNum=N+1)             │
     │                                       │
     │──── ACK (ack=1, ackNum=M+1) ─────────→│
     │         [连接建立]                      │
```

## 数据传输

```
     │──── DATA (obt=1, seqNum=K, ──────────→│
     │     chn=X, payload)                   │
     │                                       │
     │←─── ACK (ack=1, ackNum=K+1) ─────────│
```

- `obt=1`：请求对方 ACK
- `seqNum` 每次发送 +1 (mod 16)
- `ackNum` = 对方的 seqNum + 1

## 连接断开

```
     │──── FIN (fin=1) ──────────────────────→│
     │         [连接断开]                      │
```

## 超时重传

```
     │──── DATA (obt=1, seqNum=K) ──────────→│
     │      [等待 ACK ... 100ms]              │
     │      [超时! 重传]                       │
     │──── DATA (obt=1, seqNum=K) ──────────→│  ← 相同 seqNum
     │                                       │
     │←─── ACK (ack=1, ackNum=K+1) ─────────│
```

| 参数 | 值 |
|------|------|
| 超时 | 100ms (`STTP_TIMEOUT_NS = 100000000`) |
| seqNum 范围 | 0-15，`NEXT_NUM(x) = (x+1) % 16` |

## 状态机

```
INITIALIZED ──[STTP_Connect]──→ CONNECTING ──[SYN+ACK]──→ CONNECTED
    ↑                                │                       │
    └──────[STTP_Disconnect]─────────┴───────────────────────┘
                                                            │
                                                    [FIN received]
                                                            ↓
                                                       DISCONNECTED
```

## SDK 代码入口

```c
STTP_Connect()    → 发送 SYN 帧
STTP_Disconnect() → 发送 FIN 帧
STTP_Process()    → 主循环中调用，处理超时重传和接收解析
```

## 关联概念

- [[STTP 协议]] — 所属协议总览
- [[STTP 帧格式]] — SYN/ACK/FIN 帧的标志位组合
- [[STTP 通道分配]] — 连接建立后可使用的通道

#flashcard
问：STTP 三次握手的三个步骤分别是什么？
答：①Client 发 SYN(syn=1) ②Server 回 SYN+ACK(syn=1,ack=1) ③Client 发 ACK(ack=1)

问：STTP 重传时 seqNum 会变化吗？
答：不会。重传使用相同的 seqNum，只有收到 ACK 后 seqNum 才会 +1。
