---
type: concept
created: 2026-07-16
updated: 2026-07-17
tags: [mcu, audio, pipeline, dsp, opus, 音频管道, 数据流, codec]
aliases: [音频管道, Audio Pipeline, 音频数据流, 音频处理链]
---

# WQ7036AX 音频管道

**一句话结论**：音频管道是声音从麦克风到手机的完整处理链——4 颗 PDM 数字麦采集声音，DCORE 做 DSP 降噪增强，Opus 编码压缩，经 BLE 发给手机；反向路径从手机经 BLE 接收、Opus 解码、I2S 输出到扬声器。

---

## 30 秒先看懂

- 音频管道分为上行（麦克风到手机）和下行（手机到扬声器）两条路径。
- 上行有 5 个阶段：PDM 采集 → Decimation 转 PCM → DSP 处理（AEC/NR/AGC/VAD）→ Opus 编码 → BLE 发送。
- 下行有 4 个阶段：BLE 接收 → Opus 解码 → PCM 混音/音量调节 → I2S 输出到功放驱动扬声器。
- 你不需要写 DSP 代码，只需调用 `aud_sv_api.h` 中的音频服务 API。
- DSP 处理在 DCORE（HiFi5）上运行，与 ACORE 的应用代码通过 IPC 交换音频数据。

---

## 学完以后应该能做什么

**第一遍学完**：
- 能画出从麦到手机和从手机到扬声器的完整数据流
- 能说出 AEC、NR、AGC、VAD 各自的作用
- 能在 SDK 中找到 `aud_sv_api.h` 并说出音频采集/播放的主要 API
- 能说出 Opus 编码的压缩比（PCM 256kbps → Opus 16-32kbps）

**进阶目标**：
- 能阅读 `codec_factory` 的编码器接口，理解策略模式切换编解码器
- 能通过 Kconfig 配置音频参数（采样率、VAD 开关、双扬声器）
- 能理解采样率、位深、声道数对带宽的影响

---

## 前置知识

- [[pdm-mic-PDM麦克风]] — 采集入口，理解 PDM 1-bit 输出原理
- [[i2s-protocol-I2S协议]] — 播放输出接口
- [[audio-system-音频系统基础]] — 采样率、位深、AEC、Opus 等底层原理
- [[memory-dma-内存管理与DMA]] — DMA 双缓冲、Cache 一致性
- [[interrupt-concurrency-中断并发同步]] — DMA 中断与音频任务之间的同步

---

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 脉冲密度调制 | PDM (Pulse Density Modulation) | 1-bit 数字音频接口，用脉冲密度表示模拟信号幅度 |
| 抽取滤波 | Decimation Filter | 将 PDM 1-bit 高速流转换为 PCM 多 bit 低速流的硬件滤波器 |
| 音频回声消除 | AEC (Acoustic Echo Cancellation) | 消除扬声器声音被麦克风重新采集产生的回声 |
| 降噪 | NR (Noise Reduction) | 去除环境中的背景噪声（风扇、空调等） |
| 自动增益控制 | AGC (Automatic Gain Control) | 自动调节输入音量，小声放大、大声压缩 |
| 语音活动检测 | VAD (Voice Activity Detection) | 检测是否有人在说话，无语音时停止发送以省电 |
| 波束成形 | Beam Forming | 利用多路麦克风阵列，增强特定方向的声音信号 |
| 动态均衡器 | Dynamic EQ (Equalizer) | 根据音频内容自动调整频响曲线的均衡器 |

---

## 第一层：费曼心智模型

### 类比：音频管道就像一条矿泉水生产线

**上行采集**（麦克风到手机）：
- **PDM 采集** = 从水源（声波）取水
- **Decimation 转 PCM** = 初级过滤，把浑水变成清水
- **DSP 处理** = 精炼加工（AEC去杂质、NR去沉淀、AGC调浓度、VAD检测有没有水）
- **Opus 编码** = 把桶装水压缩成浓缩液（体积缩小 8-16 倍）
- **BLE 发送** = 通过快递（BLE）寄给手机

**下行播放**（手机到扬声器）：
- 手机把浓缩液（Opus）发回来
- 解码还原成清水（PCM）
- 通过 I2S 管道送到功放和扬声器

### 边界

- 音频管道**只处理声音数据**，不处理控制命令（控制命令走 WQ Protocol 控制通道）
- DSP 处理在 DCORE 上完成，与 ACORE 的应用代码隔离
- 上行和下行是独立的路径，可以同时进行（全双工通话场景）

