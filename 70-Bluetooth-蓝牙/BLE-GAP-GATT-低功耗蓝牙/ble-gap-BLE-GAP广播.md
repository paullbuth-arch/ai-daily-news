---
type: concept
created: 2026-07-17
tags: [protocol, ble, gap, advertising, 广播, 蓝牙, wq7036ax]
aliases: [BLE 广播, BLE Advertising, GAP, Generic Access Profile]
---

# BLE GAP 广播

## 一句话结论

GAP（Generic Access Profile，通用访问配置文件）广播是 BLE 设备让周围设备发现自己的机制——设备周期性地在 3 个专用信道上发送包含设备身份、服务类型等信息的广播包，就像在街上举着招牌告诉别人"我在这里，可以连接"。WQ7036AX 的广播 API 集中在 `wq_adv.h` 中，通过 `wq_adv_create_adv_handle`、`wq_adv_set_adv_data`、`wq_adv_set_enabled` 三步完成广播启动。

## 30秒先看懂

- 广播是 BLE 通信的第一步，目的是让手机"发现"你的设备，广播不正确则连接无法建立。
- 广播包最大 31 字节，由多个 AD Structure 拼接而成，每个 AD Structure 格式为[长度][类型][值]。
- 手机可以发送 Scan Request，设备回复 Scan Response 再额外提供 31 字节数据。
- 广播间隔决定功耗和发现速度的平衡：间隔越短发现越快但越耗电，反之则省电但发现慢。
- WQ7036AX 的 BLE 广播在 BCORE 固件中处理，ACORE 通过 RPC 调用 `wq_adv_*` API 控制广播。

## 学完以后应该能做什么

### 第一遍
- 在 WQ7036AX SDK 中找到 `wq_adv.h` 和 `ota_transport_ble.c` 中的广播相关代码
- 使用 `wq_adv_create_adv_handle`、`wq_adv_set_adv_data`、`wq_adv_set_enabled` 实现基础的广播启停
- 理解广播包的数据结构，能手动拼接 AD Structure

### 进阶
- 根据业务场景（正常模式 vs 配网模式）切换广播参数（间隔、地址类型、超时）
- 配置 Scan Response 数据，在广播中通告自定义厂商数据
- 排查广播相关的连接失败问题（广播间隔配置不当、广播数据超长、信道冲突）

## 前置知识

- [[ble-gatt-BLE-GATT]]：广播成功后建立连接，进入 GATT 数据交互阶段
- [[wq7036ax-chip-WQ7036AX芯片]]：了解 BLE 射频硬件和双模蓝牙架构
- [[rtos-freertos-RTOS原理与FreeRTOS]]：BLE 广播任务运行在哪个上下文

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 通用访问配置文件 | GAP (Generic Access Profile) | BLE 协议栈中负责设备发现、连接建立和安全的层 |
| 广播 | Advertising | 设备周期性地发送数据包宣告自身存在的机制 |
| 广播数据结构 | AD Structure (Advertising Data Structure) | 广播包中每个数据片段的格式：长度+类型+值 |
| 广播间隔 | Advertising Interval | 两次广播包之间的时间间隔，范围 20ms~10.24s |
| 扫描响应 | Scan Response | 手机发送扫描请求后，设备额外回复的 31 字节数据 |
| 广播句柄 | Advertising Handle | 标识一个广播集的编号，由 `wq_adv_create_adv_handle` 返回 |
| 公共地址 | Public Address | 芯片出厂时固定的蓝牙地址，不可更改 |
| 随机地址 | Random Address | 设备随机生成的蓝牙地址，用于保护隐私 |

## 第一层费曼心智模型

### 类比：街边举招牌

广播就像在商业街上举着招牌走路招揽顾客：

- **招牌内容（广播数据）**：写着店名、卖什么、有什么优惠——对应 Flags、设备名、Service UUID
- **举招牌的频率（广播间隔）**：每 100ms 举一次，还是每 1000ms 举一次——频率越高越累（耗电），但顾客容易注意到
- **主动上前问（Scan Request）**：顾客对招牌感兴趣，走过来问更多细节——设备回复 Scan Response
- **招牌上写什么**：不能写太多，31 字节的"广告位"有限，只能放最重要的信息

### 边界

- 广播包最大 31 字节，Scan Response 额外 31 字节，总计 62 字节。不能超。
- 广播间隔最小 20ms（BLE 规范限制），最大 10.24 秒。
- 广播只在 3 个专用信道（37/38/39）上发送，不是所有 40 个 BLE 信道。
- 广播不加密——任何人都可以收到广播包的内容，不要在广播数据中放敏感信息。

### 场景推演

**场景：reGlasses 第一次开机**

