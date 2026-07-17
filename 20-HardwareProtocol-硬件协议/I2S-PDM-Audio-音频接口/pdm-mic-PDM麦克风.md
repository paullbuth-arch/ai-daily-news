---
type: concept
created: 2026-07-17
tags: [protocol, pdm, dmic, microphone, 数字麦克风, 音频采集, 1-bit]
aliases: [PDM, Pulse Density Modulation, DMIC, 数字麦克风]
---

# PDM 麦克风：从 1-bit 密度调制到 PCM 音频流

> **一句话结论**：PDM（Pulse Density Modulation，脉冲密度调制）不是"CLK+DATA 两根线传音频"这么简单，它是一套由高频过采样时钟（通常 1-3 MHz）、1-bit 密度编码（'1'的密度正比于信号幅度）、抽取滤波器（decimation filter，PDM→PCM 转换）、L/R 边沿分时复用和麦克风偏置电压（MICBIAS）共同组成的数字麦克风接口。真正会用 PDM，意味着你能从 CLK 频率推导出 PCM 输出采样率，在逻辑分析仪上从 DATA 线上区分左/右声道麦克风的 1-bit 流，并追踪从声波到 PCM 缓冲区的完整信号链。

本篇的代码锚点来自两个真实工程：

- **WQ7036AX**：`/home/ys/wq7036a/wq-audio/wqcore/driver/audio/declare/wq_pdm_declare.h`（API 声明）、`wqcore/components/audsys/device/aud_pdm.c`（音频设备层）、`wqcore/driver/audio/bbb/hal/pdm/`（硬件抽象层）。
- **V861/reGlasses**：PDM 麦克风直接连接到 WQ7036AX，不经过 V861。reGlasses 的 4 颗 SDM0103B 数字麦通过两组 PDM 总线（L1 和 R1）接入 WQ。

文中"通用原理"是 PDM 协议本身；"SDK 事实"只针对上述源码和配置；"待确认"标记表示尚未由当前源码或板级资料证实。

## 学完以后应该能做什么

1. 解释 PDM"1 的密度正比于信号幅度"的编码原理，以及为什么它能用 1 bit 表示模拟音频。
2. 计算 CLK 频率与 PCM 输出采样率的关系（CLK ÷ 64 或 ÷ 128）。
3. 解释一条 PDM 总线（CLK+DATA）如何通过 L/R 引脚电平在 CLK 上升沿/下降沿分时复用两路麦克风。
4. 描述抽取滤波器（decimation filter）的工作原理——PDM 1-bit 流如何变成 PCM 16-bit 样本。
5. 看懂 WQ HAL 的 `wq_rx_pdm_open/start/stop`、`wq_rx_pdm_sample_rate_set`、`wq_rx_pdm_gain_set` 的调用契约。
6. 追踪 reGlasses 中 4 颗 PDM 麦克风 → WQ7036AX → DSP 处理链 → Opus 编码 → BLE 上传的完整数据流。

## 前置知识

- 理解采样率（Fs）和 PCM 的基本概念；可先看 [[pcm-audio-PCM音频基础]]。
- 知道 I2S 的时钟模型（BCLK/LRCK）会帮助理解 PDM 为什么更简单；可先看 [[i2s-protocol-I2S协议]]。
- 如果要理解 PDM 后面的 DSP 处理链，需要 [[wq7036ax-audio-pipeline-WQ7036AX音频管道]]。

## 术语先讲清楚

| 术语 | 英文 | 在 PDM 中具体指什么 |
|---|---|---|
| 脉冲密度调制 | PDM（Pulse Density Modulation） | 用 1-bit 数字信号的"1"的密度编码模拟信号幅度。密度越高（1 越多），表示信号幅度越正；密度越低（0 越多），表示幅度越负。50% 密度 = 零幅度（静音） |
| 抽取滤波器 | decimation filter | 数字滤波器，将高频 1-bit PDM 流（如 2.048 MHz）降采样为低频多 bit PCM 流（如 16 kHz, 16-bit）。同时完成低通滤波——滤除 PDM 高频量化噪声 |
| 过采样率 | OSR（Over-Sampling Ratio） | PDM CLK 频率与 PCM 输出采样率的比值。OSR = 64 时，每 64 个 PDM bit 产生 1 个 PCM 样本。CLK = 2.048 MHz, OSR = 64 → PCM Fs = 32 kHz |
| L/R 选择 | Left/Right select | 麦克风芯片的硬件引脚。L/R = GND 时，麦克风在 CLK 上升沿输出数据；L/R = VDD 时，在 CLK 下降沿输出。注意：这个 L/R 和 I2S 的 LRCK 是完全不同的概念——PDM 的 L/R 是静态引脚电平，不是时钟信号 |
| 麦克风偏置 | MICBIAS | WQ 为数字麦克风提供的偏置电压（通常 1.8V-3.3V）。`wq_rx_pdm_micbias_start` 使能偏置供电。没有 MICBIAS，麦克风内部的 ASIC 不工作 |
| 增益 | gain | PDM 抽取后的数字增益，WQ 支持 `wq_rx_pdm_gain_set`，步长 0.1875 dB |
| 低延迟模式 | less delay mode | PDM 抽取滤波器的一种工作模式，以降低群延迟为代价换取更快的响应。WQ 的 `wq_rx_pdm_sample_rate_set` 支持 `less_delay_mode_en` 参数 |
| 量化噪声 | quantization noise | 1-bit 量化引入的高频噪声。PDM 的诀窍在于用极高的过采样率（OSR=64 或 128）把量化噪声推到远高于音频频带的位置，然后用抽取滤波器滤除高频噪声，保留音频频带内的信号 |

