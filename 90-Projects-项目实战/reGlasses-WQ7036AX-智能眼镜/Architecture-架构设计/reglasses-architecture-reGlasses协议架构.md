---
type: project
created: 2026-07-16
updated: 2026-07-17
tags: [project, reglasses, architecture, topology, 架构, 拓扑, 协议]
aliases: [协议架构, 通信拓扑, 系统架构, reGlasses系统架构]
---

# reGlasses 协议架构

**一句话结论**：reGlasses 系统由三台设备组成——眼镜（WQ7036AX）通过双模蓝牙（经典蓝牙 + BLE）与手机通信，通过 UART 与主控（V881）通信；手机和 V881 之间还能通过 WiFi 直接高速传视频。WQ7036AX 是承上启下的"翻译官"。

---

## 30 秒先看懂

- reGlasses 系统中有三个"说话的人"：手机、WQ7036AX（眼镜芯片）、V881（主控芯片）。
- 手机到 WQ7036AX 有两条链路：经典蓝牙（HFP/A2DP 通话和音乐）和 BLE（GATT 控制和遥测）。
- WQ7036AX 到 V881 通过 UART 通信，所有跨芯片指令和数据都走这条线，速率约 1Mbps。
- 手机到 V881 可以通过 WiFi 直接传视频和点云数据，速率约 100Mbps，不经 WQ7036AX 中转。
- WQ7036AX 承担三种角色：翻译官（指令转发）、音频管家（采集处理发送）、外设保姆（传感器按键 LED）。

---

## 学完以后应该能做什么

**第一遍学完**：
- 能画出手机、WQ7036AX、V881 三方的拓扑图及每条链路的协议
- 能说出 WQ7036AX 的三种角色及其对应的功能
- 能判断给定的功能需求应该由哪个设备实现

**进阶目标**：
- 能理解每种链路的带宽约束并据此设计数据流
- 能分析新增功能时应该新增哪种协议通信
- 能理解系统架构设计中的权衡（功耗、带宽、延迟）

---

## 前置知识

- [[uart-basics-UART基础]] — WQ7036AX 与 V881 通信的物理层
- [[ble-gap-BLE-GAP广播]] — BLE 广播和连接建立
- [[wq7036ax-chip-WQ7036AX芯片]] — 硬件平台的能力边界
- [[wq-audio-protocol-WQ-Audio-Protocol]] — 应用层协议封装

---

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 经典蓝牙 | Classic Bluetooth (BR/EDR) | 传统蓝牙模式，提供 HFP（通话）和 A2DP（音乐）服务 |
| 低功耗蓝牙 | BLE (Bluetooth Low Energy) | 低功耗蓝牙模式，提供 GATT 服务用于控制和遥测 |
| 通用属性协议 | GATT (Generic Attribute Profile) | BLE 上的数据交换协议，基于 Characteristic 读写 |
| 免提协议 | HFP (Hands-Free Profile) | 经典蓝牙协议，用于蓝牙通话音频传输 |
| 高级音频分发协议 | A2DP (Advanced Audio Distribution Profile) | 经典蓝牙协议，用于高质量音乐传输 |
| 实时流协议 | RTSP (Real Time Streaming Protocol) | 用于控制流媒体服务器的网络协议 |
| 应用层命令协议 | STTP (Smart Things Transfer Protocol) | 自定义的 UART 命令协议，用于 WQ7036AX 与 V881 通信 |

---

## 第一层：费曼心智模型

### 类比：三个人的办公室

reGlasses 就像一个办公室里的三个人：

| 设备 | 角色 | 类比 | 类比说明 |
|------|------|------|---------|
| **手机** | 用户交互终端 | 客户 | 发布指令、接收结果 |
| **WQ7036AX** | 翻译官 + 音频管家 + 外设保姆 | 行政助理 | 听客户指令、管办公设备、翻译给技术团队 |
| **V881** | 主控处理器 | 技术团队 | 干重活——摄像头、WiFi、视频处理 |

**WQ7036AX 的三种角色**：
1. **翻译官**（指令转发）：手机说 BLE 语言，V881 说 UART 语言，WQ7036AX 在中间翻译
2. **音频管家**（采集+处理+发送）：管麦克风采集、DSP 处理、编码、发送
3. **外设保姆**（传感器+按键+LED）：管光传感器、充电 IC、按键、LED

### 边界

- 手机和 V881 之间可以**直接通过 WiFi 通信**，不经 WQ7036AX 中转。这是为了高速传输视频和点云数据。
- 控制指令**必须经过 WQ7036AX 中转**，因为手机只通过 BLE 连接 WQ7036AX，不直接连 V881。
- 音频数据**走两条路**：通话走经典蓝牙 HFP，语音控制走 BLE + Opus 编码。

### 场景推演

**场景：用户想录制一段带音频的视频**

