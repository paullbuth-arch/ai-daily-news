---
type: concept
created: 2026-07-16
updated: 2026-07-17
tags: [dataflow, audio, pdm, opus, ble, 数据流, 音频, pipeline]
aliases: [音频数据流, 麦到手机, 音频上行]
---

# 数据流：声音从麦到手机

**一句话结论**：声音被 4 颗 PDM 数字麦捕获后，经过 6 个处理阶段（PDM 采集、Decimation 转 PCM、DSP 处理、Opus 编码、WQ Protocol 封装、BLE 发送）才能到达手机。每一步都有对应的 SDK 代码文件和关键函数。

---

## 30 秒先看懂

- 这是 reGlasses 最核心的数据流——所有语音交互、音频录制、通话功能都依赖这条管道。
- 6 个阶段分跨硬件层（PDM 控制器）、DSP 层（DCORE 音频算法）、编码层（Opus 压缩）、传输层（WQ Protocol + BLE）。
- 带宽从 PDM 的 2.048Mbps 逐级压缩到 BLE 的 16-32Kbps，压缩比约 100 倍。
- 你不需要自己实现这些阶段，只需调用 `aud_sv_api.h` 中的 API 接口。
- 调试时重点是确认每个阶段的数据是否正常到达下一阶段。

---

## 学完以后应该能做什么

**第一遍学完**：
- 能画出声音从麦到手机的完整 6 阶段数据流图
- 能说出每个阶段的数据格式和带宽变化
- 能在 SDK 中找到每个阶段对应的代码目录

**进阶目标**：
- 能通过添加日志追踪音频数据穿越每个阶段的延迟
- 能理解 Opus 编码参数对音质和带宽的 trade-off
- 能分析音频数据流中的瓶颈并提出优化方案

---

## 前置知识

- [[pdm-mic-PDM麦克风]] — PDM 接口原理
- [[wq7036ax-audio-pipeline-WQ7036AX音频管道]] — 音频管道总览
- [[wq-audio-protocol-WQ-Audio-Protocol]] — 传输层封装
- [[ble-gatt-BLE-GATT]] — BLE 数据传输

---

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| Sigma-Delta 调制 | Sigma-Delta Modulation | 用高速 1-bit 流表示模拟信号幅度的调制方式 |
| 抽取滤波 | Decimation Filter | 将 PDM 1-bit 高速流降采样为 PCM 多 bit 低速流 |
| 声道合并 | Channel Merge | 将多路麦克风声道合并为单声道或双声道 |
| 帧封装 | Frame Packing | 将编码后的音频数据加上协议头，形成传输帧 |
| 空中传输延迟 | Air Latency | 数据在 BLE 射频空中传输的时间 |
| 数据回调 | Data Callback | 音频数据就绪后通知应用层的回调函数 |

---

## 第一层：费曼心智模型

### 类比：从天然泉水到瓶装水

声音从麦克风到手机的旅程，就像从泉水到瓶装水的过程：

| 阶段 | 类比 | 说明 |
|------|------|------|
| Step 1 PDM 采集 | 从泉眼取水 | 声波振动振膜，变成 1-bit 数字流 |
| Step 2 Decimation 转 PCM | 初级过滤去杂质 | 硬件滤波器把 1-bit 流变成 16-bit PCM |
| Step 3 DSP 处理 | 精炼加工 | AEC 去杂质、NR 除沉淀、AGC 调浓度、VAD 检测有无水 |
| Step 4 Opus 编码 | 压缩成浓缩液 | 把桶装水变成浓缩液，体积缩小 8-16 倍 |
| Step 5 WQ Protocol 封装 | 贴上快递单 | 加上收件人地址（手机）和包裹信息 |
| Step 6 BLE 发送 | 快递寄出 | 通过 BLE 无线发送到手机 |

### 边界

- 这条数据流只处理**上行**音频（麦克风到手机）。
- 下行音频（手机到扬声器）走另一条路径，是反向的流程。
- DSP 处理在 DCORE 上完成，与 ACORE 的应用代码隔离。
- 并不是所有阶段都一直运行——VAD 检测到无语音时会暂停编码和发送以省电。

