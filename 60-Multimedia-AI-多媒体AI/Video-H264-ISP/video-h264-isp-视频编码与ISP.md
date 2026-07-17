---
type: concept
tags: [视频编码, ISP, H.264, H.265, 图像处理, 摄像头, 嵌入式]
aliases: [视频编码, ISP, H.264, 图像信号处理]
---

# 视频编码与 ISP

## 一句话结论

ISP（Image Signal Processor）是摄像头 Sensor 的"修图师"——把 RAW 数据变成好看的画面（白平衡、降噪、色彩校正）。H.264/H.265 是"压缩师"——把连续画面压缩到能传输的大小（200:1 压缩比）。reGlasses 用 V881 的硬件 ISP + 硬件编码器做实时视频采集和传输。

## 30秒先看懂

1. ISP 把 Sensor 的 RAW Bayer 数据（灰蒙蒙的原始数据）处理成 YUV 格式的好看画面，包括黑电平校正、白平衡、降噪、锐化等八个步骤。
2. H.264 利用 I/P/B 帧消除帧间冗余——I 帧是关键帧（完整画面），P/B 帧只存差异，压缩比可达 200:1。
3. 硬件编码器比 CPU 软件编码快 100 倍、功耗低 10 倍——1080p@30fps 的 H.264 编码，硬件编码器功耗 < 0.5W。
4. H.265 (HEVC) 比 H.264 压缩率再高 50%，但编码复杂度高 2-10 倍，需要更强的硬件编码器。
5. V881 使用硬件 ISP 和硬件 H.264 编码器，1080p@30fps 实时压缩只需约 5Mbps。

## 学完以后应该能做什么

### 第一遍
- 理解 ISP 的处理流水线（RAW → YUV 的八个步骤）
- 理解 H.264 的 I/P/B 帧结构和 GOP 概念
- 区分 H.264 和 H.265 的差异和选型依据
- 理解硬件编码器 vs 软件编码器的优劣

### 进阶
- 配置 ISP 参数（白平衡、曝光、降噪强度）
- 理解码率控制（CBR vs VBR）和 GOP 结构对视频质量的影响
- 在 V881 上通过 V4L2 接口控制 ISP 和 VENC
- 调试视频编码质量问题（花屏、马赛克、延迟）

## 前置知识

- 基本的图像处理概念（像素、分辨率、色彩空间）
- 摄像头工作原理
- 嵌入式 Linux 驱动基础

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 图像信号处理器 | ISP (Image Signal Processor) | 将 Sensor RAW 数据转换为高质量 YUV 图像的硬件模块 |
| 原始 Bayer 数据 | RAW Bayer | Sensor 直接输出的原始数据，每个像素只有一种颜色（R/G/B） |
| 去马赛克 | Demosaic | 从 Bayer 排列还原出每个像素完整 RGB 值的过程 |
| 白平衡 | AWB (Auto White Balance) | 修正色温偏色，让白色看起来是白色 |
| 关键帧 | I Frame (Intra Frame) | 完整编码的帧，可独立解码，不依赖其他帧 |
| 预测帧 | P/B Frame | 只存储与前后帧的差异，压缩率高但依赖其他帧 |
| 图像组 | GOP (Group of Pictures) | I 帧之间的帧组，GOP 大小决定 I 帧间隔 |
| 码率控制 | Rate Control | 控制编码器输出码率的策略（CBR 固定码率 / VBR 可变码率） |

## 第一层：费曼心智模型

### 类比：摄影师 + 压缩软件

- **ISP** = 摄影师修图：RAW 格式的照片（灰蒙蒙的，偏色）→ 经过白平衡、曝光调整、降噪 → 变成好看的 JPEG
- **H.264 编码** = 压缩软件：100MB 的照片文件夹 → ZIP 压缩成 5MB，画质没怎么变
- **硬件编码器** = 专用的压缩硬件：比 CPU 软件压缩快 100 倍，功耗低 10 倍

### 边界

- ISP 不是万能的：在极暗光环境下，ISP 无法创造信息，画面会充满噪点
- 硬件编码器不能处理所有编码格式：芯片自带的硬件编码器通常只支持特定格式（如 H.264）
- H.265 虽然压缩率更高，但不是所有手机都支持硬件解码——老款手机可能卡顿
- 压缩比越高，编码延迟越大——实时视频通话需要在压缩率和延迟之间权衡

### 场景推演：V881 视频采集和传输

