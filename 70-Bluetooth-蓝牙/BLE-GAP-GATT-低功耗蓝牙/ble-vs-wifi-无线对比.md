---
type: concept
created: 2026-07-17
tags: [comparison, ble, wifi, wireless, 对比, 无线, 带宽]
aliases: [无线对比, BLE vs WiFi, BLE 与 WiFi 对比]
---

# 无线对比：BLE vs WiFi

## 一句话结论

BLE 和 WiFi 是 reGlasses 中互补的两条无线链路——BLE（WQ7036AX 负责，~1.4 Mbps 实际吞吐）传输低功耗、小数据量的控制指令、遥测和压缩音频，WiFi（V881 负责，~100-500 Mbps）传输高带宽的视频流、深度点云和 OTA 大文件。理解两者的带宽硬约束是设计数据流架构的前提。

## 30秒先看懂

- BLE 5.4 实际吞吐约 1-1.4 Mbps，WiFi 6 约 100-500 Mbps，差距约 100 倍，BLE 只适合传小数据量。
- reGlasses 中 BLE 走控制指令（~1 Kbps）、Opus 音频（~32 Kbps）、IMU 降采样（~32 Kbps）；WiFi 走 H.264 视频（5-20 Mbps）、TOF 点云（2-10 Mbps）。
- BLE 功耗极低（uA~mA 级），适合电池供电设备；WiFi 功耗高（百 mA 级），不适合持续开启。
- 经典蓝牙（HFP/A2DP）和 BLE 可以同时工作，但共享 2.4GHz 天线和带宽，同时使用时各自带宽下降。
- PCM 音频（48kHz/24bit，~2.3 Mbps）和 H.264 视频（~10 Mbps）都远超 BLE 带宽上限，必须走 WiFi 或经典蓝牙。

## 学完以后应该能做什么

### 第一遍
- 判断某种数据类型应该走 BLE 还是 WiFi，依据是带宽需求和功耗要求
- 解释 reGlasses 的带宽分配图，说明每条链路的流量
- 计算 BLE 的有效负载与带宽匹配

### 进阶
- 在 BLE 带宽受限时进行降采样或压缩策略调整
- 设计双模蓝牙（经典蓝牙 + BLE）共存时的带宽分配方案
- 排查因带宽超限导致的通信卡顿或丢包问题

## 前置知识

- [[ble-gatt-BLE-GATT]]：BLE 的数据交互方式
- [[classic-bluetooth-经典蓝牙]]：经典蓝牙的 HFP/A2DP 带宽占用
- [[reglasses-architecture-reGlasses协议架构]]：整体系统拓扑

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 实际吞吐 | Actual Throughput | 扣除协议开销后实际能传输的有效数据速率 |
| 带宽 | Bandwidth | 单位时间内能传输的数据量，通常以 bps 为单位 |
| 延迟 | Latency | 数据从发送端到接收端的传输延迟 |
| 时分复用 | TDM (Time Division Multiplexing) | 多个协议共享同一物理信道，按时间片轮流使用 |
| 双模蓝牙 | Dual-mode Bluetooth | 同时支持经典蓝牙（BR/EDR）和低功耗蓝牙（BLE）的芯片 |
| 码率 | Bitrate | 音频/视频编码后的数据速率 |
| 信噪比 | SNR (Signal-to-Noise Ratio) | 信号强度与噪声强度的比值，影响实际吞吐 |

## 第一层费曼心智模型

### 类比：自来水管和消防水管

BLE 和 WiFi 就像两种不同口径的水管：

- **BLE** = 家用自来水管（细管）——水流小但稳定，随时可以打开，不怎么费水费电。适合：喝水（控制指令）、洗手（状态上报）、接一杯水（压缩音频）。
- **WiFi** = 消防水管（粗管）——水流巨大，但打开需要更大的泵（功耗高），不能一直开着。适合：灌满游泳池（视频流）、洗车（大文件传输）、消防（高带宽实时数据）。
- **经典蓝牙（HFP/A2DP）** = 已经接好的专用水管——通话（HFP）是双向对讲管道，音乐（A2DP）是单向高品质管道，和 BLE 共用同一个水表（天线）。