### 场景推演

**场景：用户在嘈杂环境中说"打开录音"**

1. 声波（含人声+背景噪声）传入 4 颗 SDM0103B 麦克风
2. PDM 1-bit 信号从麦克风 DATA 线输出到 WQ7036AX
3. Decimation 滤波后变成 4 路 PCM 16bit/16kHz 数据
4. 送入 DCORE 做波束成形增强用户方向的声音 + NR 降噪 + AGC 增益调整
5. VAD 检测到有效语音 → 触发 Opus 编码（20ms 一帧，16-32kbps）
6. 编码帧通过 WQ Protocol 封装，加上序列号
7. 通过 BLE GATT Notify 发送到手机
8. 手机语音识别"打开录音"并执行

---

## 第二层：原理、时序与约束

### 完整数据流

```
Step 1: 声波 → PDM 1-bit
  器件: SDM0103B (U12-U15)
  连接: CLK+DATA 线，L/R 引脚区分前后
  带宽: 2.048 MHz CLK，1-bit 数据流

Step 2: PDM → PCM 16-bit (Decimation)
  硬件: WQ7036AX PDM Controller
  输出: 16-bit PCM @ 16kHz x 4ch
  带宽: 1.024 Mbps
  代码: wqcore/driver/pdm/

Step 3: DSP 处理 (AEC + NR + AGC + VAD + Beam Forming)
  核: DCORE (HiFi5)
  输出: 16-bit PCM @ 16kHz x 1-2ch
  带宽: 256-512 Kbps
  代码: wq-adk/components/audio_service/

Step 4: Opus 编码 (压缩 8-16 倍)
  代码: wqcore/components/codec_factory/encode/
  输出: Opus 帧 @ 20ms 一帧
  带宽: 16-32 Kbps

Step 5: WQ Protocol 帧封装
  代码: wq-adk/components/wq_protocol/
  帧格式: sync=0x5751 + header + payload

Step 6: BLE GATT Notify
  代码: wq-adk/components/apps/acore/ota/src/ota_transport_ble.c
  通道: C3 Audio Stream Characteristic
  传输: 每个包 244B (MTU-3)，每秒 ~10-20 包
```

### 带宽变化

| 阶段 | 数据格式 | 带宽 | 压缩比 |
|------|----------|------|--------|
| PDM | 1-bit @ 2.048MHz | 2.048 Mbps | 原始 |
| PCM | 16-bit @ 16kHz x 4ch | 1.024 Mbps | 2x |
| DSP 后 | 16-bit @ 16kHz x 1-2ch | 256-512 Kbps | 4-8x |
| Opus 后 | 压缩帧 | 16-32 Kbps | 64-128x |
| BLE 发送 | GATT Notify | ~16-32 Kbps | 不变 |

### 时序约束

| 参数 | 值 | 说明 |
|------|-----|------|
| 音频帧长 | 20ms | Opus 编码帧长，每帧处理 320 个 PCM 样本 |
| BLE 连接间隔 | 7.5-30ms | 影响 BLE 传输延迟 |
| DSP 处理延迟 | <10ms | DCORE 处理一帧音频的时间 |
| 端到端延迟 | ~50-100ms | 从麦克风到手机 APP 的总延迟 |

---

## 第三层：真实 SDK 代码

### Step 1：PDM 采集

**硬件连接**：
- CLK 由 WQ7036AX 提供 (DMIC_L1_CLK / DMIC_R1_CLK)
- DATA 送回 WQ7036AX (DMIC_L1_DATA / DMIC_R1_DATA)
- L/R 引脚电平决定 CLK 哪个边沿输出

**文件路径**：`wqcore/driver/pdm/`

PDM 时钟配置在 Kconfig 中通过 `CONFIG_AUDIO_SPK_FB_REF_PDM_CLK_ENABLE` 控制。

### Step 2：PDM → PCM

WQ7036AX 内部的 PDM Controller（硬件模块）对 1-bit PDM 流做 Decimation（抽取滤波），输出 16-bit PCM 数据。