1. 摄像头 Sensor 捕捉到 1080p 画面，输出 RAW Bayer 10bit 数据
2. ISP 硬件处理：黑电平校正 → 去马赛克 → 白平衡 → 色彩校正 → Gamma → 降噪 → 锐化
3. 输出 YUV NV12 格式（1920×1080，每秒 30 帧）
4. 硬件 H.264 编码器编码：每帧分析，区分 I/P/B 帧，输出 H.264 比特流
5. 每 30 帧插入一个 I 帧（1 秒一个关键帧），其余为 P/B 帧
6. 最终码率约 5Mbps，通过 WiFi 推送到手机 APP

## 第二层：原理/时序/约束

### ISP 的处理流水线

```
摄像头 Sensor → RAW Bayer 数据
    │
    ↓ ① 黑电平校正 (BLC): 去除 Sensor 暗电流噪声
    ↓ ② 坏点校正 (DPC): 修复 Sensor 上的坏像素
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

### H.264 压缩的核心：I/P/B 帧

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

### H.264 vs H.265

| | H.264 | H.265 (HEVC) |
|---|---|---|
| 压缩率 | 基准 | **比 H.264 高 50%**（同等画质码率减半） |
| 编码复杂度 | 基准 | 2-10 倍（需要更强的硬件编码器） |
| 解码复杂度 | 低 | 中（大多数手机硬件支持） |
| 专利 | MPEG-LA | 多个专利池（更复杂） |
| 适用场景 | 通用 | 4K/8K、低带宽场景 |
| reGlasses | **当前使用** | 可选（如果 V881 支持） |

### 码率控制：CBR vs VBR

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

## 第三层：真实SDK代码

### V881 视频管道的完整流程

在 `/home/ys/aiglass/tina-v861/kernel/linux/drivers/media/platform/sunxi/isp/` 和 `venc/` 中：

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

### V4L2 控制 ISP 参数

```c
// 伪代码——通过 V4L2 控制 ISP
// 文件路径: reglasses/services/camera/isp_control.c

#include <linux/videodev2.h>
#include <sys/ioctl.h>

int fd = open("/dev/video0", O_RDWR);

// 设置曝光时间
struct v4l2_ext_control ctrl[] = {
    { .id = V4L2_CID_EXPOSURE_ABSOLUTE, .value = 1000 },  // 1ms
    { .id = V4L2_CID_GAIN, .value = 128 },                 // 增益
};
struct v4l2_ext_controls ctrls = {
    .count = 2,
    .controls = ctrl,
};
ioctl(fd, VIDIOC_S_EXT_CTRLS, &ctrls);

// 设置白平衡模式
struct v4l2_control awb = {
    .id = V4L2_CID_AUTO_WHITE_BALANCE,
    .value = 1,  // 自动白平衡
};
ioctl(fd, VIDIOC_S_CTRL, &awb);
```

### 硬件编码器配置

```c
// 伪代码——V881 硬件 H.264 编码器配置
// 文件路径: reglasses/services/camera/venc_config.c

// 通过 V4L2 的编码器接口（M2M 设备）
int venc_fd = open("/dev/video1", O_RDWR);

// 设置编码格式
struct v4l2_format fmt = {
    .type = V4L2_BUF_TYPE_VIDEO_OUTPUT_MPLANE,
    .fmt.pix_mp = {
        .width = 1920,
        .height = 1080,
        .pixelformat = V4L2_PIX_FMT_NV12,
        .field = V4L2_FIELD_NONE,
        .num_planes = 1,
    },
};
ioctl(venc_fd, VIDIOC_S_FMT, &fmt);

// 设置码率控制
struct v4l2_ext_control ctrl[] = {
    { .id = V4L2_CID_MPEG_VIDEO_BITRATE, .value = 5000000 },
    { .id = V4L2_CID_MPEG_VIDEO_BITRATE_MODE,
      .value = V4L2_MPEG_VIDEO_BITRATE_MODE_CBR },
    { .id = V4L2_CID_MPEG_VIDEO_GOP_SIZE, .value = 30 },
};
```

## 第四层：正常/异常路径

### 正常路径

```
Sensor 采集 → MIPI CSI 传输 RAW 数据
  → ISP 硬件处理（8 步流水线）
  → YUV 帧通过 DMA 写入内存
  → VENC 硬件编码（运动估计 → 变换量化 → 熵编码）
  → H.264 帧写入输出缓冲区
  → 应用层读取编码帧，通过 RTSP/UDP 发送