### 场景推演

**场景：用户对着眼镜说"今天天气怎么样"**

1. 4 颗 SDM0103B 麦克风采集声波，输出 PDM 1-bit 信号
2. WQ7036AX PDM Controller 硬件滤波转换为 PCM 16-bit
3. PCM 数据通过 IPC 送到 DCORE，做 AEC 消除环境音、NR 降噪、AGC 增益调整
4. VAD 检测到有效语音，触发 Opus 编码器压缩
5. 编码后的音频帧通过 WQ Protocol 封装，经 BLE 发送到手机
6. 手机语音识别后返回结果，经 BLE 回传
7. WQ7036AX 解码 Opus，通过 I2S 输出到 MAX98357A 功放，驱动扬声器播报

---

## 第二层：原理、时序与约束

### 上行数据流（麦克风到手机）

```
┌─ 硬件层 ─────────────────────────────────────────┐
│                                                    │
│  SDM0103B ×4 ──PDM──→ PDM Controller (硬件)       │
│  (U12-U15)              │                          │
│                    Decimation Filter               │
│                    (PDM 1-bit → PCM 16-bit)        │
│                         │                          │
│                    PCM 16kHz, 4ch                  │
└─────────────────────────┼──────────────────────────┘
                          ↓
┌─ DSP 层 (DCORE HiFi5) ────────────────────────────┐
│                                                    │
│  AEC (回声消除) → 消除扬声器播放的声音被麦再次录入  │
│  NR (降噪) → 去除环境噪声 (风扇、空调等)           │
│  AGC (自动增益) → 声音太小自动放大，太大自动压小    │
│  VAD (语音活动检测) → 没说话时不发送，省电          │
│  Beam Forming (波束成形) → 4路麦组合增强方向性      │
└─────────────────────────┼──────────────────────────┘
                          ↓
┌─ 编码层 ──────────────────────────────────────────┐
│                                                    │
│  Opus 编码器 → PCM 16kHz/16bit = 256kbps          │
│              → Opus 压缩到 16-32kbps (8-16倍)      │
│              → 20ms 一帧                           │
└─────────────────────────┼──────────────────────────┘
                          ↓
┌─ 传输层 ──────────────────────────────────────────┐
│                                                    │
│  WQ Protocol 帧封装 (TRANS_UP 帧 + seq + payload)  │
│  BLE GATT Notify (C3: Audio Stream)               │
│  → 每个包 244B (MTU-3)，每秒 ~10-20 包             │
└─────────────────────────┼──────────────────────────┘
                          ↓
                     手机 APP (Opus 解码 → PCM → 播放/ASR)
```

### 下行数据流（手机到扬声器）

```
手机 APP ──BLE Write──→ WQ Protocol 解析
                               │
                         Opus 解码 → PCM
                               │
                    混音/音量调节 → 音频路由
                               │
                    ┌──────────┴──────────┐
                    │   I2S #2 (Master)    │
                    │  MAX98357A ×2        │
                    │  (U16/U17)           │
                    └──────────┬───────────┘
                               ↓
                        双扬声器 (AMP1_OUTP/N + AMP2_OUTP/N)
```

### 关键 Kconfig 配置

在 `defconfig.stereo.i2s` 中查看当前配置：

| 配置项 | 值 | 说明 |
|--------|---|------|
| `CONFIG_EXT_TRANS_I2S_SAMPLE_RATE` | 16000 | I2S 采样率 16kHz |
| `CONFIG_AUDIO_VAD_SEND_PKT_BY_OPUS` | y | VAD 检测到的语音用 Opus 编码发送 |
| `CONFIG_AUDIO_VAD_WAKEUP_TVAD` | y | 使用 TVAD (Tiny VAD) 做唤醒检测 |
| `CONFIG_DUAL_SPK_ENABLE` | y | 双扬声器使能 |
| `CONFIG_DRIVER_I2S_EXT_PA_ENABLE` | y | 外部功放 (MAX98357A) |
| `CONFIG_DYNAMIC_EQ_ENABLE` | y | 动态均衡器 |
| `CONFIG_CODEC_LC3_ENABLE` | y | LC3 编解码器 (LE Audio 预留) |

### 带宽变化

