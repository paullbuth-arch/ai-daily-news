---
type: concept
created: 2026-07-16
tags: [protocol, pdm, dmic, microphone, 数字麦克风, 音频采集]
aliases: [PDM, Pulse Density Modulation, DMIC, 数字麦克风]
---

# PDM 麦克风

## 一句话理解

PDM (Pulse Density Modulation，脉冲密度调制) 就像**用鼓点记录音乐**：声音高的时候鼓点密集，声音低的时候鼓点稀疏。只需要 2 根线 (CLK + DATA) 就能把声音从麦克风送进芯片——比 [[I2S 协议|I2S]] 还少一根线。

## 为什么学它

reGlasses 有 **4 颗 PDM 数字麦克风** ([[SDM0103B 数字麦]]) 组成阵列，负责：
- 语音交互 (语音助手、唤醒词)
- 环境声音采集 (工业数据集)
- 通话音频

所有音频的起点都是 PDM，不懂它就看不懂音频链的源头。

## 第一步：理解 PDM 编码原理

```
模拟音频波形 (正弦波):
     ╱╲        ╱╲
    ╱  ╲      ╱  ╲
───╱────╲────╱────╲─── (0 线)

PDM 编码输出 (1-bit):
  11111000111100001111110011110000...
  ↑ 密 = 正幅度      ↑ 疏 = 负幅度
```

- 信号幅度高 → "1" 的密度大
- 信号幅度低 → "0" 的密度大
- 接收端通过 **Decimation Filter (抽取滤波器)** 还原为 PCM (多 bit 数字音频)

## PDM 时钟配置

在 SDK 中，Kconfig 的 `CONFIG_AUDIO_SPK_FB_REF_PDM_CLK_ENABLE` 控制 PDM 时钟使能，`MIC_BIAS` 配置麦克风偏置电压。

PDM 时钟关系：

| 参数 | 典型值 |
|------|--------|
| PDM CLK 频率 | 1.024 ~ 3.072 MHz |
| PCM 输出采样率 | CLK ÷ 64 或 CLK ÷ 128 |
| 如 CLK = 2.048MHz | PCM = 32kHz (÷64) 或 16kHz (÷128) |

## 第三步：理解 L/R 声道选择

PDM 麦克风通过 **L/R 引脚电平** 选择输出在 CLK 的哪个边沿：

```
L/R = GND → 数据在 CLK 上升沿输出 (左声道)
L/R = VDD → 数据在 CLK 下降沿输出 (右声道)
```

**这意味着一条 CLK + DATA 线可以同时传 2 路麦克风的数据！**

```
                    CLK 脉冲
                 ╱╲  ╱╲  ╱╲  ╱╲
上升沿 (↑) → MIC A 的数据    (L/R=GND)
下降沿 (↓) → MIC B 的数据    (L/R=VDD)
```

## reGlasses 麦克风阵列

```
        ┌──── 眼镜正面 ────┐
        │                  │
   U12  │   [TOF]  [广角]  │  U14
  (左前) │                  │ (右前)
        │                  │
   U13  │                  │  U15
  (左后) │                  │ (右后)
        └──────────────────┘
```

### 两组连接

```
左声道组 (MIC_BIAS_0 供电, WQ7036AX B5):
  DMIC_L1_CLK ──→ U12.CLK + U13.CLK
  DMIC_L1_DATA ←── U12.DATA + U13.DATA (L/R 区分前后)

右声道组 (MIC_BIAS_1 供电, WQ7036AX A7):
  DMIC_R1_CLK ──→ U14.CLK + U15.CLK
  DMIC_R1_DATA ←── U14.DATA + U15.DATA (L/R 区分前后)
```

| MIC | ref | 位置 | 声道组 | L/R |
|-----|-----|------|--------|-----|
| 左前 | U12 | 左侧朝内 | L1 | L (上升沿) |
| 左后 | U13 | 左侧朝内 | L1 | R (下降沿) |
| 右前 | U14 | 右侧朝内 | R1 | L (上升沿) |
| 右后 | U15 | 右侧朝内 | R1 | R (下降沿) |

## 第四步：数据从麦到手机的完整路径

```
SDM0103B (PDM 1-bit)
    │ PDM 流 (CLK+DATA)
    ↓
WQ7036AX PDM Controller (硬件)
    │ Decimation Filter (抽取滤波, PDM→PCM)
    ↓
PCM 16-bit 数据 (16kHz, 4ch)
    │
    ↓
DSP 处理链 (DCORE HiFi5)
    │ AEC (Acoustic Echo Cancellation, 回声消除)
    │ NR  (Noise Reduction, 降噪)
    │ AGC (Automatic Gain Control, 自动增益)
    │ VAD (Voice Activity Detection, 语音活动检测)
    ↓
Opus 编码器 (压缩到 16-32kbps)
    │
    ↓
WQ Protocol 帧封装 (TRANS_UP 帧)
    │
    ↓
BLE GATT Notify → 手机 APP
```

这就是 [[WQ7036AX 音频管道]] 的采集侧全链路。

## 验收标准

- [ ] 能解释 PDM 的编码原理 (1 的密度 = 信号幅度)
- [ ] 能说出 PDM 只需 2 根线 (CLK+DATA) 以及 L/R 选择机制
- [ ] 能画出 reGlasses 4 路麦的分组方式 (2 组 × 2 路)
- [ ] 能说出从麦到手机的完整数据流路径 (至少 5 步)

## 关联概念

- [[I2S 协议]] — 对比：I2S 传 PCM，PDM 传 1-bit 密度调制
- [[SDM0103B 数字麦]] — reGlasses 使用的具体麦克风
- [[WQ7036AX 音频管道]] — PDM 在完整音频链中的位置
- [[音频接口对比：I2S vs PDM]] — 两种接口全面对比
- [[数据流：声音从麦到手机]] — 完整数据流追踪

#flashcard
问：PDM 接口需要几根线？分别是什么？
答：2 根：CLK (时钟) 和 DATA (数据)。L/R 选择由麦克风芯片的 L/R 引脚电平决定。

问：一条 PDM CLK+DATA 线能同时传几路麦克风？原理是什么？
答：2 路。L/R=GND 的麦在 CLK 上升沿输出，L/R=VDD 的麦在下降沿输出，互不干扰。

问：PDM 数据进入 WQ7036AX 后，第一步处理是什么？
答：Decimation Filter (抽取滤波器)，把 1-bit PDM 流转换为多 bit PCM 数据。
