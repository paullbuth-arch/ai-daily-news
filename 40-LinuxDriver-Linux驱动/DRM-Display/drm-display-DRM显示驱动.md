---
type: concept
tags: [linux, drm, display, kms, gem, framebuffer, aiglass]
aliases: [DRM显示驱动, Direct Rendering Manager, KMS, GEM]
---

# DRM 显示驱动

## 一句话结论

DRM（Direct Rendering Manager）是 Linux 现代显示框架，替代了旧的 fbdev。它把显示系统抽象成四个核心对象：Framebuffer（存像素）、Plane（图层）、CRTC（显示时序）、Encoder/Connector（输出接口）。理解这四个对象的关系，就理解了 DRM 的核心。

## 30秒先看懂

- DRM 由两个子系统组成：KMS（Kernel Mode Setting，管理显示模式，包括分辨率、刷新率、时序）和 GEM（Graphics Execution Manager，管理显存分配和共享）。四个核心对象的关系是：Framebuffer 存像素数据 → Plane 叠加图层 → CRTC 控制显示时序 → Encoder 转换信号格式 → Connector 物理输出。原子提交（Atomic Commit）是 DRM 最强大的特性——多个显示参数修改打包成一个原子操作，要么全部生效，要么全部不生效，避免画面撕裂。Page Flip 是双缓冲 + VBLANK 期间切换的机制，保证画面切换无撕裂。

## 学完以后应该能做什么

**第一遍看完后可以：**
- 理解 DRM 的四个核心对象及其关系
- 使用 `modetest` 查看 DRM 设备状态
- 理解原子提交和 Page Flip 的作用
- 知道 DRM 和 fbdev 的区别

**进阶后可以：**
- 编写 DRM 驱动（KMS + GEM）
- 使用 DMA-BUF 实现零拷贝跨设备共享 buffer
- 调试显示问题（黑屏、撕裂、分辨率不对）
- 在 reGlasses 项目中调试 V881 的 OLED 显示

## 前置知识

- Linux 设备驱动基础（字符设备、platform 驱动）
- 显示基本概念（分辨率、刷新率、VBLANK）
- 内存管理基础（DMA-BUF 概念）

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 直接渲染管理器 | DRM | Direct Rendering Manager，Linux 现代显示驱动框架 |
| 内核模式设置 | KMS | Kernel Mode Setting，管理显示分辨率和时序 |
| 图形执行管理器 | GEM | Graphics Execution Manager，管理显存分配 |
| 帧缓冲 | Framebuffer | 存储一帧像素数据的内存缓冲区 |
| 图层 | Plane | 叠加在显示画面上的图层，支持 Primary/Overlay/Cursor |
| 显示控制器 | CRTC | CRT Controller，控制显示时序和分辨率 |
| 编码器 | Encoder | 把数字像素信号转换成特定接口的电信号 |
| 连接器 | Connector | 物理显示接口（HDMI、MIPI DSI、eDP） |
| 原子提交 | Atomic Commit | 多个显示参数修改打包一次性提交 |
| 页面翻转 | Page Flip | 双缓冲切换，在 VBLANK 期间交换前后缓冲 |

## 第一层：费曼心智模型

### 类比：电影放映系统

- **Framebuffer（GEM 缓冲）** = 胶片：存着一帧画面的像素数据，通常是 1920x1080x4 = 8MB
- **Plane** = 投影仪：把胶片投射出去。可以有多个 Plane（Primary 显示桌面、Overlay 显示视频、Cursor 显示鼠标）
- **CRTC** = 放映控制台：控制分辨率、刷新率、时序（HSYNC/VSYNC）
- **Encoder** = 信号转换器：把数字像素转成 HDMI/MIPI/DP 格式的电信号
- **Connector** = 物理接口：HDMI 口、MIPI DSI 口、eDP 口

**数据流**：Framebuffer → Plane（叠加/混合）→ CRTC（时序控制）→ Encoder（信号转换）→ Connector（物理输出）

**边界：**
- DRM 是内核框架，不是应用层 API——应用层通过 `drmModeAtomic*` 等 libdrm 接口使用
- DRM 不直接处理字体渲染、窗口管理——那是 Wayland/X11 的工作
- 不是所有硬件都支持多个 Plane——有些 MCU 只有单个显示层

### 场景演练：播放视频

1. 视频解码器输出一帧 YUV 数据到 GEM buffer
2. 通过 DMA-BUF 共享给 DRM 驱动
3. 原子提交：把新 buffer 的 FB ID 和 Plane 的 zpos 一起提交
4. DRM 驱动在下一个 VBLANK 期间完成 Page Flip
5. 前缓冲变为后缓冲，后缓冲变为前缓冲
6. 画面无缝切换，无撕裂

## 第二层：原理/时序/约束

### DRM 对象关系

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

### 原子提交 vs 传统方式

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

### Page Flip 时序

```
前缓冲 (Front Buffer)  ← 当前显示的画面
后缓冲 (Back Buffer)   ← GPU 正在渲染的下一帧

渲染完成 → Page Flip → 前后交换（在 VBLANK 期间，无撕裂）
          → 前缓冲变成后缓冲，后缓冲变成前缓冲
```

## 第三层：真实 SDK 代码

### reGlasses 的 DRM 驱动

V881 的 OLED 显示屏通过 MIPI DSI 连接，使用 sunxi-drm 驱动。驱动源码在 `/home/ys/aiglass/tina-v861/bsp/drivers/drm/` 下：

