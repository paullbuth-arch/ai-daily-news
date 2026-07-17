---
type: concept
tags: [音频, PCM, I2S, PDM, 编解码, 嵌入式音频, DSP]
aliases: [音频系统, Audio System, 数字音频, 音频基础]
---

# 音频系统基础

## 一句话结论

嵌入式音频系统 = 麦克风采集 → 音频接口（PDM/I2S）传输 → DSP 处理 → 编解码压缩 → 输出/传输。整条链路的每个节点都有**采样率、位深、时钟**三个约束，理解这三个参数就能看懂任何音频问题。

## 30秒先看懂

1. 数字音频三要素：采样率（每秒拍多少张快照）、位深（每张快照多精细）、通道数（同时录几个方向）。
2. 未压缩音频带宽 = 采样率 × 位深 × 通道数，例如 16kHz/16bit/单声道 = 256kbps。
3. PDM 是麦克风的原始输出（1-bit 高频信号），I2S 是芯片间传输 PCM 的标准接口（多 bit）。
4. 音频延迟从麦克风到播放，由每个环节累加（采集 1ms + DSP 5-20ms + 编码 20ms + 传输 + 解码 20ms）。
5. 通话场景总延迟必须 < 150ms，所以用 HFP/SCO（经典蓝牙同步链路）而不是 BLE GATT（尽力而为）。

## 学完以后应该能做什么

### 第一遍
- 计算未压缩音频的带宽需求（采样率 × 位深 × 通道数）
- 理解 PDM 和 I2S 的区别，知道各自用在音频链路的哪个环节
- 理解音频延迟的来源和累加关系
- 知道为什么通话场景对延迟敏感

### 进阶
- 设计音频处理链（PDM → PCM → DSP → 编码 → 传输）
- 理解 AEC 的原理和延迟约束
- 配置 I2S 时钟（MCLK/BCLK/LRCK 的数学关系）
- 在 WQ7036AX 上调试音频管道

## 前置知识

- 基本的模拟信号和数字信号概念
- 频率、带宽的基本概念
- 嵌入式系统中的时钟和中断概念

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 脉冲编码调制 | PCM | 标准数字音频格式，用固定采样率对模拟信号量化 |
| 脉冲密度调制 | PDM | 麦克风原始 1-bit 输出，采样率极高（如 3.072MHz） |
| 芯片间音频总线 | I2S | 传输 PCM 数字音频的标准接口，3 线制（BCLK+LRCK+DATA） |
| 采样率 | Sample Rate | 每秒对模拟信号采样的次数，单位 Hz |
| 位深 | Bit Depth | 每个采样值的量化精度，单位 bit |
| 抽取滤波 | Decimation | 将 PDM 高频 1-bit 流转换为标准 PCM 多-bit 信号的过程 |
| 声学回声消除 | AEC | 从麦克风信号中减去扬声器播放信号的算法 |
| 语音活动检测 | VAD | 检测是否有人在说话，静音时停止编码传输以省电 |
| 编解码器 | Codec | 压缩/解压缩数字音频的算法或硬件 |
| 延迟 | Latency | 从音频输入到输出的总时间 |

## 第一层：费曼心智模型

### 类比：拍电影

把数字音频想象成**拍电影**：

| 电影 | 音频 | 含义 |
|------|------|------|
| 帧率 (24fps) | **采样率** (Sample Rate) | 每秒"拍"多少次 |
| 分辨率 (1080p) | **位深** (Bit Depth) | 每次"拍"多精细 |
| 单机位/多机位 | **通道数** (Channels) | 同时录几个方向 |

```
模拟声波 (连续):  ∿∿∿∿∿∿∿
                      ↓ 采样 (每秒 16000 次)
数字音频 (离散):  [1234] [1256] [1198] [1302] ...
                  每个数字是一个 PCM 采样值 (16-bit)
```

### 边界

