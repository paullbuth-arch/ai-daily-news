---
type: concept
created: 2026-07-16
tags: [comparison, i2s, pdm, audio, 对比, 音频接口]
aliases: [音频接口对比]
---

# 音频接口对比：I2S vs PDM

## 为什么要对比

reGlasses 同时用了 [[i2s-protocol-I2S协议|I2S]] 和 [[pdm-mic-PDM麦克风|PDM 两种数字音频接口]]。I2S 连功放和 V881，PDM 连麦克风。你得知道为什么麦克风用 PDM 而不用 I2S。

## 一图看懂

```
I2S (3线, PCM 直接传):
  BCLK ──────────→ 位时钟
  LRCK ──────────→ 左/右声道切换
  DATA ──────────→ 16/24-bit PCM 数据

PDM (2线, 1-bit 密度调制):
  CLK  ──────────→ 时钟
  DATA ──────────→ 1-bit 密度流
```

## 对比表

| 维度 | [[I2S 协议\|I2S]] | [[PDM 麦克风\|PDM]] |
|------|--------|--------|
| **信号线** | 3 (BCLK+LRCK+DATA) | **2 (CLK+DATA)** |
| **数据格式** | PCM (16/24-bit 直接值) | 1-bit 密度调制 |
| **需要 DSP** | 否 (直接可用) | **是 (需 Decimation Filter)** |
| **多路复用** | LRCK 区分左右 | **L/R 引脚电平区分** |
| **适用场景** | 芯片间音频传输 | **数字麦克风采集** |
| **速度** | BCLK = 2×位宽×Fs | CLK = 64~128 × Fs |
| **reGlasses 用在哪** | 功放 (MAX98357A) + V881 | 麦克风 (SDM0103B ×4) |

## 为什么麦克风用 PDM 不用 I2S？

1. **线更少**：PDM 只需 2 根线，4 颗麦只需要 2 条 CLK + 2 条 DATA = 4 根线。如果用 I2S，每颗麦需要 BCLK+LRCK+DATA = 3 根共享 + 更多配置
2. **麦克风天然输出 PDM**：MEMS 麦克风芯片内部就是 1-bit Sigma-Delta 调制器，PDM 是最自然的输出格式
3. **抗噪性好**：1-bit 数字信号比模拟信号抗干扰，适合眼镜这种紧凑 PCB 布局

## 为什么功放用 I2S 不用 PDM？

1. **功放需要 PCM**：MAX98357A 内部有 DAC (Digital-to-Analog Converter)，它需要标准 PCM 数据
2. **I2S 直接传 PCM**：不需要额外的格式转换
3. **音质更好**：I2S 传 16-bit PCM，精度比 PDM 的 1-bit 高

## 数据流中的位置

```
麦克风 (PDM) → Decimation → PCM → DSP → Opus → BLE → 手机
                                                    │
手机 → BLE → Opus 解码 → PCM → I2S → 功放 → 扬声器
```

PDM 在最前端 (采集)，I2S 在最后端 (播放)。中间全是 PCM 格式。

## 关联概念

- [[i2s-protocol-I2S协议]] — 芯片间 PCM 音频传输
- [[pdm-mic-PDM麦克风]] — 数字麦克风采集
- [[wq7036ax-audio-pipeline-WQ7036AX音频管道]] — 两种接口在音频链中的位置
- [[max98357a-MAX98357A功放]] — I2S 接收端
- [[sdm0103b-SDM0103B数字麦]] — PDM 输出端

#flashcard
问：为什么麦克风用 PDM 而不用 I2S？
答：PDM 只需 2 根线 (比 I2S 少 1 根)，MEMS 麦克风天然输出 PDM 格式，且 1-bit 数字信号抗噪性好。

问：PDM 数据怎么变成 PCM？
答：通过 Decimation Filter (抽取滤波器)，把高频 1-bit PDM 流转换为低频多 bit PCM 数据。