| 阶段 | 数据格式 | 带宽 |
|------|----------|------|
| PDM | 1-bit @ 2.048MHz | 2.048 Mbps |
| PCM | 16-bit @ 16kHz x 4ch | 1.024 Mbps |
| DSP 后 | 16-bit @ 16kHz x 1-2ch | 256-512 Kbps |
| Opus 后 | 压缩帧 | 16-32 Kbps |
| BLE 发送 | GATT Notify | ~16-32 Kbps (占用 BLE ~2%) |

---

## 第三层：真实 SDK 代码

### 音频服务 API

**文件路径**：`wq-adk/components/audio_service/api/aud_sv_api.h`

这是音频服务对外提供的统一接口，包含音频采集、播放、音量控制等 API：

```c
// 音频数据路径枚举
enum {
    DATAPATH_MAIN,        // 主路径：音乐或语音
    DATAPATH_TONE,        // 提示音路径
    DATAPATH_LOOPBACK,    // 回环路径
    DATAPATH_EXTERNAL,    // 外部数据路径
    DATAPATH_MAX,
};

// 流类型
typedef enum {
    STREAM_IDLE = 0,      // 空闲
    STREAM_MUSIC = 1,     // 音乐
    STREAM_VOICE = 2,     // 语音
    STREAM_TONE = 3,      // 提示音
    STREAM_VAD_ID = 4,    // VAD 检测
    STREAM_LOOPBACK = 6,  // 回环
    STREAM_RECORDSV = 7,  // 录音
} stream_type_t;
```

常用 API：
- `aud_sv_start_capture(config)` — 启动音频采集
- `aud_sv_register_data_callback(callback)` — 注册音频数据回调
- `aud_sv_play_pcm(data, len, sample_rate)` — 播放 PCM 音频

### 编解码器工厂

**文件路径**：`wqcore/components/codec_factory/`

采用策略模式设计，统一编码器接口 `audio_encoder.h`，支持多种编解码器运行时切换：

| 编解码器 | 类型 | 用途 | reGlasses 用哪个 |
|---------|------|------|-----------------|
| **Opus** | 编码 | BLE 音频传输 | 主要用这个 |
| SBC | 解码 | A2DP 蓝牙音频 | 可选 |
| AAC | 解码 | 高级音频 | 可选 |
| CVSD | 编解码 | SCO 通话 | 可选 |
| mSBC | 编解码 | 宽带语音通话 | 可选 |
| LC3 | 编解码 | LE Audio | 预留 |

### 应用层音频下行处理

**文件路径**：`wq-adk/examples/glass/acore/app/app_customer_ext_trans/` 目录下的 `app_uart_cmd.c` 等文件，处理音频下行数据。

---

## 第四层：正常与异常路径

### 上行正常路径

麦克风采集正常 → PDM Controller 输出 PCM → IPC 送到 DCORE → DSP 处理完成 → Opus 编码 → WQ Protocol 封装 → BLE Notify 发送成功

### 上行异常路径

| 问题 | 现象 | 根因 |
|------|------|------|
| 麦克风无声音 | PDM 数据全零 | MIC_BIAS 未使能或 PDM 时钟未开启 |
| 声音断续 | BLE 发送间隔不稳定 | BLE 带宽不足或连接间隔配置过大 |
| 噪音大 | 背景噪声明显 | NR 降噪未开启或参数配置不当 |
| 回声 | 对方听到自己声音 | AEC 未使能或参考信号未正确接入 |
| 编码失败 | 音频卡顿 | Opus 编码器内存不足或参数非法 |

### 下行异常路径

| 问题 | 现象 | 根因 |
|------|------|------|
| 无声音输出 | 扬声器不响 | I2S 时钟未配置或功放 SD 引脚拉低 |
| 声音失真 | 破音 | I2S 位深/声道数配置不匹配 |
| 左右声道反 | 左右声道互换 | I2S LRCLK 极性配置错误 |

---

## 第五层：调试方法

### 1. 检查音频 Kconfig 配置

确认关键配置项已启用：
```bash
grep CONFIG_AUDIO_VAD_SEND_PKT_BY_OPUS sdkconfig
grep CONFIG_DRIVER_I2S_EXT_PA_ENABLE sdkconfig
```

### 2. 音频数据抓取

在 `aud_sv_register_data_callback` 注册的回调中用串口打印 `seq_number` 和 `len`，确认音频数据帧连续到达。

### 3. 检查 PDM 时钟

用示波器或逻辑分析仪测量 DMIC_L1_CLK / DMIC_R1_CLK 引脚，确认有 2.048MHz 时钟输出。

