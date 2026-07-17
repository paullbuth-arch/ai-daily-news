---
type: concept
created: 2026-07-16
tags: [protocol, i2s, clock, mclk, bclk, audio]
aliases: [I2S Clock, I2S 时钟关系]
---

# I2S 时钟树

## 是什么

[[i2s-protocol-I2S协议 中 MCLK、BCLK、LRCK 三个时钟信号之间的频率关系和配置方法]]。正确配置时钟是 I2S 正常工作的关键。

## 时钟关系公式

```
Fs = 采样率 (如 16000 Hz)

LRCK = Fs
BCLK = 2 × BitWidth × Fs
MCLK = N × Fs  (N 通常为 256 或 128)
```

## 以 reGlasses 16kHz/16-bit 为例

| 时钟 | 频率 | 计算 |
|------|------|------|
| Fs (采样率) | 16,000 Hz | — |
| LRCK | 16 kHz | = Fs |
| BCLK | 512 kHz | = 2 × 16 × 16000 |
| MCLK (×256) | 4.096 MHz | = 256 × 16000 |
| MCLK (×128) | 2.048 MHz | = 128 × 16000 |

## 常见采样率对照

| Fs | LRCK | BCLK (16bit) | MCLK (×256) |
|----|------|-------------|-------------|
| 8 kHz | 8 kHz | 256 kHz | 2.048 MHz |
| 16 kHz | 16 kHz | 512 kHz | 4.096 MHz |
| 32 kHz | 32 kHz | 1.024 MHz | 8.192 MHz |
| 44.1 kHz | 44.1 kHz | 1.411 MHz | 11.289 MHz |
| 48 kHz | 48 kHz | 1.536 MHz | 12.288 MHz |

## WQ7036AX 时钟源

```
系统时钟 (32MHz 晶振 X4)
    │
    └── 音频 PLL ──→ 分频器 ──→ MCLK 输出
                              ──→ BCLK 生成
                              ──→ LRCK 生成
```

Kconfig: `CONFIG_AUDIO_CLOCK_15_36M=y` — 音频系统时钟选择

## Master 模式时钟输出

当 WQ7036AX 为 I2S Master 时（I2S #2 → MAX98357A）：
- BCLK 和 LRCK 由 WQ7036AX **输出**到功放
- 功放作为 Slave 接收时钟和数据

## Slave 模式时钟输入

当 WQ7036AX 为 I2S Slave 时（I2S #1 ← V881）：
- BCLK 和 LRCK 由 V881 **提供**
- WQ7036AX 跟随外部时钟采样

## 关联概念

- [[i2s-protocol-I2S协议]] — 时钟树所属的协议
- [[wq7036ax-audio-pipeline-WQ7036AX音频管道]] — 时钟配置在音频初始化中的位置
- [[pdm-mic-PDM麦克风]] — PDM 的时钟更简单（只有 CLK）

#flashcard
问：16kHz 采样率、16-bit 位宽时 BCLK 频率是多少？
答：512 kHz = 2 × 16 × 16000

问：I2S Master 和 Slave 的区别是什么？
答：Master 提供 BCLK 和 LRCK 时钟，Slave 接收外部时钟。reGlasses 中 V881 是 I2S#1 的 Master，WQ7036AX 是 I2S#2 的 Master。
