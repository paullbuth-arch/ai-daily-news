# 经典蓝牙：HFP / A2DP / AVRCP / SPP

**一句话结论（20% 核心）**：经典蓝牙（BR/EDR）管两件事——通话（HFP）和音乐（A2DP）。HFP 是双向低质量语音，A2DP 是单向高质量音频。WQ7036AX 是双模蓝牙芯片，同时支持 BLE 和经典蓝牙。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：电话 vs 音响

- **HFP（Hands-Free Profile）** = 电话：双向通话，音质一般（8-16 kHz），但延迟低
- **A2DP（Advanced Audio Distribution Profile）** = 蓝牙音响：单向播放，音质好（44.1/48 kHz），但延迟高
- **AVRCP（Audio/Video Remote Control Profile）** = 遥控器：切歌、调音量、暂停
- **SPP（Serial Port Profile）** = 串口线：传任意数据，类似无线 UART

### 1.2 四大 Profile 对比

| Profile | 方向 | 音频质量 | 延迟 | 用途 |
|---------|------|---------|------|------|
| **HFP** | 双向 | 8-16 kHz（窄带/宽带） | ~30ms | 通话 |
| **A2DP** | 单向（手机→耳机） | 44.1/48 kHz | ~150ms | 听音乐 |
| **AVRCP** | 双向控制 | 无音频 | — | 切歌/暂停 |
| **SPP** | 双向 | 无音频 | 低 | 传数据（类似 UART） |

### 1.3 经典蓝牙 vs BLE 对比

| | 经典蓝牙 (BR/EDR) | BLE |
|---|---|---|
| 速度 | 1-3 Mbps | 125k-2 Mbps |
| 功耗 | 较高 | 极低 |
| 音频 | HFP/A2DP（原生支持） | 需要 LE Audio/LC3 |
| 连接 | 持续连接 | 间歇连接 |
| reGlasses 用途 | 通话+音乐 | 控制+遥测+音频传输 |

### 1.4 如果只记得一件事

> 经典蓝牙 = 通话（HFP）+ 音乐（A2DP）+ 遥控（AVRCP）+ 数据（SPP）。WQ7036AX 是双模芯片，经典蓝牙和 BLE 可以同时工作。

---

## 第二层：实战理解

### 2.1 HFP 的音频链路

```
手机                    WQ7036AX
  │                        │
  │── SCO/eSCO 链路 ──────→│  (同步面向连接，专为语音设计)
  │  CVSD/mSBC 编码        │
  │                        ├─→ I2S → 功放 → 扬声器（对方的语音）
  │                        │
  │←── SCO/eSCO 链路 ──────│  (自己的语音)
  │                        │
                           └─→ PDM 麦 → DSP → 编码
```

### 2.2 A2DP 的音频链路

```
手机                    WQ7036AX
  │                        │
  │── A2DP 链路 ──────────→│  (单向，高质量)
  │  SBC/AAC/LDAC 编码     │
  │                        ├─→ 解码 → I2S → 功放 → 扬声器
```

### 2.3 常见坑

| 问题 | 现象 | 根因 |
|------|------|------|
| HFP 和 A2DP 同时用 | 音质变差 | 经典蓝牙带宽有限，共享 SCO + ACL |
| SCO 链路断开 | 通话中断 | 距离太远或干扰，SCO 没有重传机制 |
| A2DP 延迟大 | 画面和声音不同步 | A2DP 缓冲大（~150ms），不适合游戏/视频 |

### 2.4 在 reGlasses 项目中怎么用

WQ7036AX 的 BCORE 负责经典蓝牙的底层协议栈，ACORE 负责应用层控制。reGlasses 通过 HFP 实现免提通话，通过 A2DP 播放手机音乐。BCORE 固件和蓝牙协议栈在 `wqcore/components/bluetooth/` 下。

---

## 第三层：延伸阅读

- [[ble-gap-BLE-GAP广播]] — BLE 和经典蓝牙的区别
- [[reglasses-bandwidth-reGlasses带宽约束]] — 双模蓝牙 + WiFi 的带宽分配