---
type: project
created: 2026-07-16
tags: [project, reglasses, architecture, topology, 架构, 拓扑]
aliases: [协议架构, 通信拓扑, 系统架构]
---

# reGlasses 协议架构

## 一句话理解

reGlasses 有三个"说话的人"：眼镜 (WQ7036AX) 通过**双模蓝牙**和手机通信——经典蓝牙 (HFP/A2DP) 管通话和音乐，BLE 管控制和遥测；通过 **UART ([[uart-basics-UART基础)** 和主控 (V881) 通信]]。手机和 V881 之间还能通过 **WiFi** 直接高速传视频。你要做的就是让 WQ7036AX 当好这个"翻译官"。

## 全局地图

```
                    ┌──────────────────────────────┐
                    │         手机 / PC APP          │
                    └──┬─────────┬─────────┬─────────┘
                       │经典蓝牙   │ BLE 5.4  │ WiFi 6
                       │HFP/A2DP  │ GATT    │ RTSP/UDP
                       │通话+音乐  │控制+遥测  │视频+点云
                    ┌──┴──────────┴──┐  ┌───┴──────────┐
                    │ WQ7036AX       │  │   V881 SoC    │
                    │ (双模蓝牙芯片)   │  │  (主控 Linux)  │
                    │ (你负责的)      │  │               │
                    └──────┬─────────┘  └───────────────┘
                           │ UART 命令协议 (app_uart_cmd)
                           │ (~1Mbps)
                    ┌──────┴──────────────────────┐
                    │       WQ7036AX 的外设们       │
                    │  [[elm2713-ELM2713光传感器 (I2C)    │]]
                    │  充电IC (I2C)                 │
                    │  [[max98357a-MAX98357A功放×2 (I2S)   │]]
                    │  [[sdm0103b-SDM0103B数字麦×4 (PDM)  │]]
                    │  按键×3 + LED (GPIO)          │
                    └─────────────────────────────┘
```

## 每条链路用什么协议

| 链路                 | 协议栈                              | 带宽            | 方向         |
| ------------------ | -------------------------------- | ------------- | ---------- |
| 手机 ↔ WQ (通话)    | **经典蓝牙 HFP + SCO/eSCO**        | 64-128 kbps   | 双向 (语音)   |
| 手机 ↔ WQ (音乐)    | **经典蓝牙 A2DP + AVRCP**          | 328-990 kbps  | WQ→手机 (音频)|
| 手机 ↔ WQ (控制)    | BLE GATT + [[wq-audio-protocol-WQ-Audio-Protocol]] | ~1 Mbps       | 双向         |
| WQ7036AX ↔ V881    | UART + [[uart-basics-UART基础             ]] | ~1 Mbps       | 双向         |
| 手机 ↔ V881          | WiFi (RTSP/UDP)                  | ~100 Mbps     | 双向         |
| WQ7036AX ↔ 麦       | [[pdm-mic-PDM麦克风                     ]] | 2.048 MHz CLK | 单向 (麦→芯片)  |
| WQ7036AX ↔ 功放      | [[i2s-protocol-I2S协议                      ]] | 512 kHz BCLK  | 单向 (芯片→功放) |
| WQ7036AX ↔ V881 音频 | [[i2s-protocol-I2S协议                      ]] | 512 kHz BCLK  | 双向         |
| WQ7036AX ↔ 传感器     | [[i2c-basics-I2C基础                      ]] | 400 kHz       | 双向         |

## WQ7036AX 的三种角色

### 1. 翻译官（指令转发）
```
手机 "开始录制" → BLE → WQ7036AX → UART 命令 → V881 → 启动摄像头
```
手机不懂 UART 命令协议，V881 不懂 BLE，WQ7036AX 在中间翻译。详见 [[reglasses-cross-chip-reGlasses跨芯片转发]]。

### 2. 音频管家（采集+处理+发送）
```
麦克风 → PDM → PCM → DSP → Opus → BLE → 手机
手机 → BLE → Opus 解码 → PCM → I2S → 功放 → 扬声器
```
详见 [[wq7036ax-audio-pipeline-WQ7036AX音频管道]]。

### 3. 外设保姆（传感器+按键+LED）
```
按键按下 → GPIO 中断 → 识别短按/长按 → 执行对应操作
ELM2713 中断 → I2C 读状态 → 上报佩戴检测
充电IC → I2C 读电量 → BLE 通知手机
```

## 你该从哪开始

按照 [[reglasses-study-plan-reGlasses学习计划]] 的阶段顺序：
1. **阶段 1**：看本页 + [[reglasses-bandwidth-reGlasses带宽约束]] + [[wq7036ax-chip-WQ7036AX芯片 → 建立全局地图]]
2. **阶段 2**：学 [[uart-basics-UART基础 → 理解 MCU↔V881 通信]]
3. **阶段 3**：学 [[i2s-protocol-I2S协议]] + [[pdm-mic-PDM麦克风 → 理解音频管道]]
4. **阶段 4**：学 [[ble-gap-BLE-GAP广播]] + [[ble-gatt-BLE-GATT → 理解蓝牙通信]]
5. **阶段 5**：学 [[wq-audio-protocol-WQ-Audio-Protocol]] + [[reglasses-ext-commands-reGlasses扩展命令集 → 能做新功能]]

## 关联概念

- [[reglasses-bandwidth-reGlasses带宽约束]] — 什么数据走什么链路
- [[wq7036ax-chip-WQ7036AX芯片]] — 硬件平台
- [[reglasses-cross-chip-reGlasses跨芯片转发]] — 指令路由规则
- [[reglasses-ext-commands-reGlasses扩展命令集]] — 新增命令定义
- [[dataflow-cmd-to-v881-手机指令到V881]] — 完整指令追踪
- [[dataflow-mic-to-phone-声音从麦到手机]] — 完整音频追踪
