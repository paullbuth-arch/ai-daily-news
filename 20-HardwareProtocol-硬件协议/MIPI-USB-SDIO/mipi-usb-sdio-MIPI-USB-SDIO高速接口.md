# MIPI / USB / SDIO 高速接口

**一句话结论（20% 核心）**：MIPI、USB、SDIO 是嵌入式三大高速接口——MIPI 传视频（Gbps 级），USB 通用数据+充电（480M-5G），SDIO 连 WiFi 和 SD 卡（25-200M）。它们的核心共性：差分信号抗干扰、多 lane 并行提速度、复杂协议栈保证可靠性。比 UART/I2C/SPI 快 3-4 个数量级。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：为什么需要高速接口？

低速接口（UART/I2C/SPI）就像自行车道——够用，但传不了大货。高速接口是高速公路：
- **MIPI** = 专用的视频高速公路：1080p@30fps 原始视频 ≈ 1 Gbps，只有 MIPI 传得动
- **USB** = 城市主干道：什么都能运（数据+充电），通用性最强
- **SDIO** = 物流专线：专门给 SD 卡和 WiFi 模块用的

### 1.2 差分信号：高速接口的物理基础

所有高速接口都用差分信号，而不是单端信号（如 UART 的 TX）：

```
单端信号 (UART): 一根线 + GND
  干扰后: 1→0 可能误判

差分信号 (MIPI/USB): 两根线 (D+ 和 D-)，传相反的信号
  发送: D+ = 1, D- = 0
  接收: (D+ - D-) = 1 - 0 = 1
  干扰同时影响 D+ 和 D- → 差值不变 → 抗干扰！
```

**差分信号的好处**：抗共模干扰、可用更低电压摆幅（更快）、传更远距离。

### 1.3 三大高速接口深度对比

| | MIPI DSI/CSI | USB 2.0/3.0 | SDIO 3.0 |
|---|---|---|---|
| 用途 | 显示屏(DSI)/摄像头(CSI) | 通用数据+充电 | WiFi/SD 卡 |
| 物理层 | 差分对，1-4 lane | 差分对（2.0=1对，3.0=2对） | 单端 4-bit 并行 |
| 速度 | 1-6 Gbps/lane | 480M(2.0)-5G(3.0) bps | 25-200 Mbps |
| 线数 | clk± + data0±..data3± (3-9线) | D+/D-(2.0), +SSRX±/SSTX±(3.0) | CLK+CMD+DATA0-3 (6线) |
| 拓扑 | 点对点 | 主机↔设备(树形) | 主机↔设备(可多设备) |
| 协议栈 | DSI/CSI 协议层 | USB 协议栈(端点/管道) | SD 命令协议 |
| reGlasses | V881→OLED(DSI), Sensor→V881(CSI) | V881 USB-C | 未使用 |

### 1.4 速度计算实例

```
MIPI DSI 需要的带宽:
  1920×1080 × 24bit/pixel × 60fps = 2.99 Gbps
  → 4 lane × 1Gbps/lane = 4 Gbps (够用)

USB 3.0 传输 1GB 文件:
  1GB × 8 / 5Gbps = 1.6 秒 (理论值)
  实际 ~3 秒 (协议开销)

SDIO 传输 WiFi 数据:
  200Mbps / 8 = 25 MB/s (够 802.11ac 用)
```

### 1.5 如果只记得一件事

> MIPI 传视频（1-6 Gbps/lane，差分），USB 通用数据+充电（480M-5G），SDIO 连 WiFi/SD 卡（25-200M）。高速接口的核心：差分信号抗干扰 + 多 lane 并行 + 复杂协议栈。WQ7036AX 不涉及，全在 V881 侧。

---

## 第二层：实战理解

### 2.1 MIPI DSI 的 Lane 配置

