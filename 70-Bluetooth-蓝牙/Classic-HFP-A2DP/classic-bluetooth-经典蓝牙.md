---
type: concept
created: 2026-07-17
tags: [protocol, bluetooth, classic, hfp, a2dp, avrcp, wq7036ax]
aliases: [经典蓝牙, Classic Bluetooth, BR/EDR, HFP, A2DP, AVRCP]
---

# 经典蓝牙：HFP / A2DP / AVRCP / SPP

## 一句话结论

经典蓝牙（BR/EDR）是 WQ7036AX 双模蓝牙芯片的一部分，负责两件事——通话（HFP，双向低延迟语音，走 SCO/eSCO 链路）和音乐播放（A2DP，单向高质量音频，走 ACL 链路）。HFP 使用 SCO 链路保证低延迟（~30ms）但不重传，A2DP 使用 ACL 链路保证可靠传输但缓冲大导致延迟高（~150ms）。WQ7036AX 的经典蓝牙和 BLE 可以同时工作，共享 2.4GHz 天线通过时分复用交替使用射频。

## 30秒先看懂

- 经典蓝牙有两条物理链路：SCO/eSCO 用于语音通话（低延迟无重传），ACL 用于数据传输和音乐（有重传保证可靠）。
- HFP（免提通话）走 SCO 链路，延迟低（~30ms）但音质有限（8/16kHz），适合通话场景。
- A2DP（音乐播放）走 ACL 链路，音质好（44.1/48kHz）但延迟高（~150ms），适合听音乐。
- WQ7036AX 是双模芯片，ACORE 上通过 bt_service API 控制经典蓝牙，BCORE 固件实现底层协议栈。
- 双模同时工作时，经典蓝牙和 BLE 共享带宽，各自性能会下降约一半。

## 学完以后应该能做什么

### 第一遍
- 描述 HFP、A2DP、AVRCP、SPP 四个 Profile 的用途和底层链路
- 解释 SCO 和 ACL 链路的区别及对通话/音乐延迟的影响
- 在 SDK 中找到经典蓝牙的 API 头文件位置

### 进阶
- 排查 HFP 通话卡顿和 A2DP 延迟大的根因
- 理解双模蓝牙共存时的带宽分配策略
- 配置音频路由（通话时音频走 I2S→功放，音乐时走 DAC→功放）

## 前置知识

- [[ble-gap-BLE-GAP广播]]：BLE 和经典蓝牙的技术对比
- [[ble-gatt-BLE-GATT]]：BLE 的数据交换方式
- [[wq7036ax-chip-WQ7036AX芯片]]：双模蓝牙硬件架构，ACORE 和 BCORE 的分工
- [[reglasses-bandwidth-reGlasses带宽约束]]：双模蓝牙带宽分配

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 基本速率/增强数据速率 | BR/EDR (Basic Rate / Enhanced Data Rate) | 经典蓝牙的物理层标准，BR 1 Mbps，EDR 2-3 Mbps |
| 免提协议 | HFP (Hands-Free Profile) | 用于车载免提或蓝牙耳机的通话协议 |
| 高级音频分发协议 | A2DP (Advanced Audio Distribution Profile) | 用于无线传输高质量音频的协议 |
| 音频/视频远程控制协议 | AVRCP (Audio/Video Remote Control Profile) | 用于远程控制音频/视频播放的协议 |
| 串口仿真协议 | SPP (Serial Port Profile) | 将蓝牙模拟为串口，传输任意二进制数据 |
| 异步无连接链路 | ACL (Asynchronous Connection-Less) | 面向数据的链路，有重传保证可靠，延迟较高 |
| 同步面向连接链路 | SCO (Synchronous Connection-Oriented) | 面向语音的链路，预留时隙保证低延迟，无重传 |
| 增强型同步链路 | eSCO (Enhanced SCO) | SCO 的改进版，支持可选的有限重传 |
| 低复杂度子带编码 | SBC (Low Complexity Subband Codec) | A2DP 必须支持的音频编码器 |
| 连续可变斜率增量调制 | CVSD (Continuous Variable Slope Delta Modulation) | HFP 窄带语音编码器（8kHz） |
| 修正子带编码 | mSBC (modified Subband Coding) | HFP 宽带语音编码器（16kHz） |
| 逻辑链路控制和适配协议 | L2CAP (Logical Link Control and Adaptation Protocol) | 蓝牙协议栈中的复用和分段重组层 |
| 射频通信 | RFCOMM (Radio Frequency Communication) | 在 L2CAP 上模拟串口操作的协议 |

