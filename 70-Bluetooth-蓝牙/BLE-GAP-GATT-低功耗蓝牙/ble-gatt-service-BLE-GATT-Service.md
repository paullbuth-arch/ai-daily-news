---
type: concept
created: 2026-07-17
tags: [protocol, ble, gatt, uuid, reglasses, service, characteristic]
aliases: [reGlasses GATT, 自定义 GATT Service]
---

# BLE GATT Service

## 一句话结论

GATT Service 是 BLE GATT 协议中用于组织功能相关 Characteristic 的容器，每个 Service 有唯一的 UUID 标识。reGlasses 定义了一个自定义 Primary Service（UUID: 454C4753-5245-474C-4153-534553000001），包含 7 个 Characteristic 分别承载控制指令、状态上报、音频流、IMU 数据、OTA 升级和配置参数。WQ7036AX 的 SDK 以 `ota_transport_ble.c` 中的 OTA Service 为参考模板，通过 `wq_gatts_register_service` 和 `wq_gatts_register_characteristic` 注册。

## 30秒先看懂

- reGlasses 自定义 Service 使用 128-bit UUID（454C4753-5245-474C-4153-534553000001），避免与标准 16-bit UUID 冲突。
- 7 个 Characteristic 覆盖了 reGlasses 的所有 BLE 通信需求：控制（Write）、状态（Notify）、音频（Notify）、IMU（Notify）、OTA（Write+Notify）、配置（Read/Write）。
- 音频流 Characteristic 传输 Opus 编码帧（16-32 kbps），IMU 数据 Characteristic 传输降采样后的 IMU 采样（100-250Hz）。
- 配置参数 Characteristic 支持双向读写，通过参数 ID 区分不同配置项（如广播间隔、连接间隔、WiFi 凭据）。
- SDK 参考实现位于 `ota_transport_ble.c`，已实现完整的 OTA Service（UUID=0x7033，RX+TX 两个 Characteristic）。

## 学完以后应该能做什么

### 第一遍
- 描述 reGlasses 的 7 个 Characteristic 各自的功能、属性、数据流向
- 在 SDK 中定位 `ota_transport_ble.c` 作为 GATT Service 注册的参考实现
- 根据业务需求选择合适的 Characteristic 属性（Read/Write/Notify）

### 进阶
- 设计新的自定义 GATT Service，定义 UUID 和 Characteristic 布局
- 配置 CCCD 回调，精确控制 Notify 的使能和禁用时机
- 在多连接场景下管理多个 Client 的 CCCD 状态

## 前置知识

- [[ble-gatt-BLE-GATT]]：GATT 协议基础，Service 和 Characteristic 的概念
- [[ble-gap-BLE-GAP广播]]：广播中通告 Service UUID 让手机识别设备类型
- [[wq7036ax-chip-WQ7036AX芯片]]：BLE 射频能力和带宽约束

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 主服务 | Primary Service | 设备的主要功能服务，区别于 Secondary Service（被其他 Service 引用） |
| 128-bit UUID | 128-bit UUID | 完整的 128 位 UUID，用于自定义 Service，避免与标准 16-bit UUID 冲突 |
| 16-bit UUID | 16-bit UUID | 蓝牙 SIG 标准的短 UUID，如 Battery Service = 0x180F |
| 属性 | Properties | Characteristic 的操作权限，如 Read/Write/Notify/Indicate 的组合 |
| 描述符 | Descriptor | Characteristic 的附加配置信息，CCCD 是最常见的描述符 |
| 厂商数据 | Manufacturer Specific Data | AD Type 0xFF，包含 Company ID 和自定义数据 |

## 第一层费曼心智模型

### 类比：超市的货架布局

reGlasses 的 GATT Service 就像超市的货架系统：

