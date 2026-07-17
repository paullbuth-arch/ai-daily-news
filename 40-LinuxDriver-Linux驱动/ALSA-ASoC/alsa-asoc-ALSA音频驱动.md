# ALSA ASoC 音频驱动

**一句话结论（20% 核心）**：ALSA 是 Linux 音频子系统，ASoC（ALSA System on Chip）是嵌入式音频框架。ASoC 把音频驱动拆成三层：Codec（编解码芯片驱动）、Platform（SoC 音频接口驱动）、Machine（板级连接）。芯片厂商写好 Codec 和 Platform，你写 Machine 层描述它们怎么连在一起。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：音响系统的三个组件

- **Codec 驱动** = 功放说明书：这个功放支持什么格式（16bit/24bit）、支持什么采样率（44.1k/48k）、怎么调音量、怎么静音
- **Platform 驱动** = 播放器的音频输出口：这个播放器怎么输出 I2S 数据、DMA 怎么搬数据、支持几个声道
- **Machine 驱动** = 连接线 + 系统集成：功放和播放器之间哪根线接哪根、时钟从哪来、上电时序

**你是 Machine 层的作者**：Codec 和 Platform 通常芯片厂商已写好，你只需写 Machine 驱动告诉系统"这个 Codec 和这个 Platform 通过 I2S 连接在一起，时钟从 Platform 来"。

### 1.2 ASoC 三层架构详解

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

### 1.3 DAI（Digital Audio Interface）：音频链路的抽象

每个 Codec 和 Platform 都有一个或多个 DAI。DAI 是音频数据进出芯片的"接口"。

```
Machine 驱动中的 DAI Link:
┌──────────────────────────────────────────┐
│  CPU DAI (Platform 侧)                    │
│  e.g. "sunxi-i2s-dai.0"                 │
│  ↓ I2S 总线                               │
│  CODEC DAI (Codec 侧)                    │
│  e.g. "max98357a-dai"                    │
└──────────────────────────────────────────┘
```

### 1.4 如果只记得一件事

> ASoC = Codec（芯片驱动）+ Platform（SoC 接口）+ Machine（板级连接，你来写）。Machine 驱动的核心是定义 `snd_soc_dai_link`，把 CPU DAI（Platform 侧）和 CODEC DAI（Codec 侧）配对。

---

## 第二层：实战理解

### 2.1 完整的 Machine 驱动示例

```c
#include <sound/soc.h>

// ① 定义 DAI Link：连接 CPU DAI 和 CODEC DAI
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

// ② 定义声卡
static struct snd_soc_card my_card = {
    .name       = "ReGlasses-SoundCard",
    .owner      = THIS_MODULE,
    .dai_link   = my_dai_links,
    .num_links  = ARRAY_SIZE(my_dai_links),
};

// ③ Machine 驱动 probe
static int my_probe(struct platform_device *pdev) {
    struct snd_soc_card *card = &my_card;
    card->dev = &pdev->dev;

    // 注册声卡
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

### 2.2 DAI fmt 的三个组成部分

```c
.dai_fmt = SND_SOC_DAIFMT_I2S           // ① 格式
         | SND_SOC_DAIFMT_NB_NF          // ② 时钟关系
         | SND_SOC_DAIFMT_CBS_CFS,       // ③ Master/Slave

// ① 格式（数据怎么对齐）
// I2S: 标准 Philips 格式
// LEFT_J: 左对齐
// DSP_A / DSP_B: DSP 模式

// ② 时钟关系
// NB_NF: Normal Bit clock, Normal Frame sync
// NB_IF: Normal Bit clock, Inverted Frame sync

// ③ Master/Slave
// CBS_CFS: Codec BCLK Slave, Codec FSYNC Slave (Codec 是 Slave)
// CBM_CFM: Codec BCLK Master, Codec FSYNC Master (Codec 是 Master)
```

### 2.3 常见坑（附排查方法）

| 问题 | 现象 | 排查方法 | 根因 |
|------|------|---------|------|
| DAI 名称不匹配 | 声卡注册失败，dmesg 中无 sound card | `cat /proc/asound/cards` 看声卡是否出现 | cpu_dai_name 和 Platform 驱动中定义的不一致 |
| 时钟没配 | 音频播放全是噪音 | 示波器看 BCLK/LRCK 频率 | I2S 时钟源没配置，或频率不对 |
| dai_fmt 配错 | 左右声道互换或数据偏移 | 逻辑分析仪看 LRCK 和 DATA 时序 | I2S 格式选择错误 |
| 采样率不支持 | aplay 报错 | 查看 Codec 驱动的 DAI 支持的采样率列表 | 硬件不支持该采样率 |

### 2.4 在 reGlasses 项目中怎么用

WQ7036AX 侧跑 FreeRTOS，音频管理走 `aud_sv_api`（Audio Service），不是 ALSA。V881 侧跑 Linux，音频播放走 ALSA ASoC。V881↔WQ7036AX 之间的 I2S 音频数据交换，在 V881 侧需要 Machine 驱动描述连接关系。

**reGlasses 的两条音频路径对应两个 DAI Link**：
1. V881(I2S) → WQ7036AX(I2S Slave)：V881 播放音频，WQ7036AX 接收后送功放
2. WQ7036AX(I2S) → V881(I2S)：WQ7036AX 采集的音频送给 V881

---

## 第三层：深入扩展

### 3.1 ALSA 控制接口（kcontrol / mixer）

```c
// 定义音量控制
static const struct snd_kcontrol_new my_controls[] = {
    SOC_SINGLE("Master Volume", 0, 0, 127, 0, 0),  // 寄存器 0, 0-127
    SOC_SINGLE("Mic Boost", 1, 0, 3, 0, 0),          // 寄存器 1, 0-3
};

// 在声卡中注册
static struct snd_soc_card my_card = {
    .controls     = my_controls,
    .num_controls = ARRAY_SIZE(my_controls),
};
// 用户空间: amixer set "Master Volume" 100
```

### 3.2 常见问题

- **ASoC 和 ALSA 的关系？** ALSA 是 Linux 音频子系统的基础层，ASoC 是 ALSA 上的嵌入式框架。ASoC 简化了 ALSA 在嵌入式 SoC 上的使用。
- **DAI 和 DAI Link 的关系？** DAI 是单个芯片的音频接口（CPU 有一个 DAI，Codec 有一个 DAI），DAI Link 是 Machine 驱动中把两个 DAI 连接起来的桥梁。
- **为什么需要 Machine 驱动？** 因为 Codec 和 Platform 驱动不知道彼此的存在。Machine 驱动的作用就是告诉内核"这个 Codec 和这个 Platform 通过 I2S 连接在一起"。

### 3.3 延伸阅读

- [[i2s-protocol-I2S协议]] — I2S 协议基础和时钟配置
- [[wq7036ax-audio-pipeline-WQ7036AX音频管道]] — WQ7036AX 侧的音频处理链
- [[devicetree-DeviceTree设备树]] — Machine 驱动在设备树中的声明