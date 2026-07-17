---
type: project
created: 2026-07-16
tags: [project, reglasses, gatt, service, design]
aliases: [GATT 设计, Service 设计]
---

# reGlasses GATT Service 设计

## Service UUID

```
Service: reGlasses Main Service
UUID (128-bit): 454C4753-5245-474C-4153-534553000001
```

## Characteristic 总览

| # | 名称 | UUID | 属性 | 数据格式 |
|---|------|------|------|----------|
| C1 | Device Control | ...0002 | Write, WriteNoResp | [[wq-audio-protocol-WQ-Audio-Protocol 帧 |]]
| C2 | Device Status | ...0003 | Read, Notify | status_notify_t |
| C3 | Audio Stream | ...0004 | Notify | WQ TRANS_UP 帧 (Opus) |
| C4 | IMU Data | ...0005 | Notify | imu_data_payload_t |
| C5 | OTA Data RX | ...0006 | WriteNoResp | OTA 固件块 |
| C6 | OTA Data TX | ...0007 | Notify | OTA 进度 |
| C7 | Config Params | ...0008 | Read, Write | TLV (param_id + value) |

## 数据流方向

```
手机 → C1 Write → WQ7036AX 解析 → 本地执行 / 转发 V881
WQ7036AX → C2 Notify → 手机 (状态变化通知)
WQ7036AX → C3 Notify → 手机 (Opus 音频流)
WQ7036AX → C4 Notify → 手机 (IMU 数据流)
手机 → C5 Write → WQ7036AX (OTA 固件数据)
WQ7036AX → C6 Notify → 手机 (OTA 进度)
手机 ↔ C7 Read/Write → WQ7036AX (配置参数)
```

## 设计决策记录

1. **为什么 C1 用 Write + WriteNoResp？**
   - Write 用于需要确认的重要指令 (录制/拍照)
   - WriteNoResp 用于高频低价值指令 (音量调节)

2. **为什么 C3/C4 用 Notify 而非 Indicate？**
   - Notify 不需要 ACK，延迟更低
   - 音频/IMU 是实时流，允许偶尔丢帧

3. **为什么 OTA 单独用 C5/C6 而非复用 C1？**
   - OTA 数据量大，需要 WriteNoResp 高速传输
   - 独立通道避免阻塞控制指令

4. **为什么 Config 用 Read/Write 而非 Notify？**
   - 配置是低频操作，Read/Write 更简单
   - 不需要主动推送

## SDK 参考实现

`ota_transport_ble.c` → `ble_init()` 已有完整 Service 注册流程可参考。

## 关联概念

- [[ble-gatt-service-BLE-GATT-Service]] — 详细 Characteristic 定义
- [[ble-gatt-BLE-GATT]] — GATT 基础概念
- [[reglasses-ext-commands-reGlasses扩展命令集]] — C1 接收的命令定义
- [[snippet-ble-gatt-BLE-GATT注册模板]] — 代码模板
