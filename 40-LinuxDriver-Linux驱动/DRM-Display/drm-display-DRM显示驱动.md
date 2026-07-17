# DRM 显示驱动

**一句话结论（20% 核心）**：DRM（Direct Rendering Manager）是 Linux 现代显示框架，替代了旧的 fbdev。它把显示系统抽象成四个核心对象：Framebuffer（存像素）、Plane（图层）、CRTC（显示时序）、Encoder/Connector（输出接口）。理解这四个对象的关系，就理解了 DRM 的核心。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：电影放映系统

- **Framebuffer（GEM 缓冲）** = 胶片：存着一帧画面的像素数据，通常是 1920×1080×4 = 8MB
- **Plane** = 投影仪：把胶片投射出去。可以有多个 Plane（Primary 显示桌面、Overlay 显示视频、Cursor 显示鼠标）
- **CRTC** = 放映控制台：控制分辨率、刷新率、时序（HSYNC/VSYNC）
- **Encoder** = 信号转换器：把数字像素转成 HDMI/MIPI/DP 格式的电信号
- **Connector** = 物理接口：HDMI 口、MIPI DSI 口、eDP 口

**数据流**：Framebuffer → Plane（叠加/混合）→ CRTC（时序控制）→ Encoder（信号转换）→ Connector（物理输出）

### 1.2 DRM 的两个子系统：KMS + GEM

```
         DRM Framework
        ┌──────┴──────┐
        │             │
      KMS           GEM
 (显示控制)     (内存管理)
        │             │
   CRTC/Encoder/   Framebuffer
   Connector/      分配/共享/
   Plane           同步
```

- **KMS（Kernel Mode Setting）**：管理显示模式设置（分辨率、刷新率），替代了旧的 fbdev
- **GEM（Graphics Execution Manager）**：管理显存分配，多个进程可以共享 framebuffer
- **原子提交（Atomic Commit）**：DRM 最强大的特性——多个显示参数的修改可以打包成一个原子操作，要么全部生效，要么全部不生效。避免画面撕裂。

### 1.3 DRM 对象的关系

```
Connector (HDMI-A-1)       Connector (eDP-1)
    │                           │
  Encoder (HDMI)             Encoder (eDP)
    │                           │
    └──────┬────────────────────┘
         CRTC (CRTC-0)
           │
    ┌──────┴──────┐
  Plane (Primary)   Plane (Overlay)   Plane (Cursor)
    │                │                  │
  FB #1            FB #2              FB #3
```

### 1.4 如果只记得一件事

> DRM = KMS（显示控制）+ GEM（显存管理）。四个核心对象：Framebuffer（存像素）、Plane（图层叠加）、CRTC（时序控制）、Encoder/Connector（输出）。原子提交是 DRM 的核心优势——保证显示参数修改不会导致画面撕裂。

---

## 第二层：实战理解

### 2.1 查看和调试 DRM 状态

```bash
# 查看 DRM 设备
ls /sys/class/drm/
# card0, card0-HDMI-A-1, card0-eDP-1, renderD128

# 查看支持的显示模式
cat /sys/class/drm/card0-HDMI-A-1/modes
# 1920x1080
# 1280x720
# 1024x768

# 查看当前使用的模式
cat /sys/class/drm/card0-HDMI-A-1/mode

# 查看 EDID（显示器上报的块信息，包含支持的分辨率/色深/厂商）
cat /sys/class/drm/card0-HDMI-A-1/edid | hexdump -C

# 用 modetest 查看完整 DRM 状态（包括所有 Plane/CRTC/Encoder）
modetest -M sunxi
```

### 2.2 原子提交：DRM 的核心优势

