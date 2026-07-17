---
type: concept
tags: [Opus, 音频编码, 压缩, 语音编解码, 音频传输, BLE]
aliases: [Opus编码, Opus Codec, 音频编解码器]
---

# Opus 编码

## 一句话结论

Opus 是嵌入式音频传输的黄金编码器——压缩比 8-16 倍（256kbps PCM → 16-32kbps），支持 8-48kHz 采样率，延迟低至 5ms，开源免费。reGlasses 用 Opus 把麦克风音频压缩后通过 BLE 发给手机，这是整个音频链路的关键环节。

## 30秒先看懂

1. Opus 是目前唯一一个同时擅长语音和音乐的编解码器，内部集成了 SILK（语音引擎）和 CELT（音乐引擎）自动切换。
2. 压缩比 8-16 倍：16kHz/16bit PCM 256kbps → Opus 16-32kbps，人耳几乎听不出区别。
3. 延迟低至 5ms（帧长 2.5ms），远低于 AAC（~100ms）和 MP3（~150ms），适合实时通信。
4. 开源免费（BSD 协议），无专利风险，所有主流平台都支持。
5. reGlasses 用 16kHz/32kbps/20ms 帧长的配置，这是 BLE 带宽和语音质量之间的最优平衡点。

## 学完以后应该能做什么

### 第一遍
- 理解 Opus 的压缩原理和核心参数（采样率、码率、帧长、复杂度）
- 知道 Opus 和其他编码器（SBC、AAC、CVSD）的对比和选型依据
- 在 WQ7036AX 上调用 Opus 编码器压缩音频数据
- 理解码率 vs 质量的权衡

### 进阶
- 理解 Opus 内部 SILK + CELT 双引擎的工作原理
- 配置 Opus FEC（前向纠错）应对 BLE 丢包
- 理解 Opus 的算法延迟和帧长选择
- 在嵌入式平台上优化 Opus 编码性能

## 前置知识

- PCM 数字音频基础（采样率、位深、通道数）
- 音频带宽计算
- 基本的音频处理概念

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| Opus | Opus | 开源通用音频编解码器，IETF 标准 RFC 6716 |
| SILK | SILK | Opus 内部的语音编码引擎，基于语音模型 |
| CELT | CELT | Opus 内部的音乐编码引擎，基于 MDCT 变换 |
| 码率 | Bitrate | 编码后每秒的数据量，单位 bps |
| 帧长 | Frame Size | 每帧编码的音频时长，单位 ms |
| 可变码率 | VBR (Variable Bitrate) | 根据内容复杂程度动态调整码率 |
| 前向纠错 | FEC (Forward Error Correction) | 在帧中嵌入前一帧的低码率副本，抗丢包 |
| 算法延迟 | Algorithmic Delay | 编码器自身引入的延迟，不等同于帧长 |
| 复杂度 | Complexity | 编码器计算量等级（0-10），嵌入式通常用 0-2 |

## 第一层：费曼心智模型

### 类比：把一本书压缩成笔记

- **PCM 原始音频** = 一本 300 页的书，逐字逐句记录
- **Opus 编码** = 把这 300 页压缩成 20 页的笔记——保留核心意思，扔掉冗余信息
- **Opus 解码** = 把 20 页笔记还原成 300 页——不可能完全还原，但人耳听不出区别

**为什么能压缩这么多？** 因为 PCM 数据里有大量冗余：人耳听不到的高频（>20kHz）、被大声音掩盖的小声音（掩蔽效应）、相邻采样点之间的相关性。Opus 利用这些冗余，把数据量压缩到 1/8-1/16。

### 边界

- Opus 不是万能的：在极高码率（>256kbps）下，AAC 可能略好；在极低码率（<12kbps）下，专用语音编码器（如 AMR）可能更好
- Opus 编码需要计算资源：嵌入式芯片上复杂度不能设太高（通常 0-2）
- Opus 不适合广播场景：因为专利开源，但广播设备（如数字电视）有专用编码标准
- Opus 帧长越小，压缩效率越低：2.5ms 帧长适合实时通信，60ms 帧长适合流媒体

### 场景推演：BLE 音频传输

WQ7036AX 采集到音频后，通过 BLE 发送给手机：
1. 麦克风采集原始 PCM 数据（16kHz/16bit = 256kbps）
2. 如果直接传 PCM，BLE 带宽完全不够（BLE 理论 1Mbps，实际 100-200kbps 可用）
3. 必须压缩！Opus 将 256kbps 压缩到 32kbps（8 倍压缩）
4. 每 20ms 产生一帧 Opus 数据（约 60-80 字节），通过 BLE Notify 发送
5. 手机收到后解码播放，用户听到清晰的声音

## 第二层：原理/时序/约束

### Opus 的核心特性