```dts
// V881 设备树中配置 MIPI DSI（简化）
&dsi0 {
    status = "okay";
    compatible = "allwinner,sunxi-mipi-dsi";

    panel@0 {
        compatible = "visionox,oled-1080p";
        reg = <0>;
        dsi-lanes = <4>;              // 4 lane 模式
        dsi-format = <MIPI_DSI_FMT_RGB888>;
        dsi-mode = <MIPI_DSI_MODE_VIDEO_BURST>;

        display-timings {
            native-mode = <&timing0>;
            timing0: timing0 {
                clock-frequency = <148500000>;  // 148.5 MHz
                hactive = <1920>;
                vactive = <1080>;
                hfront-porch = <88>;
                hback-porch = <148>;
                hsync-len = <44>;
                vfront-porch = <4>;
                vback-porch = <36>;
                vsync-len = <5>;
            };
        };
    };
};
```

### 2.2 USB 的两种角色：Host vs Gadget

| 角色 | 谁供电 | 谁控制 | reGlasses 场景 |
|------|--------|--------|---------------|
| **Host** | 本端供电 | 本端控制设备 | V881 作为 Host 连接 U 盘 |
| **Gadget/Device** | 对端供电 | 对端控制 | V881 作为 Device 连接 PC（ADB/MTP） |
| **OTG** | 可切换 | 可切换 | V881 USB-C 支持 OTG |

### 2.3 常见坑

| 问题 | 现象 | 排查方法 | 根因 |
|------|------|---------|------|
| MIPI lane 数配错 | 显示花屏或黑屏 | 示波器看 lane 上有没有数据 | 配置的 lane 数和实际硬件连接不一致 |
| MIPI 时序不对 | 显示偏移、撕裂 | 调整 front/back porch 值 | 时序参数和屏幕 datasheet 不匹配 |
| USB 差分线不等长 | 高速传输不稳定 | 检查 PCB 走线 | D+/D- 长度差 > 5mm 会导致阻抗不匹配 |
| SDIO 时钟太高 | WiFi 偶尔断连 | 降低时钟频率 | 超过了 WiFi 模块的 SDIO 时钟上限 |

### 2.4 在 reGlasses 项目中怎么用

| 接口 | 芯片 | 连接 | 驱动位置 |
|------|------|------|---------|
| MIPI DSI | V881 | 微型 OLED | `~/aiglass/tina-v861/kernel/linux/drivers/gpu/drm/sunxi/` |
| MIPI CSI | V881 | 摄像头 sensor | `~/aiglass/tina-v861/kernel/linux/drivers/media/platform/sunxi/` |
| USB 2.0 | V881 | Type-C | `~/aiglass/tina-v861/kernel/linux/drivers/usb/` |

WQ7036AX 不涉及高速接口，它的外设全部是低速接口。

---

## 第三层：深入扩展

### 3.1 MIPI DSI 的两种传输模式

| 模式 | 特点 | 用途 |
|------|------|------|
| **Video Mode** | 持续传输像素数据，类似 HDMI | 普通显示屏，持续刷新 |
| **Command Mode** | 只传更新的像素，类似 SPI 显示屏 | 智能屏（自带 GRAM），省电 |

### 3.2 常见问题

- **MIPI 和 LVDS 的区别？** MIPI 是移动设备标准（手机、平板），LVDS 是工业/车载标准。MIPI 更省电，LVDS 传输距离更长。
- **USB 2.0 和 3.0 的物理区别？** 2.0 用 1 对差分线（D+/D-），3.0 额外增加 2 对差分线（SSRX±、SSTX±），实现全双工 5Gbps。
- **SDIO 和 SPI 模式的区别？** SD 卡同时支持 SDIO 和 SPI 模式。SDIO 模式 4-bit 并行，速度快；SPI 模式 1-bit 串行，兼容性好但慢。

### 3.3 延伸阅读

- [[drm-display-DRM显示驱动]] — MIPI DSI 显示驱动属于 DRM 框架
- [[v4l2-camera-V4L2摄像头驱动]] — MIPI CSI 摄像头驱动属于 V4L2 框架
- [[devicetree-DeviceTree设备树]] — 高速接口在设备树中的配置