- **Service（服务）** = 整个超市（"reGlasses 超市"），有唯一的地址
- **Characteristic（特征）** = 每个货架，每个货架有编号（UUID）和功能：
  - C1（Device Control）：收银台——顾客（手机）在这里下达指令
  - C2（Device Status）：公告板——超市主动贴出通知（电量、温度）
  - C3（Audio Stream）：音响区——超市持续播放音乐
  - C4（IMU Data）：传感器区——实时显示超市的振动数据
  - C5/C6（OTA）：快递收发区——接收和反馈大包裹
  - C7（Config）：服务台——双向咨询和修改信息
- **CCCD** = 订阅通知——你告诉超市"有更新请通知我"

### 边界

- 一个 Service 最多包含 14 个 Characteristic（WQ7036AX 限制）。
- 128-bit UUID 的 Base 部分（前 96-bit）可自定义，但建议使用有意义的模式便于调试。
- Notify 类型的 Characteristic 必须有对应的 CCCD，否则手机无法使能通知。
- 每个 Characteristic 的最大数据长度受 MTU 限制（MTU - 3 字节，建议最大 244 字节）。

### 场景推演

**场景：APP 通过 Device Control 下发"开始录制"指令**

1. 手机向 C1（Device Control）写入指令数据（Write）
2. WQ7036AX 的 write_callback 被触发
3. ACORE 解析指令，识别为"开始录制"
4. 通过跨芯片通信转发给 V881 摄像头
5. V881 开始录制，返回结果
6. WQ7036AX 通过 C2（Device Status）Notify 上报"录制中"状态

## 第二层原理/时序/约束

### reGlasses 7 个 Characteristic 详解

| # | 名称 | UUID 后缀 | 属性 | 最大长度 | 数据流向 | 用途 |
|---|------|----------|------|----------|---------|------|
| C1 | Device Control | `...0002` | Write, Write Without Resp | 244B | 手机→眼镜 | 控制指令（录制/拍照/切镜头） |
| C2 | Device Status | `...0003` | Read, Notify | 64B | 眼镜→手机 | 状态上报（电量/温度/错误码） |
| C3 | Audio Stream | `...0004` | Notify | 244B | 眼镜→手机 | Opus 编码音频流 |
| C4 | IMU Data | `...0005` | Notify | 244B | 眼镜→手机 | IMU 采样数据流 |
| C5 | OTA Data RX | `...0006` | Write Without Resp | 244B | 手机→眼镜 | OTA 固件数据块 |
| C6 | OTA Data TX | `...0007` | Notify | 244B | 眼镜→手机 | OTA 进度/状态 |
| C7 | Config Params | `...0008` | Read, Write | 128B | 双向 | 配置参数读写 |

完整 UUID 模板：`454C4753-5245-474C-4153-53455300000X`

### C3 Audio Stream 数据格式

```c
// Opus 音频帧封装
// 编码格式：Opus (16kHz, 20ms 帧长)
// 码率范围：16-32 kbps（BLE 带宽自适应）
// 每包负载：~200 字节（244B MTU - 帧头开销）

typedef struct {
    uint8_t  frame_type;      // 帧类型（0x01 = Opus）
    uint8_t  sequence;        // 序列号（用于检测丢包）
    uint32_t timestamp_ms;    // 时间戳（毫秒）
    uint8_t  data[];          // Opus 编码数据
} __attribute__((packed)) audio_frame_t;
```

### C4 IMU Data 数据格式

```c
typedef struct {
    uint32_t timestamp_us;    // 微秒时间戳
    int16_t  accel_x;         // X 轴加速度 (0.001g)
    int16_t  accel_y;         // Y 轴加速度 (0.001g)
    int16_t  accel_z;         // Z 轴加速度 (0.001g)
    int16_t  gyro_x;          // X 轴角速度 (0.01 deg/s)
    int16_t  gyro_y;          // Y 轴角速度 (0.01 deg/s)
    int16_t  gyro_z;          // Z 轴角速度 (0.01 deg/s)
} __attribute__((packed)) imu_sample_t;  // 16 bytes/sample

// 每包最多 14 个采样 (14 * 16 + 2 = 226B < 244B)
// 原始采样率: 1000Hz (V881 IMU)
// BLE 上报率: 100-250Hz (降采样)
// 带宽占用: ~32 kbps
```

