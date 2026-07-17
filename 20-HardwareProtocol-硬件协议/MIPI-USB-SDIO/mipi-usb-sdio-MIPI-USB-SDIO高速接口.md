---
type: concept
created: 2026-07-17
tags: [protocol, mipi, usb, sdio, 高速接口, 差分信号]
aliases: [MIPI, USB, SDIO, 高速串行接口]
---

# MIPI / USB / SDIO 高速接口：从差分信号到协议栈

> **一句话结论**：MIPI、USB、SDIO 是嵌入式三大高速接口——MIPI DSI/CSI 用差分对+多 lane 传输视频（Gbps 级），USB 用差分信号传输通用数据+供电（480M-5G），SDIO 用 4-bit 并行总线连接 WiFi 和 SD 卡（25-200M）。它们的共同技术基础是差分信号（抗共模干扰）、多 lane/channel 并行（提高带宽）和分层协议栈（物理层→链路层→传输层）。WQ7036AX 不涉及高速接口——全部在 V861 侧。

本篇的代码锚点：

- **V861/reGlasses**：`/home/ys/aiglass/reglasses/device/configs/reglasses/linux-6.6-xuantie/board.dts` 中无 MIPI/USB/SDIO 设备树节点（当前可编辑 BSP 中未配置）。厂商 SDK `tina-v861/` 中包含完整驱动，但该目录只读参考。
- **WQ7036AX**：不涉及高速接口。WQ 的外设接口全部是低速的（UART/I2C/SPI/I2S/PDM）。

**重要声明**：当前两套可编辑 SDK（`wq7036a` 和 `aiglass/reglasses`）中，高速接口的证据缺口较大。MIPI DSI/CSI 驱动在 `tina-v861/` 只读 SDK 中，USB 驱动同理。本篇以通用原理为主，项目事实标注为"待确认"。

## 30 秒先看懂

传一张 1080p 图片（1920×1080×24 bit ≈ 50 Mbit），UART 115200 需要 7 分钟，SPI 10 MHz 需要 5 秒，MIPI DSI 1 Gbps 需要 0.05 秒。当数据量超过几十 Mbps 时，低速接口（UART/I2C/SPI）就"搬不动"了——需要高速接口。

高速接口的共同策略是：**差分信号**代替单端信号（两根线传相反信号，差值抗干扰）、**多 lane**并行（像多车道高速公路）、**分层协议栈**（物理层连接→链路层训练→传输层打包）。

## 学完以后应该能做什么

**第一遍**：能解释差分信号为什么抗干扰，说出 MIPI/USB/SDIO 各自的典型用途和速度级别。

**进阶后**：能理解 MIPI DSI 的 Video Mode vs Command Mode、USB 的 Host vs Gadget 角色、SDIO 的 4-bit 并行命令/数据分离。

## 前置知识

- 理解 SPI 的四线全双工和推挽输出；可先看 [[spi-basics-SPI基础]]。
- 知道设备树的基本概念；可先看 [[devicetree-DeviceTree设备树]]。

## 术语先讲清楚

| 术语 | 英文 | 具体含义 |
|---|---|---|
| 差分信号 | differential signaling | 用两根线（D+和 D-）传输互为反相的信号。接收端取差值（D+ - D-），共模干扰在相减时被消除。这是所有高速接口的物理基础 |
| lane | data lane | 一组差分对（两根线）。MIPI DSI 支持 1-4 lane，4 lane × 1 Gbps = 4 Gbps 总带宽 |
| MIPI DSI | Display Serial Interface | MIPI 联盟的显示接口标准，连接 SoC 到显示屏。V861 通过 DSI 连接微型 OLED |
| MIPI CSI | Camera Serial Interface | MIPI 联盟的摄像头接口标准，连接摄像头 sensor 到 SoC。V861 通过 CSI 接收摄像头数据 |
| OTG | USB On-The-Go | USB 补充标准，允许设备在 Host 和 Device 角色之间切换。V861 USB-C 支持 OTG |
| SDIO | Secure Digital I/O | SD 协会的扩展标准，在 SD 物理接口上支持 I/O 设备（WiFi、GPS、蓝牙）。4-bit 并行数据总线 |
| 链路训练 | link training | 高速接口在建立连接时，双方协商 lane 数、速率和时序的过程。如果训练失败，链路无法建立 |

## 第一层：费曼式心智模型

### 1.1 差分信号：在嘈杂房间里清晰对话

把差分信号想成两个人在嘈杂房间里传递消息：

- 单端信号（UART TX）：一个人喊话，噪音大了听不清
- 差分信号（MIPI/USB）：两个人同时喊互为反相的"暗号"，接收方不听每个人喊什么，而是听"两个人的差别"——噪音对两个人的影响一样，差别不变

这就是"共模抑制"：干扰同时影响 D+ 和 D-，但差值（D+ - D-）保持不变。差分信号还可以用更小的电压摆幅（如 200 mV vs 3.3V），切换更快，功耗更低。

### 1.2 完整场景：MIPI DSI 显示一帧画面