### Step 3：DSP 处理

**文件路径**：`wq-adk/components/audio_service/api/aud_sv_api.h`

PCM 数据送入 DCORE（HiFi5 DSP）做 4 种处理：

| 算法 | 英文 | 作用 |
|------|------|------|
| AEC | Acoustic Echo Cancellation | 消除扬声器回声 |
| NR | Noise Reduction | 去除环境噪声 |
| AGC | Automatic Gain Control | 自动调节音量 |
| VAD | Voice Activity Detection | 检测是否有人在说话 |

### Step 4：Opus 编码

**文件路径**：`wqcore/components/codec_factory/encode/`

```c
// 编码器统一接口在 audio_encoder.h
// PCM 16kHz/16bit = 256kbps
// Opus 编码后 16-32kbps (压缩 8-16 倍)
// 20ms 一帧，每帧 320 个 PCM 样本
```

Kconfig 中 `CONFIG_AUDIO_VAD_SEND_PKT_BY_OPUS` 确认使用 Opus 编码。

### Step 5：WQ Protocol 帧封装

**文件路径**：`wq-adk/components/wq_protocol/`

```c
wq_proto_pkt_pack(&pkt,
    SERVICE_TYPE_TRANS_UP,  // 音频上行
    TRANS_UP_DATA_IND,      // 数据帧
    FRAME_TYPE_IND,         // 单向通知
    seq_number++,           // 序列号
    0,                      // 不需要 ACK
    opus_data,              // Opus 编码后的数据
    opus_data_len           // 数据长度
);
```

### Step 6：BLE GATT Notify

**文件路径**：`wq-adk/components/apps/acore/ota/src/ota_transport_ble.c`

```c
wq_gatts_notify(conn_handle, char_audio, pkt_buf, pkt_size);
```

打包好的 WQ Protocol 帧通过 BLE GATT 的 **C3 Audio Stream Characteristic** 以 Notify 方式推送给手机。

---

## 第四层：正常与异常路径

### 正常路径

声波 → 麦克风采集正常 → PDM 数据稳定 → Decimation 输出正常 PCM → DCORE DSP 处理完成 → Opus 编码成功 → WQ Protocol 封装 → BLE Notify 发送成功 → 手机 App 收到并解码播放

### 异常路径

| 问题 | 现象 | 根因 | 排查方向 |
|------|------|------|---------|
| 麦克风无数据 | PDM 数据全零 | MIC_BIAS 未使能 | 检查电源配置 |
| 声音断续 | 音频帧不连续 | BLE 带宽不足或连接间隔过大 | 检查 BLE 配置 |
| 噪声大 | 背景噪声明显 | NR 降噪未开启或参数不当 | 检查 DSP 配置 |
| 回声 | 对方听到自己声音 | AEC 未使能或参考信号未接入 | 检查 AEC 配置 |
| 编码失败 | 编码器返回错误 | Opus 编码器内存不足 | 检查编码器初始化 |
| 断流 | 一段时间无音频帧 | VAD 阈值过高导致有效语音被丢弃 | 调整 VAD 阈值 |
| 延迟大 | 对讲延迟明显 | BLE 连接间隔过大或 DSP 处理超时 | 优化连接间隔 |

---

## 第五层：调试方法

### 1. 音频数据回调验证

在 `aud_sv_register_data_callback` 注册的回调中添加日志：
```c
void my_audio_callback(uint8_t *data, uint16_t len, uint32_t seq) {
    printf("Audio frame: seq=%d, len=%d\r\n", seq, len);
    // 确认数据连续到达，长度正常
}
```

### 2. 检查 PDM 时钟

用示波器测量 DMIC_L1_CLK / DMIC_R1_CLK 引脚，确认有 2.048MHz 时钟输出。

### 3. 带宽计算

在音频回调中统计每秒接收的音频帧数，计算实际带宽：
- 如果 Opus 帧长 20ms，每秒应有 50 帧
- 如果帧数明显少于 50，说明有问题

### 4. 逻辑分析仪抓 PDM 数据

