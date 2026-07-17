---
type: snippet
created: 2026-07-16
tags: [snippet, wq-protocol, frame, pack, unpack]
aliases: [WQ 帧模板, 打包解包代码]
---

# Snippet - WQ Protocol 帧打包解包

本代码片段展示了如何在 WQ7036AX SDK 中打包和解包 WQ Audio Protocol 帧，包括帧构造（`wq_proto_pkt_pack`）、帧解析（`wq_proto_pkt_unpack`）、响应发送和基于 service_type 的消息分发。在 reGlasses 项目中，这段代码用于处理手机和眼镜之间的所有 BLE 数据通信。SDK 参考路径：`apps/common/wq_protocol/inc/wq_protocol.h`、`wq-adk/components/apps/acore/src/app_trans.c`。

> 参考 `apps/common/wq_protocol/inc/wq_protocol.h`。

## 打包 (发送方)

```c
#include "wq_protocol.h"

// 打包一个控制指令帧
static uint8_t pkt_buf[256];

void send_record_start(uint8_t camera_mask, uint16_t max_duration)
{
    // 构造 payload
    ctrl_record_start_req_t payload = {
        .camera_mask    = camera_mask,
        .max_duration_s = max_duration,
        .audio_enable   = 1,
    };

    // 打包帧
    wq_proto_pkt_t pkt;
    bool ok = wq_proto_pkt_pack(
        &pkt,
        SERVICE_TYPE_CONTROL,       // service_type
        CTRL_RECORD_START_REQ,      // command_id
        FRAME_TYPE_REQ,             // frame_type
        g_seq_number++,             // seq_number (全局递增)
        1,                          // need_ack = true
        (uint8_t *)&payload,        // data
        sizeof(payload)             // len
    );

    if (ok) {
        uint16_t pkt_size = wq_proto_get_pkt_size(&pkt);
        // 通过 BLE GATT Notify 或 STTP 发送
        // ble_send(pkt_buf, pkt_size);
        // sttp_send(pkt_buf, pkt_size);
    }
}
```

## 解包 (接收方)

```c
// 从 BLE Write 回调或 STTP 接收回调中解包
void handle_received_data(const uint8_t *data, uint16_t len)
{
    wq_proto_pkt_t pkt;

    if (!wq_proto_pkt_unpack(&pkt, data, len)) {
        LOGE("Invalid WQ Protocol frame\n");
        return;
    }

    // 检查 sync_word
    // (wq_proto_pkt_unpack 内部已检查 0x5751)

    // 根据 service_type 分发
    switch (pkt.msg_header.service_type) {

    case SERVICE_TYPE_CONTROL:
        handle_control_cmd(&pkt);
        break;

    case SERVICE_TYPE_TRANS_DOWN:
        handle_audio_down(&pkt);
        break;

    case SERVICE_TYPE_CONFIG:
        handle_config_cmd(&pkt);
        break;

    case SERVICE_TYPE_TELEMETRY:
        handle_telemetry(&pkt);
        break;

    case SERVICE_TYPE_IMU:
        handle_imu_data(&pkt);
        break;

    default:
        LOGW("Unknown service_type: 0x%02X\n", pkt.msg_header.service_type);
    }
}

// 控制命令处理
static void handle_control_cmd(wq_proto_pkt_t *pkt)
{
    uint8_t cmd = pkt->msg_header.command_id;
    uint8_t *payload = pkt->payload.data;
    uint16_t len = pkt->msg_header.payload_len;

    switch (cmd) {
    case CTRL_RECORD_START_REQ: {
        ctrl_record_start_req_t *req = (ctrl_record_start_req_t *)payload;
        LOGI("Record start: camera=0x%02X, max_dur=%d\n",
             req->camera_mask, req->max_duration_s);
        // 转发给 V881 或本地执行
        break;
    }
    case CTRL_TAKE_PHOTO_REQ:
        LOGI("Take photo\n");
        break;
    // ... 其他命令
    }

    // 发送 RSP
    send_response(SERVICE_TYPE_CONTROL, cmd + 0x80, pkt->frame_header.seq_number);
}
```

## 发送响应

```c
static uint8_t g_seq_number = 0;

void send_response(uint8_t service_type, uint8_t cmd_id, uint8_t req_seq)
{
    ctrl_cmd_rsp_t rsp = { .result = 0 };  // 成功

    wq_proto_pkt_t pkt;
    wq_proto_pkt_pack(
        &pkt,
        service_type,
        cmd_id,
        FRAME_TYPE_RSP,
        g_seq_number++,
        0,              // RSP 不需要 ACK
        (uint8_t *)&rsp,
        sizeof(rsp)
    );

    uint16_t size = wq_proto_get_pkt_size(&pkt);
    // 发送 pkt_buf...
}
```

## 帧结构体

```c
// wq_protocol.h 中的定义
typedef struct {
    uint16_t sync_word;   // 0x5751
    uint8_t  checksum;
    uint8_t  reserved;
    uint8_t  frame_type : 3;
    uint8_t  need_ack   : 1;
    uint8_t  reserved1  : 4;
    uint8_t  seq_number;
} frame_header_t;  // 7 bytes

typedef struct {
    uint8_t  service_type;
    uint8_t  command_id;
    uint16_t payload_len;
} msg_header_t;  // 4 bytes

typedef struct {
    frame_header_t frame_header;
    msg_header_t   msg_header;
    payload_t      payload;  // data[0] 柔性数组
} wq_proto_pkt_t;
```

## 关联概念

- [[wq-audio-protocol-WQ-Audio-Protocol]] — 帧协议总览
- [[wq-protocol-frame-WQ-Protocol帧结构]] — bit-level 结构
- [[reglasses-ext-commands-reGlasses扩展命令集]] — 新增的 payload 结构体
- [[ble-gatt-service-BLE-GATT-Service]] — 帧通过 GATT 传输
- [[STTP 协议]] — 帧也可通过 STTP 传输
