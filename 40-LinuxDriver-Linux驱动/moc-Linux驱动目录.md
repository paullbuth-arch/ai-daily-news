---
type: moc
tags: [moc, linux, driver, platform, alsa, v4l2, i2c, spi, dma]
---

# 40-LinuxDriver：Linux 驱动开发

> Linux 驱动的核心：把硬件操作封装成标准接口（open/read/write/ioctl），应用层通过设备文件操作硬件，驱动层把这些调用翻译成寄存器读写。

## 学习路线

驱动模型（platform driver）→ 字符设备 → I2C/SPI/GPIO 子系统 → ALSA 音频 → V4L2 摄像头 → DMA/中断/电源管理

## 已有文档

| 文件 | 核心内容 |
|------|---------|
| [[platform-driver-外设驱动框架]] | Platform Driver 模型、probe/remove、设备树 compatible 匹配 |
| [[char-device-字符设备驱动]] | cdev、file_operations、ioctl、udev |
| [[i2c-spi-gpio-subsys-I2C-SPI-GPIO子系统]] | I2C/SPI/GPIO 子系统的 Linux 驱动模型 |
| [[alsa-asoc-ALSA音频驱动]] | ALSA ASoC：Codec/Platform/Machine 三层模型 |
| [[v4l2-camera-V4L2摄像头驱动]] | V4L2 框架、video_device、MIPI CSI |
| [[drm-display-DRM显示驱动]] | DRM 框架、MIPI DSI 显示驱动 |
| [[dma-interrupt-pm-DMA中断与电源管理]] | DMA 映射、request_irq、runtime_pm |
| [[wifi-ble-network-WiFi与BLE网络驱动]] | WiFi/BLE 驱动架构、网络设备模型 |

## 核心问题

- `platform_driver` 的 probe 函数什么时候被调用？设备树中有 matching compatible 的设备时。
- ALSA ASoC 中 Codec、Platform、Machine 各负责什么？Codec=编解码芯片驱动，Platform=SoC 音频接口 DMA，Machine=板级连接（即 reGlasses 的 soundcard）。