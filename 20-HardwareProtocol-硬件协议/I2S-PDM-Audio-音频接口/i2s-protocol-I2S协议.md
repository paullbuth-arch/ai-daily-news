---
type: concept
created: 2026-07-17
tags: [protocol, i2s, audio, pcm, 音频总线, 时钟]
aliases: [I2S, Inter-IC Sound, I²S, 音频串行总线]
---

# I2S 协议：从时钟树到 DMA 音频流

> **一句话结论**：I2S（Inter-IC Sound，芯片间音频总线）不是"三根线传音频"这么简单，它是一套由主时钟（MCLK）、位时钟（BCLK）和左右声道时钟（LRCK）的倍数关系、数据格式对齐（I2S/左对齐/右对齐/DSP）、Master/Slave 时钟角色、DMA 乒乓缓冲和采样率转换（ASRC）共同组成的同步音频传输协议。真正会用 I2S，意味着你能从采样率、位宽和声道数推导出所有时钟频率，在逻辑分析仪上区分左声道和右声道的数据位置，并追踪从麦克风采集到扬声器播放的完整音频链路。

本篇的代码锚点来自两个真实工程：

- **WQ7036AX**：`/home/ys/wq7036a/wq-audio/wqcore/driver/audio/declare/wq_i2s_declare.h`（API 声明）、`wqcore/components/audsys/device/aud_i2s.c`（音频设备层）、`wqcore/driver/audio/bbb/hw/i2s.c`（硬件层）。
- **V861/reGlasses**：`/home/ys/aiglass/reglasses/device/configs/reglasses/linux-6.6-xuantie/board.dts` 中 I2S0 配置（PH7-PH10，连接 WQ7036AX BT 音频）。

文中"通用原理"是 I2S 协议标准；"SDK 事实"只针对上述源码和配置；"待确认"标记表示尚未由当前源码或板级资料证实。

## 学完以后应该能做什么

1. 从采样率（Fs）、位宽（bit depth）和声道数计算出 BCLK 和 LRCK 的频率。
2. 解释 MCLK 为什么通常 = 256 × Fs，以及没有 MCLK 时（reGlasses I2S0）接收方如何工作。
3. 在逻辑分析仪上根据 LRCK 和 BCLK 的关系区分 I2S、左对齐、右对齐和 DSP 四种数据格式。
4. 区分 Master 和 Slave 的时钟责任，以及 Master/Slave 配反时的典型故障现象。
5. 看懂 WQ HAL 的 `wq_i2s_init/open/start/stop` 和 `aud_i2s` 设备层的调用路径。
6. 理解 I2S 的 DMA 乒乓缓冲机制，以及欠载（underrun）和溢出（overflow）的成因。
7. 追踪 reGlasses 中 V861 I2S0 → WQ7036AX 的音频链路配置。

## 前置知识

- 知道采样率（Fs）、位宽（bit depth）和 PCM 的基本概念；可先看 [[pcm-audio-PCM音频基础]]。
- 理解 DMA 传输和乒乓缓冲；可先看 [[dma-basics-DMA基础]]。
- 知道 GPIO 复用和引脚配置；可先看 [[gpio-config-GPIO配置]]。
- 如果要理解 WQ 的音频子系统，需要 [[wq7036ax-audio-pipeline-WQ7036AX音频管道]]。

## 术语先讲清楚

