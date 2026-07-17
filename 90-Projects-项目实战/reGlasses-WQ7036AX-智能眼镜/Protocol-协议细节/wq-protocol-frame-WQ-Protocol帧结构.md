---
type: concept
created: 2026-07-16
tags: [protocol, wq-protocol, frame, struct]
aliases: [WQ 帧结构, 0x5751 帧]
---

# WQ Protocol 帧结构

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
