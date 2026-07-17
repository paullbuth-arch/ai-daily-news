---
type: concept
tags: [LinuxDriver, ALSA, ASoC, 音频驱动, Codec, Machine, I2S, 音频子系统]
aliases: [ALSA, ASoC, 音频驱动, 音频子系统, 声卡驱动, Codec驱动, Machine驱动]
---

# ALSA ASoC 音频驱动

## 一句话结论

ALSA 是 Linux 音频子系统，ASoC（ALSA System on Chip）是嵌入式音频框架。ASoC 把音频驱动拆成三层：Codec（编解码芯片驱动）、Platform（SoC 音频接口驱动）、Machine（板级连接）。芯片厂商写好 Codec 和 Platform，你写 Machine 层描述它们怎么连在一起。

## 30秒先看懂

- ASoC 将音频驱动分为三层：Codec 驱动（编解码芯片，如 MAX98357A 功放）、Platform 驱动（SoC 的 I2S 控制器）、Machine 驱动（板级连接，你来写）。
- Machine 驱动的核心是定义 `snd_soc_dai_link`，把 CPU DAI（Platform 侧）和 CODEC DAI（Codec 侧）配对，指定 I2S 格式和主从关系。
- `dai_fmt` 由三部分组成：数据格式（I2S/LEFT_J/DSP）、时钟极性（NB_NF/NB_IF）、主从角色（CBS_CFS/CBM_CFM）。
- 芯片厂商通常已经写好了 Codec 和 Platform 驱动，BSP 工程师只需要写 Machine 驱动和对应的设备树节点。
- 用户空间通过 `aplay`/`arecord` 播放/录音，通过 `alsamixer`/`amixer` 调节音量——这些最终都通过 ALSA 核心到达 ASoC 驱动层。

## 学完以后应该能做什么

**第一遍**
- 能说出 ASoC 的三层架构和每层的职责
- 能写出一个基本的 Machine 驱动（定义 snd_soc_dai_link）
- 能理解 dai_fmt 的三个组成部分及其含义

**进阶**
- 能调试音频问题（声卡不注册、播放噪音、无声音）
- 能添加 kcontrol 实现音量调节
- 能为新的硬件平台适配 ASoC 驱动

## 前置知识

- I2S 协议基础：BCLK、LRCK、DATA 三线时序
- 设备树基础：compatible、reg 属性
- 嵌入式音频硬件：Codec、功放、DAC/ADC

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|----------|
| 高级 Linux 音频架构 | ALSA (Advanced Linux Sound Architecture) | Linux 内核音频子系统，提供声卡、混音、PCM 播放/录音等功能 |
| 嵌入式音频框架 | ASoC (ALSA System on Chip) | 基于 ALSA 的嵌入式音频框架，将驱动分为 Codec/Platform/Machine 三层 |
| 编解码器 | Codec | 音频编解码芯片，负责 DAC（数字→模拟）和 ADC（模拟→数字） |
| 数字音频接口 | DAI (Digital Audio Interface) | 音频数据进出芯片的接口，通常是 I2S 接口 |
| DAI 连接 | DAI Link | Machine 驱动中把 CPU DAI 和 CODEC DAI 配对起来的连接 |
| 声卡 | Sound Card | 用户空间看到的音频设备，如 card0、card1 |
| 控制接口 | kcontrol | 通过 amixer 操作的控制项，如音量、静音、增益 |
| I2S 格式 | I2S Format | 数据在 BCLK/LRCK 上的对齐方式，包括标准 I2S、左对齐、DSP 模式 |
| 主时钟/位时钟/帧时钟 | MCLK/BCLK/LRCK | I2S 总线的三根时钟线：主时钟、位时钟（数据位对齐）、帧时钟（声道对齐） |

## 第一层：费曼心智模型

### 类比：音响系统的三个组件

- **Codec 驱动** = 功放说明书：这个功放支持什么格式（16bit/24bit）、支持什么采样率（44.1k/48k）、怎么调音量、怎么静音
- **Platform 驱动** = 播放器的音频输出口：这个播放器怎么输出 I2S 数据、DMA 怎么搬数据、支持几个声道
- **Machine 驱动** = 连接线 + 系统集成：功放和播放器之间哪根线接哪根、时钟从哪来、上电时序

**你是 Machine 层的作者**：Codec 和 Platform 通常芯片厂商已写好，你只需写 Machine 驱动告诉系统"这个 Codec 和这个 Platform 通过 I2S 连接在一起，时钟从 Platform 来"。

### 边界在哪里

