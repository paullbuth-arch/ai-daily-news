---
type: concept
created: 2026-07-16
tags: [comparison, ble, wifi, wireless, 对比, 无线]
aliases: [无线对比, BLE vs WiFi]
---

# 无线对比：BLE vs WiFi

## 为什么要对比

reGlasses 同时有 BLE ([[wq7036ax-chip-WQ7036AX芯片 负责) 和 WiFi (V881 负责) 两种无线]]。你得知道**什么数据该走 BLE、什么数据该走 WiFi**。

## 核心区别

| 维度 | [[BLE GATT\|BLE 5.4]] | WiFi 6 (V881) |
|------|---------|---------|
| **带宽** | ~1-2 Mbps | **~100-500 Mbps** |
| **功耗** | **极低 (μA~mA)** | 高 (百mA级) |
| **延迟** | 低 (~15ms) | 中 (~10-50ms) |
| **距离** | 10-100m | 50-200m |
| **连接设备** | 手机/PC | 手机/PC/路由器 |
| **适合传** | 控制指令、遥测、压缩音频 | **视频、点云、大文件** |
| **reGlasses 芯片** | WQ7036AX | V881 |
| **你的代码涉及** | ✅ 你需要写 | ❌ 不归你管 |

## 数据该走哪条路？

```
数据量小、要求低功耗、实时性高？
  └→ BLE
  例：控制指令 (开始录制)
  例：电量/温度上报
  例：Opus 压缩音频 (16-32kbps)
  例：降采样 IMU (100-250Hz)

数据量大、要求高带宽？
  └→ WiFi
  例：H.264/H.265 视频流 (5-20 Mbps)
  例：TOF 深度点云 (2-10 Mbps)
  例：全量 IMU (1000Hz)
  例：固件 OTA 下载
```

## reGlasses 带宽分配图

```
手机 APP
  ├── BLE 连接 (WQ7036AX)
  │   ├── 控制指令 (1 Kbps)     ← 你写
  │   ├── 遥测上报 (1 Kbps)     ← 你写
  │   ├── Opus 音频 (16-32 Kbps) ← 你写
  │   └── IMU 降采样 (32 Kbps)  ← 你写
  │
  └── WiFi 连接 (V881)
      ├── H.264 视频 (5-20 Mbps) ← V881 团队负责
      ├── TOF 点云 (2-10 Mbps)   ← V881 团队负责
      └── RTSP/UDP 推流          ← V881 团队负责
```

## BLE 带宽的硬约束

BLE 5.4 的 ~1.4 Mbps 实际吞吐意味着：

| 数据 | 带宽需求 | 能走 BLE？ |
|------|----------|-----------|
| 控制指令 | ~1 Kbps | ✅ 绰绰有余 |
| Opus 音频 | ~32 Kbps | ✅ 可以 |
| IMU 250Hz | ~32 Kbps | ✅ 可以 |
| PCM 音频 16kHz/16bit | ~256 Kbps | ⚠️ 勉强 |
| PCM 音频 48kHz/24bit | ~2.3 Mbps | ❌ 超了 |
| TOF 深度图 | ~5 Mbps | ❌ 远不够 |
| H.264 视频 | ~10 Mbps | ❌ 完全不行 |

## 关联概念

- [[reglasses-bandwidth-reGlasses带宽约束]] — 详细的带宽数据
- [[ble-gatt-BLE-GATT]] — BLE 数据交互
- [[reglasses-architecture-reGlasses协议架构]] — 整体拓扑
- [[wq7036ax-audio-pipeline-WQ7036AX音频管道]] — BLE 音频传输链

#flashcard
问：BLE 和 WiFi 的实际带宽分别大约是多少？
答：BLE 5.4 约 1-1.4 Mbps，WiFi 6 约 100-500 Mbps。差了约 100 倍。

问：reGlasses 的 H.264 视频流能走 BLE 吗？
答：不能。H.264 视频需要 5-20 Mbps，远超 BLE 的 ~1.4 Mbps 上限。必须走 WiFi (V881 负责)。