## 第一层费曼心智模型

### 类比：电话线 vs 音响线 vs 对讲机

- **HFP（免提通话）** = 电话线：双向通话，双方同时说话，音质一般但延迟极低（<30ms），否则对话很难受。因为电话线（SCO 链路）是专用通道，不重传——丢了就丢了，保证实时性。
- **A2DP（音乐播放）** = 音响线：单向传输，手机→耳机，音质好（44.1/48kHz），但缓冲大导致延迟高（~150ms）。因为音响线（ACL 链路）保证数据完整到达——丢了就重传，所以延迟高。
- **AVRCP（媒体控制）** = 遥控器：切歌、暂停、调音量，只传控制命令不传音频。
- **SPP（串口仿真）** = 无线对讲机：传任意二进制数据，没有固定格式，类似无线版 UART。

### 边界

- 通话和音乐不能同时达到高品质——SCO 和 ACL 共享蓝牙带宽，SCO 预留了固定时隙给语音，剩下的才给 ACL 传音乐。
- 经典蓝牙的 SCO 链路无重传——距离远或干扰大时，通话直接断断续续或断开，没有"收不到重发"的机制。
- A2DP 延迟 ~150ms 是正常范围——看视频时音画不同步是常见问题，需要手机端做延迟补偿。
- 双模蓝牙同时工作时，BLE 和经典蓝牙共享带宽，各自的吞吐量都会下降约一半。

### 场景推演

**场景：用户戴着 reGlasses 接听微信电话**

1. 手机来电，WQ7036AX 收到来电通知
2. HFP 连接建立，手机和眼镜之间建立 SCO 链路
3. 手机麦克风采集语音 → CVSD/mSBC 编码 → SCO 发送 → 眼镜接收 → 解码 → I2S → 功放 → 扬声器
4. 眼镜 PDM 麦克风采集用户声音 → DSP（降噪 + AEC 回声消除）→ 编码 → SCO 发送 → 手机接收 → 解码 → 扬声器
5. 通话结束，SCO 链路断开，恢复 A2DP 音乐播放（或空闲）

## 第二层原理/时序/约束

### 蓝牙协议栈分层

```
应用层:    HFP  |  A2DP  |  AVRCP  |  SPP
              ↓       ↓        ↓        ↓
协议层:    RFCOMM  |  L2CAP  |  SDP（服务发现协议）
              ↓       ↓        ↓        ↓
链路层:   SCO/eSCO  |  ACL（异步无连接链路）
              ↓       ↓        ↓        ↓
物理层:    2.4GHz 射频（WQ7036AX BCORE 固件负责）
```

### SCO vs ACL 链路对比

| 特性 | SCO/eSCO | ACL |
|------|---------|-----|
| 全称 | Synchronous Connection-Oriented | Asynchronous Connection-Less |
| 用途 | 语音通话 | 数据、音乐、控制命令 |
| 传输方式 | 预留固定时隙 | 尽力传输 |
| 重传 | 无（eSCO 支持有限重传） | 有（保证可靠） |
| 延迟 | 极低（~5-10ms） | 较高（~50-100ms+） |
| 带宽 | 固定（64 kbps） | 动态分配 |
| 应用 | HFP | A2DP、AVRCP、SPP |

### 四大 Profile 详细对比