---

## 第一层：用费曼技巧建立心智模型

### 1.1 PDM 像用鼓点记录音乐——类比及其边界

把 PDM 想成用鼓点记录一段旋律：

- 音乐声大（信号幅度正）→ 鼓手疯狂敲击，鼓点密集（PDM 输出"111111..."）；
- 音乐声小（信号幅度负）→ 鼓手几乎不敲，鼓点稀疏（PDM 输出"000000..."）；
- 音乐无声（零幅度）→ 鼓手以中等速度均匀敲击，一半时间敲一半不敲（PDM 输出"10101010..."）。

远处的听众（抽取滤波器）不看每一次敲击，而是每隔一段时间（如 64 次敲击）统计一下"这段时间里敲了多少次"——敲得多的时段对应音乐大声，敲得少的时段对应音乐小声。这个统计结果就是 PCM 样本。

这个类比的关键边界：

**边界一：鼓手敲击的速度（CLK 频率）远高于音乐的最高频率。** 如果音乐最高频率是 8 kHz，CLK 至少要 1 MHz（128× 过采样）。这是 PDM 的核心代价——用极高的时钟频率换取了 1-bit 的简单性。这也是为什么 PDM 只适合短距离（麦克风到芯片，通常 < 10 cm PCB 走线）——MHz 级的单端信号不能传太远。

**边界二：统计窗口（OSR）决定了精度和延迟。** OSR=64 时，每个 PCM 样本由 64 个 PDM bit 统计而来，精度约等于 6 bit 的量化——但因为有噪声整形，实际音频频带内有效精度接近 16 bit。OSR=128 时精度更高，但 PCM 输出采样率减半（CLK 不变时）。

**边界三：两条"鼓点轨道"可以在同一根线上分时传输。** PDM 的 L/R 选择不是时钟信号，而是静态电平。L/R=GND 的麦克风在 CLK 上升沿敲鼓，L/R=VDD 的麦克风在 CLK 下降沿敲鼓——接收方在上升沿读到的 bit 来自左麦，下降沿读到的 bit 来自右麦。这和 I2S 的 LRCK 交替切换完全不同——PDM 是每个 CLK 周期同时采样两路（上升沿+下降沿各一次），I2S 是半个 LRCK 周期只传一路。

### 1.2 完整场景演算：从声波到 PCM 样本的每一步

假设一个 1 kHz 正弦波进入 PDM 麦克风，CLK = 2.048 MHz，OSR = 64。

**第一步：声波 → 麦克风振膜位移。**

```text
1 kHz 正弦波气压变化 → MEMS 振膜振动 → 电容变化 → ASIC 读取。
麦克风内部 ASIC 以 2.048 MHz 的速率对振膜位置进行 delta-sigma 调制，
产生 1-bit PDM 流。
```

**第二步：1-bit PDM 编码。**

```text
正弦波正半周（幅度 > 0）：PDM 输出中 "1" 的比例 > 50%。
  例如：在 64 个 PDM bit 中，有 45 个 "1"，19 个 "0"。
  密度 = 45/64 ≈ 70% → PCM 样本值 ≈ 正数。

正弦波负半周（幅度 < 0）：PDM 输出中 "1" 的比例 < 50%。
  例如：在 64 个 PDM bit 中，有 19 个 "1"，45 个 "0"。
  密度 = 19/64 ≈ 30% → PCM 样本值 ≈ 负数。

正弦波过零点（幅度 = 0）：PDM 输出中 "1" 的比例 = 50%。
  例如：在 64 个 PDM bit 中，有 32 个 "1"，32 个 "0"。
  密度 = 50% → PCM 样本值 ≈ 0。
```

**第三步：抽取滤波（Decimation）。**