| 术语 | 英文 | 在 I2S 中具体指什么 |
|---|---|---|
| 采样率 | Fs（Sampling Frequency） | 每秒采集的音频样本数，如 16 kHz = 每秒 16000 个样本。LRCK 的频率 = Fs（两声道时） |
| 位时钟 | BCLK（Bit Clock） | 每个脉冲传输 1 个 bit。BCLK = 声道数 × 位宽 × Fs。16-bit 立体声 16kHz 时，BCLK = 2 × 16 × 16000 = 512 kHz |
| 左右声道时钟 | LRCK（Left-Right Clock）/ WS（Word Select） | 高电平期间传输左声道数据，低电平期间传输右声道数据。频率 = Fs。WQ 的 `wq_i2s_config_t` 中通过 `sample_rate` 枚举配置 |
| 主时钟 | MCLK（Master Clock） | 通常为 256 × Fs 的高频时钟，用作内部 delta-sigma 调制器或 ASRC 的参考。不是所有 I2S 链路都需要 MCLK——reGlasses I2S0 注释明确写"no MCLK" |
| Master | 时钟提供方 | 产生 BCLK 和 LRCK 的一方。由 Master 决定采样率和位宽，Slave 跟随。WQ 的 `wq_i2s_config_t` 中 `work_mode` 字段配置 Master 或 Slave |
| Slave | 时钟跟随方 | 使用外部提供的 BCLK 和 LRCK。Slave 必须在外部时钟的边沿上发送或采样数据，不能自己决定时钟频率 |
| I2S 格式 | Philips I2S format | 数据在 LRCK 变化后的第 2 个 BCLK 开始，MSB 先发。这是最常见的格式，也是 WQ 和 reGlasses 的默认格式 |
| 左对齐格式 | Left-Justified | 数据在 LRCK 变化后立即开始（第 1 个 BCLK），MSB 先发。与 I2S 格式差 1 个 BCLK 的偏移 |
| 右对齐格式 | Right-Justified | 数据的 LSB 对齐到 LRCK 变化前的最后一个 BCLK |
| DSP/PCM 模式 | DSP mode | 用帧同步脉冲（宽度 1 个 BCLK）代替 LRCK 的 50% 占空比，数据在帧同步后第 1 个 BCLK 开始 |
| TDM | Time Division Multiplexing | 时分复用，在同一个 LRCK 周期内通过多个数据槽（slot）传输多于 2 个声道。WQ 支持 `wq_i2s_tdm_mode_config_t` |
| ASRC | Asynchronous Sample Rate Converter | 异步采样率转换器，用于桥接两个时钟域不同的音频系统。WQ 的 `aud_i2s_rx_open` 中 I2S 数据可以路由到 ASRC |
| 欠载/溢出 | underrun / overflow | DMA 没有及时向 TX FIFO 填数据导致发送中断（欠载），或 DMA 没有及时从 RX FIFO 取数据导致新数据覆盖旧数据（溢出）。在音频中表现为爆音、断音 |

---

## 第一层：用费曼技巧建立心智模型

### 1.1 I2S 像一条音频流水线传送带——类比及其边界

把 I2S 想成一条音频流水线传送带，但需要把时钟的层次关系带入：

- **BCLK** 是传送带的节拍器。每一声"滴"（一个 BCLK 脉冲），传送带往前挪一格，传送带上的货物（音频数据）往前移 1 个 bit。节拍器的速度 = 2 × 位宽 × 采样率。
- **LRCK** 是传送带上的分界线。分界线在"高"位置时（LRCK=1），传送带上的货物属于左声道；分界线在"低"位置时（LRCK=0），货物属于右声道。分界线每秒切换 2 × Fs 次（一次左、一次右 = 一个完整采样周期）。
- **DATA** 是传送带上的货物本身——PCM 音频样本的最高位（MSB）先出发，最低位（LSB）最后出发。
- **MCLK** 是传送带后面那个大齿轮的转速。大齿轮转 256 圈，传送带正好完成一个采样周期（1/Fs）。MCLK 不是必须的——如果接收方内部有自己的 PLL（锁相环），可以从 BCLK 恢复出内部时钟，就不需要 MCLK。

这个类比的关键边界：

**边界一：货物的排列顺序必须双方约定好。** 如果发送方把货物放在分界线切换后的第 2 个位置（I2S 格式），但接收方以为在第 1 个位置（左对齐格式），接收方会把同一个货物的最高位当成了最低位（或者反过来），这就是"数据格式不匹配"——声音不会完全没有，但全是噪音。

