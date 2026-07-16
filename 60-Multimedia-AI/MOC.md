---
type: moc
tags: [moc, multimedia, audio, video, gstreamer, ai]
---

# 60-Multimedia-AI: 多媒体与 AI

> 音频处理（采样→降噪→编码→传输）和视频处理（采集→编码→推流）是 reGlasses 的核心功能。这部分内容直接对应 WQ7036AX 的 DCORE 和 V881 的媒体处理。

---

## 已有笔记

| 文件 | 一句话 | 什么时候学 |
|------|--------|-----------|
| [[音频系统基础]] | 采样率/位深/PCM/编码/降噪——音频处理的完整链条 | 理解音频管道时必学 |
| [[Opus 编码]] | 压缩比 8-16 倍，BLE 传音频的关键 | 需要传音频时必学 |

## 待创建（按需补充）

| 主题 | 一句话 |
|------|--------|
| 视频系统 | H.264/H.265 编码、ISP 图像处理、V4L2 应用 |
| GStreamer pipeline | 音频/视频处理链的构建 |
| AI 推理 | TensorFlow Lite 部署、模型量化、NPU 加速 |

## 面试高频问题

- 采样率和位深对音频质量的影响？
- Opus 和 AAC 的区别？为什么 BLE 选 Opus？
- GStreamer 的 element 和 pad 是什么？