1. 眼镜上电，WQ7036AX 初始化 BLE 协议栈
2. ACORE 调用 `wq_adv_create_adv_handle()` 分配广播句柄
3. 设置广播数据：Flags（可发现+不支持经典蓝牙）+ 设备名 "reGlasses-XXXX" + Service UUID
4. 调用 `wq_adv_set_enabled(handle, true)` 开启广播
5. 手机扫描到广播包，显示"reGlasses-XXXX"设备
6. 用户点击连接，手机发起连接请求
7. 连接建立后，广播自动停止（或者继续广播以支持多设备连接）

## 第二层原理/时序/约束

### 广播信道与事件时序

BLE 在 2.4GHz ISM 频段使用 40 个信道（0-39），其中 37/38/39 号信道是广播信道：

```
信道 37 (2402 MHz)  ─── 广播事件 ───┐
信道 38 (2426 MHz)  ─── 广播事件 ───┤
信道 39 (2480 MHz)  ─── 广播事件 ───┘
                                     │
时间轴:  ┌──┬──┬──┬──┬──┬──┬──┬──┬──┐
         │37│38│39│37│38│39│37│38│39│ → 时间
         └──┴──┴──┴──┴──┴──┴──┴──┴──┘
         ←─── 广播间隔 ────→
```

每次广播事件在三个信道上依次发送相同的广播包，增加被接收的概率。

### 四种广播类型

| 类型 | 可连接 | 可扫描 | 说明 |
|------|--------|--------|------|
| ADV_IND | 是 | 是 | 通用广播，最常见 |
| ADV_DIRECT_IND | 是 | 否 | 定向广播，快速连接指定设备 |
| ADV_NONCONN_IND | 否 | 否 | 不可连接广播，仅用于广播数据 |
| ADV_SCAN_IND | 否 | 是 | 可扫描但不可连接 |

### 广播数据的约束

- 广播数据（Advertising Data）：31 字节上限
- 扫描响应数据（Scan Response Data）：31 字节上限
- 每个 AD Structure 必须包含长度字段（1 字节）+ 类型字段（1 字节）+ 数据字段
- Flags AD Structure（类型 0x01）是必须的，通常放在第一个

### WQ7036AX 的广播参数配置要点

`wq_adv.h` 中定义的关键参数：

```c
// 广播类型枚举
typedef enum {
    ADV_IND,                    // 通用可连接广播
    ADV_DIRECT_HIGH_DUTY_IND,   // 高速定向广播
    ADV_SCAN_IND,               // 可扫描广播
    ADV_NONCONN_IND,            // 不可连接广播
    ADV_DIRECT_LOW_DUTY_IND,    // 低速定向广播
} adv_type_t;

// 广播事件属性宏
#define ADV_PROPERTIE_CONN (1 << 0)     // 可连接
#define ADV_PROPERTIE_SCAN (1 << 1)     // 可扫描
#define ADV_PROPERTIE_LAGACY (1 << 4)   // 使用传统广播 PDU
```

## 第三层真实SDK代码

### 广播数据定义（`ota_transport_ble.c`）

SDK 的 OTA 模块中有一个完整的广播数据定义示例，位于 `/home/ys/wq7036a/wq-audio/wq-adk/components/apps/acore/ota/src/ota_transport_ble.c`：

```c
// 广播数据的结构体定义（packed 对齐，确保内存布局与空中包一致）
typedef struct {
    uint8_t flag_len;       // Flags AD 的长度
    uint8_t flag_type;      // Flags AD 的类型 (0x01)
    uint8_t flag;           // Flags 值 (0x1A = LE General Discoverable + BR/EDR Not)
    uint8_t vendor_len;     // 厂商数据 AD 的长度
    uint8_t vendor_type;    // 厂商数据 AD 的类型 (0xFF = Manufacturer Specific)
    uint8_t vid_low;        // Company ID 低字节
    uint8_t vid_high;       // Company ID 高字节
    uint8_t name_len;       // 设备名 AD 的长度
    uint8_t name_type;      // 设备名 AD 的类型 (0x09 = Complete Local Name)
    uint8_t name[6];        // 设备名字符串 "wq-ota"
} __attribute__((packed)) wq_adv_data_t;

// 广播数据实例化
static const wq_adv_data_t adv_data = {
    .flag_len = 0x02,
    .flag_type = 0x01,
    .flag = 0x1A,
    .vendor_len = 0x03,
    .vendor_type = 0xFF,
    .vid_low = OTA_VID & 0xFF,        // 0x076E 是物奇的公司 ID
    .vid_high = OTA_VID >> 8,
    .name_len = 0x07,
    .name_type = 0x09,
    .name = {'w', 'q', '-', 'o', 't', 'a'}
};
```

