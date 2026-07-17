# ALSA ASoC 音频驱动

**一句话结论（20% 核心）**：ALSA 是 Linux 音频子系统，ASoC 是嵌入式音频框架（ALSA System on Chip）。ASoC 把音频驱动拆成三层：Codec（编解码芯片驱动）、Platform（SoC 音频接口驱动）、Machine（板级连接）。你写音频驱动时，大部分时候在写 Machine 层。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：音响系统的三个组件

- **Codec 驱动** = 功放说明书：描述这个功放支持什么格式、怎么调音量
- **Platform 驱动** = 播放器说明书：描述这个播放器怎么输出 I2S 数据
- **Machine 驱动** = 连接线：描述功放和播放器之间怎么连接（哪根线接哪根线）

**你是 Machine 层的作者**：Codec 和 Platform 通常芯片厂商已经写好了，你只需要写 Machine 驱动告诉系统"这个 Codec 和这个 Platform 通过 I2S 连接在一起"。

### 1.2 ASoC 三层架构

```
用户空间:  arecord / aplay / alsamixer
              │
内核空间:   ALSA Core
              │
    ┌─────────┼─────────┐
    │    Machine 驱动    │  ← 你要写的（板级连接）
    └──┬──────────────┬──┘
       │              │
  Codec 驱动     Platform 驱动
  (编解码芯片)    (SoC 音频接口)
```

### 1.3 如果只记得一件事

> ASoC = Codec（编解码芯片）+ Platform（SoC 接口）+ Machine（板级连接）。你主要写 Machine 层，描述 Codec 和 Platform 怎么连接。

---

## 第二层：实战理解

### 2.1 最小 Machine 驱动

```c
// 描述 Codec 和 Platform 之间的音频链路（DAI）
static struct snd_soc_dai_link my_dai_link = {
    .name            = "I2S-Playback",
    .stream_name     = "Playback",
    .codec_dai_name  = "max98357a-dai",       // Codec 的 DAI 名称
    .codec_name      = "max98357a.0-003b",    // Codec 设备名
    .platform_name   = "sunxi-i2s.0",         // Platform（SoC I2S）设备名
    .cpu_dai_name    = "sunxi-i2s-dai.0",     // SoC 的 DAI 名称
};

static struct snd_soc_card my_card = {
    .name       = "MySoundCard",
    .owner      = THIS_MODULE,
    .dai_link   = &my_dai_link,
    .num_links  = 1,
};

static int my_probe(struct platform_device *pdev) {
    return devm_snd_soc_register_card(&pdev->dev, &my_card);
}
```

### 2.2 常见坑

| 问题 | 现象 | 根因 |
|------|------|------|
| DAI 名称不匹配 | 声卡注册失败 | codec_dai_name 和 Codec 驱动里定义的不一致 |
| 时钟没配 | 音频全是噪音 | I2S 的 BCLK/LRCK 频率不对 |
| 采样率不支持 | 播放失败 | Codec 或 Platform 不支持该采样率 |

### 2.3 在 reGlasses 项目中怎么用

WQ7036AX 侧跑 FreeRTOS，音频管理走 `aud_sv_api`（Audio Service），不是 ALSA。V881 侧跑 Linux，音频播放走 ALSA ASoC。V881 和 WQ7036AX 之间通过 I2S 交换音频数据，V881 侧的 I2S 驱动就是 ASoC Machine 驱动。

---

## 第三层：延伸阅读

- [[i2s-protocol-I2S协议]] — I2S 协议基础
- [[wq7036ax-audio-pipeline-WQ7036AX音频管道]] — WQ7036AX 侧的音频处理