### 4. 检查 I2S 输出

用逻辑分析仪抓取 AMP_I2S_BCLK / AMP_I2S_LRCLK / AMP_I2S_DOUT 波形，确认时序符合 I2S 协议。

### 5. 音频日志

在 SDK 中开启音频服务调试日志，查看 DSP 处理状态、编码器状态等信息。

---

## 第六层：实战练习

### 练习 1：在 SDK 中找到音频服务 API

打开 `wq-adk/components/audio_service/api/aud_sv_api.h`，找到以下内容：
- 音频数据路径枚举（`DATAPATH_MAIN` 等）
- 流类型枚举（`stream_type_t`）
- 音频采集启动函数声明

### 练习 2：追踪音频上行数据流

在 `aud_sv_api.h` 中搜索 `register_data_callback` 相关函数，然后在 `app_uart_cmd.c` 或 `app_trans_down.c` 中找到该回调的注册位置，画出从回调函数到 BLE 发送的完整调用链。

### 练习 3：配置 Opus 编码参数

在 Kconfig 中查找 `CONFIG_AUDIO_VAD_SEND_PKT_BY_OPUS`，理解它的作用。然后尝试修改 `defconfig.stereo.i2s` 中的配置，启用或禁用 Opus 编码，观察编译后行为的变化。

### 练习 4：阅读真实源代码

打开 `wqcore/components/codec_factory/` 目录，查看编码器统一接口。找到 `audio_encoder.h` 中的 `audio_encoder_ops` 结构体，列出其中包含的函数指针。

---

## 自测与验收

1. 音频上行数据流经过哪 5 个处理阶段？请按顺序写出。
2. AEC（回声消除）的作用是什么？在什么场景下必须启用？
3. Opus 编码的压缩比大约是多少？为什么需要压缩？
4. PDM 到 PCM 的转换由什么完成？是硬件还是软件？
5. 在 SDK 的哪个目录下可以找到音频服务的 API 头文件？
6. 下行音频从手机到扬声器经过哪些步骤？
7. 双扬声器（双声道）在硬件上如何实现？需要哪些 Kconfig 配置？
8. 如果麦克风没有声音，你会从哪些方面排查（至少 3 个）？
9. VAD 的作用是什么？省电的原理是什么？
10. 音频数据在 ACORE 和 DCORE 之间如何传输？

---

## 延伸阅读

- [[pdm-mic-PDM麦克风]] — 采集入口
- [[i2s-protocol-I2S协议]] — 播放输出接口
- [[wq-audio-protocol-WQ-Audio-Protocol]] — 音频帧的传输封装
- [[ble-gatt-BLE-GATT]] — C3 Audio Stream Characteristic
- [[max98357a-MAX98357A功放]] — 扬声器驱动
- [[sdm0103b-SDM0103B数字麦]] — 麦克风硬件
- [[dataflow-mic-to-phone-声音从麦到手机]] — 完整数据流追踪
- [[audio-system-音频系统基础]] — 采样率/位深/AEC/Opus 等底层原理
- [[memory-dma-内存管理与DMA]] — DMA 双缓冲、Cache 一致性
- [[interrupt-concurrency-中断并发同步]] — DMA 中断与音频任务之间的同步
- [[ext-trans-Ext-Trans框架]] — I2S 通过 Ext Trans 框架集成

#flashcard
问：音频采集链的 5 个处理阶段是什么？
答：① PDM 采集 ② Decimation (PDM→PCM) ③ DSP (AEC/降噪/AGC/VAD) ④ Opus 编码 ⑤ WQ Protocol 帧封装 → BLE 发送。

问：AEC（回声消除）的作用是什么？
答：消除扬声器播放的声音被麦克风再次录入形成的回声。比如在播放音乐的同时说话，AEC 会把音乐声从麦克风信号中去掉。

问：reGlasses 使用什么音频编解码器做 BLE 传输？
答：Opus。PCM 16kHz/16bit = 256kbps，Opus 压缩到 16-32kbps，压缩比约 8-16 倍。

问：音频下行数据流经过哪些步骤？
答：手机 → BLE → WQ Protocol 解析 → Opus 解码 → PCM 混音/音量调节 → I2S 输出 → MAX98357A 功放 → 扬声器。

问：在 SDK 中音频服务 API 头文件在哪个目录？
答：`wq-adk/components/audio_service/api/aud_sv_api.h`。