**边界二：节拍器（BCLK）由 Master 控制，Slave 无权决定。** 如果配置为 Slave 的设备没有收到 BCLK，它不会发送任何数据——它没有自己的时钟去驱动传送带。如果两端都配置为 Master，两个 BCLK 信号会冲突（短路），导致两端都出问题。

**边界三：传送带的速度必须精确匹配采样率。** BCLK 的频率 = 2 × bit_width × Fs。如果晶振偏差导致实际 BCLK 偏了 1%，在 16kHz 采样率下，每个采样周期的偏差是 1% × 1/16000 = 0.625 μs——看似不大，但累积几百毫秒后，DMA 缓冲区的消耗速度会偏离预期，最终导致缓冲区欠载或溢出。

### 1.2 完整场景演算：16kHz/16-bit 立体声 I2S 的每一步

这是理解 I2S 时钟关系最关键的场景。假设 WQ7036AX 作为 Master，以 16 kHz 采样率、16-bit 位宽、I2S 格式向 MAX98357A 功放发送立体声音频。

**第一步：时钟频率计算。**

```text
Fs = 16000 Hz                 → LRCK = 16000 Hz
立体声 = 2 声道
位宽 = 16 bit

BCLK = 2 × 16 × 16000 = 512000 Hz = 512 kHz
MCLK = 256 × 16000 = 4096000 Hz = 4.096 MHz（如果使用外部 MCLK）

每个 LRCK 周期 = 1/16000 = 62.5 μs
每个 BCLK 周期 = 1/512000 ≈ 1.95 μs
每个声道传输 16 bit，耗时 16 × 1.95 = 31.25 μs（正好是半个 LRCK 周期）
```

**SDK 事实**：WQ 的 `wq_i2s_config_t` 中 `sample_rate` 枚举（如 `WQ_I2S_SAMPLE_RATE_16000`）配置 Fs，`data_format` 配置位宽和对齐方式。硬件层 `i2s.c` 根据这些参数计算分频值，配置 BCLK 分频器。

**第二步：LRCK 切换，左声道数据开始传输。**

```text
LRCK 从低变高（左声道开始）。
在 I2S 格式下，数据不立即开始——等待 1 个 BCLK 的延迟后，在第 2 个 BCLK 开始发送 MSB。
BCLK 第 2 个脉冲：DATA 线上输出左声道样本的 bit 15（MSB）。
BCLK 第 3 个脉冲：DATA 线上输出 bit 14。
...
BCLK 第 17 个脉冲：DATA 线上输出 bit 0（LSB）。
左声道 16 bit 传输完成。
```

**第三步：LRCK 再次切换，右声道数据开始传输。**

```text
LRCK 从高变低（右声道开始）。
同样等待 1 个 BCLK 延迟，在第 2 个 BCLK 开始发送 MSB。
BCLK 第 18+2=20 个脉冲：DATA 线上输出右声道样本的 bit 15（MSB）。
...
BCLK 第 18+17=35 个脉冲：DATA 线上输出 bit 0（LSB）。
```

**第四步：一个完整采样周期结束。**

```text
LRCK 从低变高（下一个左声道开始）。
一个完整的 LRCK 周期 = 32 个 BCLK = 2 × 16 bit。
如果位宽是 24 bit，一个 LRCK 周期 = 64 个 BCLK（2 × 24 + 额外填充）。
注意：BCLK 的数量不一定等于实际有效数据 bit 数——I2S 允许 BCLK 多于有效 bit 数，
多余的 bit 被忽略或用 0 填充。这就是为什么 16-bit 数据可以用 32-bit 槽传输。
```

### 1.3 四种数据格式的 LRCK-DATA 时序关系

```text
I2S 格式（Philips 标准）：
LRCK: ___/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\___________
DATA: xxx MSB .......... LSB xxx
        ↑ 延迟 1 BCLK 后开始

左对齐格式（Left-Justified）：
LRCK: ___/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\___________
DATA: MSB .......... LSB xxxxxx
        ↑ 立即开始

右对齐格式（Right-Justified）：
LRCK: ___/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\___________
DATA: xxxxxx MSB .......... LSB
                         ↑ 对齐到 LRCK 切换前

DSP/PCM 模式：
LRCK: ___/‾\___________________________  （帧同步脉冲，宽度 1 BCLK）
DATA:  MSB .......... LSB MSB .......... LSB
        ↑ 帧同步后第 1 个 BCLK 开始，无左右声道区分，按槽位区分
```

