---
type: concept
tags: [linux, v4l2, camera, video, driver, aiglass]
aliases: [V4L2摄像头驱动, Video4Linux2, 视频采集]
---

# V4L2 摄像头驱动

## 一句话结论

V4L2（Video4Linux2）是 Linux 的视频/摄像头驱动框架。应用层通过 `ioctl` 设置格式、请求缓冲区、启动采集，驱动层负责从摄像头硬件读取帧数据并填充到缓冲区。

## 30秒先看懂

- V4L2 的核心流程是一个六步循环：打开设备 → 设置格式（VIDIOC_S_FMT）→ 申请缓冲区（VIDIOC_REQBUFS）→ 映射到用户空间（mmap）→ 启动采集（VIDIOC_STREAMON）→ 循环取帧（DQBUF → 处理 → QBUF）。缓冲区的生命周期由应用和驱动共同管理：应用通过 QBUF 把空缓冲区交给驱动，驱动填充数据后通过 DQBUF 还给应用。V4L2 支持三种缓冲区管理方式：MMAP（驱动分配，用户 mmap 映射）、USERPTR（应用分配，用户传递指针）和 DMABUF（通过 DMA-BUF 共享）。在 reGlasses 项目中，V881 的广角摄像头通过 `/dev/video0` 访问，TOF 摄像头通过 `/dev/video1` 访问。

## 学完以后应该能做什么

**第一遍看完后可以：**
- 理解 V4L2 的采集流程和六个核心 ioctl
- 编写简单的 V4L2 采集程序（设置格式 → 采集 → 处理帧）
- 知道 MMAP 和 USERPTR 两种缓冲区管理方式的区别
- 使用 `v4l2-ctl` 工具查看摄像头设备信息

**进阶后可以：**
- 编写 V4L2 驱动的 subdev 和 video_device
- 使用 DMA-BUF 实现摄像头到显示的零拷贝 pipeline
- 调试摄像头驱动问题（格式不支持、帧率不够、缓冲不足）
- 处理多路摄像头同时采集的场景

## 前置知识

- Linux 字符设备驱动基础
- ioctl 系统调用的原理
- 视频格式基础知识（YUV、NV12、MJPEG）

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 视频 4 Linux 2 | V4L2 | Video4Linux2，Linux 视频采集框架 |
| 输入输出控制 | ioctl | Input/Output Control，设备控制命令 |
| 缓冲区请求 | REQBUFS | Request Buffers，向驱动申请视频缓冲区 |
| 入队/出队 | QBUF / DQBUF | Queue Buffer / Dequeue Buffer，缓冲区管理 |
| 流开启/关闭 | STREAMON / STREAMOFF | 启动/停止视频采集 |
| 内存映射 | MMAP | Memory Map，把驱动缓冲区映射到用户空间 |
| 格式设置 | S_FMT / G_FMT | Set Format / Get Format，设置/获取视频格式 |
| 子设备 | subdev | V4L2 子设备，表示摄像头传感器等独立硬件 |
| 帧 | Frame | 一帧完整的视频画面 |
| 像素格式 | Pixel Format | 像素数据的编码方式（NV12、YUYV、MJPEG） |

## 第一层：费曼心智模型

### 类比：保安室的监控系统

V4L2 = 监控系统的完整工作流：
- ① 设置画质（`VIDIOC_S_FMT`）——"我要 1080p 30fps"
- ② 申请缓冲区（`VIDIOC_REQBUFS`）——"给我 4 个屏幕放视频"
- ③ 映射到用户空间（`mmap`）——"把屏幕接到我办公室"
- ④ 开始采集（`VIDIOC_STREAMON`）——"开始录像"
- ⑤ 取出帧（`VIDIOC_DQBUF`）——"把这一帧画面给我"
- ⑥ 用完放回（`VIDIOC_QBUF`）——"这个屏幕可以存下一帧了"

**边界：**
- V4L2 不处理视频编解码——那是 codec 驱动的工作
- 缓冲区数量不是越多越好——太多浪费内存，太少可能导致丢帧
- V4L2 不是零拷贝——帧数据在驱动和应用之间传递需要拷贝，但 DMA-BUF 可以绕过

### 场景演练：摄像头采集并显示

1. 打开 `/dev/video0`，查询设备能力
2. 设置格式为 1920x1080 NV12，30fps
3. 申请 4 个 MMAP 缓冲区
4. 把所有 4 个缓冲区 QBUF 交给驱动
5. STREAMON 启动采集
6. 驱动从摄像头传感器采集一帧，填充到缓冲区 A
7. DQBUF 取出缓冲区 A
8. 把缓冲区 A 的数据通过 DMA-BUF 发给 DRM 显示
9. 处理完后 QBUF 把缓冲区 A 还给驱动
10. 循环 6-9

