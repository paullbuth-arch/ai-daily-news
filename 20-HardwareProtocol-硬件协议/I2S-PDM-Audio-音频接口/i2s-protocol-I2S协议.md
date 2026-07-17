---
type: concept
created: 2026-07-16
tags: [protocol, i2s, audio, pcm, 音频总线]
aliases: [I2S, Inter-IC Sound, I²S]
---

# I2S 协议

**一句话结论（20% 核心）**：I2S 是专门传音频数据的 3 线总线——BCLK 提供节拍，LRCK 区分左右声道，DATA 传 PCM 音频数据。不需要地址、不需要打包，纯粹的音频搬运工。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：流水线传送带

I2S 就像一条**音频流水线传送带**：

- **BCLK（位时钟）** = 传送带的**节拍器**——每响一次，传送带往前挪一格（传 1 个 bit）
- **LRCK（左右声道时钟）** = 传送带上的**分界线**——高电平放左声道数据，低电平放右声道数据
- **DATA（数据线）** = 传送带上的**货物**——音频采样数据，一个 bit 接一个 bit 地流过

```
LRCK:  ┌───────────┐               ┌───────────┐
       │  左声道    │               │  右声道    │
───────┘           └───────────────┘           └─────

BCLK:  ╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲  (16 个脉冲传左声道，16 个传右声道)

DATA:  xx L15 L14 ... L0 xx R15 R14 ... R0 xx
       ↑                             ↑
    BCLK 上升沿采样               BCLK 上升沿采样
```

### 1.2 三根线各干什么？

| 信号 | 全称 | 一句话 | 方向 |
|---|---|---|---|
| **BCLK** | Bit Clock | 每个脉冲传 1 个 bit，所有数据传输的节拍 | Master→Slave |
| **LRCK** | Left-Right Clock | 高电平 = 左声道数据，低电平 = 右声道数据 | Master→Slave |
| **DATA** | Serial Data | 音频数据本身，高位（MSB）先发 | 发送方→接收方 |

### 1.3 时钟频率怎么算？

```
采样率 Fs = 16000 Hz（每秒采样 16000 次）
LRCK = Fs = 16 kHz
BCLK = 2（左右声道） × 16（位宽） × 16000（采样率） = 512 kHz
```

**举例**：16kHz 采样率、16-bit 位宽时，BCLK 是 512kHz。意味着每秒有 512,000 个时钟脉冲，每个脉冲传 1 个 bit。

### 1.4 Master vs Slave：谁提供节拍？

| 角色 | 谁提供 BCLK 和 LRCK | reGlasses 中的应用 |
|---|---|---|
| **Master** | 本端芯片提供时钟 | I2S #2：WQ7036AX → MAX98357A 功放 |
| **Slave** | 对端芯片提供时钟 | I2S #1：V881 提供时钟，WQ7036AX 跟随 |

**费曼类比**：Master 是**乐队指挥**，挥动指挥棒（BCLK/LRCK）；Slave 是**乐手**，跟着指挥的节奏演奏（在正确的时刻发送/采样数据）。

### 1.5 如果只记得一件事

> I2S = 3 根线：BCLK（节拍）、LRCK（左右切换）、DATA（音频数据）。Master 提供时钟，Slave 跟随。WQ7036AX 有两路 I2S：一路对 V881（Slave 模式），一路对功放（Master 模式）。

---

## 第二层：实战理解

### 2.1 reGlasses 中的两路 I2S

**I2S #1 — WQ7036AX ↔ V881（双向音频）**

```
V881 (Master，提供时钟)              WQ7036AX (Slave)
  BCLK ────────────────────────────→ 引脚 A17
  LRCK ────────────────────────────→ 引脚 B15
  DOUT ────(V881 播放的音频)───────→ 引脚 D17 (DIN0)
  DIN  ←───(WQ7036AX 采集的音频)──── 引脚 B16 (DOUT0)
```

**I2S #2 — WQ7036AX → MAX98357A 功放（单向，播放到扬声器）**