- 采样率不是越高越好：高采样率意味着更多数据，对传输和存储压力更大。语音通信 16kHz 足够，音乐才需要 44.1kHz 以上。
- 位深不是越深越好：16bit 动态范围 96dB，24bit 是 144dB。在噪声环境中（如户外），16bit 足够。
- PDM 和 I2S 不能混用：PDM 需要 decimation filter 转 PCM 后才能用 I2S 传输。
- 延迟不是越低越好：延迟越低，编码效率越低（短帧压缩率差）。

### 场景推演：微信通话

当用户在 reGlasses 上接听微信电话时：
1. 四个 PDM 麦克风采集语音（PDM 信号，3.072MHz 1-bit 串行流）
2. WQ7036AX 的 DCORE 将 PDM 转换（decimation）为 PCM（16kHz 16bit）
3. DSP 处理：AEC 消除扬声器回声 → 降噪 → AGC 自动增益 → 波束成形
4. 通过 HFP/SCO（经典蓝牙同步链路）传输到手机
5. 手机将音频传给微信，对方听到清晰的声音

整个链路延迟必须 < 150ms，否则通话体验差。

## 第二层：原理/时序/约束

### 奈奎斯特采样定理

**定理**：采样率必须 ≥ 2 × 信号最高频率，否则会出现**混叠 (Aliasing)**——高频信号被错误地还原为低频信号。

| 场景 | 人耳范围 | 最低采样率 | 实际采用 |
|------|----------|-----------|----------|
| 电话语音 | 300-3400 Hz | 8 kHz | 8 kHz |
| 宽带语音 | 50-7000 Hz | 16 kHz | 16 kHz |
| CD 音质 | 20-20000 Hz | 44.1 kHz | 44.1 kHz |
| 专业音频 | 20-20000 Hz | 48 kHz | 48/96 kHz |

### 带宽速算

```
带宽 = 采样率 × 位深 × 通道数

例：16kHz × 16bit × 1ch = 256 kbps (未压缩)
例：48kHz × 24bit × 2ch = 2.3 Mbps (未压缩 CD 音质)
例：8kHz × 16bit × 1ch = 128 kbps (传统电话)
```

### PDM vs I2S

| 维度 | PDM | I2S |
|------|------|---------|
| **信号线** | 2 根 (CLK + DATA) | 3 根 (BCLK + LRCK + DATA) |
| **数据格式** | 1-bit 密度调制 | 16/24-bit PCM |
| **需要转换** | 是 (Decimation Filter → PCM) | 否 (直接可用) |
| **适用场景** | 麦克风 → 芯片 | 芯片 → 芯片 / 芯片 → 功放 |
| **reGlasses 用在哪** | SDM0103B ×4 (采集) | MAX98357A (播放) + V881 (交换) |

```
音频采集链:
  声波 → PDM 麦克风 → [PDM 接口] → Decimation → PCM → [I2S] → DSP / 传输

音频播放链:
  数据源 → PCM → [I2S] → 功放 → 扬声器
```

### I2S 时钟设计

I2S 的三个时钟之间有严格的数学关系：

```
MCLK = N × Fs  (N 通常为 256 或 128)
BCLK = 2 × BitDepth × Fs × Channels
LRCK = Fs
```

例如：16kHz 采样率，16bit，立体声：
- LRCK = 16kHz
- BCLK = 2 × 16 × 16000 × 2 = 1.024MHz
- MCLK = 256 × 16000 = 4.096MHz

### 音频延迟：从嘴到耳

```
麦克风采集 → PDM→PCM 转换 → DMA 搬运 → DSP 处理 → 编码 → 传输 → 解码 → 播放
  ~1ms         ~2ms          ~1ms       ~5-20ms    ~20ms  变化大  ~20ms  ~1ms
```

| 环节 | 延迟来源 | 典型值 |
|------|----------|--------|
| 采样缓冲 | 凑够一帧再处理 | 帧长 / 采样率 (20ms@16kHz/320 采样) |
| DMA/中断 | 搬运 + 调度 | 0.1-1ms |
| DSP 算法 | AEC/降噪/AGC 计算 | 1-10ms |
| 编解码器 | Opus/AAC 编码 | 5-40ms (取决于帧长和复杂度) |
| 蓝牙传输 | 空中 + 协议栈 | 20-200ms (BLE GATT) 或 20-40ms (HFP SCO) |