```

### 异常路径

| 异常 | 现象 | 触发条件 | 恢复方式 |
|------|------|---------|---------|
| I 帧间隔太大 | 花屏后数秒才恢复 | GOP size 过大 | 减小 GOP 到 30-60 帧 |
| 码率太低 | 运动场景画面模糊、马赛克 | 带宽不够，编码器丢弃高频细节 | 提高码率或用 VBR 模式 |
| 白平衡不对 | 画面偏蓝/偏黄 | 自动白平衡不准确 | 手动设定色温值或校准 AWB |
| 编码延迟大 | 画面延迟 500ms+ | B 帧太多或编码器处理慢 | 用 Baseline profile（无 B 帧） |
| 硬件编码器过载 | 30fps 掉到 15fps | 分辨率或帧率超出硬件能力 | 降低分辨率或帧率 |
| Sensor 曝光不对 | 画面过亮/过暗 | 自动曝光不正确 | 调整曝光补偿或固定曝光时间 |

## 第五层：调试方法

### 视频调试工具

```bash
# 查看摄像头设备
v4l2-ctl --list-devices
v4l2-ctl -d /dev/video0 --all

# 查看支持的格式
v4l2-ctl -d /dev/video0 --list-formats-ext

# 设置参数
v4l2-ctl -d /dev/video0 --set-ctrl=exposure=1000
v4l2-ctl -d /dev/video0 --set-ctrl=white_balance=1

# 抓取单帧测试
ffmpeg -f v4l2 -video_size 1920x1080 -i /dev/video0 -frames 1 test.jpg
```

### 编码质量分析

```bash
# 分析编码后的视频
ffprobe encoded.h264

# 查看帧类型分布
ffprobe -show_frames encoded.h264 | grep pict_type | sort | uniq -c

# 查看码率
ffprobe -show_streams encoded.h264 | grep -E "bit_rate|nb_frames"

# 比较原始和编码后的质量
ffmpeg -i original.yuv -i encoded.h264 -filter_complex psnr -f null -
```

## 第六层：实战练习

### 练习1：分析 GOP 结构对视频大小的影响

用 ffmpeg 将同一段视频编码为不同 GOP 大小的 H.264 文件，对比文件大小和图像质量：

```bash
# GOP=10（每 10 帧一个 I 帧）
ffmpeg -i input.mp4 -c:v libx264 -g 10 -t 10 output_g10.mp4
# GOP=60（每 60 帧一个 I 帧）
ffmpeg -i input.mp4 -c:v libx264 -g 60 -t 10 output_g60.mp4
# 对比文件大小
ls -la output_g*.mp4
```

### 练习2：CBR vs VBR 对比

将同一段视频分别用 CBR（2Mbps）和 VBR（平均 2Mbps）编码，对比画面质量差异，特别是运动场景和静态场景的区别。

### 练习3：阅读真实源码——V881 ISP 驱动配置

在 `/home/ys/aiglass/tina-v861/kernel/linux/drivers/media/platform/sunxi/isp/` 目录下，阅读 ISP 驱动的源码，分析：
1. ISP 的初始化流程（注册了哪些 V4L2 控制项？）
2. ISP 的处理流水线中哪些步骤可以通过用户空间配置？
3. 如何调整 ISP 参数（曝光、增益、白平衡）？

## 自测与验收

1. ISP 的主要作用是什么？RAW 数据和 YUV 数据有什么区别？
2. H.264 中 I 帧、P 帧、B 帧的区别是什么？GOP 大小对视频有什么影响？
3. H.264 和 H.265 的主要区别是什么？为什么 reGlasses 用 H.264 而不是 H.265？
4. 硬件编码器和软件编码器相比有什么优缺点？
5. CBR 和 VBR 码率控制分别适用于什么场景？
6. 为什么视频花屏后必须等到下一个 I 帧才能恢复？

## 延伸阅读

- [[v4l2-camera-V4L2摄像头驱动]] — 视频采集的 Linux 驱动框架
- [[gstreamer-pipeline-GStreamer管道]] — 视频处理链的高级封装
- [[mipi-usb-sdio-MIPI-USB-SDIO高速接口]] — MIPI CSI 物理层
- [[audio-system-音频系统基础]] — 音视频同步的基础

## #flashcard

Q: ISP 的作用是什么？主要处理步骤？
A: ISP 将 Sensor RAW 数据转换为 YUV 图像。主要步骤：BLC → DPC → Demosaic → AWB → CCM → Gamma → Denoise → Sharpen。

Q: H.264 的 I/P/B 帧的区别？
A: I 帧 = 完整画面（关键帧），P 帧 = 只存和前帧差异，B 帧 = 存和前后帧的差异。B 帧压缩率最高，但需要前后帧都准备好。

Q: GOP 大小对视频的影响？
A: GOP 越小（I 帧越多），花屏恢复越快，但压缩率越低。GOP 越大，压缩率越高，但花屏后恢复慢。

Q: H.264 和 H.265 的主要区别？
A: H.265 压缩率比 H.264 高 50%，但编码复杂度高 2-10 倍，需要更强的硬件编码器。

Q: 为什么硬件编码器比软件编码器好？
A: 硬件编码器用专用电路，速度比 CPU 软件编码快 100 倍，功耗低 10 倍以上。