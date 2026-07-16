---
type: project
created: 2026-07-16
tags: [project, reglasses, bandwidth, ble, wifi, hfp, a2dp, 带宽, 双模蓝牙]
aliases: [带宽约束, 链路带宽]
---

# reGlasses 带宽约束

## 一句话理解

WQ7036AX 是**双模蓝牙 (Dual-Mode Bluetooth)** 芯片：经典蓝牙 (BR/EDR) 负责**通话和音乐** (HFP/A2DP)，BLE 负责**控制和遥测**。WiFi (V881) 负责视频和大文件。**不是所有音频都走 BLE**。

## 为什么重要

你设计任何功能之前，必须先知道：这条数据该走**经典蓝牙**还是 **BLE** 还是 **WiFi**？选错了链路，要么音质差 (该走 HFP 的走了 BLE)，要么功耗高 (该走 BLE 的走了经典蓝牙)。

## ⚠️ 关键纠正：WQ7036AX ≠ 纯 BLE

之前把 WQ7036AX 当成纯 BLE 芯片是**错误的**。它实际上支持：

| 蓝牙模式 | 协议 | 用途 | 你用过吗 |
|----------|------|------|---------|
| **经典蓝牙 BR/EDR** | HFP (Hands-Free Profile) | **语音通话** (微信/电话) | ✅ 微信通话清晰可用 |
| **经典蓝牙 BR/EDR** | A2DP (Advanced Audio Distribution) | **音乐播放** | ✅ |
| **经典蓝牙 BR/EDR** | AVRCP (Audio/Video Remote Control) | 媒体控制 | ✅ |
| **经典蓝牙 BR/EDR** | SPP (Serial Port Profile) | 串口透传 | 可选 |
| **BLE** | GATT | **控制指令 + 遥测 + 压缩音频** | ✅ |

SDK 代码确认 (`app_econn_demo.c`)：

```c
app_econn_handle_hfp_state()   // HFP 通话状态管理
app_econn_handle_a2dp_state()  // A2DP 音乐状态管理
app_econn_handle_avrcp_state() // AVRCP 媒体控制
app_econn_handle_acl_state()   // ACL 连接管理
```

## 四条链路带宽

| 链路 | 协议 | 理论上限 | **实际可用** | 用途 | 你管不管 |
|------|------|----------|-------------|------|---------|
| **经典蓝牙 SCO/eSCO** | HFP | 64 kbps (CVSD) / 128 kbps (mSBC) | **64-128 kbps** | **语音通话** | ✅ 你管 |
| **经典蓝牙 ACL** | A2DP | ~700 kbps (SBC) / ~990 kbps (AAC) | **328-990 kbps** | **音乐播放** | ✅ 你管 |
| **BLE 5.4** | GATT | ~2 Mbps | **~1.0-1.4 Mbps** | 控制 + 遥测 | ✅ 你管 |
| **UART** | [[UART 命令协议]] | ~1 Mbps | **~0.8 Mbps** | MCU↔SoC 指令 | ✅ 你管 |
| **WiFi 6** | RTSP/UDP | ~1.2 Gbps | **~100-500 Mbps** | 视频/点云 | ❌ V881 管 |

## 各种数据类型该走哪条路

| 数据类型 | 带宽需求 | 走哪条路 | 为什么 |
|----------|----------|---------|--------|
| **语音通话** (微信/电话) | 64-128 kbps | **经典蓝牙 HFP/SCO** | SCO/eSCO 是专为通话设计的同步链路，有保证时隙，延迟低 |
| **音乐播放** | 328-990 kbps | **经典蓝牙 A2DP** | A2DP 专为高质量音频流设计 |
| 控制指令 (录制/拍照) | ~1 Kbps | **BLE GATT** | 低频、低功耗 |
| 遥测 (电量/温度) | ~1 Kbps | **BLE GATT** | 低频 |
| Opus 压缩音频 | ~16-32 Kbps | **BLE GATT** | BLE 带宽足够 |
| IMU 降采样 (250Hz) | ~32 Kbps | **BLE GATT** | BLE 带宽足够 |
| TOF 深度图 | ~2-10 Mbps | **WiFi** | 远超蓝牙带宽 |
| H.264 视频 | ~5-20 Mbps | **WiFi** | 远超蓝牙带宽 |
| 固件 OTA 下载 | ~数 MB | **WiFi** | 大文件 |

## 你的微信通话场景是这样工作的