```text
抽取滤波器每 64 个 PDM bit 做一次统计：
  统计 64 个 bit 中 "1" 的个数（0~64）。
  减去 32（零偏移），得到 -32 到 +32 的有符号数。
  缩放为 16-bit PCM 范围（-32768 ~ +32767）。

对于 2.048 MHz CLK，OSR=64，PCM 输出速率 = 2.048M / 64 = 32000 Hz = 32 kHz。
如果 OSR=128，则 PCM 输出速率 = 2.048M / 128 = 16000 Hz = 16 kHz。
```

**第四步：PCM 样本进入 DMA 缓冲区。**

```text
WQ 的 PDM 控制器通过 DMA 将 PCM 样本写入内存中的环形缓冲区。
wq_audio_rx_fifo 管理 DMA 乒乓缓冲。
当半满或全满时触发中断，DSP 从缓冲区取数据做下一步处理。
```

**SDK 事实**：WQ 的 `wq_rx_pdm_sample_rate_set(chn, out_fs, less_delay_mode_en)` 可以在 PDM 打开后动态切换输出采样率。注释警告："If set the sample rate after PDM started, some dirty data should be discarded, it is recommended to discard no less than 10 sample points."——切换采样率后抽取滤波器需要重新稳定，前 10 个样本不可用。

**WQ PDM 的真实 API**（来自 `wq_pdm_declare.h`）：

```c
// 初始化/反初始化（RX 和 TX 分开）
WQ_RET wq_pdm_rx_init(void);
WQ_RET wq_pdm_rx_deinit(void);
WQ_RET wq_pdm_tx_init(void);
WQ_RET wq_pdm_tx_deinit(void);

// 打开/关闭 PDM RX（配置引脚、CLK 频率、通道）
WQ_RET wq_rx_pdm_open(WQ_PDM_PORT port, WQ_PDM_RX_CHANNEL chn,
                      const wq_pdm_cfg_t *pdm_cfg);
WQ_RET wq_rx_pdm_close(WQ_PDM_PORT port, WQ_PDM_RX_CHANNEL chn,
                       const wq_pdm_gpio_cfg_t *pdm_gpio_cfg);

// 启动/停止（开始 DMA 和抽取滤波）
WQ_RET wq_rx_pdm_start(WQ_PDM_RX_CHANNEL chn,
                       const wq_pdm_rx_chn_cfg_t *cfg);
WQ_RET wq_rx_pdm_stop(WQ_PDM_RX_CHANNEL chn);

// 采样率设置（可在运行时切换）
WQ_RET wq_rx_pdm_sample_rate_set(WQ_PDM_RX_CHANNEL chn,
    uint32_t out_fs, bool less_delay_mode_en);

// 增益设置（步长 0.1875 dB）
WQ_RET wq_rx_pdm_gain_set(WQ_PDM_RX_CHANNEL chn, int16_t gain);

// MICBIAS 控制
WQ_RET wq_rx_pdm_micbias_start(const wq_pdm_rx_analog_param_t *param);
WQ_RET wq_rx_pdm_micbias_stop(const wq_pdm_rx_analog_param_t *param);
```

---

## 第二层：reGlasses 的 PDM 麦克风阵列

### 2.1 硬件拓扑

reGlasses 使用 4 颗 SDM0103B 数字麦克风，分成两组 PDM 总线：

```text
左声道组（MICBIAS_0 供电，WQ7036AX B5）:
  DMIC_L1_CLK  ──→ U12.CLK + U13.CLK（并联）
  DMIC_L1_DATA ←── U12.DATA + U13.DATA（线与，CLK 上升/下降沿区分）

右声道组（MICBIAS_1 供电，WQ7036AX A7）:
  DMIC_R1_CLK  ──→ U14.CLK + U15.CLK（并联）
  DMIC_R1_DATA ←── U14.DATA + U15.DATA（线与，CLK 上升/下降沿区分）
```

| MIC | 位置 | 组 | L/R 引脚 | 数据输出边沿 |
|---|---|---|---|---|
| U12（左前） | 左侧朝内 | L1 | GND（L） | CLK 上升沿 |
| U13（左后） | 左侧朝内 | L1 | VDD（R） | CLK 下降沿 |
| U14（右前） | 右侧朝内 | R1 | GND（L） | CLK 上升沿 |
| U15（右后） | 右侧朝内 | R1 | VDD（R） | CLK 下降沿 |

每个麦克风的 DATA 引脚是开漏输出——多个麦克风可以共享同一根 DATA 线（线与），因为 L/R 引脚确保它们在 CLK 的不同边沿上输出，不会冲突。

### 2.2 数据流：从麦到手机

```text
PDM 麦克风（4 颗 SDM0103B，1-bit PDM）
  │  2 组 PDM 总线（CLK + DATA）
  ↓
WQ7036AX PDM 控制器（硬件）
  │  抽取滤波器（PDM → PCM，16 kHz/16-bit）
  │  4 通道 PCM 数据
  ↓
DCORE（HiFi5 DSP）
  │  AEC（回声消除）、NR（降噪）、AGC（自动增益）、VAD（语音活动检测）
  ↓
Opus 编码器（压缩到 16-32 kbps）
  ↓
WQ Protocol 帧封装（TRANS_UP 帧）
  ↓
BLE GATT Notify → 手机 APP
```