## 第三层：真实SDK代码

### WQ7036AX 音频管道

在 `/home/ys/wq7036a/wq-audio/wqcore/components/audsys/` 中，WQ7036AX 的音频系统接口：

```c
// 文件路径: wqcore/components/audsys/interface/audsys.h
// 音频系统初始化
int audsys_init(audsys_cfg_t *cfg);

// 音频采集管道配置
typedef struct {
    uint32_t sample_rate;      // 采样率: 8000/16000/48000
    uint8_t  channels;         // 通道数: 1/2/4
    uint8_t  bit_depth;        // 位深: 16/24/32
    uint8_t  mic_source;       // 麦克风源: PDM/I2S
    bool     enable_aec;       // 启用回声消除
    bool     enable_nr;        // 启用降噪
} audsys_capture_cfg_t;

int audsys_capture_start(audsys_capture_cfg_t *cfg);
int audsys_capture_stop(void);
```

### PDM 麦克风采集配置

在 `/home/ys/wq7036a/wq-audio/wqcore/driver/audio/` 中，PDM 接口驱动：

```c
// 伪代码——WQ7036AX PDM 接口配置
// 文件路径: wqcore/driver/audio/pdm/pdm_hal.h

// PDM 时钟配置
typedef struct {
    uint32_t clk_freq;          // PDM 时钟频率 (典型值 3.072MHz)
    uint8_t  decimation_ratio;  // 抽取比 (64/128/256)
    bool     stereo_mode;       // 立体声模式
} pdm_config_t;

// PDM 时钟频率决定最终采样率:
// 采样率 = PDM_CLK / decimation_ratio
// 例: 3.072MHz / 192 = 16kHz
```

### 完整的音频处理流水线

在 `/home/ys/wq7036a/wq-audio/wqcore/components/audsys/audsys_record.c` 中，音频采集的完整流程：

```c
// 伪代码——WQ7036AX 音频采集启动
// 文件路径: wqcore/components/audsys/audsys_record.c

int audsys_capture_start(audsys_capture_cfg_t *cfg) {
    // 1. 配置 PDM 接口（时钟频率、抽取比）
    pdm_config_t pdm_cfg = {
        .clk_freq = 3072000,        // 3.072MHz
        .decimation_ratio = 192,    // 16kHz 输出
        .stereo_mode = false,
    };
    pdm_init(&pdm_cfg);

    // 2. 配置 DMA 双缓冲传输
    dma_channel_config_t dma_cfg = {
        .src = pdm_get_data_addr(),
        .dst = audio_buffer,
        .buf_size = 320 * 2,        // 20ms @ 16kHz, 双缓冲
        .irq_callback = audio_dma_callback,
    };
    dma_channel_config(&dma_cfg, DMA_CHANNEL_AUDIO_IN);

    // 3. 启动 DMA 传输
    dma_channel_start(DMA_CHANNEL_AUDIO_IN);

    return 0;
}
```

## 第四层：正常/异常路径

### 正常路径

```
PDM 麦克风采集 → Decimation 转为 PCM
  → DMA 搬运到内存（双缓冲，中断通知）
  → DSP 处理（AEC → NR → AGC → Beamforming → VAD）
  → Opus 编码（每 20ms 一帧）
  → BLE 发送 / 本地存储
```

### 异常路径

| 异常 | 现象 | 触发条件 | 恢复方式 |
|------|------|---------|---------|
| 采样率不匹配 | 声音变速（变调） | 采集/处理/编码的采样率不一致 | 统一配置采样率 |
| 大小端弄反 | 数据全是噪声 | CPU 字节序和协议字节序不一致 | 确认字节序，必要时转换 |
| I2S 时钟不对 | 无声 / 爆音 | BCLK/MCLK 配置错误 | 确认 BCLK = 2 × 位深 × Fs × 通道数 |
| DMA 缓冲区太小 | 丢数据 / 断音 | 缓冲区不够双缓冲 | 增大缓冲区，确保足够处理时间 |
| AEC 信号延迟不对 | 回声消除失效 | 扬声器和麦克风信号未对齐 | 精确对齐时间戳 |
| PDM 时钟抖动 | 采样不稳定，噪声 | PDM CLK 质量差 | 检查 PDM 时钟源配置 |