- ASoC 只负责音频路径的建立和配置，不负责音频算法的实现（如 ANC、EQ、音效处理在 DSP 或应用层）
- Codec 驱动通常由芯片厂商提供（如 MAX98357A、WM8960），不需要自己写——除非你用了非常小众的 Codec
- Machine 驱动是板级相关的——换一个板子（即使同一颗 SoC 和 Codec），如果 I2S 引脚或时钟连接变了，Machine 驱动就要改
- ASoC 不处理非音频数据（如蓝牙 RFCOMM、I2C 控制命令）——这些由各自子系统处理

### 场景演练：V881 播放音频到 WQ7036AX

1. V881 的 CPU 从 Flash 读取 MP3 文件，解码得到 PCM 数据
2. Platform 驱动（`sun4i-i2s`）将 PCM 数据通过 DMA 送到 I2S 控制器
3. I2S 控制器通过 BCLK/LRCK/DATA 三线发送数据到 WQ7036AX
4. WQ7036AX 的 I2S 接口接收数据，通过音频管道（aud_sv_api）送到功放
5. 功放驱动扬声器，用户听到声音

这个过程中，V881 侧的 Machine 驱动需要定义 DAI Link：CPU DAI = `sunxi-i2s-dai.0`，CODEC DAI 在 WQ7036AX 侧（通过 I2S 连接，WQ7036AX 作为 I2S Slave）。

## 第二层：原理/时序/约束

### ASoC 三层架构详解

```
用户空间:  arecord / aplay / alsamixer / PulseAudio
              │
         ALSA Library (libasound)
              │
══════════════════════════════════ 系统调用层
              │
内核空间:   ALSA Core (sound/core/)
              │
         ASoC Core (sound/soc/)
              │
    ┌─────────┼─────────┐
    │    Machine 驱动    │  ← 你写这个：板级连接
    │  (sound/soc/<soc>/)│
    └──┬──────────────┬──┘
       │              │
  Codec 驱动     Platform 驱动
  (sound/soc/codecs/)   (sound/soc/<soc>/)
       │              │
  ┌────┴────┐    ┌────┴────┐
  │ 编解码芯片 │    │ SoC I2S  │
  │(MAX98357A)│    │ 控制器   │
  └─────────┘    └─────────┘
```

### DAI Link 的完整定义

```c
static struct snd_soc_dai_link my_dai_links[] = {
    {
        .name            = "I2S-Playback",
        .stream_name     = "HiFi Playback",
        .cpu_dai_name    = "sunxi-i2s-dai.0",      // Platform 的 DAI
        .platform_name   = "sunxi-i2s.0",           // Platform 设备
        .codec_dai_name  = "max98357a-dai",         // Codec 的 DAI
        .codec_name      = "max98357a.0-003b",      // Codec 设备
        .dai_fmt         = SND_SOC_DAIFMT_I2S       // I2S 格式
                          | SND_SOC_DAIFMT_NB_NF    // 标准模式
                          | SND_SOC_DAIFMT_CBS_CFS, // Codec Slave
    },
};
```

### DAI fmt 的三个组成部分

```c
.dai_fmt = SND_SOC_DAIFMT_I2S           // ① 格式：数据对齐方式
         | SND_SOC_DAIFMT_NB_NF          // ② 时钟极性：Normal Bit, Normal Frame
         | SND_SOC_DAIFMT_CBS_CFS,       // ③ 主从：Codec BCLK Slave, Codec FSYNC Slave

// ① 格式选择
// I2S:  标准 Philips 格式，数据在 LRCK 切换后延迟一个 BCLK 开始
// LEFT_J: 左对齐，数据在 LRCK 切换时立即开始
// DSP_A: DSP 模式，帧同步脉冲后紧跟数据

// ② 时钟极性
// NB_NF: Normal Bit clock, Normal Frame sync (BCLK 不反相, LRCK 不反相)
// NB_IF: Normal Bit clock, Inverted Frame sync
// IB_NF: Inverted Bit clock, Normal Frame sync

// ③ 主从角色
// CBS_CFS: Codec 是 BCLK Slave 和 FSYNC Slave（时钟由 SoC 提供）
// CBM_CFM: Codec 是 BCLK Master 和 FSYNC Master（时钟由 Codec 提供）
```

## 第三层：真实 SDK 代码

### V881 的 ASoC Platform 驱动（I2S 控制器）

文件路径：`/home/ys/aiglass/tina-v861/kernel/linux-6.6-xuantie/sound/soc/sunxi/sun4i-i2s.c`

这是全志 SoC 的 I2S 控制器驱动，实现了 Platform 层的功能：DMA 传输、I2S 时序配置、时钟管理等。V881 的 Machine 驱动会引用这个 Platform 驱动的 DAI 名称。

### WQ7036AX 的 I2S 硬件驱动（裸机风格）

文件路径：`/home/ys/wq7036a/wq-audio/wqcore/driver/audio/hornet/hw/i2s.c`