**SDK 事实**：WQ 的 `wq_i2s_data_format_t`（定义在 `wq_audio_resource.h` 中）枚举了支持的格式。reGlasses V861 的 `board.dts:911` 配置 `soundcard-mach,format = "i2s"`——使用标准 Philips I2S 格式。

### 1.4 Master/Slave 的时钟责任

```text
Master 模式（WQ 提供时钟）：
  WQ 内部 PLL → 分频器 → BCLK（输出到引脚）
                       → LRCK（输出到引脚）
                       → MCLK（可选，输出到引脚）
  外设（如功放）使用 WQ 提供的 BCLK/LRCK 作为采样时钟。

Slave 模式（WQ 跟随外部时钟）：
  外部设备（如 V861）→ BCLK（输入到 WQ 引脚）
                     → LRCK（输入到 WQ 引脚）
  WQ 内部的 BCLK/LRCK 信号来自 GPIO 输入，不经过内部 PLL。
  WQ 在 BCLK 的边沿上采样/发送数据。
```

**SDK 事实**：WQ 的 `wq_i2s_work_mode_t` 配置 Master 或 Slave。reGlasses 的 `board.dts:913-914` 配置 `soundcard-mach,frame-master = <&i2s0_cpu>` 和 `soundcard-mach,bitclock-master = <&i2s0_cpu>`——V861 作为 Master 提供 BCLK 和 LRCK，WQ7036AX 作为 Slave 跟随。

**WQ I2S 的真实 API**（来自 `wq_i2s_declare.h`）：

```c
// 初始化（指定 TX 还是 RX 方向）
WQ_RET wq_i2s_init(WQ_I2S_TRANS_MODE mode);
WQ_RET wq_i2s_deinit(WQ_I2S_TRANS_MODE mode);

// 打开/关闭（配置引脚、格式、采样率、Master/Slave）
WQ_RET wq_i2s_open(const wq_i2s_config_t *i2s_config);
WQ_RET wq_i2s_close(const wq_i2s_config_t *i2s_config);

// 启动/停止（启动 DMA 和时钟）
WQ_RET wq_i2s_start(const wq_i2s_start_cfg_t *cfg);
WQ_RET wq_i2s_stop(WQ_I2S_MODULE module);

// 同步启停（所有 I2S 模块同时启动/停止）
void wq_i2s_start_all_trigger(void);
void wq_i2s_stop_all_trigger(void);
```

---

## 第二层：reGlasses 的 I2S 音频链路

### 2.1 V861 I2S0 → WQ7036AX（BT 音频回传）

`board.dts:892-901` 的注释和配置：

```dts
/* I2S0 - Audio interface to WQ7036AX BT SoC (PH7-PH10, no MCLK) */
&i2s0_plat {
    pinctrl-0 = <&i2s0_pins_bclk &i2s0_pins_lrck
                 &i2s0_pins_din0 &i2s0_pins_dout0>;
    pinctrl-1 = <&i2s0_pins_sleep>;
};

&i2s0_mach {
    soundcard-mach,format = "i2s";
    soundcard-mach,frame-master = <&i2s0_cpu>;
    soundcard-mach,bitclock-master = <&i2s0_cpu>;
};
```

关键事实：