```c
// /home/ys/aiglass/tina-v861/bsp/drivers/drm/sunxi_drm_drv.c
// sunxi DRM 驱动入口

static struct platform_driver sunxi_drm_platform_driver = {
    .probe  = sunxi_drm_probe,
    .remove = sunxi_drm_remove,
    .driver = {
        .name = "sunxi-drm",
        .of_match_table = sunxi_drm_dt_ids,
    },
};

module_platform_driver(sunxi_drm_platform_driver);
```

### DRM 调试命令

```bash
# 查看 DRM 设备
ls /sys/class/drm/
# card0, card0-HDMI-A-1, card0-eDP-1, renderD128

# 查看支持的显示模式
cat /sys/class/drm/card0-HDMI-A-1/modes

# 查看 EDID（显示器信息）
cat /sys/class/drm/card0-HDMI-A-1/edid | hexdump -C

# 用 modetest 查看完整 DRM 状态
modetest -M sunxi
```

## 第四层：正常/异常路径

### 正常路径

DRM 初始化 → 检测 Connector → 读取 EDID → 设置显示模式 → 分配 FB → 开启 CRTC → 显示画面

### 异常路径

| 异常场景 | 现象 | 原因 | 处理方式 |
|---------|------|------|---------|
| 画面撕裂 | 画面中有一条水平线，上下不同步 | 未使用 Page Flip 或双缓冲 | 启用原子提交 + Page Flip |
| 显示黑屏 | 背光亮但无内容 | CRTC 未启动或 Encoder 未连接 | 检查 CRTC 和 Encoder 状态 |
| 分辨率不对 | 显示内容被拉伸或太小 | EDID 解析失败或手动设置错误模式 | 检查 `cat /sys/class/drm/*/modes` |
| Plane 叠加错乱 | 图层顺序不对 | zpos 配置错误 | 检查 Plane 的 zpos 属性 |
| 驱动 probe 失败 | 设备节点不存在 | 设备树配置错误或驱动未匹配 | 检查设备树和驱动匹配表 |

## 第五层：调试方法

```bash
# 查看 CRTC 是否激活
cat /sys/class/drm/card0-HDMI-A-1/status

# 查看当前使用的显示模式
cat /sys/class/drm/card0-HDMI-A-1/mode

# 查看内核日志
dmesg | grep drm

# 查看 DRM 内存使用
cat /sys/kernel/debug/dri/0/summary

# 测试显示输出
modetest -M sunxi -s 0:1920x1080-60  # 在 connector 0 上设置 1080p60
```

## 第六层：实战练习

### 练习 1：查看 DRM 状态（基础）

在 Linux 系统中查看 DRM 设备状态：
1. 列出 `/sys/class/drm/` 下的所有设备
2. 查看每个 Connector 的连接状态
3. 查看支持的显示模式列表
4. 查看当前使用的模式
5. 用 `modetest -M sunxi` 查看所有对象

### 练习 2：使用原子 API（进阶）

编写一个简单的 DRM 应用，实现：
1. 打开 DRM 设备
2. 获取 Connector 和 CRTC
3. 创建 Framebuffer
4. 用原子 API 提交显示配置
5. 实现 Page Flip 切换画面

### 练习 3：阅读 sunxi-drm 源码（深入）

阅读 `/home/ys/aiglass/tina-v861/bsp/drivers/drm/sunxi_drm_drv.c`，回答：
1. platform 驱动的 probe 函数做了什么？
2. 设备树匹配表 `sunxi_drm_dt_ids` 定义了哪些设备？
3. 驱动如何初始化 CRTC、Encoder 和 Connector？
4. DMA-BUF 是如何在驱动中实现的？

## 自测与验收

1. DRM 的四个核心对象是什么？它们之间的关系是怎样的？
2. 原子提交（Atomic Commit）解决了什么问题？
3. Page Flip 是什么？为什么需要它？
4. GEM 和 DMA-BUF 的区别是什么？
5. DRM 和 fbdev 相比有什么优势？
6. 画面撕裂是怎么产生的？如何避免？
7. 什么是 VBLANK？为什么显示切换要在 VBLANK 期间进行？

## 延伸阅读

- [[v4l2-camera-V4L2摄像头驱动]] — 摄像头采集 → DRM 显示的零拷贝 pipeline
- [[mipi-usb-sdio-MIPI-USB-SDIO高速接口]] — MIPI DSI 物理层详解
- [[devicetree-DeviceTree设备树]] — 显示设备在设备树中的定义

## #flashcard

**Q: DRM 的四个核心对象是什么？**
A: Framebuffer（存像素）、Plane（图层叠加）、CRTC（显示时序）、Encoder/Connector（输出接口）。

**Q: 原子提交解决了什么问题？**
A: 多个显示参数修改打包一次性提交，要么全部生效要么全部不生效，避免画面撕裂。

**Q: DRM 的两个子系统是什么？**
A: KMS（Kernel Mode Setting，显示控制）和 GEM（Graphics Execution Manager，显存管理）。

**Q: Page Flip 的作用？**
A: 双缓冲 + VBLANK 期间切换前后缓冲，保证画面切换无撕裂。

**Q: DRM 相比 fbdev 的主要优势？**
A: 原子提交无撕裂、多层 Plane 硬件叠加、GEM 显存共享、多进程支持。