### 边界

- BLE 的 ~1.4 Mbps 实际吞吐是理论最大值，实际受距离、干扰、连接间隔等因素影响可能更低。
- WiFi 的 100-500 Mbps 也是理论值，实际受信号强度、信道拥堵等因素影响。
- 经典蓝牙和 BLE 同时工作时，共享的 2.4GHz 天线带宽约 3 Mbps，需要 TDM 时分复用。
- 数据大小不是唯一判断标准——实时性也很重要。BLE 延迟约 15ms，适合实时控制；WiFi 延迟约 10-50ms，流媒体场景下也够用。

### 场景推演

**场景：用户按下眼镜上的拍照按钮**

1. 用户按下拍照键
2. WQ7036AX 检测到按键事件
3. 通过 BLE C1 Device Control（Write）发送"拍照"指令给手机 APP（~10 字节，~1ms）
4. 手机 APP 收到指令，通过 WiFi 发给 V881（或通过手机自身控制 V881）
5. V881 拍照，照片通过 WiFi 传输到手机（~2MB, ~0.1s）
6. 拍照完成，V881 通知 WQ7036AX
7. WQ7036AX 通过 BLE C2 Device Status（Notify）上报"拍照完成"（~5 字节，~1ms）

关键点：控制指令走 BLE（低延迟、低功耗），照片数据走 WiFi（高带宽）。

## 第二层原理/时序/约束

### 详细带宽对比

| 维度 | BLE 5.4 | 经典蓝牙 (BR/EDR) | WiFi 6 (V881) |
|------|---------|-------------------|--------------|
| **理论速率** | 2 Mbps (PHY) | 3 Mbps (EDR) | 600+ Mbps |
| **实际吞吐** | ~1.4 Mbps | ~1.5 Mbps | ~100-500 Mbps |
| **功耗** | ~10 mW (TX) | ~30-50 mW (TX) | ~100-500 mW (TX) |
| **延迟** | ~15ms | ~30ms (A2DP) / ~5ms (HFP) | ~10-50ms |
| **距离** | 10-100m | 10-50m | 50-200m |
| **频段** | 2.4 GHz | 2.4 GHz | 2.4/5 GHz |
| **reGlasses 芯片** | WQ7036AX | WQ7036AX | V881 |

### reGlasses 各数据流的带宽占用

| 数据流 | 带宽需求 | 走哪条路 | 能否走 BLE |
|--------|---------|---------|-----------|
| 控制指令 | ~1 Kbps | BLE | ✅ 绰绰有余 |
| 遥测/状态上报 | ~1 Kbps | BLE | ✅ 绰绰有余 |
| Opus 音频 (16kHz, 20ms) | 16-32 Kbps | BLE | ✅ 可以 |
| IMU 降采样 (250Hz) | ~32 Kbps | BLE | ✅ 可以 |
| PCM 音频 (16kHz, 16bit) | ~256 Kbps | 经典蓝牙 (HFP) | ⚠️ 勉强，但 HFP 已占用 |
| PCM 音频 (48kHz, 24bit) | ~2.3 Mbps | 经典蓝牙 (A2DP) / WiFi | ❌ 远超 BLE 上限 |
| H.264 视频 (720p) | 5-20 Mbps | WiFi | ❌ 完全不行 |
| TOF 深度点云 | 2-10 Mbps | WiFi | ❌ 完全不行 |
| OTA 固件 | ~1 Mbps | BLE (慢) / WiFi (快) | ⚠️ 可以但慢 |

### 双模蓝牙共存时的带宽分配

```
经典蓝牙和 BLE 共享 2.4GHz 射频，通过时分复用（TDM）交替使用：

时间轴: | BLE | 经典 | BLE | 经典 | BLE | 经典 | BLE | ...
        | GATT| A2DP | GATT| A2DP | GATT| A2DP | GATT| ...

实际影响：
- 经典蓝牙和 BLE 同时工作时，各自带宽减半
- 通话中（HFP）音频流可能受影响
- 需要合理分配连接间隔和 SCO 时隙
```