- **4 根线，无 MCLK**：BCLK + LRCK + DIN0（V861 接收，WQ 发送）+ DOUT0（V861 发送，WQ 接收）。reGlasses 注释明确写"no MCLK"——接收方（WQ）必须从 BCLK 恢复内部时钟，或使用自己的本地时钟做 ASRC。
- **V861 是 Master**：V861 提供 BCLK 和 LRCK，WQ7036AX 作为 Slave 跟随。这意味着 WQ 的 I2S 模块必须配置为 Slave 模式。
- **双向音频**：DIN0（V861 收，即 WQ 发）= BT 音频下行（手机→WQ→I2S→V861→功放），DOUT0（V861 发，即 WQ 收）= 麦克风采集上行（麦克风→V861→I2S→WQ→BT→手机）。
- **引脚 PH7-PH10**：BCLK=PH7, LRCK=PH8, DIN0=PH9, DOUT0=PH10，复用功能为 `i2s0_bclk`/`i2s0_lrck`/`i2s0_din0`/`i2s0_dout0`。

### 2.2 WQ 侧的 I2S 配置（从 aud_i2s.c 推断）

WQ 的 `aud_i2s_rx_open`（aud_i2s.c:55-80）展示了 I2S 接收的完整配置流程：

1. `wq_i2s_open(cfg)` — 配置 I2S 硬件（引脚复用、格式、采样率、Master/Slave）
2. `wq_audio_rx_fifo_open(fifo)` — 打开 RX FIFO（DMA 缓冲）
3. `wq_audio_rx_fifo_link_i2s(fifo, fifo)` — 将 I2S 数据路由到 RX FIFO（或 ASRC）
4. 如果数据目标为 ASRC：`wq_asrc_open()` — 打开异步采样率转换器

当 I2S 启动后，RX FIFO 通过 DMA 将 I2S 接收的音频数据传输到内存（DSP 处理的缓冲区）。

---

## 第三层：DMA 缓冲与时钟容差

### 3.1 乒乓缓冲

I2S 的数据是实时、连续的——BCLK 不会停，数据一直在流。CPU 不能等一个缓冲区满了再处理，因为处理期间新数据会覆盖旧数据。乒乓缓冲（ping-pong buffer）解决这个问题：

```text
缓冲区 A（正在被 DMA 填充）       缓冲区 B（正在被 CPU/DSP 处理）
        ↑                                   ↑
   I2S RX FIFO → DMA → A               B → 音频处理 → 输出

当 A 填满时，DMA 切换到 B，CPU 处理 A。
当 B 填满时，DMA 切换到 A，CPU 处理 B。
```

**SDK 事实**：WQ 的音频子系统使用 `wq_audio_rx_fifo` 和 `wq_audio_tx_fifo` 管理 DMA 乒乓缓冲。`aud_i2s_rx_xfer` 函数（在 IRAM 中执行）负责在每次 DMA 中断时切换到下一个缓冲区。

### 3.2 欠载和溢出

- **欠载（TX underrun）**：DMA 没有及时向 TX FIFO 写入新数据，FIFO 空了，I2S 发送侧没有数据可发。在音频中表现为爆音（pop）或静音间隙。原因：CPU/DSP 处理太慢、中断延迟太大、缓冲区太小。
- **溢出（RX overflow）**：DMA 没有及时从 RX FIFO 读取数据，FIFO 满了，新的 I2S 数据被丢弃。在音频中表现为数据丢失（断音、失真）。原因同上。

**预防措施**：
- 增大缓冲区（但会增加延迟）；
- 提高 DMA 优先级；
- 使用 ASRC 隔离两个时钟域，避免时钟偏差累积导致缓冲区耗尽。

---

## 第四层：常见故障与诊断

| 现象 | 第一假设 | 需要的证据 | 不要先做什么 |
|---|---|---|---|
| 完全没有声音 | Master/Slave 配反，或 BCLK/LRCK 无输出 | 示波器看 BCLK 和 LRCK 波形 | 不要只改音量 |
| 全是噪音 | 数据格式不匹配（I2S vs 左对齐） | 逻辑分析仪对比 LRCK 边沿和 DATA 起始位置 | 不要只改采样率 |
| 左右声道互换 | LRCK 极性反了 | 逻辑分析仪看 LRCK 相位 | 不要只改声道映射 |
| 周期性爆音 | DMA 缓冲区欠载（TX） | 检查 DMA 中断频率 vs CPU 负载 | 不要只增大缓冲区 |
| 声音断续 | DMA 缓冲区溢出（RX）或时钟偏差 | 检查 ASRC 是否使能、时钟源精度 | 不要只改 DMA 优先级 |
| 高频嘶嘶声 | 位宽不匹配（16-bit 数据用 24-bit 槽传输） | 逻辑分析仪看实际有效 bit 数 | 不要只改采样率 |

