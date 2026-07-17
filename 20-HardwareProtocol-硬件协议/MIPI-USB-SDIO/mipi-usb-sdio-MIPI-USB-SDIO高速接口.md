# MIPI / USB / SDIO 高速接口

**一句话结论（20% 核心）**：MIPI、USB、SDIO 是嵌入式三大高速接口——MIPI 传视频（摄像头和显示屏），USB 传数据和充电，SDIO 连接 WiFi 和存储卡。它们都比 UART/I2C/SPI 快几个数量级，也复杂得多。

---

## 第一层：核心认知（必须先看懂）

### 1.1 三大高速接口对比

| | MIPI DSI/CSI | USB 2.0/3.0 | SDIO |
|---|---|---|---|
| 用途 | 显示屏(DSI) / 摄像头(CSI) | 通用数据+充电 | WiFi 模块 / SD 卡 |
| 速度 | 1-6 Gbps/lane（多 lane） | 480M(2.0)-5G(3.0) bps | 25-200 Mbps |
| 线数 | 3-9 根（差分对） | 4 根（2.0） | 6 根 |
| 驱动复杂度 | 高 | 中 | 中 |
| reGlasses 用途 | V881→OLED 屏(DSI) | V881 USB-C | 未使用 |

### 1.2 为什么需要这些高速接口？

- **MIPI**：1080p@30fps 原始视频 = ~1 Gbps，UART/SPI 根本传不动。MIPI 用差分信号 + 多 lane 并行达到 Gbps 级别。
- **USB**：通用性最强，既传数据又充电，PC 和手机的标准接口。
- **SDIO**：SD 卡和 WiFi 模块的标准接口，比 SPI 快 10-50 倍。

### 1.3 如果只记得一件事

> MIPI 传视频（Gbps 级），USB 通用数据+充电（480M-5G），SDIO 连 WiFi 和 SD 卡（25-200M）。高速接口的核心：差分信号、多 lane 并行、复杂的协议栈。

---

## 第二层：实战理解

### 2.1 在 reGlasses 项目中怎么用

| 接口 | 哪颗芯片 | 连什么 |
|------|---------|--------|
| MIPI DSI | V881 | 微型 OLED 显示屏 |
| MIPI CSI | V881 | 摄像头 sensor |
| USB 2.0 | V881 | Type-C 接口（充电+数据） |
| SDIO | 未使用 | — |

WQ7036AX 不涉及这些高速接口，它的外设都是低速接口（UART/I2C/I2S/PDM/GPIO）。

### 2.2 驱动开发要点

- MIPI：通常芯片厂商已提供驱动，你只需要配置时序参数（分辨率、帧率、lane 数）
- USB：Linux 有完整的 USB 协议栈，设备驱动通常用 USB Gadget 或 Host 框架
- SDIO：走 Linux MMC 子系统，WiFi 驱动通过 SDIO 接口挂载

---

## 第三层：延伸阅读

- [[drm-display-DRM显示驱动]] — MIPI DSI 显示驱动属于 DRM 框架
- [[v4l2-camera-V4L2摄像头驱动]] — MIPI CSI 摄像头驱动属于 V4L2 框架