```text
第一步：SoC 准备一帧图像数据（1920×1080×24 bit = 49.8 Mbit）。
第二步：DSI 控制器将数据分包，分配到 4 个 lane 上。
第三步：每个 lane 以 1 Gbps 速度串行发送差分信号。
第四步：显示屏接收端从 4 个 lane 恢复数据，拼成完整帧。
第五步：显示屏驱动 IC 将像素数据写入面板，显示画面。

4 lane × 1 Gbps = 4 Gbps 总带宽。
49.8 Mbit / 4 Gbps ≈ 12.5 ms 传输一帧（理论值）。
加上消隐区（blanking）和协议开销，实际约 16.7 ms（60 fps）。
```

## 第二层：三大接口对比

| | MIPI DSI/CSI | USB 2.0/3.0 | SDIO 3.0 |
|---|---|---|---|
| 用途 | 显示屏(DSI)/摄像头(CSI) | 通用数据+充电 | WiFi/SD 卡 |
| 物理层 | 差分对，1-4 lane | 差分对（2.0=1对，3.0=2对） | 单端 4-bit 并行 |
| 速度 | 1-6 Gbps/lane | 480M(2.0)-5G(3.0) bps | 25-200 Mbps |
| 线数 | 3-9 线 | 4-9 线 | 6 线（CLK+CMD+DATA0-3） |
| 拓扑 | 点对点 | 树形（Host→Hub→Device） | 点对点/可多设备 |
| reGlasses | V861→OLED(DSI), Sensor→V861(CSI) | V861 USB-C | 未使用 |

## 第三层：真实 SDK 现状

**当前两套可编辑 SDK 中高速接口的证据缺口**：

- MIPI DSI/CSI 驱动：位于 `tina-v861/` 只读 SDK 的 `kernel/linux/drivers/gpu/drm/sunxi/` 和 `drivers/media/platform/sunxi/`。当前 `reglasses/` 的 `board.dts` 中无 DSI/CSI 设备树配置。
- USB 驱动：位于 `tina-v861/` 只读 SDK 的 `kernel/linux/drivers/usb/`。`reglasses/board.dts` 中有 `usb_id_gpio` 配置。
- SDIO：reGlasses 未使用 SDIO 接口（WiFi 走其他接口）。

**验证入口**：如需确认 DSI 配置，查看 `tina-v861/kernel/linux/arch/riscv/boot/dts/` 下的 SoC 级 dtsi 文件（只读参考）。

## 第四层：调试方法

| 现象 | 假设 | 证据 | 修复 |
|---|---|---|---|
| MIPI 花屏/黑屏 | lane 数或时序不匹配 | 示波器看 lane 上是否有数据 | 检查 dsi-lanes 和 display-timings |
| USB 枚举失败 | D+/D- 接反或上拉电阻不对 | 示波器看 D+/D- 电平 | 检查 GPIO 和电路 |
| SDIO 时钟太高导致不稳定 | 超过设备 SDIO 时钟上限 | 降低时钟频率测试 | 调整 max-frequency 属性 |

## 第五层：实战练习

1. **计算带宽需求**：2560×1440 分辨率、24-bit 色彩、90 Hz 刷新率，需要多少 Gbps？（不包含消隐区）
2. **差分信号验证**：用示波器同时测量 D+ 和 D-，解释为什么只看 D+ 或只看 D- 无法判断信号质量。
3. **设备树追踪**：在 `tina-v861/` 中搜索 `dsi` 关键字，找到 DSI 控制器的 dtsi 节点，记录 compatible 字符串和基础频率。

## 自测题

1. **差分信号比单端信号抗干扰的原因是什么？** 干扰同时影响 D+ 和 D-，接收端取差值（D+ - D-），共模干扰被抵消。
2. **MIPI DSI 的 lane 是什么？** 一组差分对（两根线）。多个 lane 并行传输，总带宽 = lane 数 × 单 lane 速率。
3. **USB Host 和 Device 的区别？** Host 提供电源和控制总线，Device 被 Host 枚举和管理。OTG 允许设备在两种角色间切换。
4. **SDIO 和 SPI 模式的区别？** SDIO 4-bit 并行，速度快（25-200M）；SPI 模式 1-bit 串行，兼容性好但慢。SD 卡同时支持两种模式。
5. **WQ7036AX 涉及高速接口吗？** 不涉及。WQ 的外设全部是低速接口（UART/I2C/SPI/I2S/PDM）。高速接口在 V861 侧。

## 参考资料

- [[spi-basics-SPI基础]] — 对比：低速同步总线
- [[devicetree-DeviceTree设备树]] — MIPI/USB 在设备树中的配置
- [[drm-display-DRM显示驱动]] — MIPI DSI 显示驱动属于 DRM 框架
- [[v4l2-camera-V4L2摄像头驱动]] — MIPI CSI 摄像头驱动属于 V4L2 框架

#flashcard

问：差分信号为什么抗干扰？
答：干扰同时影响 D+ 和 D-，接收端取差值（D+ - D-）时共模干扰被抵消，差值不变。

问：MIPI DSI 4 lane 的总带宽怎么算？
答：总带宽 = lane 数 × 单 lane 速率。4 lane × 1 Gbps/lane = 4 Gbps。

问：WQ7036AX 有高速接口吗？
答：没有。WQ 的外设接口全部是低速的（UART/I2C/SPI/I2S/PDM）。高速接口（MIPI/USB/SDIO）在 V861 侧。