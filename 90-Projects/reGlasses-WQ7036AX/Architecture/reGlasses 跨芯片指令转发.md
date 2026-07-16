---
type: project
created: 2026-07-16
tags: [project, reglasses, cross-chip, forwarding, 跨芯片, 指令转发]
aliases: [跨芯片转发, 指令路由, 命令路由]
---

# reGlasses 跨芯片指令转发

## 一句话理解

WQ7036AX 是手机和 V881 之间的**翻译官**：手机用 [[WQ Audio Protocol]] 说 BLE 语，V881 用 [[UART 命令协议]] 说 UART 语。WQ7036AX 在中间**听懂 BLE 语 → 翻译成 UART 语 → 传给 V881**。但有些指令不需要翻译——比如语音控制，WQ7036AX 自己就能做。

## 为什么重要

你写的每一个命令处理逻辑，都要先判断：**这件事我自己做，还是交给 V881 做？** 判断错了，要么该录的时候没录（V881 没收到指令），要么不该转的白转了（浪费 UART 带宽）。

## 路由代码入口

在 SDK 中，消息分发逻辑在 `app_trans.c`（`wq-adk/components/apps/acore/`）：

```c
static void wq_app_trans_handle_msg(uint16_t msg_id, const void *param, uint16_t param_len)
{
    switch (msg_id) {
    case APP_CUS_TRANS_MSG_ID_REMOTE_SYNC_DATA:
        // 处理远程同步数据
        break;
    // 你需要在这里加新的 case
    }
}
```

`app_trans_init` 中注册了各类消息的处理器。

## 命令路由表

| 命令 | 谁来做 | UART cmd | 为什么 |
|------|--------|----------|--------|
| **RECORD_START** | **V881** | VOICE_START | 摄像头在 V881 上，WQ 没有 |
| **RECORD_STOP** | **V881** | VOICE_RESULT | 同上 |
| **TAKE_PHOTO** | **V881** | — | 摄像头在 V881 上 |
| **SWITCH_LENS** | **V881** | — | 同上 |
| **TOF_ON/OFF** | **V881** | — | TOF 传感器在 V881 上 |
| **VOICE_ON/OFF** | **WQ 本地** | — | 麦克风在 WQ7036AX 上，WQ 自己做 |
| **STATUS_QUERY** | WQ + V881 | HEARTBEAT | WQ 填本地状态 (电量/BLE)，再问 V881 (WiFi/存储) |
| **CONFIG_WIFI** | **V881** | — | WiFi 在 V881 上 |
| **TRANS_UP_START** | **WQ 本地** | — | 音频上行，WQ 自己采集和编码 |
| **TELEMETRY** | WQ + V881 | — | 合并两端遥测 |
| **IMU_START/DATA** | V881→转发 | — | IMU 在 V881 上，V881 推数据给 WQ |

**判断原则**：硬件在谁身上，谁来做。

## 转发流程代码

```c
// 你在 app_trans.c 里需要写的逻辑
void handle_control_command(wq_proto_pkt_t *pkt)
{
    uint8_t cmd = pkt->msg_header.command_id;

    switch (cmd) {
    case CTRL_RECORD_START_REQ:
    case CTRL_RECORD_STOP_REQ:
    case CTRL_TAKE_PHOTO_REQ:
    case CTRL_TOF_REQ:
        // 这些都要转发给 V881
        forward_to_v881(pkt, UART_CMD_VOICE_START);  // 语音识别
        break;

    case CTRL_VOICE_REQ:
        // 这个 WQ 自己做
        handle_voice_command(pkt);
        break;

    case CTRL_STATUS_QUERY_REQ:
        // 先填本地状态，再问 V881
        handle_status_query(pkt);
        break;
    }
}

void forward_to_v881(wq_proto_pkt_t *pkt, uint8_t cmd)
{
    // 把 WQ Protocol 的 payload 通过 UART 命令协议发出去
    uint8_t *payload = pkt->payload.data;
    uint16_t len = pkt->msg_header.payload_len;
    uart_cmd_send(cmd, payload, len);  // 可靠命令自动有 ACK
}
```

## 时序图：开始录制

```
手机 APP            WQ7036AX              V881
  │                    │                    │
  │─ BLE Write ───────→│                    │
  │  WQ Protocol       │                    │
  │  CTRL_RECORD_START │                    │
  │                    │                    │
  │                    │ 解析:              │
  │                    │ service=CONTROL    │
  │                    │ cmd=RECORD_START   │
  │                    │ → 摄像头不在我身上  │
  │                    │ → 转发!            │
  │                    │                    │
  │                    │── UART CMD ───────→│
  │                    │  VOICE_START       │
  │                    │  session_id=42     │
  │                    │                    │
  │                    │   (V881 启动摄像头   │
  │                    │    + ASR)           │
  │                    │                    │
  │                    │←─ UART CMD ACK ───│
  │                    │  result=0 (成功)    │
  │                    │                    │
  │                    │ 打包 RSP:           │
  │                    │ EVT_RECORD_STARTED  │
  │                    │                    │
  │← BLE Notify ──────│                    │
  │  Device Status     │                    │
```

## 时序图：语音交互（WQ 本地处理）

```
手机 APP            WQ7036AX              V881
  │                    │                    │
  │─ BLE Write ───────→│                    │
  │  CTRL_VOICE(开启)   │                    │
  │                    │ 解析:              │
  │                    │ cmd=VOICE_REQ      │
  │                    │ → 麦克风在我身上    │
  │                    │ → 自己做!          │
  │                    │                    │
  │                    │ (本地启动)          │  (V881 不参与)
  │                    │ PDM 麦采集         │
  │                    │ DSP 降噪           │
  │                    │ Opus 编码          │
  │                    │                    │
  │← BLE Notify ──────│                    │
  │  Audio Stream      │                    │
  │  (Opus 帧)         │                    │
```

## 验收标准

- [ ] 能在 SDK 中找到 `app_trans.c` 并说出消息分发入口
- [ ] 能说出"硬件在谁身上谁来做"的路由原则
- [ ] 能列出至少 3 个需要转发 V881 的命令和 2 个本地处理的命令
- [ ] 能画出"开始录制"的完整时序图 (手机→WQ→V881→WQ→手机)

## 关联概念

- [[reGlasses 协议架构]] — 整体拓扑
- [[UART 命令协议]] — UART 侧帧格式
- [[数据流：手机指令到 V881]] — 完整追踪
- [[帧协议对比：UART 命令协议 vs WQ Protocol]] — 两种帧的差异

#flashcard
问：WQ7036AX 收到 CTRL_RECORD_START 后是本地执行还是转发 V881？
答：转发 V881。因为摄像头硬件连接在 V881 上，WQ7036AX 没有摄像头驱动。

问：CTRL_VOICE_REQ 谁来做？为什么？
答：WQ7036AX 本地做。因为麦克风 (PDM) 直接连在 WQ7036AX 上，音频采集和 Opus 编码都由 WQ7036AX 的 DSP 完成，不需要 V881 参与。