抓取麦克风的 CLK 和 DATA 引脚波形，确认 PDM 数据有效。

### 5. 日志分级

在 SDK 中开启音频服务调试日志，查看：
- DSP 处理状态日志
- 编码器工作状态
- BLE 发送队列长度

---

## 第六层：实战练习

### 练习 1：在 SDK 中追踪音频数据回调

在 `wq-adk/components/audio_service/api/aud_sv_api.h` 中找到 `aud_sv_register_data_callback` 的声明，然后在 `app_uart_cmd.c` 或 `app_trans_down.c` 中找到该回调的注册位置。确认回调函数收到了什么数据，以及这些数据后续被如何处理。

### 练习 2：分析带宽瓶颈

如果产品经理要求将音频质量从 16kHz 提升到 48kHz 采样率，请计算：
- PCM 数据量增加多少倍？
- Opus 编码后带宽增加多少？
- BLE 链路是否仍然够用？
- 如果不够，提出至少两种优化方案。

### 练习 3：模拟 VAD 不触发

假设 VAD 阈值设置过高，导致用户说话时音频帧没有被触发发送。请说明：
- 你会观察到什么现象？
- 你应该检查哪个 Kconfig 配置项？
- 调整哪个参数可以降低 VAD 门槛？

### 练习 4：阅读真实源代码

打开 `wqcore/components/codec_factory/` 目录，找到编码器接口文件 `audio_encoder.h`，分析其中的 `audio_encoder_ops` 结构体。列出编码器注册、打开、编码、关闭等函数指针。

---

## 自测与验收

1. 声音从麦到手机经过哪 6 个阶段？请按顺序写出。
2. Opus 编码的压缩比大约是多少？为什么需要压缩？
3. PDM 到 PCM 的转换由什么完成？是硬件还是软件？
4. 在 SDK 中，音频数据回调的注册函数在哪个文件中？
5. 如果麦克风没有声音，你会从哪些方面排查（至少 3 个）？
6. VAD 的作用是什么？省电的原理是什么？
7. 音频数据在 ACORE 和 DCORE 之间如何传输？
8. 端到端音频延迟大约多少？主要瓶颈在哪里？
9. 音频带宽从 PDM 到 BLE 减少了多少倍？
10. WQ Protocol 封装中，SERVICE_TYPE_TRANS_UP 代表什么？

---

## 延伸阅读

- [[wq7036ax-audio-pipeline-WQ7036AX音频管道]] — 音频处理链总览
- [[pdm-mic-PDM麦克风]] — Step 1 详解
- [[wq-audio-protocol-WQ-Audio-Protocol]] — Step 5 详解
- [[ble-gatt-BLE-GATT]] — Step 6 详解
- [[i2s-vs-pdm-音频接口对比]] — PDM vs I2S 选择
- [[reglasses-bandwidth-reGlasses带宽约束]] — 带宽限制
- [[sdm0103b-SDM0103B数字麦]] — 麦克风硬件
- [[max98357a-MAX98357A功放]] — 扬声器驱动

#flashcard
问：声音从麦到手机经过哪 6 个阶段？
答：① PDM 采集 ② Decimation (PDM→PCM) ③ DSP (AEC/NR/AGC/VAD/Beam Forming) ④ Opus 编码 ⑤ WQ Protocol 帧封装 ⑥ BLE GATT Notify。

问：Opus 编码的压缩比大约是多少？
答：PCM 256kbps → Opus 16-32kbps，压缩约 8-16 倍。

问：PDM 到 PCM 的转换由什么完成？
答：由 WQ7036AX 内部的 PDM Controller 硬件模块完成（Decimation Filter），不是软件。

问：音频数据在 ACORE 和 DCORE 之间如何传输？
答：通过 IPC（共享内存 + 软中断）。ACORE 将 PCM 数据通过 IPC 发送给 DCORE 做 DSP 处理，处理完成后返回。

问：在 SDK 中 BLE 发送音频数据的代码在哪个文件？
答：`wq-adk/components/apps/acore/ota/src/ota_transport_ble.c`，其中的 `wq_gatts_notify` 函数。