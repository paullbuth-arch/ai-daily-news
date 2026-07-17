# Opus 编码

**一句话结论（20% 核心）**：Opus 是嵌入式音频传输的黄金编码器——压缩比 8-16 倍（256kbps PCM → 16-32kbps），支持 8-48kHz 采样率，延迟低至 5ms，开源免费。reGlasses 用 Opus 把麦克风音频压缩后通过 BLE 发给手机，这是整个音频链路的关键环节。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：把一本书压缩成笔记

- **PCM 原始音频** = 一本 300 页的书，逐字逐句记录
- **Opus 编码** = 把这 300 页压缩成 20 页的笔记——保留核心意思，扔掉冗余信息
- **Opus 解码** = 把 20 页笔记还原成 300 页——不可能完全还原，但人耳听不出区别

**为什么能压缩这么多？** 因为 PCM 数据里有大量冗余：人耳听不到的高频（>20kHz）、被大声音掩盖的小声音（掩蔽效应）、相邻采样点之间的相关性。Opus 利用这些冗余，把数据量压缩到 1/8-1/16。

### 1.2 Opus 的核心特性

| 特性 | 值 | 为什么重要 |
|------|------|-----------|
| **采样率** | 8-48 kHz | 覆盖窄带语音到全频带音乐 |
| **码率** | 6-510 kbps | 可以根据带宽动态调整 |
| **帧长** | 2.5-60 ms | 短帧=低延迟，长帧=高压缩率 |
| **延迟** | 低至 5ms | 比 AAC(~100ms) 和 MP3(~150ms) 低得多 |
| **算法延迟** | 26.5ms（默认） | BLE 音频传输的关键指标 |
| **开源** | BSD 协议 | 免费商用，无专利风险 |

### 1.3 Opus vs 其他编码器

| 编码器 | 码率范围 | 典型延迟 | 开源 | 适用场景 |
|--------|---------|---------|------|---------|
| **Opus** | 6-510 kbps | 5-60ms | 是 | 语音+音乐，低延迟场景 |
| **SBC** | 10-345 kbps | ~100ms | 是 | A2DP 蓝牙音频（强制支持） |
| **AAC** | 8-320 kbps | ~100ms | 需授权 | 高质量音乐（iPhone 默认） |
| **CVSD** | 64 kbps | <5ms | 是 | HFP 窄带语音通话 |
| **mSBC** | 64 kbps | <10ms | 是 | HFP 宽带语音通话 |

**为什么 reGlasses 选 Opus？** 因为 BLE 带宽有限（~1Mbps 理论值），音频传输必须压缩。Opus 在 16-32kbps 码率下就能提供可接受的语音质量，SBC/AAC 在同等码率下质量差很多。

### 1.4 如果只记得一件事

> Opus = 开源、低延迟、高压缩比的音频编码器。PCM 256kbps → Opus 16-32kbps，压缩 8-16 倍。reGlasses 用它通过 BLE 传音频，是整个音频链路的关键。

---

## 第二层：实战理解

### 2.1 WQ7036AX 上 Opus 编码的调用流程

```c
// WQ7036AX SDK 中 Opus 编码器的使用（简化）
// 代码路径: wqcore/components/codec_factory/

#include "audio_encoder.h"

// ① 创建编码器实例
audio_encoder_cfg_t cfg = {
    .type       = AUDIO_ENCODER_OPUS,
    .sample_rate = 16000,        // 16kHz 采样率
    .channels   = 1,             // 单声道
    .bitrate    = 32000,         // 32kbps 码率
    .frame_ms   = 20,            // 20ms 一帧
};
audio_encoder_handle_t enc = audio_encoder_create(&cfg);

// ② 编码循环：每 20ms 输入 320 个 PCM 采样，输出 Opus 帧
// PCM 16kHz × 20ms = 320 samples
int16_t pcm_frame[320];  // 从音频管道获取
uint8_t opus_frame[256]; // Opus 输出缓冲区
int opus_len = sizeof(opus_frame);

audio_encoder_encode(enc, pcm_frame, 320, opus_frame, &opus_len);
// opus_len 通常 40-80 字节（压缩后）

// ③ 发送 Opus 帧
wq_proto_pkt_pack(&pkt, SERVICE_TYPE_TRANS_UP, ..., opus_frame, opus_len);
ble_gatts_notify(conn_handle, audio_char, &pkt);
```

### 2.2 码率 vs 质量的权衡

```
码率    质量         适用场景
16kbps  可接受语音    BLE 带宽紧张、环境噪音场景
24kbps  清晰语音      reGlasses 默认配置
32kbps  优质语音      带宽充裕时
48kbps  接近透明      音乐传输（需要 BLE 5.2+ LE Audio）
```

**reGlasses 的实际选择**：16kHz 采样率 + 32kbps 码率 + 20ms 帧长。这是 BLE 带宽和语音质量之间的最优平衡点。

### 2.3 常见坑

| 问题 | 现象 | 排查方法 | 根因 |
|------|------|---------|------|
| 码率太低 | 语音模糊、金属音 | 提高码率到 32kbps 对比 | 码率不够，编码器丢弃了高频信息 |
| 帧长太大 | 延迟高，对话不自然 | 减少帧长到 10ms 对比 | 帧长=编码延迟，BLE 每 20ms 发一包 |
| 采样率不匹配 | 声音变调、速度不对 | 确认输入 PCM 的实际采样率 | enc 配置的采样率和实际 PCM 不一致 |
| 丢帧 | 声音断续 | 看 BLE 发送队列是否溢出 | BLE 带宽不足，或发送间隔不对 |

### 2.4 在 reGlasses 项目中怎么用

Opus 编码是 WQ7036AX 音频管道的关键环节。完整链路：

```
PDM 麦克风 → PDM→PCM → DSP(AEC/降噪) → Opus 编码 → WQ Protocol → BLE → 手机
                                                              ↑
                                            CONFIG_AUDIO_VAD_SEND_PKT_BY_OPUS=y
```

Kconfig 中 `CONFIG_AUDIO_VAD_SEND_PKT_BY_OPUS=y` 控制 VAD 检测到的语音通过 Opus 编码发送。编码器代码在 `wqcore/components/codec_factory/`，统一接口在 `audio_encoder.h`。

---

## 第三层：深入扩展

### 3.1 Opus 的内部：SILK + CELT 双引擎

Opus 内部包含两个编码引擎，自动切换：
- **SILK**（语音引擎）：擅长语音，8-16kHz，低码率
- **CELT**（音乐引擎）：擅长音乐，16-48kHz，高码率
- **混合模式**：SILK 处理低频，CELT 处理高频，各取所长

这使 Opus 成为唯一一个同时擅长语音和音乐的编码器。

### 3.2 常见问题

- **Opus 和 AAC 的区别？** AAC 是纯音乐编码器，延迟高（~100ms），需要专利授权。Opus 语音+音乐都擅长，延迟低（5-60ms），开源免费。
- **为什么 BLE 音频用 Opus 而不是 SBC？** SBC 在低码率下质量差，且延迟高。Opus 在 32kbps 的质量远超 SBC。
- **Opus 支持 FEC（前向纠错）吗？** 支持。Opus 可以在当前帧中嵌入前一帧的低码率副本，如果前一帧丢失，可以用副本近似恢复。

### 3.3 延伸阅读

- [[audio-system-音频系统基础]] — 采样率、位深、PCM 等音频基础
- [[wq7036ax-audio-pipeline-WQ7036AX音频管道]] — Opus 在音频管道中的位置
- [[reglasses-bandwidth-reGlasses带宽约束]] — BLE 带宽限制和 Opus 码率选择