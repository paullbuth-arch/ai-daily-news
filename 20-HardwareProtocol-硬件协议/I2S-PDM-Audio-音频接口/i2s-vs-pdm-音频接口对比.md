---
type: concept
created: 2026-07-17
tags: [comparison, i2s, pdm, audio, 对比, 音频接口, 选型]
aliases: [音频接口对比, I2S vs PDM]
---

# 音频接口对比：I2S vs PDM

> **一句话结论**：I2S 和 PDM 不是"谁更好"的问题，而是"谁适合哪个位置"。I2S 传多 bit PCM，适合芯片间音频传输（功放、SoC 互联）；PDM 传 1-bit 密度调制，适合麦克风到芯片的采集链路。reGlasses 在采集端用 PDM（4 颗数字麦→WQ），在播放端和芯片互联端用 I2S（WQ→功放、WQ↔V861），每条链路的选择都有可追溯的工程理由。

## 30 秒先看懂

I2S 和 PDM 不是谁更好，而是谁适合哪个位置。I2S 传多比特的 PCM 数据，适合芯片间传输和功放驱动；PDM 传一比特密度调制，适合麦克风到芯片的采集链路。初学者先记住：麦克风那头用 PDM（两根线就够了），芯片之间和功放那头用 I2S（需要标准 PCM 数据），两者通过抽取滤波器桥接。

本篇是 [[i2s-protocol-I2S协议]] 和 [[pdm-mic-PDM麦克风]] 的横向对比。具体协议细节见各篇，这里只讲对比和选型。

## 物理层对比

| 维度 | I2S | PDM |
|---|---|---|
| 信号线数 | 3（BCLK + LRCK + DATA）或 4（含 MCLK） | 2（CLK + DATA） |
| 数据格式 | PCM（多 bit，如 16/24/32-bit） | 1-bit 密度调制 |
| 编码方式 | 二进制补码，每个样本是一个固定宽度的二进制数 | 脉冲密度（'1'的比例 = 信号幅度） |
| 时钟频率 | BCLK = 2 × bit_width × Fs（如 16-bit 16kHz = 512 kHz） | CLK = OSR × Fs（如 OSR=64, 16kHz = 1.024 MHz） |
| 多路复用 | LRCK 交替：高电平=左声道，低电平=右声道 | L/R 引脚静态选择：CLK 上升沿=左，下降沿=右 |
| 接收端需要 | 无（PCM 直接可用） | 抽取滤波器（PDM → PCM） |
| 传输距离 | 适中（PCB 级，≤ 15 cm） | 短（麦克风到芯片，≤ 10 cm） |
| 抗噪性 | 一般（多 bit，每个 bit 错误影响不同） | 好（1-bit，每个 bit 权重相同） |

## 选型决策框架

**用 PDM 当：**
- 源端是数字 MEMS 麦克风（内部天然输出 PDM）
- 需要节省引脚（2 根线 vs I2S 的 3-4 根）
- 多麦克风阵列（每增加 2 颗麦只需 1 组 CLK+DATA，不增加 I2S 那样的 LRCK 槽位管理复杂度）
- 短距离（麦克风紧挨着芯片）

**用 I2S 当：**
- 接收端需要标准 PCM 数据（功放 DAC、SoC 音频接口）
- 芯片间传输（需要稳定的时钟模型和明确的主从角色）
- 需要高精度（16/24-bit 直接量化 vs PDM 依赖抽取滤波器的 SNR）
- 需要双向传输（I2S 支持独立 TX/RX 数据线，PDM 只支持单向麦克风→芯片）

## reGlasses 中的实际选择

| 链路 | 接口 | 为什么选这个 |
|---|---|---|
| 麦克风 → WQ7036AX | PDM | 麦克风天然输出 PDM；4 颗麦用 2 组 CLK+DATA = 4 根线；1-bit 数字信号抗 PCB 噪声 |
| WQ7036AX → MAX98357A 功放 | I2S | 功放需要标准 PCM 数据做 DAC；WQ 作为 Master 提供时钟，功放 Slave 跟随 |
| WQ7036AX ↔ V861 | I2S | 双向音频（上行+下行）；V861 作为 Master 提供时钟；PCM 格式双方通用，无需格式转换 |

## 数据流中的位置

```text
采集链路（PDM → PCM → 编码）：
  麦克风 (PDM 1-bit) → Decimation Filter → PCM 16-bit → DSP → Opus → BLE → 手机

播放链路（解码 → PCM → I2S → 模拟）：
  手机 → BLE → Opus 解码 → PCM 16-bit → I2S → 功放 DAC → 扬声器

芯片互联（双向 I2S）：
  WQ7036AX ←─ I2S（V861 为 Master）─→ V861
```

PDM 在最前端（采集），I2S 在最后端（播放）和中间（芯片互联）。中间全是 PCM 格式。

## 参考资料

- [[i2s-protocol-I2S协议]] — I2S 协议、时钟、数据格式、Master/Slave
- [[pdm-mic-PDM麦克风]] — PDM 编码、抽取滤波、L/R 选择、MICBIAS
- [[i2s-clock-tree-I2S时钟树]] — I2S 时钟生成链路和 PLL 分频
- [[wq7036ax-audio-pipeline-WQ7036AX音频管道]] — 两种接口在音频链中的位置

#flashcard

问：为什么麦克风用 PDM 而不用 I2S？
答：MEMS 麦克风天然输出 PDM 格式；PDM 只需 2 根线（比 I2S 少 1-2 根）；1-bit 数字信号抗 PCB 噪声；多麦克风阵列通过 L/R 边沿复用，布线简单。

问：PDM 数据怎么变成 PCM？
答：通过抽取滤波器（decimation filter），每 64 个（或 128 个）PDM bit 统计"1"的密度，换算为 PCM 样本值，同时滤除高频量化噪声。

问：I2S 和 PDM 的多路复用方式有什么不同？
答：I2S 用 LRCK 时钟交替切换左右声道（半个周期传一路）。PDM 用 L/R 静态引脚电平选择输出边沿（CLK 上升沿=左，下降沿=右，每个 CLK 周期同时采样两路）。