---

## 第三层：常见故障与诊断

| 现象 | 第一假设 | 需要的证据 | 不要先做什么 |
|---|---|---|---|
| 麦克风完全无声 | MICBIAS 未使能或麦克风未供电 | 万用表测 MICBIAS 电压 | 不要只改增益 |
| 采集到的全是噪音 | CLK 频率不对或抽取滤波器配置错误 | 示波器测 CLK 频率 | 不要只改采样率 |
| 左右声道数据混淆 | L/R 引脚电平接反 | 逻辑分析仪在 CLK 上升沿和下降沿分别看 DATA | 不要只改声道映射 |
| 声音小/灵敏度低 | 增益设置不够或 MICBIAS 电压偏低 | 检查 `wq_rx_pdm_gain_set` 参数 | 不要只调大音量 |
| 切换采样率后声音异常 | 抽取滤波器未稳定，前 10 个样本脏数据 | 丢弃切换后的前 10 个样本 | 不要在切换后立即用第一批数据 |

---

## 第四层：练习与验收

### 练习一：计算 PDM 参数

给定：CLK = 3.072 MHz，OSR = 64。计算 PCM 输出采样率。如果要用 16 kHz 输出，需要多少 OSR？

### 练习二：追踪 WQ PDM RX 初始化

打开 `wqcore/components/audsys/device/aud_pdm.c`，画出 `aud_pdm_rx_open` → `wq_rx_pdm_open` → `wq_rx_pdm_start` 的调用链，标注每一步配置了什么。

### 练习三：用逻辑分析仪区分左右声道

获取一份双声道 PDM DATA 波形，在 CLK 上升沿和下降沿分别采样，还原出两路麦克风的 1-bit 流，并统计 64 个 bit 中"1"的密度来验证 PCM 样本值。

## 自测题

1. **PDM 的"1 的密度"如何表示信号幅度？**
   - 密度 > 50% = 正幅度，密度 < 50% = 负幅度，密度 = 50% = 零幅度。例如 70% 密度 → 正信号，30% 密度 → 负信号。

2. **CLK = 2.048 MHz, OSR = 64 时，PCM 输出采样率是多少？**
   - 2.048M / 64 = 32000 Hz = 32 kHz。

3. **一条 PDM DATA 线如何同时传输两路麦克风？**
   - 通过 L/R 引脚选择：L/R=GND 的麦在 CLK 上升沿输出，L/R=VDD 的麦在 CLK 下降沿输出。接收方在 CLK 上升沿读到左麦数据，下降沿读到右麦数据。

4. **PDM 和 I2S 的 L/R 概念有什么不同？**
   - PDM 的 L/R 是静态引脚电平，选择麦克风在 CLK 的哪个边沿输出。I2S 的 LRCK 是 50% 占空比的时钟信号，交替切换左右声道。PDM 是每个 CLK 周期同时采样两路，I2S 是半个周期只传一路。

5. **为什么切换 PDM 采样率后要丢弃前 10 个样本？**
   - 抽取滤波器需要时间重新稳定，前几个样本可能包含不正确的滤波结果。WQ 驱动注释明确建议丢弃不少于 10 个样本点。

## 参考资料

- WQ PDM API：`wqcore/driver/audio/declare/wq_pdm_declare.h`
- WQ PDM 音频设备层：`wqcore/components/audsys/device/aud_pdm.c`
- [[i2s-protocol-I2S协议]] — 对比：I2S 传 PCM，PDM 传 1-bit 密度调制
- [[i2s-vs-pdm-音频接口对比]] — 两种接口全面对比
- [[wq7036ax-audio-pipeline-WQ7036AX音频管道]] — PDM 在完整音频链中的位置
- [[dataflow-mic-to-phone-声音从麦到手机]] — 完整数据流追踪

#flashcard

问：PDM 接口需要几根线？
答：2 根：CLK（时钟）和 DATA（数据）。加上 MICBIAS（供电）和 L/R（静态电平选择），共 4 个引脚。但"总线"本身只需 CLK+DATA 两根。

问：一条 PDM 总线如何同时传输两路麦克风？
答：L/R=GND 的麦在 CLK 上升沿输出，L/R=VDD 的麦在下降沿输出。接收方在 CLK 的两个边沿分别采样，得到两路独立的 1-bit 流。

问：PDM 的 1-bit 流如何变成 PCM 16-bit？
答：通过抽取滤波器（decimation filter）。每 64 个（或 128 个）PDM bit 统计"1"的个数，换算为 PCM 样本值。同时滤除高频量化噪声。