### BLE 带宽计算实例

```
假设：连接间隔 = 30ms，每个连接事件传输 4 个包，每个包 244 字节

每个连接事件的吞吐量 = 4 × 244 = 976 字节
每秒连接事件数 = 1000 / 30 = 33.3
最大吞吐量 = 976 × 33.3 = 32,500 字节/秒 ≈ 260 Kbps

实际可用吞吐（考虑协议开销、重传等）≈ 130-200 Kbps
```

## 第三层真实SDK代码

### 广播数据中的带宽控制

在 `/home/ys/wq7036a/wq-audio/wq-adk/components/apps/acore/ota/src/ota_transport_ble.c` 中，广播间隔控制着发现速度和功耗：

```c
// 广播间隔控制
// 160 * 0.625ms = 100ms（正常模式）
wq_adv_set_interval(adv_handle, 160, 160);

// 如果需要更快的发现（如配网模式），可以缩短到 30ms
// 48 * 0.625ms = 30ms
wq_adv_set_interval(adv_handle, 48, 48);
```

### 连接参数控制

连接间隔直接影响 BLE 带宽：

```c
// 在连接建立后，可以请求更新连接参数
// 连接间隔越小，带宽越大，但功耗也越高
typedef struct {
    uint16_t interval_min;    // 最小连接间隔 (单位 1.25ms)
    uint16_t interval_max;    // 最大连接间隔
    uint16_t latency;         // 从机延迟
    uint16_t timeout;         // 监督超时
} wq_ble_conn_param_t;

// 高带宽场景：15ms 连接间隔
wq_ble_conn_param_t high_bw = {
    .interval_min = 12,    // 12 * 1.25ms = 15ms
    .interval_max = 12,    // 15ms
    .latency = 0,          // 不跳过连接事件
    .timeout = 400,        // 400 * 10ms = 4000ms
};

// 低功耗场景：100ms 连接间隔
wq_ble_conn_param_t low_pwr = {
    .interval_min = 80,    // 80 * 1.25ms = 100ms
    .interval_max = 80,    // 100ms
    .latency = 4,          // 可跳过 4 个连接事件
    .timeout = 400,
};
```

## 第四层正常/异常路径

### 带宽超限路径

```
正常情况：
  BLE 带宽占用：控制(1K) + 音频(32K) + IMU(32K) = ~65 Kbps
  BLE 可用带宽：~200 Kbps
  余量充足，通信流畅

异常情况：
  BLE 同时传输：控制 + 音频 + IMU + OTA(200K) = ~265 Kbps
  超过可用带宽 ~200 Kbps
  → 包重传增加 → 延迟升高 → 丢包 → 用户体验下降
```

### 带宽相关问题排查

| 问题 | 现象 | 原因 | 解决方法 |
|------|------|------|---------|
| Notify 发送间隔超长 | 手机收到数据延迟 | 连接间隔太大 | 减小连接间隔 |
| 音频卡顿 | 声音断断续续 | BLE 带宽不足 | 降低 Opus 码率或减少其他数据流 |
| 经典蓝牙和 BLE 同时用卡顿 | 通话时数据延迟 | 双模带宽共享冲突 | 调整 TDM 分配或降低其中一路的负载 |
| 远距离通信失败 | 离 10 米外就连不上 | BLE 信号衰减 | 增大发射功率或减小连接间隔 |

## 第五层调试方法

### 带宽测量

```c
// 测量 BLE Notify 的实际吞吐量
#define LOG_TAG "[bw] "
#include "app_log.h"

static uint32_t total_bytes = 0;
static uint32_t last_report_time = 0;

void on_notify_sent(uint32_t bytes) {
    total_bytes += bytes;
    uint32_t now = xTaskGetTickCount();
    if (now - last_report_time >= pdMS_TO_TICKS(5000)) {
        uint32_t elapsed_ms = (now - last_report_time) * portTICK_PERIOD_MS;
        float kbps = (total_bytes * 8.0f) / elapsed_ms;
        LOGI("BLE throughput: %.1f Kbps (%d bytes in %d ms)",
             kbps, total_bytes, elapsed_ms);
        total_bytes = 0;
        last_report_time = now;
    }
}
```

