---
type: concept
created: 2026-07-16
tags: [protocol, wq-protocol, frame, struct]
aliases: [WQ 帧结构, 0x5751 帧]
---

# WQ Protocol 帧结构

## 30 秒先看懂

本文是 WQ Audio Protocol 帧头各字段的 bit 级详细解析，适合需要手动构造或解析帧时查阅。帧结构分为三部分：帧头（7 字节，含同步字 0x5751、校验和、帧类型、序列号）、消息头（4 字节，含服务类型、命令 ID、载荷长度）和载荷（变长）。初学者先记住：WQ Protocol 帧头共 11 字节，校验和覆盖消息头和载荷的累加和，帧类型有 4 种（REQ/RSP/IND/ACK）。

## 学完以后应该能做什么

1. 能画出 WQ Protocol 帧的完整布局，标注每个字段的偏移和长度。
2. 能手动计算 checksum 的值。
3. 能解释 flags 字段中 frame_type 和 need_ack 的位分布。
4. 能说出已有 payload 结构体的字段含义。

## 前置知识

- 理解 WQ Audio Protocol 的基本概念；可先看 [[wq-audio-protocol-WQ-Audio-Protocol]]。
- 会读十六进制和位运算；可先看 [[c-core-C语言核心]]。
- 了解 reGlasses 的扩展命令集；可先看 [[reglasses-ext-commands-reGlasses扩展命令集]]。

## 术语先讲清楚

| 术语 | 英文 | 在帧结构中具体指什么 |
|---|---|---|
| 帧头 | frame_header | 帧的控制信息，7 字节，包含同步字、校验和、保留位、帧类型、需 ACK 标志和序列号 |
| 消息头 | msg_header | 消息的业务信息，4 字节，包含服务类型、命令 ID 和载荷长度 |
| 载荷 | payload | 帧携带的实际数据，变长，根据 service_type + command_id 决定解析方式 |
| 位域 | bit field | C 语言中按位定义的结构体字段，用于紧凑存储 flags 中的多个标志位 |

## 是什么

[[wq-audio-protocol-WQ-Audio-Protocol]] 的 bit-level 帧结构详解。

## 完整帧布局

```
Offset  0    1    2    3    4    5    6    7    8    9   10   11+
      ┌────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬───┐
      │sync_word │chk │rsv │flags   │seq │svc │cmd │ payload_len │
      │ (0x5751) │sum │ 00 │ft|ack|r│num │type│ id │  (LE 16)    │
      └────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴───┘
      |______ Frame Header (7B) ______|___ Message Header (4B) ___|

      ┌──────────────────────────────────────────────────────────┐
      │                     Payload (变长)                        │
      │  根据 service_type + command_id 解析为对应 C 结构体         │
      └──────────────────────────────────────────────────────────┘
```

## flags 字段 (Byte 4)

```
bit:  7  6  5  4  3  2  1  0
     ┌─────────────────────┐
     │ reserved │ack│ frame│
     │  (4 bit) │(1)│type  │
     │          │   │(3bit)│
     └─────────────────────┘
```

| 位域 | 值 | 含义 |
|------|---|------|
| frame_type [2:0] | 1=REQ, 2=RSP, 3=IND, 4=ACK | 帧类型 |
| need_ack [3] | 0/1 | 是否需要对方确认 |
| reserved [7:4] | 0 | 保留 |

## checksum 计算

```c
// 从 msg_header 开始到 payload 结束的字节累加和 (取低 8 位)
uint8_t checksum = 0;
for (int i = 0; i < sizeof(msg_header_t) + payload_len; i++) {
    checksum += data[7 + i];  // 7 = sizeof(frame_header_t)
}
```

## 已有 Payload 结构体

### TRANS_DOWN_START_REQ (0x01)

```c
typedef struct {
    uint8_t  codec_format;   // 0=PCM, 1=Opus, 2=mSBC
    uint32_t sample_rate;    // 16000
    uint8_t  bit_width;      // 16
    uint8_t  frame_duration; // 20ms
    uint8_t  opus_frame_size;
    uint8_t  trans_mode;     // LIVE/1V1/MUSIC/CALL
} trans_down_start_req_t;
```

### TRANS_DOWN_DATA_IND

```c
typedef struct {
    uint16_t sn;             // 包序列号
    uint16_t frame_num   : 5;
    uint16_t codec_type  : 4;
    uint16_t is_last_pkt : 1;
    uint16_t channel     : 2;
    uint16_t reserved    : 4;
    uint8_t  data[0];        // 音频数据
} trans_down_data_ind_t;
```

### TRANS_UP_START_REQ (0x01)

```c
typedef struct {
    uint8_t  codec_format;
    uint32_t sample_rate;
    uint8_t  bit_width;
    uint8_t  frame_duration;
    uint8_t  opus_frame_size;
    uint8_t  mic_mode;
    uint8_t  channel_count;
    uint8_t  trans_mode;
} trans_up_start_req_t;
```

## 练习

### 练习一：手动计算 checksum

给定一个帧的消息头 + 载荷为 `02 01 05 00 01 3C 00 01`（共 8 字节），计算 checksum 的值。

**通过标准**：能正确执行字节累加和取低 8 位的计算过程。

### 练习二：解析 flags 字节

给定 Byte 4 的值为 0x09，请解析出 frame_type 和 need_ack 的值，并判断这是什么类型的帧。

**通过标准**：能把十六进制转为二进制，逐位提取位域的值。

## 自测题

1. **WQ Protocol 的 checksum 覆盖范围是什么？**
   - 从 msg_header 开始到 payload 结束的字节累加和（不含 frame_header），取低 8 位。

2. **frame_type=3 (IND) 和 frame_type=1 (REQ) 的区别？**
   - REQ 是请求-响应模式（需要 RSP），IND 是单向通知（如音频数据流，不需要响应，但可选 ACK）。

3. **flags 字节中 frame_type 占多少位？need_ack 占多少位？**
   - frame_type 占 3 位（bit 2-0），need_ack 占 1 位（bit 3），reserved 占 4 位（bit 7-4）。

## 关联概念

- [[wq-audio-protocol-WQ-Audio-Protocol]] — 帧结构所属的协议总览
- [[wq-protocol-service-WQ-Protocol服务类型]] — 所有 Service/Command 列表
- [[STTP 帧格式]] — 对比：另一种帧格式设计 (4B Header + CRC + 0x5A)
- [[reglasses-ext-commands-reGlasses扩展命令集]] — 新增的 payload 结构体

#flashcard
问：WQ Protocol 的 checksum 覆盖范围是什么？
答：从 msg_header 开始到 payload 结束的字节累加和（不含 frame_header），取低 8 位。

问：frame_type=3 (IND) 和 frame_type=1 (REQ) 的区别？
答：REQ 是请求-响应模式（需要 RSP），IND 是单向通知（如音频数据流，不需要响应，但可选 ACK）。