1. 手机 APP 通过 BLE 发送"开始录制"指令给 WQ7036AX
2. WQ7036AX 翻译成 UART 命令转发给 V881
3. V881 启动摄像头（视频由它处理）和 WiFi 流
4. 同时 WQ7036AX 启动麦克风采集音频
5. 音频数据通过 I2S 传给 V881 与视频合成
6. 或者音频通过 BLE 直接发送到手机，视频通过 WiFi 发送到手机
7. 手机将音视频合并保存

---

## 第二层：原理、时序与约束

### 全局拓扑

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
                    │  ELM2713 光传感器 (I2C)       │
                    │  充电IC (I2C)                 │
                    │  MAX98357A 功放 x2 (I2S)      │
                    │  SDM0103B 数字麦 x4 (PDM)     │
                    │  按键 x3 + LED (GPIO)         │
                    └─────────────────────────────┘
```

### 每条链路的协议栈

| 链路 | 协议栈 | 带宽 | 方向 |
|------|--------|------|------|
| 手机 ↔ WQ（通话） | 经典蓝牙 HFP + SCO/eSCO | 64-128 kbps | 双向（语音） |
| 手机 ↔ WQ（音乐） | 经典蓝牙 A2DP + AVRCP | 328-990 kbps | WQ→手机（音频） |
| 手机 ↔ WQ（控制） | BLE GATT + WQ Protocol | ~1 Mbps | 双向 |
| WQ7036AX ↔ V881 | UART + STTP 协议 | ~1 Mbps | 双向 |
| 手机 ↔ V881 | WiFi (RTSP/UDP) | ~100 Mbps | 双向 |
| WQ7036AX ↔ 麦 | PDM | 2.048 MHz CLK | 单向（麦→芯片） |
| WQ7036AX ↔ 功放 | I2S | 512 kHz BCLK | 单向（芯片→功放） |
| WQ7036AX ↔ V881 音频 | I2S | 512 kHz BCLK | 双向 |
| WQ7036AX ↔ 传感器 | I2C | 400 kHz | 双向 |

### 带宽约束

| 数据类型 | 走哪条链路 | 带宽需求 | 够用吗 |
|---------|-----------|---------|--------|
| 控制指令（几十字节） | BLE GATT | ~1 Mbps | 绰绰有余 |
| 音频（Opus 16-32kbps） | BLE GATT | ~32 kbps | 很宽裕 |
| 音频（PCM 256kbps） | 经典蓝牙 A2DP | ~990 kbps | 够用 |
| 视频（1080p 30fps） | WiFi | ~50 Mbps | 需要 WiFi |
| 点云数据 | WiFi | ~80 Mbps | 需要 WiFi |

---

## 第三层：真实 SDK 代码

### 指令转发流程

**文件路径**：`wq-adk/examples/glass/acore/app/app_customer_ext_trans/app_uart_cmd.c`

这是 WQ7036AX 上处理 UART 命令的主文件。它接收手机发来的 BLE 指令，解包后通过 UART 转发给 V881。

```c
// 以 write_callback 为例（在 ota_transport_ble.c 中）
static void write_callback(uint8_t index, const uint8_t *data, uint16_t len)
{
    // ① 解包 WQ Protocol 帧
    wq_proto_pkt_t pkt;
    wq_proto_pkt_unpack(&pkt, data, len);

    // ② 根据 service_type 路由
    switch (pkt.msg_header.service_type) {
    case SERVICE_TYPE_CONTROL:
        // 控制命令 → 转发给 V881
        forward_to_v881_via_sttp(&pkt);
        break;
    case SERVICE_TYPE_TRANS_UP:
        // 音频上行 → 本地处理
        handle_audio_up(&pkt);
        break;
    }
}
```

### 路由规则

| 命令 | 执行位置 | 原因 |
|------|----------|------|
| RECORD_START | V881 | 摄像头在 V881 上 |
| TAKE_PHOTO | V881 | 同上 |
| TOF_ON/OFF | V881 | TOF 在 V881 上 |
| VOICE_ON/OFF | WQ 本地 | 麦克风在 WQ7036AX 上 |
| STATUS_QUERY | WQ + V881 | 合并两端状态 |

### 应用层架构

**文件路径**：`wq-adk/components/apps/acore/`

应用层框架包含事件处理、BLE 服务、音频服务等模块，提供 `app_main.h`、`app_evt.h` 等入口。

---

## 第四层：正常与异常路径

### 正常路径

手机发 BLE 指令 → WQ7036AX 解包 → 判断路由 → 本地执行或转发 V881 → V881 处理 → 响应原路返回 → 手机收到结果

### 异常路径

| 问题 | 现象 | 根因 |
|------|------|------|
| UART 通信超时 | 指令发送后无响应 | V881 未开机或 UART 波特率不匹配 |
| BLE 断连 | 手机无法控制眼镜 | 超出蓝牙范围或 BLE 连接超时 |
| 指令路由错误 | 命令执行错位 | WQ7036AX 路由表配置错误 |
| 带宽不足 | 音频卡顿或视频模糊 | 链路带宽超限，需要降级处理 |
| 命令冲突 | 两条指令同时操作同一资源 | 缺少互斥锁或状态机处理不当 |

---

## 第五层：调试方法

### 1. 确认链路连通性

- **BLE 链路**：使用 nRF Connect 手机 APP 扫描，确认眼镜广播可见
- **UART 链路**：串口工具监听 WQ7036AX TX 引脚，确认有数据发送
- **WiFi 链路**：手机 ping V881 IP 地址，确认网络可达

### 2. 追踪指令流转

在 `app_uart_cmd.c` 和 `ota_transport_ble.c` 中添加日志打印，追踪指令从收到到转发的完整路径。

### 3. 带宽监控

- BLE 带宽：通过连接间隔和 MTU 计算理论带宽，对比实际数据量
- UART 带宽：计算波特率对应的理论吞吐量，确保不超限

### 4. 逻辑分析仪

抓取 UART TX/RX 引脚波形，验证帧格式和时序。

---

## 第六层：实战练习

### 练习 1：画拓扑图并标注协议

在不看笔记的情况下，画出手机、WQ7036AX、V881 三方的拓扑图，在每条线路上标注使用的协议名称和物理接口。

### 练习 2：判断新增功能的路由

假设产品经理要求新增一个"环境光强度上报"功能，WQ7036AX 收到手机查询后应该怎么做？请画出完整的数据流，标注每个阶段的协议和 API。

### 练习 3：阅读真实源代码

打开 `wq-adk/examples/glass/acore/app/app_customer_ext_trans/app_uart_cmd.c`，找到 UART 命令的接收处理函数，分析它如何解析帧头和 payload，画出其状态机。

### 练习 4：分析带宽约束

如果产品经理要求通过 BLE 同时传输 3 路 16kHz 16bit 的 PCM 音频（不经压缩），请计算所需的带宽，并判断 BLE 链路是否够用。如果不够，提出至少两种解决方案。

---

## 自测与验收

1. reGlasses 系统由哪三个设备组成？它们之间分别用什么物理接口连接？
2. WQ7036AX 承担哪三种角色？请各举一个例子。
3. 手机和 V881 之间可以直接通信吗？通过什么链路？
4. 控制指令（如"开始录制"）为什么必须经过 WQ7036AX 中转？
5. 音频数据有哪两条路径可以到达手机？
6. 视频数据走哪条链路？为什么不走 BLE？
7. 如果 WQ7036AX 和 V881 之间的 UART 通信中断，哪些功能会受影响？
8. 在 SDK 中，指令路由的代码在哪个文件中？
9. 经典蓝牙和 BLE 各自负责什么业务？
10. 新增一个功能时，如何判断它在哪个设备上实现？

---

## 延伸阅读

- [[reglasses-bandwidth-reGlasses带宽约束]] — 什么数据走什么链路
- [[wq7036ax-chip-WQ7036AX芯片]] — 硬件平台
- [[reglasses-cross-chip-reGlasses跨芯片转发]] — 指令路由规则
- [[reglasses-ext-commands-reGlasses扩展命令集]] — 新增命令定义
- [[dataflow-cmd-to-v881-手机指令到V881]] — 完整指令追踪
- [[dataflow-mic-to-phone-声音从麦到手机]] — 完整音频追踪
- [[wq7036ax-audio-pipeline-WQ7036AX音频管道]] — 音频处理链
- [[ext-trans-Ext-Trans框架]] — UART 通过 Ext Trans 框架集成

#flashcard
问：reGlasses 系统由哪三个设备组成？
答：手机（用户交互终端）、WQ7036AX（眼镜蓝牙芯片，你负责的）、V881（主控 Linux 芯片）。

问：WQ7036AX 的三种角色是什么？
答：翻译官（指令转发，手机 BLE ↔ V881 UART）、音频管家（采集+处理+发送音频）、外设保姆（传感器+按键+LED）。

问：手机和 V881 之间可以直接通信吗？
答：可以，通过 WiFi 6（RTSP/UDP，~100Mbps），用于高速传输视频和点云数据，不经 WQ7036AX 中转。

问：控制指令为什么必须经过 WQ7036AX 中转？
答：手机只通过 BLE 连接 WQ7036AX，不直接连 V881。WQ7036AX 需要把 BLE 指令翻译成 UART 命令再转发给 V881。

问：控制指令的路由规则是什么？
答：硬件连在谁身上谁就负责。摄像头/TOF/WiFi 在 V881 上，转发；麦克风/扬声器/传感器在 WQ7036AX 上，本地执行。