### 信号质量检查

```bash
# 使用 btmon 查看 RSSI
sudo btmon -w rssi_capture.log

# 查看 RSSI 变化
btmon -r rssi_capture.log | grep -i "rssi"
```

## 第六层实战练习

### 练习1：计算 BLE 带宽预算

reGlasses 在以下场景中，BLE 带宽是否够用？请计算各数据流的总带宽需求：

```
- 控制指令：每 100ms 发送 10 字节
- Opus 音频：32 Kbps
- IMU 数据：250Hz，每采样 16 字节，每包 14 个采样
- 假设 BLE 实际可用带宽为 200 Kbps
```

### 练习2：分析经典蓝牙 + BLE 共存问题

在 `/home/ys/wq7036a/wq-audio/wqcore/components/bluetooth/` 目录下搜索与双模共存相关的代码，分析：
- 经典蓝牙和 BLE 的 TDM 配置在哪里定义？
- 同时连接时如何分配连接间隔？
- 通话中（HFP SCO 连接）音频流是否有优先级？

### 练习3：设计数据流降级策略

如果 BLE 带宽不足，设计一个降级策略，按优先级决定哪些数据流应该降级或停止：

```c
// 优先级：控制指令 > 状态上报 > 音频 > IMU > OTA
// 降级策略函数
typedef enum {
    STREAM_CTRL,   // 控制指令（最高优先级，必须保证）
    STREAM_STATUS, // 状态上报
    STREAM_AUDIO,  // 音频流
    STREAM_IMU,    // IMU 数据
    STREAM_OTA,    // OTA 升级（最低优先级）
} data_stream_t;

void bandwidth_management(void) {
    // 1. 测量当前 BLE 吞吐量
    // 2. 如果超过阈值（如 180 Kbps），按优先级降级
    // 3. 优先降低 OTA 速率，然后降低 IMU 频率
    // 4. 控制指令始终保持
    // 请补全
}
```

## 自测与验收

1. BLE 和 WiFi 的实际吞吐大约分别是多少？差距多少倍？
2. reGlasses 的 H.264 视频流能走 BLE 吗？为什么？
3. 双模蓝牙（经典蓝牙 + BLE）同时工作时会有什么影响？如何应对？
4. BLE 的实际可用带宽除了受 PHY 速率限制，还受哪些因素影响？
5. PCM 音频 48kHz/24bit 的带宽需求是多少？能否走 BLE？

## 延伸阅读

- [[reglasses-bandwidth-reGlasses带宽约束]] — 详细的带宽数据
- [[ble-gatt-BLE-GATT]] — BLE 数据交互
- [[classic-bluetooth-经典蓝牙]] — 经典蓝牙的带宽特性
- [[reglasses-architecture-reGlasses协议架构]] — 整体拓扑
- [[wq7036ax-audio-pipeline-WQ7036AX音频管道]] — BLE 音频传输链

#flashcard
问：BLE 和 WiFi 的实际带宽分别大约是多少？
答：BLE 5.4 约 1-1.4 Mbps，WiFi 6 约 100-500 Mbps，差了约 100 倍。

问：reGlasses 的 H.264 视频流能走 BLE 吗？
答：不能。H.264 视频需要 5-20 Mbps，远超 BLE 的 ~1.4 Mbps 上限。必须走 WiFi（V881 负责）。

问：经典蓝牙和 BLE 同时工作时有什么影响？
答：共享 2.4GHz 天线和带宽，通过 TDM 时分复用，同时使用时各自带宽下降约一半。

问：什么音频格式能走 BLE？
答：Opus 压缩音频（16-32 Kbps）可以。PCM 原始音频（16kHz/16bit 需要 256 Kbps）勉强，48kHz/24bit 需要 2.3 Mbps 完全不行。

问：BLE 实际可用带宽主要受哪些因素影响？
答：连接间隔、从机延迟、距离（RSSI）、干扰、包重传率、MTU 大小。