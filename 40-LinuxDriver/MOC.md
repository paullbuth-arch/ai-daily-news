---
type: moc
tags: [moc, linux, driver, platform, alsa, v4l2]
---

# 40-LinuxDriver: Linux 驱动开发

> Linux 驱动的核心：把硬件操作封装成标准接口（open/read/write/ioctl），应用层通过设备文件操作硬件，驱动层把这些调用翻译成寄存器读写。

---

## 已有笔记

| 文件 | 一句话 |
|------|--------|
| [[外设驱动通用框架]] | Platform Driver 模型、probe/remove、设备树 compatible 匹配 |

## 待创建（按需补充）

| 主题 | 一句话 |
|------|--------|
| 字符设备驱动 | cdev、file_operations、ioctl、udev |
| I2C 子系统 | i2c_driver、i2c_client、probe、设备树 |
| SPI 子系统 | spi_driver、spi_message、spi_transfer |
| GPIO 子系统 | gpiod API、设备树 gpios 属性 |
| ALSA ASoC 音频 | Codec/Platform/Machine 三层驱动模型、DMA |
| V4L2 摄像头 | video_device、vb2_queue、MIPI CSI |
| DMA/中断/PM | DMA 映射、request_irq、runtime_pm |

## 面试高频问题

- platform_driver 的 probe 函数什么时候被调用？设备树中有 matching compatible 的设备时。
- ALSA ASoC 中 Codec、Platform、Machine 各负责什么？Codec=编解码芯片驱动，Platform=SoC 音频接口，Machine=板级连接。
- DMA 映射的 dma_map_single 和 dma_map_sg 区别？前者单块连续内存，后者 scatter-gather 多块。