### C7 Config 参数 ID 表

| ID | 参数 | 类型 | 读写 | 说明 |
|----|------|------|------|------|
| 0x01 | BLE 广播间隔 | uint16_t (ms) | R/W | 100-1000ms |
| 0x02 | BLE 连接间隔 | uint16_t (ms) | R/W | 7.5-400ms |
| 0x10 | 音频编码格式 | uint8_t | R/W | 0=Opus, 1=PCM |
| 0x11 | 采样率 | uint32_t | R/W | 16000/32000/48000 |
| 0x20 | IMU 上报频率 | uint16_t (Hz) | R/W | 50-250Hz |
| 0x30 | 设备名 | string (max 20) | R/W | 蓝牙广播名称 |
| 0x40 | WiFi SSID | string | R/W | 配网用 |
| 0x41 | WiFi 密码 | string | R/W | 配网用 |
| 0x50 | 固件版本 | string (max 16) | R/O | 只读 |

### 数据流向总图

```
手机 APP ──Write──→ C1 (Device Control) ──→ WQ7036AX 解析执行
                                                   ↓
                                            ┌──────┴──────┐
                                            │ 本地执行      │ 转发 V881
                                            │ (音频/LED)   │ (录制/拍照)
                                            └──────┬──────┘
                                                   ↓
手机 APP ←─Notify── C2 (Device Status) ←── 执行结果
手机 APP ←─Notify── C3 (Audio Stream) ←── Opus 帧
手机 APP ←─Notify── C4 (IMU Data) ←────── IMU 采样
手机 APP ──Write──→ C5 (OTA RX) ─────────→ OTA 数据块
手机 APP ←─Notify── C6 (OTA TX) ←───────── OTA 进度
手机 APP ──Write──→ C7 (Config) ──────────→ 参数写入
手机 APP ←─Read──── C7 (Config) ←───────── 参数读取
```

## 第三层真实SDK代码

### SDK 参考实现：OTA Service

位于 `/home/ys/wq7036a/wq-audio/wq-adk/components/apps/acore/ota/src/ota_transport_ble.c`：

```c
// OTA Service 的 UUID 定义
#define OTA_UUID_SERVICE 0x7033           // 16-bit UUID
#define OTA_UUID_CHARACTER_RX 0x2001      // RX: 手机写 OTA 数据
#define OTA_UUID_CHARACTER_TX 0x2002      // TX: 设备通知 OTA 进度

// 全局保存 Characteristic 指针
static const gatts_characteristic_t *character_rx = NULL;
static const gatts_characteristic_t *character_tx = NULL;

// GATT Service 初始化
static void ble_init(void)
{
    // 注册连接状态回调
    wq_gatt_register_connection_callback(gatt_connection_callback);

    // 定义 Service
    gatts_service_t service_param = {0};
    service_param.uuid.uuid_type = UUID_TYPE_16;
    service_param.uuid.uuid_union.uuid_16 = OTA_UUID_SERVICE;
    service_param.handle = 0xFFFF;  // 自动分配 handle

    // 注册 Service
    gatts_service_t *service = wq_gatts_register_service(service_param);

    // 注册 RX Characteristic（Write Without Response）
    gatts_characteristic_t char_rx_param = {0};
    char_rx_param.uuid.uuid_union.uuid_16 = OTA_UUID_CHARACTER_RX;
    char_rx_param.props = GATT_PROP_WRITE_WITHOUT_RSP;
    char_rx_param.write_callback = write_callback;
    character_rx = wq_gatts_register_characteristic(service, char_rx_param);

    // 注册 TX Characteristic（Notify）
    gatts_characteristic_t char_tx_param = {0};
    char_tx_param.uuid.uuid_union.uuid_16 = OTA_UUID_CHARACTER_TX;
    char_tx_param.props = GATT_PROP_NOTIFY;
    character_tx = wq_gatts_register_characteristic(service, char_tx_param);
}
```

