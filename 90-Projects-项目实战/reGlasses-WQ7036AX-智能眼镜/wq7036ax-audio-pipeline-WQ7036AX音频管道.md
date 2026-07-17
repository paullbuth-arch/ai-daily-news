---
type: concept
created: 2026-07-16
tags: [mcu, audio, pipeline, dsp, opus, 音频管道, 数据流]
aliases: [音频管道, Audio Pipeline, 音频数据流]
---

# WQ7036AX 音频管道

## 一句话理解

音频管道 (Audio Pipeline) 就是**声音从麦克风到手机的完整旅程**：4 颗 [[pdm-mic-PDM麦克风]] 采集声音 → 硬件滤波变 PCM → DSP 降噪增强 → Opus 压缩 → [[wq-audio-protocol-WQ-Audio-Protocol]] 打包 → [[ble-gatt-BLE-GATT 发给手机]]。这条管道是 reGlasses 最核心的功能之一。

## 为什么要学它

语音交互、音频录制、通话——所有跟"声音"相关的功能都走这条管道。你要做的是确保声音**进得来、处理得好、发得出**。

## 音频服务 API

`wq-adk/components/audio_service/api/aud_sv_api.h` 是音频服务的入口：

```c
// 启动音频采集
aud_sv_start_capture(config);

// 注册回调：收到编码后的 Opus 帧时调用
aud_sv_register_data_callback(callback);

// 播放音频 (从手机收到的音频)
aud_sv_play_pcm(data, len, sample_rate);
```

应用层音频下行处理在 `app_trans_down` 中。

## 第二步：完整数据流

### 采集侧（麦克风 → 手机）

```
┌─ 硬件层 ─────────────────────────────────────────┐
│                                                    │
│  SDM0103B ×4 ──PDM──→ PDM Controller (硬件)       │
│  (U12-U15)              │                          │
│                    Decimation Filter               │
│                    (PDM 1-bit → PCM 16-bit)        │
│                         │                          │
│                    PCM 16kHz, 4ch                  │
└─────────────────────────┼──────────────────────────┘
                          ↓
┌─ DSP 层 (DCORE HiFi5) ────────────────────────────┐
│                                                    │
│  AEC (Acoustic Echo Cancellation, 回声消除)        │
│    → 消除扬声器播放的声音被麦再次录入              │
│                                                    │
│  NR (Noise Reduction, 降噪)                        │
│    → 去除环境噪声 (风扇、空调等)                    │
│                                                    │
│  AGC (Automatic Gain Control, 自动增益)            │
│    → 声音太小自动放大，太大自动压小                 │
│                                                    │
│  VAD (Voice Activity Detection, 语音活动检测)      │
│    → 检测"有人在说话"，没说话时不发送，省电         │
│                                                    │
│  Beam Forming (波束成形)                           │
│    → 4 路麦组合，增强特定方向的声音                 │
└─────────────────────────┼──────────────────────────┘
                          ↓
┌─ 编码层 ──────────────────────────────────────────┐
│                                                    │
│  Opus 编码器                                       │
│    → PCM 16kHz/16bit = 256kbps                    │
│    → Opus 压缩到 16-32kbps (压缩 8-16 倍)          │
│    → 20ms 一帧                                     │
└─────────────────────────┼──────────────────────────┘
                          ↓
┌─ 传输层 ──────────────────────────────────────────┐
│                                                    │
│  WQ Protocol 帧封装                                │
│    → TRANS_UP 帧 + seq + payload                   │
│                                                    │
│  BLE GATT Notify (C3: Audio Stream)               │
│    → 每个包 244B (MTU-3)                           │
│    → 每秒 ~10-20 包 (受 BLE 带宽限制)              │
└─────────────────────────┼──────────────────────────┘
                          ↓
                     手机 APP (Opus 解码 → PCM → 播放/ASR)
```

### 播放侧（手机 → 扬声器）