### 广播 API 函数原型（`wq_adv.h`）

广播 API 头文件位于 `/home/ys/wq7036a/wq-audio/wq-adk/components/bt_rpc/inc/acore/wq_adv.h`，核心函数：

```c
// 创建广播句柄，返回 0x00~0xEF 的句柄编号
uint8_t wq_adv_create_adv_handle(void);

// 设置广播数据
void wq_adv_set_adv_data(uint8_t handle, const uint8_t *data, uint8_t data_len);

// 设置扫描响应数据
void wq_adv_set_scan_response(uint8_t handle, const uint8_t *response, uint8_t reseponse_len);

// 设置广播间隔（单位：0.625ms）
// interval_min 和 interval_max 范围 0x0020~0x4000
void wq_adv_set_interval(uint8_t handle, uint16_t interval_min, uint16_t interval_max);

// 设置广播类型
void wq_adv_set_adv_type(uint8_t handle, adv_type_t adv_type);

// 设置广播发送功率，范围 -127~+20 dBm
// WQ703x 芯片只支持有限功率等级，例如设置 15dBm 实际可能只输出 11dBm
void wq_adv_set_adv_tx_pwr(uint8_t handle, int8_t tx_power);

// 启用/禁用广播
void wq_adv_set_enabled(uint8_t handle, bool enabled);

// 移除广播集
void wq_adv_remove_set(uint8_t handle);

// 清除所有广播集
void wq_adv_clear_sets(void);
```

### 广播启动的完整流程

参考 `ota_transport_ble.c` 中的实现，广播启动的标准流程是：

```c
// 1. 创建广播句柄
uint8_t adv_handle = wq_adv_create_adv_handle();

// 2. 设置广播数据（使用打包好的结构体）
wq_adv_set_adv_data(adv_handle, (const uint8_t *)&adv_data, sizeof(adv_data));

// 3. 设置广播参数
wq_adv_set_adv_type(adv_handle, ADV_IND);              // 通用可连接广播
wq_adv_set_interval(adv_handle, 160, 160);             // 100ms = 160 * 0.625ms

// 4. 设置发射功率
wq_adv_set_adv_tx_pwr(adv_handle, 7);                  // 7 dBm

// 5. 开启广播
wq_adv_set_enabled(adv_handle, true);
```

## 第四层正常/异常路径

### 正常路径

```
ACORE 调用 wq_adv_create_adv_handle()
  → 通过 RPC 通知 BCORE 分配广播资源
  → 返回 handle (0x00~0xEF)
  ↓
ACORE 调用 wq_adv_set_adv_data()
  → BCORE 将广播数据存入 Controller 内存
  ↓
ACORE 调用 wq_adv_set_enabled(handle, true)
  → BCORE 启动广播定时器
  → 在每个广播间隔，在 37/38/39 信道发送广播包
  ↓
手机扫描到广播包，发起连接请求
  → BCORE 收到连接请求
  → 通知 ACORE 连接建立
  → 广播自动停止（或继续广播）
```

### 异常路径

| 异常 | 原因 | 现象 | 解决方案 |
|------|------|------|---------|
| 广播创建失败 | BCORE 资源不足 | `wq_adv_create_adv_handle` 返回 0xFF | 检查 BLE 连接数是否已达上限 |
| 广播数据超长 | 超过 31 字节 | 广播数据被截断或设置失败 | 检查 AD Structure 总长度 |
| 广播开启失败 | BCORE 未就绪 | `wq_adv_set_enabled` 无效果 | 等待 BT 协议栈初始化完成后再开广播 |
| 广播间隔异常 | 参数越界 | 广播行为不符合预期 | 检查 interval 范围 0x0020~0x4000 |
| 广播被意外终止 | 连接建立或超时 | 设备不可被发现 | 在断开连接回调中重新开启广播 |

## 第五层调试方法

### 检查广播是否正常开启

```bash
# 使用 btmon 监听 BLE 广播
sudo btmon -w adv_capture.log

# 启动后观察日志中是否有 LE Advertising Report
# 查看广播数据是否正确
btmon -r adv_capture.log | grep -A 10 "Advertising Report"
```

### 使用 nRF Connect App 验证

1. 打开手机 nRF Connect App
2. 扫描设备，查看是否能发现 reGlasses
3. 点击设备查看广播数据内容（Flags、Name、Service UUID 等）
4. 检查 RSSI 信号强度（-30dBm 为极佳，-90dBm 为很差）

### WQ7036AX 日志调试