| 特性 | 值 | 为什么重要 |
|------|------|-----------|
| **采样率** | 8-48 kHz | 覆盖窄带语音到全频带音乐 |
| **码率** | 6-510 kbps | 可以根据带宽动态调整 |
| **帧长** | 2.5-60 ms | 短帧=低延迟，长帧=高压缩率 |
| **延迟** | 低至 5ms | 比 AAC(~100ms) 和 MP3(~150ms) 低得多 |
| **算法延迟** | 26.5ms（默认） | BLE 音频传输的关键指标 |
| **开源** | BSD 协议 | 免费商用，无专利风险 |

### Opus vs 其他编码器

| 编码器 | 码率范围 | 典型延迟 | 开源 | 适用场景 |
|--------|---------|---------|------|---------|
| **Opus** | 6-510 kbps | 5-60ms | 是 | 语音+音乐，低延迟场景 |
| **SBC** | 10-345 kbps | ~100ms | 是 | A2DP 蓝牙音频（强制支持） |
| **AAC** | 8-320 kbps | ~100ms | 需授权 | 高质量音乐（iPhone 默认） |
| **CVSD** | 64 kbps | <5ms | 是 | HFP 窄带语音通话 |
| **mSBC** | 64 kbps | <10ms | 是 | HFP 宽带语音通话 |

**为什么 reGlasses 选 Opus？** 因为 BLE 带宽有限（~1Mbps 理论值，实际可用约 100-200kbps），音频传输必须压缩。Opus 在 16-32kbps 码率下就能提供可接受的语音质量，SBC/AAC 在同等码率下质量差很多。

### 码率 vs 质量的权衡

```
码率    质量         适用场景
16kbps  可接受语音    BLE 带宽紧张、环境噪音场景
24kbps  清晰语音      reGlasses 默认配置
32kbps  优质语音      带宽充裕时
48kbps  接近透明      音乐传输（需要 BLE 5.2+ LE Audio）
```

### Opus 的内部：SILK + CELT 双引擎

Opus 内部包含两个编码引擎，自动切换：
- **SILK**（语音引擎）：擅长语音，8-16kHz，低码率，基于线性预测编码（LPC）
- **CELT**（音乐引擎）：擅长音乐，16-48kHz，高码率，基于 MDCT 变换
- **混合模式**：SILK 处理低频，CELT 处理高频，各取所长

## 第三层：真实SDK代码

### WQ7036AX 上 Opus 编码的调用流程

在 `/home/ys/wq7036a/wq-audio/wqcore/components/codec_factory/encode/` 中，Opus 编码器的调用：

```c
// 伪代码——WQ7036AX SDK 中 Opus 编码器
// 文件路径: wqcore/components/codec_factory/encode/factory/inc/audio_encoder.h

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

### Kconfig 中的 Opus 配置

在 `/home/ys/wq7036a/wq-audio/wqcore/components/codec_factory/Kconfig.in` 中：

```kconfig
# Opus 编码器配置选项
config CODEC_OPUS_ENABLE
    bool "Enable Opus encoder"
    default y
    help
        Enable Opus audio encoder for BLE audio transmission.

config CODEC_OPUS_BITRATE
    int "Opus encoder bitrate"
    range 6000 510000
    default 32000
    help
        Opus encoding bitrate in bps. 32000 for voice, 64000+ for music.

config CODEC_OPUS_FRAME_MS
    int "Opus frame duration (ms)"
    range 5 60
    default 20
    help
        Frame duration. Shorter = lower latency, longer = better compression.
```

### VAD 和 Opus 的联动

在 Kconfig 中，`CONFIG_AUDIO_VAD_SEND_PKT_BY_OPUS=y` 控制 VAD 检测到的语音通过 Opus 编码发送：

```c
// 伪代码——VAD 触发 Opus 编码
// 文件路径: wqcore/components/audsys/audsys_record.c

void audio_process_frame(int16_t *pcm, int len) {
    if (vad_detect(pcm, len)) {
        // 检测到语音，编码并发送
        uint8_t opus_buf[256];
        int opus_len = sizeof(opus_buf);
        audio_encoder_encode(enc, pcm, len, opus_buf, &opus_len);
        ble_send_audio(opus_buf, opus_len);
    }
    // 没有语音，不编码不发送（省电）
}
```

## 第四层：正常/异常路径

### 正常路径

```
PCM 输入 (16kHz/16bit/320 samples) → Opus 编码
  → 码率控制 (32kbps CBR 或 VBR)
  → SILK 或 CELT 引擎选择 → 帧打包
  → Opus 帧输出 (40-80 bytes / 20ms)
  → 通过 BLE Notify 发送