## 第五层：调试方法

### 音频调试工具

```bash
# 查看音频设备
arecord -l
aplay -l

# 录制和播放测试（V881 Linux）
arecord -D hw:0,0 -f S16_LE -r 16000 -c 1 -t wav test.wav
aplay -D hw:0,0 test.wav

# 分析音频文件
ffprobe test.wav  # 查看采样率、位深、通道数
sox test.wav -n stat  # 统计分析

# 查看 ALSA 配置
cat /proc/asound/cards
amixer controls
```

### WQ7036AX 音频调试

```c
// 通过日志输出音频参数
printf("Audio config: %dHz/%dbit/%dch\n",
       cfg->sample_rate, cfg->bit_depth, cfg->channels);

// 检查音频缓冲区状态
printf("DMA buffer: pos=%d, remaining=%d\n",
       dma_get_pos(DMA_CHANNEL_AUDIO_IN),
       dma_get_remaining(DMA_CHANNEL_AUDIO_IN));
```

## 第六层：实战练习

### 练习1：计算音频带宽

计算以下场景的未压缩音频带宽，并说出对应的传输方式是否可行：
1. 16kHz/16bit/1ch → BLE 1Mbps 能否传输？
2. 48kHz/24bit/2ch → WiFi 50Mbps 能否传输？
3. 8kHz/16bit/1ch → 经典蓝牙 SCO 64kbps 能否传输？

### 练习2：I2S 时钟配置

给定采样率 48kHz，位深 24bit，立体声，计算：
1. LRCK 频率
2. BCLK 频率
3. MCLK 频率（假设 N=256）

### 练习3：阅读真实源码——WQ7036AX 音频管道

阅读 `/home/ys/wq7036a/wq-audio/wqcore/components/audsys/` 目录下的源码，分析：
1. 音频采集接口 `audsys_capture_start` 的完整流程
2. 音频数据从 PDM 到 PCM 的转换参数
3. DMA 双缓冲是如何配置的

## 自测与验收

1. 数字音频的三要素是什么？未压缩音频带宽如何计算？
2. 采样率为什么必须满足奈奎斯特定理？不满足会怎样？
3. PDM 和 I2S 有什么区别？分别用在音频链路的哪个环节？
4. 音频延迟的构成有哪些？为什么通话场景对延迟敏感？
5. I2S 的三个时钟（MCLK/BCLK/LRCK）之间有什么关系？
6. 什么是 AEC？为什么 AEC 对延迟抖动敏感？

## 延伸阅读

- [[wq7036ax-audio-pipeline-WQ7036AX音频管道]] — 项目中完整的音频处理链
- [[i2s-protocol-I2S协议]] — I2S 总线详解
- [[pdm-mic-PDM麦克风]] — PDM 接口详解
- [[i2s-clock-tree-I2S时钟树]] — I2S 时钟频率计算
- [[opus-codec-Opus编码]] — Opus 编解码器详解
- [[memory-dma-内存管理与DMA]] — DMA 双缓冲详解

## #flashcard

Q: 数字音频三要素是什么？如何计算未压缩带宽？
A: 采样率 × 位深 × 通道数。例：16kHz × 16bit × 1ch = 256kbps。

Q: 奈奎斯特定理的内容是什么？
A: 采样率必须 ≥ 2 × 信号最高频率，否则会出现混叠（Aliasing）。

Q: PDM 和 I2S 的区别？
A: PDM 是 1-bit 高采样率密度调制（麦克风原始输出），I2S 是多-bit PCM 标准传输接口（芯片间传输）。

Q: 音频延迟的主要来源？
A: 采样缓冲（帧长决定）、DMA 搬运、DSP 处理、编解码延迟、传输延迟。

Q: I2S 的 BCLK 如何计算？
A: BCLK = 2 × 位深 × 采样率 × 通道数。