```c
void i2s_get_default_config(i2s_cfg_t *cfg)
{
    cfg->single_chan = false;
    cfg->slave_mode = false;
    cfg->i2s_mode = I2S_MODE_PHILIPS_MODE;
    cfg->bits_mode = I2S_SAMPLE_BITS_16BIT;
    cfg->sample_freq = 44100;
    cfg->bit_clk_num = 16;
    cfg->tdm_cfg.ws_format = WS_FORMAT_STANDARD;
    cfg->tdm_cfg.tdm_chn_num = 2;
    cfg->right_channel_first = false;
    cfg->pcm_mode = false;
    cfg->external_clk = 0;
    cfg->use_external_clk = false;
}

WQ_RET i2s_config_rx(const i2s_cfg_t *rx_cfg, uint8_t clk_div)
{
    // 根据时钟分频系数调整输出延迟
    if (clk_div <= I2S_FREQUENCE_DIV_NUM_4) {
        WR_REG_FIELD(rx_i2s_base[rx_i2s_module]->i2s_rx_conf,
                     reg_rx_mst_out_delay_ena, 1);
        WR_REG_FIELD(rx_i2s_base[rx_i2s_module]->i2s_rx_timing,
                     reg_rece_bck_out_delay, 2);
    }
    // 配置主从模式
    WR_REG_FIELD(rx_i2s_base[rx_i2s_module]->i2s_rx_conf,
                 reg_rece_slave_mod, rx_cfg->slave_mode ? 1 : 0);
}
```

这段代码展示了 WQ7036AX 的 I2S 配置 API，与 Linux 的 ASoC 框架不同，它是直接操作寄存器的方式。在 reGlasses 项目中，WQ7036AX 作为 I2S Slave 接收 V881 的音频数据，`slave_mode = true`。

### 完整的 Machine 驱动示例

```c
#include <sound/soc.h>

static struct snd_soc_dai_link my_dai_links[] = {
    {
        .name            = "I2S-Playback",
        .stream_name     = "HiFi Playback",
        .cpu_dai_name    = "sunxi-i2s-dai.0",
        .platform_name   = "sunxi-i2s.0",
        .codec_dai_name  = "max98357a-dai",
        .codec_name      = "max98357a.0-003b",
        .dai_fmt         = SND_SOC_DAIFMT_I2S
                          | SND_SOC_DAIFMT_NB_NF
                          | SND_SOC_DAIFMT_CBS_CFS,
    },
};

static struct snd_soc_card my_card = {
    .name       = "ReGlasses-SoundCard",
    .owner      = THIS_MODULE,
    .dai_link   = my_dai_links,
    .num_links  = ARRAY_SIZE(my_dai_links),
};

static int my_probe(struct platform_device *pdev) {
    struct snd_soc_card *card = &my_card;
    card->dev = &pdev->dev;
    return devm_snd_soc_register_card(&pdev->dev, card);
}

static const struct of_device_id my_of_match[] = {
    { .compatible = "reglasses,sound-card" },
    { }
};

static struct platform_driver my_machine_drv = {
    .probe  = my_probe,
    .driver = {
        .name = "reglasses-sound",
        .of_match_table = my_of_match,
    },
};
module_platform_driver(my_machine_drv);
```

## 第四层：正常/异常路径

### 正常路径

1. 驱动加载 → Machine 驱动 probe → 注册声卡
2. 用户空间 `aplay test.wav` → ALSA 核心 → ASoC → Platform 驱动启动 DMA → I2S 控制器发送数据
3. Codec 接收数据 → DAC 转换 → 功放输出 → 扬声器发声

### 异常路径

| 问题 | 现象 | 根因 | 排查方法 |
|------|------|------|----------|
| DAI 名称不匹配 | 声卡注册失败，dmesg 无 sound card | cpu_dai_name 和 Platform 驱动中定义的不一致 | `cat /proc/asound/cards` 看声卡是否出现 |
| 时钟没配 | 音频播放全是噪音 | I2S 时钟源没配置，或频率不对 | 示波器测 BCLK/LRCK 频率是否和采样率匹配 |
| dai_fmt 配错 | 左右声道互换或数据偏移 | I2S 格式选择错误 | 逻辑分析仪看 LRCK 和 DATA 时序 |
| 采样率不支持 | aplay 报错 | Codec 硬件不支持该采样率 | 查看 Codec 驱动的 DAI 支持的采样率列表 |
| DMA 通道冲突 | 播放卡顿或无声 | DMA 通道被其他设备占用 | 检查 DMA 引擎的使用情况 |
| Codec 未初始化 | 无声音输出 | Codec 的上电时序不对 | 检查 Codec 的电源和复位引脚配置 |

## 第五层：调试方法

### 查看声卡信息

