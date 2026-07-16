---
type: concept
created: 2026-07-16
tags: [protocol, ble, gatt, uuid, reglasses, service]
aliases: [reGlasses GATT, 自定义 GATT Service]
---

# BLE GATT Service

## 是什么

GATT Service 是 [[BLE GATT]] 中的**服务容器**，包含一组功能相关的 Characteristic。每个 Service 有唯一的 UUID。reGlasses 需要定义自定义 Service 来承载控制、音频、IMU 等业务。

## reGlasses Service 定义

```
Service: reGlasses Main Service
  UUID (128-bit): 454C4753-5245-474C-4153-534553000001
  Type: Primary Service
```

> 此 UUID 为建议值，正式使用前确认不与已有 UUID 冲突。
> SDK 内置 OTA Service 使用 `0x7033`。

## 7 个 Characteristic

| # | 名称 | UUID 后缀 | 属性 | 最大长度 | 用途 |
|---|------|----------|------|----------|------|
| C1 | **Device Control** | `...0002` | Write, Write Without Resp | 244B | 手机→眼镜：控制指令 |
| C2 | **Device Status** | `...0003` | Read, Notify | 64B | 眼镜→手机：状态上报 |
| C3 | **Audio Stream** | `...0004` | Notify | 244B | 眼镜→手机：Opus 音频流 |
| C4 | **IMU Data** | `...0005` | Notify | 244B | 眼镜→手机：IMU 数据流 |
| C5 | **OTA Data RX** | `...0006` | Write Without Resp | 244B | 手机→眼镜：OTA 固件 |
| C6 | **OTA Data TX** | `...0007` | Notify | 244B | 眼镜→手机：OTA 进度 |
| C7 | **Config Params** | `...0008` | Read, Write | 128B | 双向：配置参数 |

完整 UUID：`454C4753-5245-474C-4153-53455300000X`

## 数据流向图

```
手机 APP ──Write──→ C1 (Device Control) ──→ WQ7036AX 解析
                                                   ↓
                                            ┌──────┴──────┐
                                            │ 本地执行      │ 转发 V881
                                            │ (音频/LED)   │ (录制/拍照)
                                            └──────┬──────┘
                                                   ↓
手机 APP ←─Notify── C2 (Device Status) ←── 执行结果
手机 APP ←─Notify── C3 (Audio Stream) ←── Opus 压缩帧
手机 APP ←─Notify── C4 (IMU Data) ←────── IMU 采样
手机 APP ──Write──→ C5 (OTA RX) ─────────→ OTA 数据块
手机 APP ←─Notify── C6 (OTA TX) ←───────── OTA 进度
手机 APP ──Write──→ C7 (Config) ──────────→ 参数写入
手机 APP ←─Read──── C7 (Config) ←───────── 参数读取
```

## C3 Audio Stream 细节

- 编码：Opus (16kHz, 20ms 帧)
- 码率：16-32 kbps (BLE 带宽自适应)
- 每包：~200B payload (244B MTU - 帧头)
- 帧格式：[[WQ Audio Protocol]] TRANS_UP 帧

## C4 IMU Data 细节

```c
typedef struct {
    uint32_t timestamp_us;  // 微秒时间戳
    int16_t  accel_x, accel_y, accel_z;   // 加速度 (0.001g)
    int16_t  gyro_x, gyro_y, gyro_z;      // 角速度 (0.01°/s)
} imu_sample_t;  // 16 bytes/sample

// 每包最多 14 个采样 (14×16+2 = 226B < 244B)
```

| 参数 | 值 |
|------|------|
| 原始采样率 | 1000Hz (V881 IMU) |
| BLE 上报率 | 100-250Hz (降采样) |
| 带宽占用 | ~32 kbps |

## C7 Config 参数 ID

| ID | 参数 | 类型 |
|----|------|------|
| 0x01 | BLE 广播间隔 | uint16_t (ms) |
| 0x02 | BLE 连接间隔 | uint16_t (ms) |
| 0x10 | 音频编码格式 | uint8_t |
| 0x11 | 采样率 | uint32_t |
| 0x20 | IMU 上报频率 | uint16_t (Hz) |
| 0x30 | 设备名 | string (max 20) |
| 0x40 | WiFi SSID | string |
| 0x41 | WiFi 密码 | string |
| 0x50 | 固件版本 | string (Read only) |

## SDK 参考

`ota_transport_ble.c` → `ble_init()` 已实现完整的 GATT Service 注册流程：
- 注册 Service (UUID=0x7033)
- 注册 RX Characteristic (Write Without Resp)
- 注册 TX Characteristic (Notify)
- 注册连接回调

## 关联概念

- [[BLE GATT]] — GATT 协议基础
- [[BLE GAP 广播]] — 广播中通告 Service UUID
- [[WQ Audio Protocol]] — C3 Audio Stream 的帧封装
- [[reGlasses 扩展命令集]] — C1 Device Control 的命令定义
- [[reGlasses 跨芯片指令转发]] — C1 写入后如何转发给 V881
- [[Snippet - BLE GATT Service 注册模板]] — 代码模板

#flashcard
问：reGlasses 自定义了几个 GATT Characteristic？
答：7 个：Device Control (Write)、Device Status (Notify)、Audio Stream (Notify)、IMU Data (Notify)、OTA RX (Write)、OTA TX (Notify)、Config Params (Read/Write)

问：C4 IMU Data 每包最多能放多少个采样？
答：14 个。每个采样 16 字节，14×16+2(包头) = 226B < 244B (MTU-3)
