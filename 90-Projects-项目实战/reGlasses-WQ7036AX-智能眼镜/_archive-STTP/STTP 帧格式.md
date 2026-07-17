---
type: concept
created: 2026-07-16
tags: [protocol, sttp, frame, uart, deprecated]
aliases: [STTP Frame, STTP 帧结构]
---

# STTP 帧格式

> ⚠️ **已弃用**：STTP 已被 [[uart-basics-UART基础 (app_uart_cmd)]] 替代]]。本笔记保留作为历史参考。

## 是什么

[[STTP 协议]] 的数据帧 bit-level 结构定义。理解帧格式是解析和构造 STTP 消息的基础。

## 完整帧布局

```
Bit:  7  6  5  4  3  2  1  0
    ┌────────────────────────┐
  0 │fin syn ack obt crc rsv│  ← op byte (控制标志)
    ├────────────────────────┤
  1 │ seqNum   │  ackNum    │  ← num byte (序列号)
    ├────────────────────────┤
  2 │       chn              │  ← 通道号
    ├────────────────────────┤
  3 │       len              │  ← 载荷长度
    ├────────────────────────┤
4-5 │    Ext16Len (可选)      │  ← 当 len==253
    ├────────────────────────┤
4-7 │    Ext32Len (可选)      │  ← 当 len==254
    ├────────────────────────┤
    │                        │
    │      Payload           │  ← 实际数据
    │                        │
    ├────────────────────────┤
    │    CRC16 (可选)         │  ← 当 crc==1
    ├────────────────────────┤
    │      0x5A              │  ← 结束标志 (固定)
    └────────────────────────┘
```

## SDK 结构体定义

```c
// sttp.c:179-199
union STTP_Header_u {
    struct {
        /* op byte */
        uint8_t fin : 1;    // 连接结束
        uint8_t syn : 1;    // 连接同步
        uint8_t ack : 1;    // 确认
        uint8_t obt : 1;    // 需要对方确认
        uint8_t crc : 1;    // CRC 校验
        uint8_t rsv : 3;    // 保留
        /* num byte */
        uint8_t seqNum : 4; // 发送序列号 (0-15)
        uint8_t ackNum : 4; // 确认序列号 (0-15)
        /* chn byte */
        uint8_t chn;        // 通道号
        /* len byte */
        uint8_t len;        // 载荷长度
    } header;
    uint8_t raw[4];
};
```

## len 字段编码规则

| len 值 | 含义 | 后续字节 |
|--------|------|----------|
| 0-252 | 实际载荷长度 | 无扩展 |
| 253 | 使用 Ext16Len | 2 字节 (uint16_t, 小端) |
| 254 | 使用 Ext32Len | 4 字节 (uint32_t, 小端) |
| 255 | 保留 | — |

## CRC 计算

- 覆盖范围：Header + ExtLen + Payload
- 算法：CRC16 (查表法, `_STTP_CalCrc()`)
- 仅在 `crc==1` 时附加

## 关联概念

- [[STTP 协议]] — 帧格式所属的协议总览
- [[STTP 连接管理]] — SYN/ACK 帧的标志位组合
- [[wq-protocol-frame-WQ-Protocol帧结构]] — 对比：另一种帧格式设计

#flashcard
问：STTP 帧的最小长度是多少字节？
答：6 字节 = 4B Header + 0B Payload + 0B CRC + 1B EndFlag + 1B（实际无 payload 时 len=0，帧 = 4+1 = 5B）

问：STTP 帧的 op byte 中 obt 标志的含义是什么？
答：obt (obtain) = "需要对方确认"，设 obt=1 表示要求接收方回复 ACK
