---
type: concept
created: 2026-07-17
tags: [protocol, i2s, clock, mclk, bclk, audio, 时钟树, 分频]
aliases: [I2S Clock, I2S 时钟关系, 音频时钟树]
---

# I2S 时钟树：从 PLL 到 BCLK/LRCK 的分频链路

> **一句话结论**：I2S 的 BCLK、LRCK 和 MCLK 不是三个独立的时钟，而是从同一个时钟源（通常是音频 PLL）经过整数分频器产生的三个倍数相关信号。时钟配置错误——无论是 PLL 频率选错、分频值不整除、还是 Master/Slave 角色反了——都会导致音频全损。reGlasses 中 V861 作为 I2S0 Master 提供时钟，WQ7036AX 作为 Slave 跟随，这个角色分配决定了时钟信号的流向和双方的 PLL 配置。

## 30 秒先看懂

I2S 的三种时钟（主时钟、位时钟、左右声道时钟）不是各自独立的，而是从同一个音频锁相环经过整数分频产生的三个倍数相关的信号。时钟配置错误会导致音频完全无声或全是噪音。初学者先记住：44.1 kHz 和 48 kHz 两个采样率家族需要不同的锁相环频率，混用会导致分频不整除，产生音频失真。

本篇是 [[i2s-protocol-I2S协议]] 的补充，聚焦时钟生成链路的细节。协议概念和 API 见主文档。

## 术语先讲清楚

| 术语 | 在时钟树中具体指什么 |
|---|---|
| 音频 PLL | 锁相环（Phase-Locked Loop），从系统晶振（如 32 MHz）倍频产生音频所需的高精度时钟（如 12.288 MHz 或 11.2896 MHz）。WQ 的 Kconfig 中 `CONFIG_AUDIO_CLOCK` 选择音频 PLL 频率 |
| 整数分频 | 时钟分频器只能产生整数分频比。WQ `bbb/hw/i2s.c` 中的 `i2s_set_frequence()` 根据采样率和位宽计算 BCLK 分频值。如果 PLL 频率不能被 BCLK 整除，实际 BCLK 会有偏差 |
| 44.1k vs 48k 系列 | 音频行业的两大采样率家族。44.1k 系列（44.1k/88.2k/176.4k）需要 11.2896 MHz 或其倍数的 PLL；48k 系列（48k/96k/192k）需要 12.288 MHz 或其倍数。混用两个家族的 PLL 和采样率会导致分频不整除 |
| 时钟源选择 | WQ 的 `wq_i2s_mclk_src_t` 枚举选择 MCLK 的来源（内部 PLL 或外部引脚）。Slave 模式下 BCLK/LRCK 来自外部引脚，不经过内部 PLL 分频器 |

## 时钟生成链路

```text
系统晶振（32 MHz）
  │
  └── 音频 PLL（倍频到 12.288 MHz 或 11.2896 MHz 等）
        │
        ├── MCLK 分频器 → MCLK 输出引脚（可选，Master 模式）
        │
        ├── BCLK 分频器 → BCLK 输出引脚（Master 模式）
        │                 BCLK 输入引脚（Slave 模式）
        │
        └── LRCK 分频器 → LRCK 输出引脚（Master 模式）
                          LRCK 输入引脚（Slave 模式）
                          LRCK = BCLK / (2 × bit_width)
```

**SDK 事实**：WQ 的 `bbb/hw/i2s.c` 中 `i2s_set_frequence()` 根据采样率、位宽和声道数计算 BCLK 分频值，写入硬件寄存器。LRCK 由 BCLK 进一步分频（2 × bit_width）得到，不需要独立配置。

## 场景一：WQ 作为 Master（I2S #2 → MAX98357A）

WQ 提供 BCLK 和 LRCK 给功放。时钟链路：

```text
WQ 内部音频 PLL → BCLK 分频器 → BCLK 输出引脚 → MAX98357A BCLK 输入
               → LRCK 分频器 → LRCK 输出引脚 → MAX98357A LRCLK 输入
```

WQ 需要配置：
- 音频 PLL 频率（如 12.288 MHz 支持 48k/96k 系列）
- BCLK 分频值（如 12.288M / 512k = 24）
- LRCK 由 BCLK / 32（16-bit × 2 声道）自动产生

## 场景二：WQ 作为 Slave（I2S #1 ← V861）

V861 提供 BCLK 和 LRCK，WQ 跟随。时钟链路：

```text
V861 内部音频 PLL → BCLK 分频器 → V861 BCLK 输出引脚 → WQ BCLK 输入引脚
                 → LRCK 分频器 → V861 LRCK 输出引脚 → WQ LRCK 输入引脚
```

WQ 不需要配置 PLL 或分频器——它从 BCLK/LRCK 输入引脚直接获取时钟。但如果 WQ 的内部 DSP 处理采样率和 V861 的 I2S 采样率不同（如 I2S 是 16 kHz 但 DSP 跑 48 kHz），需要 ASRC（异步采样率转换器）桥接两个时钟域。

**SDK 事实**：`aud_i2s_rx_open` 中，如果 `rx_data_dst == WQ_I2S_RX_DATA_DST_ASRC`，I2S 数据直接路由到 ASRC 而不是 RX FIFO，由 ASRC 处理后进入 DSP 的时钟域。

## 常见采样率对照表

| Fs | 家族 | LRCK | BCLK (16-bit × 2ch) | MCLK (×256) | 推荐 PLL |
|---|---|---|---|---|---|
| 16 kHz | 48k 系列 | 16 kHz | 512 kHz | 4.096 MHz | 12.288 MHz |
| 32 kHz | 48k 系列 | 32 kHz | 1.024 MHz | 8.192 MHz | 12.288 MHz |
| 48 kHz | 48k 系列 | 48 kHz | 1.536 MHz | 12.288 MHz | 12.288 MHz |
| 44.1 kHz | 44.1k 系列 | 44.1 kHz | 1.4112 MHz | 11.2896 MHz | 11.2896 MHz |

**关键约束**：如果 PLL = 12.288 MHz 但采样率 = 44.1 kHz，BCLK = 1.4112 MHz，12.288M / 1.4112M = 8.707...——不整除！实际 BCLK 会有偏差，导致音频失真。44.1k 和 48k 家族必须匹配对应的 PLL 频率。

## 参考资料

- [[i2s-protocol-I2S协议]] — 时钟树所属的协议主文档
- [[wq7036ax-audio-pipeline-WQ7036AX音频管道]] — 时钟配置在音频初始化中的位置

#flashcard

问：为什么 44.1 kHz 和 48 kHz 需要不同的 PLL 频率？
答：44.1k 系列需要 11.2896 MHz 的 PLL 才能整除；48k 系列需要 12.288 MHz。混用会导致分频不整除，实际 BCLK 偏离目标值，音频失真。