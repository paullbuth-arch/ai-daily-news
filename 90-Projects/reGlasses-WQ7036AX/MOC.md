---
type: moc
tags: [moc, project, reglasses, wq7036ax]
---

# 90-Projects: reGlasses 智能眼镜 (WQ7036AX + V881)

> 当前项目。WQ7036AX 双模蓝牙音频 SoC + 全志 V881 主控 Linux SoC。这是你学习嵌入式开发的实战平台——所有基础概念最终都会在这个项目里落地。

---

## 项目总览：三个"说话的人"

```
手机 APP ──蓝牙──→ WQ7036AX ──UART──→ V881 ──WiFi──→ 云端
  │                   │
  │                   ├── 4 颗麦克风 (PDM)
  │                   ├── 2 个扬声器 (I2S)
  │                   ├── 光传感器 (I2C)
  │                   ├── 按键/LED (GPIO)
  │                   └── 充电 IC (I2C)
```

WQ7036AX 扮演三种角色：
- **翻译官**：手机不懂 UART，V881 不懂 BLE，WQ7036AX 在中间翻译
- **音频管家**：采集麦克风→DSP 处理→Opus 编码→BLE 发送
- **外设保姆**：管按键、LED、传感器、电源

---

## 学习路线（按这个顺序，不要跳）

### 第一步：建立全局地图

| 顺序 | 看什么 | 一句话 |
|---|---|---|
| 1.1 | [[WQ7036AX 芯片]] | 三核架构/引脚/电源域——认识你的芯片 |
| 1.2 | [[reGlasses 协议架构]] | 三方通信拓扑——谁和谁怎么说话 |
| 1.3 | [[reGlasses 带宽约束]] | 什么数据走什么链路、为什么 |

### 第二步：追数据流（理解系统怎么跑）

| 顺序 | 看什么 | 一句话 |
|---|---|---|
| 2.1 | [[数据流：声音从麦到手机]] | PDM→PCM→DSP→Opus→BLE 完整链路 |
| 2.2 | [[数据流：手机指令到 V881]] | BLE Write→WQ Protocol→UART CMD→V881 |

### 第三步：深入各子系统

| 看什么 | 一句话 |
|--------|--------|
| [[WQ7036AX 音频管道]] | 音频处理的完整链：AEC/降噪/AGC/VAD/Opus |
| [[reGlasses 跨芯片指令转发]] | 命令路由表——什么事自己做，什么事转发 V881 |
| [[reGlasses GATT Service 设计]] | BLE 7 个 Characteristic 的完整定义 |
| [[reGlasses 扩展命令集]] | WQ Protocol 新增的 4 类 Service |

### 第四步：硬件外设

| 看什么 | 一句话 |
|--------|--------|
| [[ELM2713 光传感器]] | I2C 光/近程传感器 (0x39) |
| [[MAX98357A 功放]] | I2S Class-D 功放 ×2 |
| [[SDM0103B 数字麦]] | PDM 数字麦克风 ×4 |
| [[Ext Trans 框架]] | SDK 可插拔 IO + Protocol 架构 |

---

## Protocol（协议细节）

| 文件 | 一句话 |
|------|--------|
| [[WQ Audio Protocol]] | 0x5751 帧协议——手机和 WQ7036AX 之间的语言 |
| [[WQ Protocol 帧结构]] | bit-level 详解 |
| [[WQ Protocol 服务类型]] | 已有 + 新增命令 ID |
| [[帧协议对比：UART 命令协议 vs WQ Protocol]] | 两种帧格式对比 |

## Snippets（代码片段）

| 文件 | 一句话 |
|------|--------|
| [[Snippet - BLE GATT Service 注册模板]] | GATT Service 注册的标准代码 |
| [[Snippet - I2C 读写寄存器]] | I2C 设备寄存器操作模板 |
| [[Snippet - WQ Protocol 帧打包解包]] | WQ Protocol pack/unpack 代码 |

## 归档（已弃用）

| 文件 | 说明 |
|------|------|
| _archive-STTP/ | STTP 协议已弃用，已被 UART 命令协议替代 |