| Profile | 底层链路 | 音频编码 | 采样率 | 方向 | 延迟 | 带宽 | reGlasses 场景 |
|---------|---------|---------|--------|------|------|------|---------------|
| **HFP** | SCO/eSCO | CVSD / mSBC | 8/16 kHz | 双向 | ~30ms | 64 kbps | 微信通话、电话 |
| **A2DP** | ACL | SBC / AAC / LDAC | 44.1/48 kHz | 单向 | ~150ms | 328 kbps (SBC) | 听音乐、导航播报 |
| **AVRCP** | ACL | 无音频 | — | 双向 | <10ms | <1 kbps | 按键切歌、调音量 |
| **SPP** | ACL | 无音频 | — | 双向 | <50ms | 可变 | 传自定义数据（已较少用） |

### HFP 音频编码器

| 编码 | 采样率 | 码率 | 音质 | 延迟 |
|------|--------|------|------|------|
| **CVSD** | 8 kHz | 64 kbps | 窄带（电话音质） | 极低 |
| **mSBC** | 16 kHz | 64 kbps | 宽带（微信音质） | 低 |

WQ7036AX 支持 mSBC（宽带语音），协商时优先使用。如果手机不支持 mSBC，回退到 CVSD。

### A2DP 音频编码器

| 编码 | 码率 | 音质 | 兼容性 |
|------|------|------|--------|
| **SBC** | 328 kbps | 基础 | 所有蓝牙设备都支持（必须支持） |
| **AAC** | 256 kbps | 优于 SBC | iPhone 默认 |
| **LDAC** | 330/660/990 kbps | 接近无损 | 索尼设备 |

WQ7036AX 主要用 SBC（兼容性最好），A2DP 规范要求所有设备必须支持 SBC。

### 双模蓝牙共存时序

```
时间轴（每个时隙 625us）:
| BLE 事件 | 经典蓝牙 SCO | BLE 事件 | 经典蓝牙 ACL | BLE 事件 | 经典蓝牙 SCO | ...

ACORE 和 BCORE 通过 HCI 协议通信，BCORE 固件负责 TDM 调度。
应用层不需要直接管理 TDM，但需要理解：
- 经典蓝牙和 BLE 同时工作时，各自带宽约下降 50%
- 通话中 A2DP 音质会下降（SCO 预留了时隙）
- 大数据量 BLE 传输（如 OTA）会干扰通话质量
```

### HFP 完整音频链路

```
手机端                            WQ7036AX 端
  │                                  │
  │ 麦克风采集                       │
  │   ↓                              │
  │ CVSD/mSBC 编码                   │
  │   ↓                              │
  │── SCO/eSCO 空中发送 ────────────→│
  │                                  │ 收到 → 解码 → I2S → 功放 → 扬声器
  │                                  │     (你听到对方的声音)
  │                                  │
  │←── SCO/eSCO 空中发送 ────────────│
  │                                  │ PDM 麦 → DSP(降噪/AEC) → 编码
  │ 收到 → 解码 → 扬声器              │     (你的声音发给对方)
  │     (对方听到你的声音)            │
```

**AEC（回声消除）在 HFP 中极其重要**：扬声器播放的声音如果被麦克风重新采集，对方会听到自己的回声。WQ7036AX 的 DCORE 做 AEC 处理。

## 第三层真实SDK代码

### 经典蓝牙 API 位置

位于 `/home/ys/wq7036a/wq-audio/wqcore/components/bluetooth/host/bbb/inc/wq_bth_api.h` 和 `/home/ys/wq7036a/wq-audio/wq-adk/components/bt_service/api/bt_srv_api.h`：

```c
// HFP 通话连接
bt_srv_hfp_connect(peer_addr);

// 注册通话状态回调
bt_srv_register_hfp_callback(on_call_state_change);

// SCO 数据写入（DCORE 处理音频后写入 SCO 链路）
uint16_t bt_srv_sco_write(uint16_t connection_handle,
                           uint8_t *packet, uint16_t packet_len);

// 获取当前 SCO 连接句柄
uint16_t bt_srv_get_sco_handle(void);

// 获取远程设备 ID 和地址
uint8_t bt_srv_get_remote_device_id(void);
uint8_t *bt_srv_get_remote_device_addr(void);
```