```
你对着 WQ7036AX 开发板的 Mic 讲话
    │
    ↓ PDM 采集 → PCM → DSP (AEC/降噪/AGC)
    │
    ↓ CVSD 或 mSBC 编码 (经典蓝牙音频编解码器)
    │
    ↓ HFP SCO/eSCO 链路 (经典蓝牙专用语音通道)
    │  ↑ 这不是 BLE！这是 BR/EDR 的同步链路
    │  ↑ SCO 有固定的时隙分配，保证 64kbps 不被挤占
    │
    ↓ 手机收到 → 微信发送 → 同事听到
```

**关键点**：
- HFP 使用的是 **SCO (Synchronous Connection-Oriented)** 或 **eSCO (Enhanced SCO)** 链路
- 这是经典蓝牙的**同步链路**，和 BLE GATT 的**异步链路**完全不同
- SCO/eSCO 有**保证时隙** (Guaranteed Slots)，不会被其他数据挤占
- 所以即使带宽只有 64kbps (CVSD) 或 128kbps (mSBC)，语音依然清晰

## 经典蓝牙 vs BLE 音频对比

| 维度       | 经典蓝牙 (HFP/A2DP)                  | BLE GATT               |
| -------- | -------------------------------- | ---------------------- |
| **链路类型** | 同步 (SCO/eSCO) + 异步 (ACL)         | 异步 (GATT Notify/Write) |
| **带宽保障** | ✅ SCO 有保证时隙                      | ❌ 尽力而为                 |
| **音频延迟** | 低 (~20-40ms)                     | 较高 (~30-100ms)         |
| **适用场景** | **通话、音乐**                        | 控制、遥测、压缩音频数据           |
| **功耗**   | 较高 (mA 级)                        | 极低 (μA~mA)             |
| **编解码器** | CVSD, mSBC, SBC, AAC, LDAC, LHDC | Opus (自定义)             |

## BLE 带宽详细计算

```
BLE 5.4, 2M PHY:
  理论: 2 Mbps
  扣除 L2CAP/ATT 头: ~80% 有效
  扣除 GATT Notify 开销: ~70% 有效
  实际: ~1.4 Mbps

MTU = 247 → payload = 244B
Connection Interval = 15ms → 每秒 ~66 次事件
每次最多发 4 个包 (Data Length Extension)
理论: 244B × 4 × 66 = ~51.5 KB/s ≈ 412 Kbps

实际稳定值: ~100-200 Kbps (手机端限制)
```

> ⚠️ 不同手机的 BLE 实现差异很大。iPhone 通常比 Android 手机支持更高的吞吐。

## 设计决策总结

```
需要通话质量语音？
  └→ 经典蓝牙 HFP + SCO/eSCO
     CVSD (窄带 64kbps) 或 mSBC (宽带 128kbps)

需要高质量音乐？
  └→ 经典蓝牙 A2DP
     SBC/AAC/LDAC/LHDC

需要低功耗控制 + 遥测 + 压缩音频数据？
  └→ BLE GATT
     Opus 压缩, IMU 降采样

需要视频/点云/大文件？
  └→ WiFi (V881 负责)
```

## 验收标准

- [ ] 能说出 WQ7036AX 是**双模蓝牙** (经典 BR/EDR + BLE)
- [ ] 能区分 HFP/SCO (通话) 和 BLE GATT (控制) 的不同用途
- [ ] 能解释为什么微信通话走 HFP 而不是 BLE
- [ ] 能说出四种数据各自该走哪条路 (通话→HFP, 音乐→A2DP, 控制→BLE, 视频→WiFi)

## 关联概念

- [[reGlasses 协议架构]] — 整体拓扑
- [[无线对比：BLE vs WiFi]] — 两种无线详细对比 (需补充经典蓝牙)
- [[WQ7036AX 音频管道]] — 音频处理链
- [[BLE GATT]] — BLE 数据交互
- [[WQ7036AX 芯片]] — 双模蓝牙硬件

#flashcard
问：WQ7036AX 是纯 BLE 芯片还是双模蓝牙？
答：双模蓝牙 (Dual-Mode)。同时支持经典蓝牙 BR/EDR (HFP/A2DP/AVRCP/SPP) 和 BLE (GATT)。

问：微信语音通话走的是 BLE 还是经典蓝牙？为什么？
答：经典蓝牙 HFP + SCO/eSCO。SCO 是专为通话设计的同步链路，有保证时隙，延迟低 (~20-40ms)，带宽 64kbps (CVSD) 或 128kbps (mSBC)。BLE GATT 是异步链路，没有带宽保障，不适合实时通话。

问：A2DP 支持哪些音频编解码器？
答：SBC (必选)、AAC、LDAC、LHDC。reGlasses SDK 的 defconfig 中 CONFIG_CODEC_LDAC_ENABLE=y、CONFIG_CODEC_LHDC_ENABLE=y。
