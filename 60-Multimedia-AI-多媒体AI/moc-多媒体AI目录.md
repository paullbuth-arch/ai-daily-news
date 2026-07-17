---
type: moc
tags: [moc, multimedia, audio, video, gstreamer, ai]
---

# 60-Multimedia-AI：多媒体与 AI

> 音频处理（采样→降噪→编码→传输）和视频处理（采集→编码→推流）是 reGlasses 的核心功能。这部分内容直接对应 WQ7036AX 的 DCORE 和 V881 的媒体处理。

## 已有文档

| 文件 | 核心内容 |
|------|---------|
| [[audio-system-音频系统基础]] | 采样率/位深/PCM/编码/降噪——音频处理的完整链条 |
| [[opus-codec-Opus编码]] | 压缩比 8-16 倍，BLE 传音频的关键 |
| [[gstreamer-pipeline-GStreamer管道]] | GStreamer 多媒体管道框架 |
| [[video-h264-isp-视频编码与ISP]] | H.264/H.265 编码、ISP 图像处理 |
| [[ai-inference-AI推理部署]] | AI 推理部署：NPU、模型量化、推理框架 |

## 核心问题

- 采样率和位深对音频质量的影响？更高的采样率 = 更高的频率响应，更高的位深 = 更大的动态范围。
- Opus 和 AAC 的区别？Opus 延迟低（适合实时通信），AAC 兼容性好（适合音乐存储）。BLE 选 Opus 是因为在 16-32 kbps 的低码率下质量最优。
- GStreamer 的 element 和 pad 是什么？element 是处理单元，pad 是 element 的输入/输出接口。