```bash
# 查看声卡列表
cat /proc/asound/cards

# 查看声卡设备
ls -l /dev/snd/

# 查看 PCM 设备
cat /proc/asound/pcm

# 查看 Codec 信息
cat /proc/asound/card0/codec#0
```

### 音频播放测试

```bash
# 播放 WAV 文件
aplay -D hw:0,0 test.wav

# 录音
arecord -D hw:0,0 -f S16_LE -r 44100 -c 2 test.wav

# 查看混音器控制项
amixer contents

# 设置音量
amixer set "Master Volume" 80
```

### 调试工具

```bash
# 查看音频设备的 DAI 配置
cat /sys/kernel/debug/asoc/card0/dai_list

# 查看音频路径
cat /sys/kernel/debug/asoc/card0/codec_reg

# 使用逻辑分析仪抓取 I2S 信号
# BCLK: 位时钟，频率 = 采样率 × 位宽 × 声道数
# LRCK: 帧时钟，频率 = 采样率
# DATA: 数据线，MSB 对齐
```

## 第六层：实战练习

### 练习 1：写一个 Machine 驱动

假设 V881 使用 MAX98357A 功放（I2S 输入），通过 I2S0 接口连接。MAX98357A 在 I2C 总线 0 上，地址 0x3b。写一个完整的 Machine 驱动：
- 定义 `snd_soc_dai_link`，连接 CPU DAI 和 CODEC DAI
- 定义 `snd_soc_card` 声卡
- 实现 probe 函数注册声卡
- 定义 `of_match_table` 用于设备树匹配

### 练习 2：分析 WQ7036A 的 I2S 配置

阅读 `/home/ys/wq7036a/wq-audio/wqcore/driver/audio/hornet/hw/i2s.c`，回答：
- WQ7036A 的 I2S 支持哪些采样率？
- 如何配置 WQ7036A 为 I2S Slave 模式？
- I2S 的时钟分频是如何计算的？

### 练习 3：调试音频问题

假设你的 V881 板子 `aplay test.wav` 没有声音，但声卡已注册（`cat /proc/asound/cards` 能看到）。列出你的排查步骤（至少 6 步）。

### 练习 4：添加音量控制

在 Machine 驱动中添加一个 kcontrol，实现"Master Volume"控制，范围为 0-127，映射到 Codec 的某个寄存器。

## 自测与验收

1. ASoC 的三层架构是哪三层？每层的职责是什么？
2. Machine 驱动的核心工作是什么？`snd_soc_dai_link` 中需要定义哪些关键字段？
3. `dai_fmt` 由哪三个部分组成？`CBS_CFS` 和 `CBM_CFM` 分别代表什么？
4. DAI 和 DAI Link 的区别是什么？
5. 如果声卡注册失败，dmesg 中没有任何错误信息，最可能的原因是什么？

## 延伸阅读

- [[i2s-protocol-I2S协议]] — I2S 协议基础和时钟配置
- [[wq7036ax-audio-pipeline-WQ7036AX音频管道]] — WQ7036AX 侧的音频处理链
- [[devicetree-DeviceTree设备树]] — Machine 驱动在设备树中的声明
- [[platform-driver-外设驱动框架]] — Machine 驱动本质上是一个 platform driver

## #flashcard

Q: ASoC 的三层架构是哪三层？
A: Codec 驱动（编解码芯片驱动）、Platform 驱动（SoC 的 I2S 控制器驱动）、Machine 驱动（板级连接，描述 Codec 和 Platform 如何连接）。

Q: Machine 驱动的核心工作是什么？
A: 定义 `snd_soc_dai_link`，把 CPU DAI（Platform 侧）和 CODEC DAI（Codec 侧）配对，指定 I2S 格式、时钟极性、主从关系，然后注册声卡。

Q: `dai_fmt` 中的 `CBS_CFS` 和 `CBM_CFM` 分别代表什么？
A: CBS_CFS = Codec 是 BCLK Slave 和 FSYNC Slave（时钟由 SoC 提供）。CBM_CFM = Codec 是 BCLK Master 和 FSYNC Master（时钟由 Codec 提供）。

Q: DAI 和 DAI Link 的区别是什么？
A: DAI 是单个芯片的音频接口（CPU 有一个 DAI，Codec 有一个 DAI），DAI Link 是 Machine 驱动中把两个 DAI 连接起来的桥梁。

Q: 声卡已注册但没有声音，如何排查？
A: 1. 检查 `amixer contents` 看音量是否静音；2. 示波器测 BCLK/LRCK 是否有时钟；3. 测 DATA 线是否有数据；4. 检查 Codec 电源和复位引脚；5. 检查 `dmesg` 有无音频相关错误；6. 检查 DAI 名称是否匹配。