# 视频编码与 ISP

**一句话结论（20% 核心）**：ISP（Image Signal Processor）是摄像头 Sensor 的"修图师"——把 RAW 数据变成好看的画面（白平衡、降噪、色彩校正）。H.264/H.265 是"压缩师"——把连续画面压缩到能传输的大小（200:1 压缩比）。reGlasses 用 V881 的硬件 ISP + 硬件编码器做实时视频采集和传输。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：摄影师 + 压缩软件

- **ISP** = 摄影师修图：RAW 格式的照片（灰蒙蒙的，偏色）→ 经过白平衡、曝光调整、降噪 → 变成好看的 JPEG
- **H.264 编码** = 压缩软件：100MB 的照片文件夹 → ZIP 压缩成 5MB，画质没怎么变
- **硬件编码器** = 专用的压缩硬件：比 CPU 软件压缩快 100 倍，功耗低 10 倍

### 1.2 ISP 的处理流水线

```
摄像头 Sensor → RAW Bayer 数据
    │
    ↓ ① 黑电平校正 (BLC)
    ↓ ② 坏点校正 (DPC)
    ↓ ③ 去马赛克 (Demosaic): Bayer → RGB
    ↓ ④ 白平衡 (AWB): 修正色温，让白色看起来是白色
    ↓ ⑤ 色彩校正 (CCM): RGB → 标准色彩空间
    ↓ ⑥ Gamma 校正: 让暗部更亮，亮部更暗（人眼对暗部敏感）
    ↓ ⑦ 降噪 (Denoise): 去除暗光下的噪点
    ↓ ⑧ 锐化 (Sharpen): 增强边缘
    │
    ↓ YUV 格式数据 (通常是 NV12/NV21)
```

**每一个环节都有对应的寄存器可以调**。ISP 调优（tuning）是图像质量工程师的核心工作。

### 1.3 H.264 压缩的核心：I/P/B 帧

```
视频 = 连续的帧画面。相邻帧之间差异很小（背景不变，只有人在动）。

I 帧 (Intra/关键帧):  完整的 JPEG 压缩画面，可独立解码。    大，压缩率低
P 帧 (Predictive):    只存和前一个 I/P 帧的差异（运动矢量）。小，压缩率高
B 帧 (Bidirectional): 存和前后帧的差异。                    最小，压缩率最高

典型 GOP 结构: I B B P B B P B B I ...
一个 GOP 中只有 1 个 I 帧，其余都是 P/B 帧 → 大幅压缩

为什么 I 帧间隔很重要？
  - 视频花屏后，必须等到下一个 I 帧才能恢复完整画面
  - I 帧间隔太大 → 花屏后恢复慢
  - I 帧间隔太小 → 压缩率低，带宽高
  - 典型值: 1-2 秒一个 I 帧 (30-60 帧)
```

### 1.4 H.264 vs H.265

| | H.264 | H.265 (HEVC) |
|---|---|---|
| 压缩率 | 基准 | **比 H.264 高 50%**（同等画质码率减半） |
| 编码复杂度 | 基准 | 2-10 倍（需要更强的硬件编码器） |
| 解码复杂度 | 低 | 中（大多数手机硬件支持） |
| 专利 | MPEG-LA | 多个专利池（更复杂） |
| 适用场景 | 通用 | 4K/8K、低带宽场景 |
| reGlasses | **当前使用** | 可选（如果 V881 支持） |

### 1.5 如果只记得一件事

> ISP 修图（RAW→YUV 的美化流水线），H.264 压缩（I/P/B 帧去冗余，200:1 压缩比）。V881 有硬件 ISP 和硬件 H.264 编码器，1080p 实时压缩只需 ~5 Mbps。H.265 比 H.264 压缩率再高 50%。

---

## 第二层：实战理解

### 2.1 V881 视频管道的完整流程

```
V881 摄像头 Sensor (MIPI CSI)
    │ RAW Bayer 数据 (1920×1080, 10bit, 30fps)
    ↓
ISP (硬件，Allwinner ISP)
    │ → BLC → DPC → Demosaic → AWB → CCM → Gamma → Denoise
    ↓ YUV NV12/NV21 (1920×1080)
    ↓
VENC (硬件 H.264 编码器, Allwinner VE)
    │ → 运动估计 → 变换量化 → 熵编码
    ↓ H.264 比特流 (I/P/B 帧, ~5 Mbps)
    ↓
RTSP Server / UDP Socket
    ↓
WiFi (V881) → 手机 APP
```

### 2.2 码率控制：CBR vs VBR

```c
// CBR (Constant Bit Rate): 固定码率，适合稳定带宽的传输
// VBR (Variable Bit Rate): 可变码率，复杂画面给更多码率

// 典型配置（V4L2 + VENC）
struct venc_config cfg = {
    .codec      = VENC_CODEC_H264,
    .bitrate    = 5000000,        // 5 Mbps
    .rc_mode    = VENC_RC_CBR,    // 固定码率
    .gop_size   = 30,             // 每 30 帧一个 I 帧 (1 秒)
    .profile    = H264_PROFILE_HIGH,
    .level      = H264_LEVEL_4_0,
};
```

### 2.3 常见坑

| 问题 | 现象 | 排查方法 | 根因 |
|------|------|---------|------|
| I 帧间隔太大 | 花屏后数秒才恢复 | 减小 GOP size | I 帧间隔过长，关键帧来得太慢 |
| 码率太低 | 运动场景画面模糊、马赛克 | 提高码率或用 VBR | 带宽不够，编码器丢弃了高频细节 |
| ISP 白平衡不对 | 画面偏蓝/偏黄 | 调整 AWB 参数或改为固定色温 | 自动白平衡不准确，或色温传感器不工作 |
| 编码延迟大 | 画面延迟 500ms+ | 减少 B 帧数量，用 baseline profile | B 帧需要前后帧，增加了编码延迟 |
| 硬件编码器过载 | 30fps 掉到 15fps | 降低分辨率或帧率 | 编码器处理能力不够 |

### 2.4 在 reGlasses 项目中怎么用

V881 负责全部视频处理：
- **ISP 驱动**：在 `~/aiglass/tina-v861/kernel/linux/drivers/media/platform/sunxi/isp/` 下
- **VENC 驱动**：在 `~/aiglass/tina-v861/kernel/linux/drivers/media/platform/sunxi/venc/` 下
- **应用层**：通过 V4L2 接口控制 ISP 和 VENC

WQ7036AX 不参与视频处理——它的职责是音频采集+蓝牙传输。

---

## 第三层：深入扩展

### 3.1 常见问题

- **RAW 和 YUV 的区别？** RAW 是 Sensor 最原始的输出（每个像素只有一种颜色，Bayer 排列），YUV 是经过 ISP 处理后的完整彩色图像。RAW 文件大但包含完整信息，YUV 是处理后的可用于编码/显示的格式。
- **为什么需要硬件编码器？** 1080p@30fps 的 H.264 编码，CPU 软件编码需要 ~2GHz 的 4 核全力运行，功耗 5-10W。硬件编码器功耗 <0.5W，性能更好。
- **H.264 Profile 的选择？** Baseline（最低延迟，无 B 帧）→ 适合实时视频通话。Main（中等延迟）→ 适合录制。High（最高压缩率）→ 适合存储和点播。

### 3.2 延伸阅读

- [[v4l2-camera-V4L2摄像头驱动]] — 视频采集的 Linux 驱动框架
- [[gstreamer-pipeline-GStreamer管道]] — 视频处理链的高级封装
- [[mipi-usb-sdio-MIPI-USB-SDIO高速接口]] — MIPI CSI 物理层