```

### 异常路径

| 异常 | 现象 | 触发条件 | 恢复方式 |
|------|------|---------|---------|
| 码率太低 | 语音模糊、金属音 | 码率 < 16kbps 时语音质量劣化严重 | 提高码率到 24-32kbps |
| 帧长太大 | 延迟高，对话不自然 | 帧长 > 40ms | 减小帧长到 10-20ms |
| 采样率不匹配 | 声音变调 | 编码器配置的采样率和输入 PCM 不一致 | 统一配置采样率 |
| BLE 丢帧 | 声音断续 | BLE 无线环境差，GATT 通知丢失 | 开启 Opus FEC 或降低帧率 |
| 编码器溢出 | 编码失败 | 输入 PCM 帧长与配置不符 | 确保输入帧长 = 采样率 × 帧长 / 1000 |
| 复杂度太高 | 编码耗时超过帧长 | 嵌入式 CPU 跟不上复杂度设置 | 降低复杂度到 0-2 |

## 第五层：调试方法

### Opus 编码调试

```c
// 输出编码参数和结果
printf("Opus: %dHz/%dbps/%dms frame\n",
       cfg->sample_rate, cfg->bitrate, cfg->frame_ms);
printf("Opus frame: %d bytes (compression ratio: %d:1)\n",
       opus_len, (320 * 2) / opus_len);

// 输出码率统计
static uint32_t total_bytes = 0;
static uint32_t total_frames = 0;
total_bytes += opus_len;
total_frames++;
printf("Average bitrate: %d bps\n",
       total_bytes * 8 / (total_frames * cfg->frame_ms / 1000));
```

### 质量评估

```bash
# 在 PC 上对比编码前后的音频
ffmpeg -i original.wav -c:a libopus -b:a 32k -frame_duration 20 test.opus
ffprobe test.opus  # 查看编码参数

# 用 speex 工具评估质量
# 下载: https://github.com/xiph/speex
speexdec test.opus test_decoded.wav

# 对比原始和编解码后的频谱
ffmpeg -i original.wav -f lavfi -i anullsrc -shortest -filter_complex \
  "[0:a][1:a]psnr" -f null -
```

## 第六层：实战练习

### 练习1：计算 Opus 帧大小

给定采样率 16kHz，码率 32kbps，帧长 20ms，计算：
1. 每帧输入的 PCM 采样数
2. 每帧 Opus 编码后的目标字节数
3. 如果 BLE 每 20ms 能发送 100 字节，是否够用？

### 练习2：对比不同码率的语音质量

在 PC 上使用 ffmpeg 将一段 PCM 文件编码为不同码率的 Opus 文件（16kbps、24kbps、32kbps、48kbps），对比听感差异，找出可接受的最低码率。

```bash
# 提示
ffmpeg -f s16le -ar 16000 -ac 1 -i input.pcm -c:a libopus -b:a 16k test_16k.opus
ffmpeg -f s16le -ar 16000 -ac 1 -i input.pcm -c:a libopus -b:a 32k test_32k.opus
```

### 练习3：阅读真实源码——WQ7036AX codec_factory 的 Opus 实现

阅读 `/home/ys/wq7036a/wq-audio/wqcore/components/codec_factory/encode/` 目录下的源码，分析：
1. Opus 编码器的创建流程（`audio_encoder_create` 做了什么？）
2. 编码参数是如何传递到 Opus 库的？
3. 如果编码失败，返回值是什么？上层如何处理？

## 自测与验收

1. Opus 相比 SBC 和 AAC 的优势是什么？为什么 reGlasses 选 Opus？
2. Opus 内部有哪两个编码引擎？分别擅长什么？
3. Opus 的帧长选择对延迟和压缩率有什么影响？
4. 为什么嵌入式平台上 Opus 的复杂度参数通常设为 0-2？
5. 什么是 Opus FEC？在 BLE 丢包时有什么作用？
6. 给定 16kHz/32kbps/20ms 帧长，每帧 Opus 数据大约多少字节？

## 延伸阅读

- [[audio-system-音频系统基础]] — 采样率、位深、PCM 等音频基础
- [[wq7036ax-audio-pipeline-WQ7036AX音频管道]] — Opus 在音频管道中的位置
- [[reglasses-bandwidth-reGlasses带宽约束]] — BLE 带宽限制和 Opus 码率选择
- [[codec-factory-编解码器工厂]] — codec_factory 组件的设计

## #flashcard

Q: Opus 相比 SBC/AAC 在嵌入式音频传输中的优势？
A: 低码率下质量好（16-32kbps 可接受），延迟低（5-60ms），开源免费，同时擅长语音和音乐。

Q: Opus 内部的双引擎是什么？
A: SILK（语音引擎，基于 LPC，低码率）和 CELT（音乐引擎，基于 MDCT，高码率），可混合模式运行。

Q: Opus 帧长对性能的影响？
A: 帧长越短延迟越低，但压缩效率越低。20ms 是语音和延迟的平衡点。

Q: 为什么嵌入式 Opus 复杂度设 0-2？
A: 嵌入式 CPU 算力有限，高复杂度（5-10）编码质量提升不大但计算量暴增，实时性无法保证。

Q: 16kHz/32kbps/20ms 帧长，每帧 Opus 数据多少字节？
A: 32kbps × 0.02s = 640 bits = 80 字节。实际因 VBR 可能在 40-80 字节之间。