```
WQ7036AX (Master)                  MAX98357A 功放 × 2
  AMP_I2S_BCLK ──────────────────→ BCLK（两颗功放共享）
  AMP_I2S_LRCLK ─────────────────→ LRCLK
  AMP_I2S_DOUT ──────────────────→ DIN（左声道数据走 LRCK 高电平，右声道走低电平）
```

**为什么两颗功放可以共享一条 I2S？** 因为 LRCK 区分了左右声道：左声道功放只取 LRCK 高电平期间的数据，右声道功放只取低电平期间的数据。

### 2.2 WQ7036AX 的 I2S 配置

在 SDK 的 Kconfig 中配置（`defconfig.stereo.i2s`）：

| 配置项 | 当前值 | 含义 |
|---|---|---|
| I2S 采样率 | 16000 | 16kHz 采样率 |
| 数据格式 | 0（Philips 标准） | 最常见的 I2S 格式 |
| Master/Slave | Slave（I2S #1）/ Master（I2S #2） | 取决于对端是谁 |
| 传输方向 | 双向（I2S #1）/ 发送（I2S #2） | |

### 2.3 常见坑

| 问题 | 现象 | 根因 |
|---|---|---|
| BCLK 频率不对 | 音频全是噪音 | 采样率或位宽配置错误，时钟算错了 |
| Master/Slave 配反 | 没有声音 | 两端都在等对方提供时钟，或两端都在输出时钟 |
| LRCK 相位反了 | 左右声道互换 | LRCK 极性配置错误 |
| 数据格式不匹配 | 声音有杂音 | 一端用 I2S 格式，另一端用左对齐格式 |

---

## 第三层：深入扩展

### 3.1 I2S 数据格式

I2S 有多种数据格式，由 LRCK 和 DATA 的时序关系区分：

| 格式 | 特点 |
|---|---|
| **Philips I2S** | 数据在 LRCK 变化后的第 2 个 BCLK 开始（最常用） |
| Left-Justified | 数据在 LRCK 变化后立即开始 |
| Right-Justified | 数据右对齐到 LRCK 变化前 |
| DSP/PCM Mode | 用帧同步脉冲代替 LRCK |

### 3.2 常见问题

- **I2S 的 3 根线分别是什么？** BCLK（位时钟）、LRCK（左右声道/帧时钟）、DATA（串行数据）。
- **16kHz/16-bit 时 BCLK = ?** 512 kHz = 2 × 16 × 16000。
- **Master 和 Slave 的区别？** Master 提供 BCLK 和 LRCK，Slave 跟随外部时钟。
- **I2S 和 PDM 怎么选？** I2S 传 PCM 数据（多 bit），适合芯片间传输；PDM 传 1-bit 密度调制，适合麦克风到芯片。

### 3.3 核心术语表

| 英文 | 中文 | 说明 |
|---|---|---|
| I2S | 芯片间音频总线 | Inter-IC Sound |
| BCLK | 位时钟 | Bit Clock，每个脉冲传 1 bit |
| LRCK | 左右声道时钟 | Left-Right Clock，也称 WS (Word Select) |
| MCLK | 主时钟 | Master Clock，通常 = 256 × Fs，可选 |
| PCM | 脉冲编码调制 | Pulse Code Modulation，音频数据格式 |
| MSB | 最高有效位 | Most Significant Bit，I2S 先发高位 |
| TDM | 时分复用 | Time Division Multiplexing，多声道复用 |

### 3.4 延伸阅读

- [[i2s-clock-tree-I2S时钟树]] — MCLK/BCLK/LRCK 频率关系详解
- [[pdm-mic-PDM麦克风]] — 对比：PDM 只需 2 根线，I2S 需 3 根
- [[max98357a-MAX98357A功放]] — I2S #2 的接收端
- [[wq7036ax-audio-pipeline-WQ7036AX音频管道]] — I2S 在完整音频链中的位置
- [[i2s-vs-pdm-音频接口对比]] — 两种音频接口全面对比