```c
// 在广播相关代码中添加日志
#define LOG_TAG "[adv] "
#include "app_log.h"

LOGI("Creating adv handle...");
uint8_t handle = wq_adv_create_adv_handle();
LOGI("Adv handle = %d", handle);

LOGI("Setting adv data (%d bytes)...", sizeof(adv_data));
wq_adv_set_adv_data(handle, (const uint8_t *)&adv_data, sizeof(adv_data));

LOGI("Starting advertising...");
wq_adv_set_enabled(handle, true);
LOGI("Advertising started");
```

## 第六层实战练习

### 练习1：实现广播参数切换

编写代码实现 reGlasses 在正常模式和配网模式下的广播参数切换：

```c
// 正常模式：100ms 间隔，Public Address，持续广播
// 配网模式：30ms 间隔，Random Address，120 秒超时
void switch_adv_mode(bool pairing_mode, uint8_t adv_handle) {
    if (pairing_mode) {
        // 配网模式：快速被发现
        wq_adv_set_interval(adv_handle, 48, 48);  // 30ms = 48 * 0.625ms
        uint8_t random_addr[6] = {0x01, 0x02, 0x03, 0x04, 0x05, 0x06};
        wq_adv_set_random_addr(adv_handle, random_addr);
        // 注意：需要 120 秒后自动停止广播
        // 提示：启动一个定时器，到时调用 wq_adv_set_enabled(adv_handle, false)
    } else {
        // 正常模式
        wq_adv_set_interval(adv_handle, 160, 160);  // 100ms
        wq_adv_set_local_addr_type(adv_handle, 0x00);  // Public Address
    }
}
```

### 练习2：阅读 SDK 源码查找广播生命周期

在 `/home/ys/wq7036a/wq-audio/wq-adk/components/apps/acore/ota/src/ota_transport_ble.c` 中搜索 `wq_adv_handle_ble_adv_set_terminated` 回调函数，分析：
- 广播在什么情况下被终止（reason 参数的值有哪些）
- 广播终止后 SDK 是否自动重新开启广播
- 连接建立后如何处理广播句柄

### 练习3：自定义广播数据

编写代码，在广播数据中增加厂商自定义数据段，包含产品 ID 和固件版本号：

```c
// 要求：广播数据包含以下 AD Structure
// 1. Flags (0x01) = 0x06 (LE General Discoverable + BR/EDR Not)
// 2. 完整设备名 (0x09) = "reGlasses"
// 3. 厂商数据 (0xFF) = Company ID (0x076E) + Product ID (0x7033) + Version (1.0.0)
// 提示：总长度不能超过 31 字节
uint8_t custom_adv_data[31] = {
    // 请补全...
};
```

## 自测与验收

1. BLE 广播包最大有多少字节？Scan Response 能额外提供多少字节？
2. 广播间隔对功耗和设备发现速度有什么影响？reGlasses 正常模式和配网模式的广播间隔各是多少？
3. WQ7036AX 中创建广播需要哪三个核心 API 调用？请按顺序写出。
4. BLE 广播在哪些信道上发送？为什么选这些信道？
5. 广播数据（Advertising Data）和扫描响应（Scan Response）有什么区别？什么场景下需要使用 Scan Response？

## 延伸阅读

- [[ble-gatt-BLE-GATT]] — 连接建立后的数据交互层
- [[ble-smp-BLE-SMP配对]] — 安全配对和链路加密
- [[ble-gatt-service-BLE-GATT-Service]] — 广播中通告的 Service UUID
- [[bt-debug-蓝牙调试]] — 蓝牙调试工具链
- [[wq7036ax-chip-WQ7036AX芯片]] — BLE 射频硬件
- `/home/ys/wq7036a/wq-audio/wq-adk/components/bt_rpc/inc/acore/wq_adv.h` — 广播 API 完整定义
- `/home/ys/wq7036a/wq-audio/wq-adk/components/apps/acore/ota/src/ota_transport_ble.c` — 广播使用示例

#flashcard
问：BLE 广播包最大多少字节？
答：广播数据 31 字节 + Scan Response 31 字节 = 总计 62 字节。

问：广播间隔短和长各有什么优缺点？
答：短间隔（如 30ms）→ 手机发现快但耗电多。长间隔（如 100ms）→ 省电但手机发现慢。

问：WQ7036AX 中创建广播需要哪三个核心 API 调用？
答：wq_adv_create_adv_handle() → wq_adv_set_adv_data() → wq_adv_set_enabled(handle, true)

问：BLE 广播在哪些信道上发送？
答：37 号（2402 MHz）、38 号（2426 MHz）、39 号（2480 MHz）信道，这三个信道避开了 WiFi 的 1/6/11 信道。

问：wq_adv.h 中定义的广播发射功率范围是多少？
答：-127 到 +20 dBm，但 WQ703x 芯片只支持有限功率等级（如 4/7/11dBm 三级）。