## 第二层：原理/时序/约束

### 核心 ioctl 时序

```
应用:                          驱动:
  │                              │
  ├─ open("/dev/video0") ──────→ │
  ├─ QUERYCAP ─────────────────→ │  ← 查询能力
  ├─ S_FMT (1920x1080, NV12) ──→ │  ← 设置格式
  ├─ REQBUFS (count=4) ────────→ │  ← 申请缓冲区
  │                              ├─ 分配 DMA 缓冲区
  │←────── 返回 4 个 buffer ────┤
  ├─ 对每个 buffer 做 mmap ────→ │  ← 映射到用户空间
  ├─ QBUF (buf[0..3]) ─────────→ │  ← 把缓冲区交给驱动
  ├─ STREAMON ─────────────────→ │  ← 开始采集
  │                              ├─ 启动摄像头传感器
  │                              ├─ 采集帧 → 填 buf[0]
  ├─ DQBUF ────────────────────→ │  ← 取帧
  │←────── buf[0] 已就绪 ────────┤
  ├─ 处理帧数据                   │
  ├─ QBUF (buf[0]) ────────────→ │  ← 放回缓冲区
  │                              ├─ 采集帧 → 填 buf[1]
  │  ... 循环 ...                │
  ├─ STREAMOFF ────────────────→ │  ← 停止采集
  ├─ close() ──────────────────→ │
```

### 最小采集代码

```c
int fd = open("/dev/video0", O_RDWR);

// 设置格式
struct v4l2_format fmt = {0};
fmt.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
fmt.fmt.pix.width  = 1920;
fmt.fmt.pix.height = 1080;
fmt.fmt.pix.pixelformat = V4L2_PIX_FMT_NV12;
ioctl(fd, VIDIOC_S_FMT, &fmt);

// 申请缓冲区
struct v4l2_requestbuffers req = {0};
req.type   = V4L2_BUF_TYPE_VIDEO_CAPTURE;
req.memory = V4L2_MEMORY_MMAP;
req.count  = 4;
ioctl(fd, VIDIOC_REQBUFS, &req);

// 启动采集
ioctl(fd, VIDIOC_STREAMON, &req.type);

// 采集循环
while (running) {
    struct v4l2_buffer buf = {0};
    buf.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    buf.memory = V4L2_MEMORY_MMAP;
    ioctl(fd, VIDIOC_DQBUF, &buf);  // 取一帧
    process_frame(buf);              // 处理
    ioctl(fd, VIDIOC_QBUF, &buf);   // 放回缓冲区
}
```

## 第三层：真实 SDK 代码

### reGlasses 的 V4L2 使用

在 reGlasses 项目中，V881 的摄像头通过 V4L2 框架驱动。应用层代码参考 `/home/ys/aiglass/tina-v861/platform/allwinner/eyesee-apps/demo_uvc/extream_dual_stream_demo/v4l2_demo.c`：

```c
// V4L2 采集示例
static int v4l2_capture_init(const char *dev, int width, int height) {
    int fd = open(dev, O_RDWR);
    // 设置格式
    struct v4l2_format fmt = {0};
    fmt.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    fmt.fmt.pix.width = width;
    fmt.fmt.pix.height = height;
    fmt.fmt.pix.pixelformat = V4L2_PIX_FMT_NV12;
    ioctl(fd, VIDIOC_S_FMT, &fmt);

    // 申请缓冲区
    struct v4l2_requestbuffers req = {0};
    req.count = 4;
    req.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    req.memory = V4L2_MEMORY_MMAP;
    ioctl(fd, VIDIOC_REQBUFS, &req);
    return fd;
}
```

### V4L2 内核驱动核心

V4L2 内核框架在 `/home/ys/aiglass/tina-v861/kernel/linux-6.6-xuantie/drivers/media/v4l2-core/` 下：

```c
// /home/ys/aiglass/tina-v861/kernel/linux-6.6-xuantie/drivers/media/v4l2-core/v4l2-device.c
// V4L2 设备注册
int v4l2_device_register(struct device *dev, struct v4l2_device *v4l2_dev);

// Video 设备注册
int video_register_device(struct video_device *vdev, int type, int nr);
```

### 调试工具

```bash
# 查看 V4L2 设备
v4l2-ctl --list-devices

# 查看支持的格式
v4l2-ctl -d /dev/video0 --list-formats

# 查看当前参数
v4l2-ctl -d /dev/video0 --all

# 抓取一帧保存为文件
v4l2-ctl -d /dev/video0 --set-fmt-video=width=1920,height=1080,pixelformat=NV12 \
  --stream-mmap --stream-to=frame.raw --stream-count=1
```

