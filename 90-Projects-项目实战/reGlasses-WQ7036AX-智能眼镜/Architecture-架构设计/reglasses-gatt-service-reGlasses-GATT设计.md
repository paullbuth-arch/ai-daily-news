---
type: project
created: 2026-07-16
tags: [project, reglasses, gatt, service, design]
aliases: [GATT 设计, Service 设计]
---

# reGlasses GATT Service 设计

## 30 秒先看懂

reGlasses 通过 BLE GATT 和手机通信，需要定义手机和眼镜之间交换数据的"接口规范"。就像 USB 协议定义了设备类型和端点，GATT Service 定义了手机 app 和眼镜之间的所有数据通道——控制指令、状态通知、音频流、IMU 数据、OTA 升级和配置参数。初学者先记住：reGlasses 定义了一个主 Service（UUID 以 0001 结尾），包含 7 个 Characteristic，分别负责控制、状态、音频、IMU、OTA 和配置。

## 学完以后应该能做什么

1. 能说出 reGlasses GATT Service 的 7 个 Characteristic 的名称和用途。
2. 能解释为什么 C1 用 Write + WriteNoResp 而 C3 用 Notify。
3. 能画出手机到眼镜的数据流方向图。
4. 能在 SDK 中找到 `ota_transport_ble.c` 的 Service 注册参考实现。

## 前置知识

- 理解 BLE GATT 的基本概念（Service、Characteristic、UUID、Notify/Write/Read）；可先看 [[ble-gatt-BLE-GATT]]。
- 知道 WQ Audio Protocol 的帧格式；可先看 [[wq-audio-protocol-WQ-Audio-Protocol]]。
- 了解 reGlasses 的扩展命令集；可先看 [[reglasses-ext-commands-reGlasses扩展命令集]]。

## 术语先讲清楚

| 术语 | 英文 | 在 GATT 设计中具体指什么 |
|---|---|---|
| 服务 | Service | 一组相关功能的集合，由一个 UUID 唯一标识。reGlasses 有 1 个主 Service |
| 特征 | Characteristic | Service 中的一个具体数据通道，有属性（Read/Write/Notify）和 UUID |
| 通知 | Notify | 设备主动向手机推送数据，不需要手机确认。适合音频流、IMU 数据等实时数据 |
| 写入 | Write | 手机向设备写入数据，需要设备确认。适合重要指令如录制、拍照 |
| 无响应写入 | WriteNoResp | 手机向设备写入数据，不需要设备确认。适合高频低价值指令如音量调节 |
| CCCD | Client Characteristic Configuration Descriptor | 手机端使能 Notify 的开关，必须配置才能收到通知 |

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

## 练习

### 练习一：设计新的 Characteristic

假设需要新增一个 Characteristic 用于传输 TOF 深度数据，应该用什么属性？Notify 还是 Write？为什么？

**通过标准**：能根据数据类型（实时流 vs 控制指令）选择正确的属性。

### 练习二：分析设计决策

解释为什么 C3（Audio Stream）和 C4（IMU Data）都使用 Notify 而不是 Indicate，如果使用 Indicate 会有什么问题？

**通过标准**：能说出 Notify 和 Indicate 在延迟和可靠性上的取舍。

## 自测题

1. **reGlasses GATT Service 有几个 Characteristic？**
   - 7 个：C1 Device Control、C2 Device Status、C3 Audio Stream、C4 IMU Data、C5 OTA Data RX、C6 OTA Data TX、C7 Config Params。

2. **为什么 C1 同时支持 Write 和 WriteNoResp？**
   - Write 用于需要确认的重要指令（录制、拍照），WriteNoResp 用于高频低价值指令（音量调节）。

3. **为什么音频流使用 Notify 而不是 Indicate？**
   - Notify 不需要手机回复 ACK，延迟更低，适合实时音频流。偶尔丢帧可以接受。

## 关联概念

- [[ble-gatt-service-BLE-GATT-Service]] — 详细 Characteristic 定义
- [[ble-gatt-BLE-GATT]] — GATT 基础概念
- [[reglasses-ext-commands-reGlasses扩展命令集]] — C1 接收的命令定义
- [[snippet-ble-gatt-BLE-GATT注册模板]] — 代码模板