---
type: concept
created: 2026-07-16
tags: [protocol, sttp, channel, multiplexing, deprecated]
aliases: [STTP 通道, STTP chn]
---

# STTP 通道分配

> ⚠️ **已弃用**：STTP 已被 [[UART 命令协议]] (app_uart_cmd) 替代。当前协议不使用通道机制，而是用 5 种固定命令类型区分业务。

## 是什么

[[STTP 协议]] 的 **chn (channel)** 字段实现**逻辑通道多路复用** — 一条 UART 物理链路承载多种业务数据流。类似 TCP 的端口号概念。

## 工作原理

```
UART 物理链路 (单条 TX/RX)
         │
    ┌────┴────┐
    │ STTP 层 │
    └────┬────┘
         │ chn 分发
    ┌────┼────┬────┬────┬────┬────┐
    ▼    ▼    ▼    ▼    ▼    ▼    ▼
  chn0 chn1 chn2 chn3 chn4 chn5 chn6 ...
  心跳 控制  音频↑ 音频↓ 遥测  配置  IMU
```

- 发送方指定 `chn` → STTP_Send(sttp, chn, data, len, needCheck)
- 接收方注册回调 → STTP_AddReceiver(sttp, chn, callback, usr)
- 最多 256 个通道 (0-255)

## SDK API

```c
// 注册某个通道的接收回调
int32_t STTP_AddReceiver(
    STTP_Obj_t *sttp,
    uint8_t chn,
    int32_t (*recv)(void *usr, const void *data, uint32_t len),
    void *usr
);

// 向某个通道发送数据
int64_t STTP_Send(
    STTP_Obj_t *sttp,
    uint8_t chn,
    void *data,
    uint32_t len,
    uint8_t needCheck   // 1=需要ACK, 0=不需要
);
```

## reGlasses 通道分配方案

| chn | 业务 | 方向 | 需要 ACK | 数据频率 |
|-----|------|------|----------|----------|
| 0 | 心跳/链路管理 | 双向 | 否 | 周期 1s |
| 1 | 控制指令 | 双向 | 是 | 按需 |
| 2 | 音频上行 | WQ→V881 | 否 | 持续流 |
| 3 | 音频下行 | V881→WQ | 否 | 持续流 |
| 4 | 遥测/状态 | V881→WQ | 否 | 周期 10s |
| 5 | 配置参数 | 双向 | 是 | 按需 |
| 6 | IMU 数据 | V881→WQ | 否 | 高频流 |
| 7 | OTA 升级 | 双向 | 是 | 按需 |

### 设计原则

1. **控制类用 ACK**（chn 1/5/7）— 指令不能丢
2. **流数据不用 ACK**（chn 2/3/4/6）— 允许偶尔丢帧，避免阻塞
3. **chn 0 保留**给链路管理

## 与 Ext Trans 的集成

STTP 在 SDK 中通过 [[Ext Trans 框架]] 集成：

```
ext_trans_io_create(UART) → ext_trans_dev_uart_open()
                                ↓
                         STTP_New(CLIENT)
                         STTP_Connect()
                                ↓
                         ext_trans_io_data_send()
                                ↓
                         STTP_Send(chn, ...)
```

## 关联概念

- [[STTP 协议]] — 所属协议总览
- [[STTP 帧格式]] — chn 字段在帧中的位置
- [[Ext Trans 框架]] — STTP 如何通过 SDK 框架集成
- [[reGlasses 跨芯片指令转发]] — 通道在项目中的实际使用

#flashcard
问：STTP 通道号的数据类型和范围是什么？
答：uint8_t，范围 0-255，最多 256 个逻辑通道。

问：为什么音频流通道（chn 2/3）不需要 ACK？
答：音频是实时流数据，允许偶尔丢帧。如果要求 ACK 重传，会导致延迟累积和缓冲区溢出，反而影响音质。