### GATT 注册 API 原型

位于 `/home/ys/wq7036a/wq-audio/wq-adk/components/bt_rpc/inc/acore/wq_gatts.h`：

```c
// 初始化 GATT Server
void wq_gatts_init(void);

// 注册 Service，返回 Service 指针
gatts_service_t *wq_gatts_register_service(gatts_service_t param);

// 注册 Characteristic，返回 Characteristic 指针
gatts_characteristic_t *
wq_gatts_register_characteristic(gatts_service_t *service,
                                 gatts_characteristic_t characteristic_param);

// 发送 Notify
bool wq_gatts_send_notify(const BD_ADDR_T *addr,
                          const gatts_characteristic_t *characteristic,
                          const uint8_t *data, uint16_t len);

// 注册发送完成回调
WQ_RET wq_gatts_register_send_complete_callback(wq_gatts_send_complete_callback_t cbk);

// 注册回调类型定义
typedef void (*wq_gatts_register_done_callback_t)(void);
typedef void (*wq_gatts_send_complete_callback_t)(const BD_ADDR_T *addr, bool success);
```

## 第四层正常/异常路径

### 正常路径

```
ACORE 启动 → wq_gatts_init()
  → 注册 Service（UUID 和 Handle）
  → 注册 Characteristic（UUID 和属性）
  → 注册连接回调和写回调
  ↓
手机连接 → 发现 Service → 发现 Characteristic
  → 手机写入 CCCD 使能 Notify
  → 正常通信
```

### 异常路径

| 异常 | 现象 | 原因 | 解决方案 |
|------|------|------|---------|
| Service 注册冲突 | 注册失败 | 多个模块注册了相同的 Service UUID | 确保 UUID 全局唯一 |
| Characteristic 注册冲突 | 注册失败 | 同一个 Service 内 UUID 重复 | Characteristic UUID 不能重复 |
| 写回调未触发 | 手机写成功但设备无响应 | write_callback 未注册或为 NULL | 注册时检查 write_callback 参数 |
| Notify 发送失败 | 手机收不到数据 | 手机未写入 CCCD 或连接已断开 | 检查 CCCD 状态和连接状态 |
| 128-bit UUID 配置错误 | 手机无法发现 Service | UUID 高低字节顺序错误 | 检查字节序（Little Endian） |

## 第五层调试方法

### 使用 nRF Connect 验证 Service

1. 打开手机 nRF Connect App
2. 连接到设备
3. 查看 Service 列表，确认自定义 Service UUID 是否正确显示
4. 查看每个 Characteristic 的 UUID、属性和支持的操作
5. 测试 Write 操作，观察设备是否响应
6. 使能 CCCD，测试 Notify 是否正常推送

### 日志调试

```c
// 在注册和回调中加入日志
#define LOG_TAG "[gatt_svc] "
#include "app_log.h"

// 注册日志
LOGI("Registering Service: UUID=0x%04X", service_param.uuid.uuid_union.uuid_16);
gatts_service_t *svc = wq_gatts_register_service(service_param);
LOGI("Service registered: handle=%d", svc->handle);

// 写回调日志
static WQ_ROT write_callback(uint16_t conn_handle, uint16_t char_handle,
                              const uint8_t *data, uint16_t len)
{
    LOGI("Write: char=0x%04X, len=%d", char_handle, len);
    LOG_BUFFER("Data:", data, len > 16 ? 16 : len);
    return WQ_RET_OK;
}
```

### Wireshark 过滤

```
# 找特定 UUID 的 Service
btatt.uuid16 == 0x7033

# 找指定 Characteristic 的操作
btatt.handle == 0x0012

# 查看 CCCD 写入
btatt.opcode == 0x12 && btatt.handle == <cccd_handle>
```

## 第六层实战练习

### 练习1：设计并注册 C7 Config Params Characteristic