### HFP 通话状态回调示例

```c
// 通话状态回调
void on_call_state_change(hfp_call_state_t state) {
    switch (state) {
    case HFP_CALL_ACTIVE:
        // 通话中，调整音频路由到 I2S→功放
        aud_sv_set_route(AUDIO_ROUTE_I2S_SPEAKER);
        // 启动 DCORE 的 AEC 处理
        aec_processing_start();
        break;

    case HFP_CALL_IDLE:
        // 通话结束，恢复正常
        aud_sv_set_route(AUDIO_ROUTE_NONE);
        aec_processing_stop();
        break;

    case HFP_CALL_INCOMING:
        // 有来电
        // 播放来电提示音
        play_ringtone();
        break;

    case HFP_CALL_DIALING:
        // 正在拨出
        break;
    }
}
```

### 经典蓝牙 API 头文件（`wq_bt_sdp_api.h`）

位于 `/home/ys/wq7036a/wq-audio/wqcore/components/bluetooth/host/bbb/inc/wq_bt_sdp_api.h`，负责服务发现：

```c
// SDP（服务发现协议）用于在两台蓝牙设备之间发现对方支持哪些 Profile
// 手机通过 SDP 查询 WQ7036AX 是否支持 HFP、A2DP 等 Profile
// WQ7036AX 通过 SDP 注册自己支持的 Profile
```

## 第四层正常/异常路径

### 异常路径

| 问题 | 现象 | 排查方法 | 根因 |
|------|------|---------|------|
| HFP+A2DP 同时用时音质变差 | 音乐播放中接电话，音质骤降 | 看带宽是否超限 | SCO 预留了固定时隙，ACL 可用带宽被压缩 |
| SCO 链路断开 | 通话中突然没声音 | 看 HCI log，检查监督超时 | 距离太远/干扰大，SCO 无重传，断了就断了 |
| A2DP 音频延迟大 | 看视频时画面和声音不对 | 测量实际延迟 | A2DP 默认缓冲 100-200ms |
| 配对后无法连接 HFP | 只连上了 A2DP，HFP 连不上 | 检查手机端是否支持 HFP | 手机只配对了 A2DP，HFP 需要单独建立 SCO 连接 |
| 回声 | 对方听到自己的回声 | 检查 AEC 是否开启 | DCORE 的 AEC 处理未使能或参数不当 |
| 通话音质差 | 对方听不清 | 检查编码器协商 | 回退到 CVSD 窄带编码 |

## 第五层调试方法

### HCI Log 分析经典蓝牙

```bash
# 抓取 HCI 日志
sudo btmon -w classic_bt_trace.log

# 查看 SCO 连接建立
btmon -r classic_bt_trace.log | grep -i "sco"

# 查看 A2DP 编码协商
btmon -r classic_bt_trace.log | grep -i "a2dp\|codec"

# 查看 HFP 状态
btmon -r classic_bt_trace.log | grep -i "hfp\|call"
```

### 常见排查命令

```bash
# 查看蓝牙设备信息
hciconfig

# 查看经典蓝牙连接状态
hcitool con

# 扫描经典蓝牙设备
hcitool scan

# 查看 SDP 服务
sdptool browse <bd_addr>
```

### WQ7036AX 日志

```c
// 在通话状态变化时添加日志
#define LOG_TAG "[hfp] "
#include "app_log.h"

void on_call_state_change(hfp_call_state_t state) {
    LOGI("HFP call state changed: %d", state);
    switch (state) {
    case HFP_CALL_ACTIVE:
        LOGI("HFP call active, SCO handle=0x%04X",
             bt_srv_get_sco_handle());
        break;
    case HFP_CALL_IDLE:
        LOGI("HFP call idle");
        break;
    case HFP_CALL_INCOMING:
        LOGI("Incoming call");
        break;
    }
}
```

