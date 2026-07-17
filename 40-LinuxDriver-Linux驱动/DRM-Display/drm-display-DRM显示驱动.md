# DRM 显示驱动

**一句话结论（20% 核心）**：DRM（Direct Rendering Manager）是 Linux 现代显示框架，替代了旧的 fbdev。它管理显示输出（CRTC/Encoder/Connector）和渲染表面（Plane/Framebuffer/GEM）。图形栈从应用层到硬件：OpenGL → Mesa → DRM → 硬件。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：电影放映系统

- **Framebuffer（GEM）** = 胶片：存着一帧画面的像素数据
- **Plane** = 投影仪：把胶片投射出去（支持多层叠加，如视频层+UI 层）
- **CRTC** = 放映控制台：控制分辨率、刷新率、时序
- **Encoder** = 信号转换器：把数字信号转成 HDMI/MIPI 格式
- **Connector** = 接口：HDMI 口、MIPI DSI 口、eDP 口

### 1.2 DRM 架构

```
用户空间:  Wayland / X11 / Android SurfaceFlinger
             │
内核空间:   DRM Core
             ├── GEM (内存管理：分配 framebuffer)
             ├── KMS (显示控制：CRTC/Encoder/Connector/Plane)
             └── 硬件驱动 (sunxi-drm, vc4, i915, ...)
```

### 1.3 如果只记得一件事

> DRM = Linux 现代显示框架。GEM 管显存分配，KMS 管显示控制（CRTC/Encoder/Connector/Plane）。替代旧的 fbdev，支持多层合成和 GPU 加速。

---

## 第二层：实战理解

### 2.1 查看 DRM 设备状态

```bash
# 查看 DRM 设备
ls /sys/class/drm/
# card0, card0-HDMI-A-1, card0-eDP-1, ...

# 查看当前显示模式
cat /sys/class/drm/card0-HDMI-A-1/modes
# 1920x1080
# 1280x720

# modetest 查看 DRM 状态
modetest -M sunxi
```

### 2.2 在 reGlasses 项目中怎么用

V881 的微型 OLED 显示屏通过 MIPI DSI 接口连接，使用 DRM 框架驱动。WQ7036AX 没有显示屏，不涉及 DRM。

---

## 第三层：延伸阅读

- [[v4l2-camera-V4L2摄像头驱动]] — 视频采集后通过 DRM 显示
- [[devicetree-DeviceTree设备树]] — 显示设备在设备树中的定义