```
手机 APP ──BLE Write──→ WQ Protocol 解析 ──→ Opus 解码 ──→ PCM
                                                              │
                                                              ↓
  MAX98357A ×2 ←──I2S #2── WQ7036AX (Master) ←── 混音/音量 ←┘
  (U16/U17)
       │
       ↓
  双扬声器 (AMP1_OUTP/N + AMP2_OUTP/N)
```

## 关键 Kconfig 配置

在 `defconfig.stereo.i2s` 中查看当前配置：

| 配置项 | 值 | 说明 |
|--------|---|------|
| `CONFIG_EXT_TRANS_I2S_SAMPLE_RATE` | 16000 | I2S 采样率 16kHz |
| `CONFIG_AUDIO_VAD_SEND_PKT_BY_OPUS` | y | VAD 检测到的语音用 Opus 编码发送 |
| `CONFIG_AUDIO_VAD_WAKEUP_TVAD` | y | 使用 TVAD (Tiny VAD) 做唤醒检测 |
| `CONFIG_DUAL_SPK_ENABLE` | y | 双扬声器使能 |
| `CONFIG_DRIVER_I2S_EXT_PA_ENABLE` | y | 外部功放 (MAX98357A) |
| `CONFIG_DYNAMIC_EQ_ENABLE` | y | 动态均衡器 (EQ, Equalizer) |
| `CONFIG_CODEC_LC3_ENABLE` | y | LC3 编解码器 (LE Audio 用) |

## 第四步：Codec Factory (编解码器工厂)

SDK 的 `wqcore/components/codec_factory/` 组件（`audio_encoder.h` 为编码器统一接口）支持多种编解码器：

| 编解码器 | 类型 | 用途 | reGlasses 用哪个 |
|---------|------|------|-----------------|
| **Opus** | 编码 | BLE 音频传输 | ✅ 主要用这个 |
| SBC | 解码 | A2DP 蓝牙音频 | 可选 |
| AAC | 解码 | 高级音频 | 可选 |
| CVSD | 编解码 | SCO 通话 | 可选 |
| mSBC | 编解码 | 宽带语音通话 | 可选 |
| LC3 | 编解码 | LE Audio | 预留 |

编码器统一接口在 `audio_encoder.h`（`wqcore/components/codec_factory/`）。

## 验收标准

- [ ] 能画出从麦到手机的完整数据流 (至少 5 个阶段)
- [ ] 能解释 AEC/NR/AGC/VAD 各自的作用
- [ ] 能说出 Opus 编码的压缩比 (PCM 256kbps → Opus 16-32kbps)
- [ ] 能在 SDK 中找到 `aud_sv_api.h` 并说出主要 API

## 关联概念

- [[pdm-mic-PDM麦克风]] — 采集入口
- [[i2s-protocol-I2S协议]] — 播放输出接口
- [[wq-audio-protocol-WQ-Audio-Protocol]] — 音频帧的传输封装
- [[ble-gatt-BLE-GATT]] — C3 Audio Stream
- [[max98357a-MAX98357A功放]] — 扬声器驱动
- [[dataflow-mic-to-phone-声音从麦到手机]] — 完整数据流追踪笔记
- [[audio-system-音频系统基础]] — 采样率/位深/AEC/Opus 等底层原理
- [[memory-dma-内存管理与DMA]] — DMA 双缓冲、Cache 一致性
- [[interrupt-concurrency-中断并发同步]] — DMA 中断与音频任务之间的同步

#flashcard
问：音频采集链的 5 个处理阶段是什么？
答：①PDM 采集 ②Decimation (PDM→PCM) ③DSP (AEC/降噪/AGC/VAD) ④Opus 编码 ⑤WQ Protocol 帧封装 → BLE 发送

问：AEC (回声消除) 的作用是什么？
答：消除扬声器播放的声音被麦克风再次录入形成的回声。比如你在播放音乐的同时说话，AEC 会把音乐声从麦克风信号中去掉。

问：reGlasses 使用什么音频编解码器做 BLE 传输？
答：Opus。PCM 16kHz/16bit = 256kbps，Opus 压缩到 16-32kbps，压缩比约 8-16 倍。
