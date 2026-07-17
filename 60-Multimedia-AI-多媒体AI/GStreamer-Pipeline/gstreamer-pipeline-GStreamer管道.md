# GStreamer 管道

**一句话结论（20% 核心）**：GStreamer 是 Linux 多媒体处理框架——用"管道"（pipeline）把多个处理模块（element）串起来，数据从源头（source）经过处理（filter/encoder）到达目的地（sink）。非常适合快速搭建音视频处理链。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：工厂流水线

GStreamer pipeline = 工厂流水线：
- **Source** = 原料入口（摄像头、文件、网络流）
- **Filter/Encoder** = 加工站（缩放、转码、滤镜）
- **Sink** = 成品出口（显示屏、文件、网络推流）

每个环节是一个 element，element 之间通过 pad（接头）连接。

### 1.2 一个经典 pipeline

```bash
# 摄像头 → H.264 编码 → RTSP 推流
gst-launch-1.0 \
  v4l2src device=/dev/video0 ! \
  video/x-raw,width=1920,height=1080,framerate=30/1 ! \
  x264enc bitrate=5000 ! \
  rtph264pay ! \
  udpsink host=192.168.1.100 port=5000
```

### 1.3 核心概念

| 概念 | 含义 | 例子 |
|------|------|------|
| **Element** | 处理模块 | v4l2src（摄像头源）, x264enc（H.264 编码器） |
| **Pad** | element 的连接点 | src pad（输出口）, sink pad（输入口） |
| **Pipeline** | 完整的处理链 | source → encoder → sink |
| **Bin** | 子管道 | 把多个 element 封装成一个可复用的组件 |
| **Caps** | 能力协商 | 分辨率、帧率、格式 |

### 1.4 如果只记得一件事

> GStreamer = 音视频管道框架。用 `!` 连接 element，source 进 → filter/encoder 处理 → sink 出。一行命令就能搭建摄像头推流管道。

---

## 第二层：实战理解

### 2.1 C 代码构造 pipeline

```c
#include <gst/gst.h>

// 创建 element
GstElement *src   = gst_element_factory_make("v4l2src", "src");
GstElement *enc   = gst_element_factory_make("x264enc", "enc");
GstElement *sink  = gst_element_factory_make("udpsink", "sink");

// 创建 pipeline
GstElement *pipeline = gst_pipeline_new("my-pipeline");
gst_bin_add_many(GST_BIN(pipeline), src, enc, sink, NULL);

// 连接 element
gst_element_link_many(src, enc, sink, NULL);

// 启动
gst_element_set_state(pipeline, GST_STATE_PLAYING);
```

### 2.2 常见坑

| 问题 | 现象 | 根因 |
|------|------|------|
| Caps 协商失败 | pipeline 无法启动 | source 和 encoder 之间格式不兼容 |
| element 找不到 | 创建失败 | 对应的 GStreamer 插件没安装 |
| 内存泄漏 | 长时间运行内存增长 | 忘了 unref 创建的 element |

### 2.3 在 reGlasses 项目中怎么用

V881 上可能用 GStreamer 搭建视频推流管道。WQ7036AX 不涉及 GStreamer。

---

## 第三层：延伸阅读

- [[video-h264-isp-视频编码与ISP]] — 视频编码的基础知识
- [[v4l2-camera-V4L2摄像头驱动]] — V4L2 摄像头驱动