```c
// 传统方式（非原子）：先改分辨率，再改 Plane 位置，中间可能撕裂
// 原子方式：所有修改打包，一次提交，硬件在 VBLANK 期间切换

struct drm_mode_atomic_req *req = drmModeAtomicAlloc();

// 添加多个修改到同一个请求
drmModeAtomicAddProperty(req, crtc_id, mode_id, 1);       // 改分辨率
drmModeAtomicAddProperty(req, plane_id, fb_id, new_fb);   // 切换 framebuffer
drmModeAtomicAddProperty(req, plane_id, zpos, 1);         // 改图层顺序

// 一次性提交，非阻塞
drmModeAtomicCommit(fd, req, DRM_MODE_ATOMIC_NONBLOCK, NULL);
drmModeAtomicFree(req);
```

### 2.3 Page Flip：无撕裂的画面切换

```
双缓冲 + Page Flip:

前缓冲 (Front Buffer)  ← 当前显示的画面
后缓冲 (Back Buffer)   ← GPU 正在渲染的下一帧

渲染完成 → Page Flip → 前后交换（在 VBLANK 期间，无撕裂）
          → 前缓冲变成后缓冲，后缓冲变成前缓冲
```

**没有 Page Flip 的后果**：GPU 正在写 framebuffer 的时候，显示控制器同时也在读 framebuffer 输出到屏幕 → 画面撕裂（上半帧是新画面，下半帧是旧画面）。

### 2.4 常见坑

| 问题 | 现象 | 排查方法 | 根因 |
|------|------|---------|------|
| 画面撕裂 | 画面中有一条水平线，上下不同步 | 检查是否用了 Page Flip | 未使用双缓冲或 Page Flip |
| 显示黑屏 | 屏幕背光亮但无内容 | `modetest -M sunxi` 看 CRTC 是否激活 | CRTC 未启动或 Encoder 未连接 |
| 分辨率不对 | 显示内容被拉伸或太小 | `cat /sys/class/drm/*/modes` | EDID 解析失败或手动设置了错误模式 |
| 多个 Plane 叠加错乱 | 视频窗口和 UI 层叠顺序不对 | 检查 zpos 属性 | Plane 的 zpos（Z 轴位置）配置错误 |

### 2.5 在 reGlasses 项目中怎么用

V881 的微型 OLED 显示屏通过 MIPI DSI 接口连接，使用 DRM/sunxi-drm 驱动。WQ7036AX 没有显示屏，不涉及 DRM。V881 侧的 DRM 驱动在 `~/aiglass/tina-v861/kernel/linux/drivers/gpu/drm/sunxi/`。

---

## 第三层：深入扩展

### 3.1 DRM vs fbdev

| | fbdev | DRM |
|---|---|---|
| 显示模式设置 | ioctl（可能在渲染中切换，撕裂） | 原子提交（VBLANK 期间切换，无撕裂） |
| 多层合成 | 不支持 | 多个 Plane 硬件叠加 |
| GPU 加速 | 无标准接口 | 通过 GEM + DMA-BUF 共享 buffer |
| 多进程 | 独占 | 可多个进程共享 framebuffer |
| 当前状态 | **已废弃** | **现代标准** |

### 3.2 常见问题

- **DRM 和 Wayland/X11 的关系？** Wayland 和 X11 是显示服务器，它们使用 DRM 作为底层显示驱动。Wayland 直接使用 DRM 原子 API，X11 通过 DDX 驱动使用 DRM。
- **GEM 和 DMA-BUF 的区别？** GEM 是 DRM 内部的显存管理器，DMA-BUF 是跨设备的 buffer 共享机制（摄像头→GPU→显示 的零拷贝 pipeline）。
- **为什么需要 Render Node（/dev/dri/renderD128）？** 分离渲染和显示权限。Render Node 只允许 GPU 渲染（不能操作显示），给没有显示权限的应用使用。

### 3.3 延伸阅读

- [[v4l2-camera-V4L2摄像头驱动]] — 摄像头采集 → DRM 显示的零拷贝 pipeline
- [[mipi-usb-sdio-MIPI-USB-SDIO高速接口]] — MIPI DSI 物理层详解
- [[devicetree-DeviceTree设备树]] — 显示设备在设备树中的定义