## 第六层实战练习

### 练习1：实现通话状态音频路由切换

编写代码，在 HFP 通话状态变化时自动切换音频路由：

```c
// 通话开始时：音频路由到 I2S 功放
// 通话结束时：音频路由关闭
// 请补全
void on_hfp_call_state(hfp_call_state_t state) {
    switch (state) {
    case HFP_CALL_ACTIVE:
        // 设置音频路由到 I2S 功放

        // 打印 SCO 连接句柄

        break;

    case HFP_CALL_IDLE:
        // 关闭音频路由

        break;

    case HFP_CALL_INCOMING:
        // 播放来电铃声

        break;
    }
}
```

### 练习2：阅读 SDK 源码分析经典蓝牙初始化

在 `/home/ys/wq7036a/wq-audio/wq-adk/components/bt_service/` 目录下搜索经典蓝牙的初始化代码，分析：
- 经典蓝牙初始化顺序（SDP 注册 → Profile 注册 → 可发现模式）
- HFP 和 A2DP 的注册流程
- 双模蓝牙的共存配置

### 练习3：分析 A2DP 延迟优化方案

对于 reGlasses 的场景（看视频时需要音画同步），分析以下方案哪个可行：

```
方案 A：减少 A2DP 缓冲大小（降低延迟但可能卡顿）
方案 B：切换到低延迟编码器（如 aptX Low Latency）
方案 C：视频走 WiFi，音频走 BLE 同步（自定义延迟补偿）
方案 D：手机端做视频延迟补偿（匹配 A2DP 延迟）
```

## 自测与验收

1. HFP 和 A2DP 分别使用哪条物理链路？SCO 和 ACL 的核心区别是什么？
2. 为什么通话延迟低但音质差，音乐音质好但延迟高？
3. CVSD 和 mSBC 的区别是什么？WQ7036AX 支持哪个？
4. 双模蓝牙同时工作时有什么影响？如何应对？
5. A2DP 必须支持什么编码器？SBC 的典型码率是多少？

## 延伸阅读

- [[ble-gap-BLE-GAP广播]] — BLE 和经典蓝牙的技术对比
- [[ble-gatt-BLE-GATT]] — BLE 的数据交换方式
- [[reglasses-bandwidth-reGlasses带宽约束]] — 双模蓝牙+WiFi 的带宽分配策略
- [[bt-debug-蓝牙调试]] — 用 HCI Log 排查蓝牙问题
- `/home/ys/wq7036a/wq-audio/wqcore/components/bluetooth/host/bbb/inc/` — 经典蓝牙 HCI API
- `/home/ys/wq7036a/wq-audio/wq-adk/components/bt_service/api/bt_srv_api.h` — BT 服务层 API

#flashcard
问：HFP 和 A2DP 分别使用什么物理链路？
答：HFP 使用 SCO/eSCO 链路（同步面向连接，预留时隙，无重传），A2DP 使用 ACL 链路（异步无连接，有重传保证可靠）。

问：为什么通话延迟低但音质差？
答：HFP 走 SCO 链路，预留固定时隙无重传，延迟极低（~30ms），但带宽有限（64kbps），音质差。A2DP 走 ACL 链路有重传，延迟高（~150ms），但带宽大（328kbps SBC），音质好。

问：CVSD 和 mSBC 的区别？
答：CVSD 是 8kHz 窄带编码，电话音质。mSBC 是 16kHz 宽带编码，微信音质。WQ7036AX 支持 mSBC。

问：双模蓝牙同时工作时有什么影响？
答：经典蓝牙和 BLE 共享 2.4GHz 天线和带宽，通过 TDM 时分复用，同时工作时各自带宽约下降一半。

问：A2DP 必须支持什么编码器？
答：SBC（Low Complexity Subband Codec），328 kbps，所有蓝牙设备都支持。