参照 `ota_transport_ble.c` 的 `ble_init()`，编写代码注册 C7 Config Params Characteristic（支持 Read 和 Write）：

```c
// UUID 后缀: ...0008
// 属性: Read + Write
// 最大长度: 128 字节
// 提示：需要同时注册 read_callback 和 write_callback
// 请补全
void register_config_characteristic(gatts_service_t *service) {
    gatts_characteristic_t config_param = {0};
    // 设置 UUID
    // 设置属性
    // 注册回调
    // 注册 Characteristic
}
```

### 练习2：阅读 SDK 源码分析 CCCD 处理

在 `/home/ys/wq7036a/wq-audio/wq-adk/components/apps/acore/ota/src/ota_transport_ble.c` 中查找 CCCD 相关代码，分析：
- Notify Characteristic 的 CCCD 是由 SDK 自动管理的，还是需要应用层手动处理？
- 连接断开后重新连接时，CCCD 值是否保留？
- 如果 CCCD 值丢失，应用层需要做什么？

### 练习3：实现多 Characteristic 数据路由

编写代码，在 write_callback 中根据 Characteristic 的 UUID 路由到不同的处理函数：

```c
// 判断写请求来自哪个 Characteristic，并路由到对应的处理函数
static WQ_RET reglasses_write_callback(uint16_t conn_handle, uint16_t char_handle,
                                        const uint8_t *data, uint16_t len)
{
    // 根据 char_handle 判断是哪个 Characteristic
    // 如果是 Device Control (C1)：调用 handle_device_control(data, len)
    // 如果是 OTA RX (C5)：调用 handle_ota_data(data, len)
    // 如果是 Config Params (C7)：调用 handle_config_write(data, len)
    // 请补全
}
```

## 自测与验收

1. reGlasses 自定义了几个 GATT Characteristic？请列出每个的名称、UUID 后缀、属性。
2. 128-bit UUID 和 16-bit UUID 有什么区别？reGlasses 为什么使用 128-bit UUID？
3. C3 Audio Stream 的每包数据最大能放多少字节？为什么？
4. C7 Config Params 中有哪些配置参数？固件版本是只读还是可写？
5. 如果手机连接后发现不了自定义 Service，可能的原因有哪些？

## 延伸阅读

- [[ble-gatt-BLE-GATT]] — GATT 协议基础
- [[ble-gap-BLE-GAP广播]] — 广播中通告 Service UUID
- [[wq-audio-protocol-WQ-Audio-Protocol]] — C3 Audio Stream 的帧封装
- [[reglasses-ext-commands-reGlasses扩展命令集]] — C1 Device Control 的命令定义
- `/home/ys/wq7036a/wq-audio/wq-adk/components/apps/acore/ota/src/ota_transport_ble.c` — GATT Service 注册参考实现
- `/home/ys/wq7036a/wq-audio/wq-adk/components/bt_rpc/inc/acore/wq_gatts.h` — GATT Server API 完整定义

#flashcard
问：reGlasses 自定义了几个 GATT Characteristic？
答：7 个：Device Control (Write)、Device Status (Notify)、Audio Stream (Notify)、IMU Data (Notify)、OTA RX (Write)、OTA TX (Notify)、Config Params (Read/Write)

问：C4 IMU Data 每包最多能放多少个采样？
答：14 个。每个采样 16 字节，14x16+2(包头)=226B < 244B (MTU-3)

问：reGlasses 使用什么类型的 UUID？为什么？
答：128-bit UUID（454C4753-5245-474C-4153-534553000001），避免与标准 16-bit UUID 冲突，同时支持自定义标识。

问：C7 Config Params 中固件版本对应的参数 ID 是什么？是可读还是可写？
答：ID=0x50，只读（R/O），版本信息由设备固件提供，不可修改。

问：手机连接后发现不了自定义 Service，最可能的原因是什么？
答：Service 注册失败（UUID 冲突、注册时序不对）、或 128-bit UUID 字节序错误。