---

## 第五层：练习与验收

### 练习一：计算时钟频率

给定：采样率 48 kHz，24-bit 位宽，立体声。计算 LRCK、BCLK 和 MCLK 的频率。如果 MCLK 使用 256 × Fs，MCLK = 12.288 MHz。验证 BCLK 是否为 MCLK 的整数分频。

### 练习二：追踪 reGlasses I2S0 设备树

阅读 `board.dts` 中 I2S0 的配置，回答：
1. 为什么没有 MCLK？
2. V861 作为 Master 意味着什么？WQ 侧应如何配置？
3. DIN0 和 DOUT0 分别对应什么音频流方向？

### 练习三：用逻辑分析仪区分 I2S 格式

获取一份 I2S 逻辑分析仪抓取波形，标出 LRCK 切换点、每位数据对应的 BCLK 边沿，并判断使用的是哪种数据格式。

## 自测题

1. **16kHz/16-bit 立体声时，BCLK 是多少？**
   - BCLK = 2 × 16 × 16000 = 512 kHz。LRCK = 16000 Hz。

2. **I2S 格式和左对齐格式的区别是什么？**
   - I2S 格式数据在 LRCK 变化后第 2 个 BCLK 开始；左对齐格式在第 1 个 BCLK 立即开始。相差 1 个 BCLK 偏移。

3. **Master 和 Slave 各负什么时钟责任？**
   - Master 提供 BCLK 和 LRCK（以及可选的 MCLK）。Slave 使用外部时钟，在 BCLK 边沿上发送/采样数据。

4. **reGlasses I2S0 为什么没有 MCLK？**
   - 接收方（WQ7036AX）可以从 BCLK 恢复内部时钟，或使用 ASRC 桥接两个时钟域。不需要额外的 MCLK 引脚，减少了 FPC 上的线数。

5. **DMA 欠载在音频中表现为什么？如何预防？**
   - 表现为爆音或静音间隙。预防：增大缓冲区、提高 DMA 优先级、使用 ASRC 隔离时钟域。

## 参考资料

- WQ I2S API：`wqcore/driver/audio/declare/wq_i2s_declare.h`
- WQ I2S 音频设备层：`wqcore/components/audsys/device/aud_i2s.c`
- reGlasses I2S0 设备树：`aiglass/reglasses/device/configs/reglasses/linux-6.6-xuantie/board.dts`
- [[pdm-mic-PDM麦克风]] — 对比：PDM 1-bit 密度调制
- [[i2s-clock-tree-I2S时钟树]] — MCLK/BCLK/LRCK 频率关系详解
- [[i2s-vs-pdm-音频接口对比]] — 两种音频接口全面对比
- [[wq7036ax-audio-pipeline-WQ7036AX音频管道]] — I2S 在完整音频链中的位置

#flashcard

问：I2S 的三根线（BCLK/LRCK/DATA）各做什么？
答：BCLK 是位时钟，每个脉冲传 1 bit。LRCK 是左右声道时钟，高=左声道，低=右声道，频率=采样率。DATA 是串行音频数据，MSB 先发。

问：16kHz/16-bit 立体声的 BCLK 频率是多少？
答：BCLK = 2（左右声道）× 16（位宽）× 16000（采样率）= 512 kHz。

问：reGlasses I2S0 的 Master 是谁？为什么？
答：V861 是 Master（`frame-master = <&i2s0_cpu>`，`bitclock-master = <&i2s0_cpu>`）。WQ7036AX 作为 Slave 跟随 V861 的 BCLK/LRCK。