## 第四层：正常/异常路径

### 正常路径

open → QUERYCAP → S_FMT → REQBUFS → mmap → QBUF → STREAMON → DQBUF → 处理 → QBUF → ... → STREAMOFF → close

### 异常路径

| 异常场景 | 现象 | 原因 | 处理方式 |
|---------|------|------|---------|
| 格式不支持 | S_FMT 失败 | 摄像头不支持请求的分辨率或像素格式 | 检查支持的格式列表 |
| 缓冲区不足 | DQBUF 阻塞 | 缓冲区数量太少或处理速度低于采集速度 | 增加缓冲区数量 |
| 帧率不够 | 画面卡顿 | 采集帧率低于显示帧率 | 降低分辨率或调整帧率 |
| 设备忙 | open 失败 | 另一个进程已占用设备 | 使用 `v4l2-ctl` 查看占用情况 |
| DMA 缓冲区分配失败 | REQBUFS 失败 | 内存不足 | 减少缓冲区数量或大小 |

## 第五层：调试方法

```bash
# 查看 V4L2 设备状态
v4l2-ctl -d /dev/video0 --all

# 查看内核日志
dmesg | grep -i v4l2

# 查看驱动注册的 video_device
ls -la /dev/video*

# 测试帧率
v4l2-ctl -d /dev/video0 --set-fmt-video=width=640,height=480,pixelformat=NV12 \
  --stream-mmap --stream-count=100 --stream-to=/dev/null
# 输出会显示实际帧率

# 检查缓冲区状态
cat /sys/kernel/debug/video0/buffers
```

## 第六层：实战练习

### 练习 1：V4L2 采集程序（基础）

编写一个简单的 V4L2 采集程序：
1. 打开 `/dev/video0`
2. 设置格式为 640x480 YUYV
3. 申请 4 个 MMAP 缓冲区
4. 启动采集，采集 10 帧
5. 每帧保存为文件
6. 用 `ffplay` 或图像查看器查看结果

### 练习 2：MMAP vs USERPTR 对比（进阶）

对比 MMAP 和 USERPTR 两种缓冲区管理方式的性能：
1. 分别用 MMAP 和 USERPTR 实现采集
2. 在采集循环中测量每帧的处理时间
3. 对比两种方式的内存占用
4. 分析哪种方式在什么场景下更优

### 练习 3：阅读 V4L2 驱动源码（深入）

阅读 `/home/ys/aiglass/tina-v861/kernel/linux-6.6-xuantie/drivers/media/v4l2-core/v4l2-device.c`，回答：
1. `v4l2_device_register` 函数做了什么？
2. video_device 和 v4l2_device 的关系是什么？
3. 驱动如何实现 `vidioc_s_fmt` 回调？
4. 缓冲区管理是如何实现的？

## 自测与验收

1. V4L2 的六个核心 ioctl 是什么？按顺序说明。
2. MMAP 和 USERPTR 两种缓冲区管理方式的区别是什么？
3. QBUF 和 DQBUF 的作用是什么？
4. 为什么需要多个缓冲区（为什么是 count=4 而不是 1）？
5. 什么是 V4L2 subdev？它和 video_device 的关系是什么？
6. 摄像头采集的帧率达不到预期，可能的原因有哪些？
7. 如何实现摄像头到显示器的零拷贝 pipeline？

## 延伸阅读

- [[drm-display-DRM显示驱动]] — 视频采集后用 DRM 显示
- [[char-device-字符设备驱动]] — V4L2 设备也是字符设备
- [[mipi-usb-sdio-MIPI-USB-SDIO高速接口]] — 摄像头接口物理层

## #flashcard

**Q: V4L2 六步采集流程是什么？**
A: 打开设备 → 设置格式（S_FMT）→ 申请缓冲区（REQBUFS）→ 映射（mmap）→ 启动采集（STREAMON）→ 循环（DQBUF → 处理 → QBUF）。

**Q: QBUF 和 DQBUF 的作用？**
A: QBUF 把空缓冲区交给驱动填充数据，DQBUF 从驱动取出已填充数据的缓冲区。

**Q: V4L2 支持哪三种缓冲区管理方式？**
A: MMAP（驱动分配，用户 mmap 映射）、USERPTR（应用分配，用户传递指针）、DMABUF（DMA-BUF 共享）。

**Q: 为什么需要多个缓冲区？**
A: 保证驱动在应用处理一帧时仍有缓冲区可写，避免丢帧。通常 3-4 个缓冲区是平衡点。

**Q: V4L2 和 V4L2 subdev 的关系？**
A: subdev 表示摄像头传感器等独立硬件模块，video_device 是用户空间看到的设备节点。