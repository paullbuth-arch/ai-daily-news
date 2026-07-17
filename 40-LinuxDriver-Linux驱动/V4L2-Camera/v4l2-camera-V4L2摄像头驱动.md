# V4L2 摄像头驱动

**一句话结论（20% 核心）**：V4L2（Video4Linux2）是 Linux 的视频/摄像头驱动框架。应用层通过 `ioctl` 设置格式、请求缓冲区、启动采集，驱动层负责从摄像头硬件读取帧数据并填充到缓冲区。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：保安室的监控系统

V4L2 = 监控系统的完整工作流：
- ① 设置画质（`VIDIOC_S_FMT`）——"我要 1080p 30fps"
- ② 申请缓冲区（`VIDIOC_REQBUFS`）——"给我 4 个屏幕放视频"
- ③ 映射到用户空间（`mmap`）——"把屏幕接到我办公室"
- ④ 开始采集（`VIDIOC_STREAMON`）——"开始录像"
- ⑤ 取出帧（`VIDIOC_DQBUF`）——"把这一帧画面给我"
- ⑥ 用完放回（`VIDIOC_QBUF`）——"这个屏幕可以存下一帧了"

### 1.2 核心 ioctl 命令

| 命令 | 含义 | 调用时机 |
|------|------|---------|
| `VIDIOC_QUERYCAP` | 查询设备能力 | 打开设备后 |
| `VIDIOC_S_FMT` | 设置视频格式 | 采集前 |
| `VIDIOC_REQBUFS` | 申请缓冲区 | 格式设置后 |
| `VIDIOC_QBUF` | 把缓冲区交给驱动 | 启动前/每帧用完 |
| `VIDIOC_STREAMON` | 开始采集 | 一切就绪 |
| `VIDIOC_DQBUF` | 取出已填充的帧 | 采集循环中 |

### 1.3 如果只记得一件事

> V4L2 = Linux 视频采集框架。核心流程：设置格式 → 申请缓冲区 → 启动采集 → 循环取帧 → 用完放回。应用层用 ioctl 控制，驱动层负责填缓冲区。

---

## 第二层：实战理解

### 2.1 应用层最小采集代码

```c
int fd = open("/dev/video0", O_RDWR);

// 设置格式
struct v4l2_format fmt = {0};
fmt.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
fmt.fmt.pix.width  = 1920;
fmt.fmt.pix.height = 1080;
fmt.fmt.pix.pixelformat = V4L2_PIX_FMT_NV12; // YUV 格式
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

### 2.2 在 reGlasses 项目中怎么用

V881 的摄像头（广角+TOF）通过 V4L2 框架驱动。WQ7036AX 没有摄像头，不涉及 V4L2。应用层通过 `/dev/video0`（广角）和 `/dev/video1`（TOF）访问摄像头。

---

## 第三层：延伸阅读

- [[drm-display-DRM显示驱动]] — 视频采集后用 DRM 显示
- [[char-device-字符设备驱动]] — V4L2 设备也是字符设备