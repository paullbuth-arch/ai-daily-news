---
type: concept
created: 2026-07-17
tags: [protocol, ble, gatt, service, characteristic, 蓝牙, 属性, wq7036ax]
aliases: [GATT, BLE GATT, Generic Attribute Profile]
---

# BLE GATT

## 一句话结论

GATT（Generic Attribute Profile，通用属性配置文件）定义了 BLE 连接建立后 Client 和 Server 之间如何通过 Attribute（属性）进行数据交互——Server 上注册 Service 和 Characteristic，Client 通过 Read/Write/Notify 三种方式读写这些属性。WQ7036AX 的 GATT Server API 在 `wq_gatts.h` 中，通过 `wq_gatts_register_service` 和 `wq_gatts_register_characteristic` 注册服务，通过 `wq_gatts_send_notify` 主动推送数据给手机。

## 30秒先看懂

- GATT 是 BLE 连接建立后唯一的数据通道，所有控制指令、状态上报、音频流、OTA 数据都通过 GATT 传输。
- GATT 的层级结构是 Profile → Service → Characteristic，一个 Service 包含多个 Characteristic，每个 Characteristic 有独立的 UUID 和属性（Read/Write/Notify）。
- MTU（Maximum Transmission Unit）决定每个 BLE 包能装多少数据，默认 23 字节，协商后可到 247 字节。
- 手机要收到 Notify 必须先写入 CCCD（Client Characteristic Configuration Descriptor）使能通知，类似于订阅公众号。
- WQ7036AX 的 GATT Server 通过 RPC 在 BCORE 上注册，ACORE 通过 `wq_gatts_*` API 操作。

## 学完以后应该能做什么

### 第一遍
- 在 WQ7036AX SDK 中找到 `wq_gatts.h` 和 `ota_transport_ble.c` 中的 GATT 注册代码
- 使用 `wq_gatts_register_service` 和 `wq_gatts_register_characteristic` 注册自定义 GATT Service
- 理解 Read/Write/Notify 三种交互方式的区别和适用场景

### 进阶
- 配置 MTU 协商参数，优化大包数据传输效率
- 实现 CCCD 回调处理，控制 Notify 的使能和禁用
- 排查 GATT 通信失败问题（Handle 错误、权限不足、MTU 协商失败）

## 前置知识

- [[ble-gap-BLE-GAP广播]]：GATT 通信的前提是已经通过 GAP 广播建立了 BLE 连接
- [[wq7036ax-chip-WQ7036AX芯片]]：了解 BLE 双模架构，ACORE 和 BCORE 的分工
- [[rtos-freertos-RTOS原理与FreeRTOS]]：GATT 回调函数的任务上下文

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 通用属性配置文件 | GATT (Generic Attribute Profile) | 定义 BLE 设备间如何通过属性进行数据交互的规范 |
| 服务 | Service | 一组功能相关的 Characteristic 的集合，有唯一 UUID |
| 特征 | Characteristic | 一个具体的数据通道，有 UUID、属性和值 |
| 属性 | Attribute | GATT 中最基本的数据单元，包含 Handle、UUID、权限和值 |
| 通用唯一标识符 | UUID (Universally Unique Identifier) | 128-bit 或 16-bit 标识符，用于唯一标识 Service 和 Characteristic |
| 句柄 | Handle | 连接建立后系统为 Attribute 分配的 16-bit 编号 |
| 最大传输单元 | MTU (Maximum Transmission Unit) | 单个 BLE 包能传输的最大数据量 |
| 客户端特征配置描述符 | CCCD (Client Characteristic Configuration Descriptor) | 控制 Notify/Indicate 使能的开关描述符 |
| 通知 | Notify | Server 主动推送数据给 Client，不需要确认 |
| 指示 | Indicate | Server 主动推送数据给 Client，需要 Client 确认 |

## 第一层费曼心智模型

### 类比：自动售货机

GATT 就像一台自动售货机：

- **Service（服务）** = 这台售货机本身，有唯一的地址（UUID）
- **Characteristic（特征）** = 售货机上的每个货道，每个货道有编号（UUID）、卖不同的东西
- **Read（读）** = 你看一下货道上的价格标签，获取信息但不改变任何东西
- **Write（写）** = 你投币并按按钮，把指令发给售货机
- **Notify（通知）** = 售货机自动把饮料推出来给你，售货机主动发东西给你
- **CCCD** = 你要先关注这个货道的公众号，之后它才会主动推送消息给你
- **MTU** = 每次出货的传送带大小，越大一次能装的货物越多

### 边界

- GATT 只在 BLE 连接建立后才工作，不能用于广播阶段。
- 一个 Service 可以包含多个 Characteristic，但 WQ7036AX 限制最多 14 个 Characteristic。
- Notify 不保证送达——如果手机没收到不会重发。要保证送达需要用 Indicate（需要确认）。
- CCCD 存在于每个支持 Notify/Indicate 的 Characteristic 中，手机断开重连后需要重新写入 CCCD。

### 场景推演

**场景：手机 APP 读取眼镜电量**

1. 手机通过 BLE 连接到眼镜，GATT 连接建立
2. 手机读取 Device Status Characteristic（UUID 后缀 ...0003）
3. WQ7036AX 的 GATT Server 收到 Read 请求
4. ACORE 的 read_callback 被调用，返回当前电量值（如 85%）
5. 手机收到电量值，显示在 APP 界面

**场景：眼镜主动上报状态**

1. 手机已连接，且已写入 CCCD 使能了 Device Status 的 Notify
2. 眼镜检测到电量变化（从 85% 降到 80%）
3. ACORE 调用 `wq_gatts_send_notify()` 推送新电量值
4. 手机收到 Notify，更新 APP 界面

## 第二层原理/时序/约束

### GATT 层级结构

```
Profile (应用规范，如"智能眼镜")
 └── Service (服务，UUID: 454C4753-5245-474C-4153-534553000001)
      │   Type: Primary Service
      │
      ├── Characteristic: Device Control
      │     UUID: ...0002
      │     Properties: Write
      │     Value: [控制指令数据]
      │
      ├── Characteristic: Device Status
      │     UUID: ...0003
      │     Properties: Read + Notify
      │     Value: [状态数据]
      │     └── Descriptor: CCCD
      │           UUID: 0x2902
      │           Value: 0x0000 (禁用) / 0x0001 (使能Notify)
      │
      └── Characteristic: Audio Stream
            UUID: ...0004
            Properties: Notify
            Value: [音频数据]
            └── Descriptor: CCCD
                  UUID: 0x2902
```

### MTU 协商时序

```
手机 (Client)                     WQ7036AX (Server)
    │                                    │
    │── MTU Exchange Request (MTU=512) →│  ① 手机发起 MTU 协商
    │                                    │
    │←── MTU Exchange Response (MTU=247)─│  ② 回复支持的 MTU 值
    │                                    │
    │   [之后 MTU = min(512, 247) = 247] │  ③ 取双方较低值
    │   [Payload = 247 - 3 = 244 字节]   │  ④ 扣除 ATT 头部
```

### 三种数据交互方式对比

| 方式 | 方向 | 是否需要 CCCD | 是否保证送达 | 典型延迟 | 适用场景 |
|------|------|-------------|------------|---------|---------|
| Read | Client→Server | 否 | 是（有响应） | ~10ms | 读配置、读版本号 |
| Write | Client→Server | 否 | 是（有响应） | ~10ms | 下发控制指令 |
| Write Without Response | Client→Server | 否 | 否 | ~5ms | OTA 数据块（高吞吐） |
| Notify | Server→Client | 是 | 否 | ~5ms | 状态上报、音频流 |
| Indicate | Server→Client | 是 | 是（有确认） | ~15ms | 关键事件上报 |

### WQ7036AX 的 GATT 约束

```c
// wq_bt_gatt_api.h 中定义的 GATT Server 限制
#define WQ_GATT_MAX_SERVICES             1         // 最多 1 个 Service
#define WQ_GATT_MAX_CHARACTERISTICS      14        // 最多 14 个 Characteristic
#define WQ_GATT_MAX_CHAR_DESCRIPTORS     1         // 每个 Characteristic 最多 1 个 Descriptor
```

## 第三层真实SDK代码

### GATT Service 注册（`ota_transport_ble.c`）

位于 `/home/ys/wq7036a/wq-audio/wq-adk/components/apps/acore/ota/src/ota_transport_ble.c`：

```c
// Service UUID 定义
#ifndef OTA_UUID_SERVICE
#define OTA_UUID_SERVICE 0x7033           // 16-bit UUID
#endif
#ifndef OTA_UUID_CHARACTER_RX
#define OTA_UUID_CHARACTER_RX 0x2001      // RX Characteristic UUID
#endif
#ifndef OTA_UUID_CHARACTER_TX
#define OTA_UUID_CHARACTER_TX 0x2002      // TX Characteristic UUID
#endif

// 静态保存 Characteristic 指针，供后续发送数据使用
static const gatts_characteristic_t *character_rx = NULL;
static const gatts_characteristic_t *character_tx = NULL;

static void ble_init(void)
{
    // 1. 注册连接回调
    wq_gatt_register_connection_callback(gatt_connection_callback);

    // 2. 定义 Service 参数
    gatts_service_t service_param = {0};
    service_param.uuid.uuid_type = UUID_TYPE_16;
    service_param.uuid.uuid_union.uuid_16 = OTA_UUID_SERVICE;
    service_param.handle = 0xFFFF;  // 让 SDK 自动分配 handle

    // 3. 注册 Service
    gatts_service_t *service = wq_gatts_register_service(service_param);

    // 4. 注册 RX Characteristic（手机→设备）
    gatts_characteristic_t char_rx_param = {0};
    char_rx_param.uuid.uuid_union.uuid_16 = OTA_UUID_CHARACTER_RX;
    char_rx_param.props = GATT_PROP_WRITE_WITHOUT_RSP;
    char_rx_param.write_callback = write_callback;
    character_rx = wq_gatts_register_characteristic(service, char_rx_param);

    // 5. 注册 TX Characteristic（设备→手机）
    gatts_characteristic_t char_tx_param = {0};
    char_tx_param.uuid.uuid_union.uuid_16 = OTA_UUID_CHARACTER_TX;
    char_tx_param.props = GATT_PROP_NOTIFY;
    character_tx = wq_gatts_register_characteristic(service, char_tx_param);
}
```

### GATT Notify 发送 API（`wq_gatts.h`）

位于 `/home/ys/wq7036a/wq-audio/wq-adk/components/bt_rpc/inc/acore/wq_gatts.h`：

```c
// 发送 Notify：设备主动推送数据给手机
// 返回 true 表示发送成功（但不保证手机收到）
bool wq_gatts_send_notify(
    const BD_ADDR_T *addr,                    // 目标设备蓝牙地址
    const gatts_characteristic_t *characteristic,  // 目标 Characteristic
    const uint8_t *data,                      // 数据内容
    uint16_t len                              // 数据长度
);

// 发送 Indicate：设备主动推送数据给手机（需要确认）
bool wq_gatts_send_indicate(
    const BD_ADDR_T *addr,
    const gatts_characteristic_t *characteristic,
    const uint8_t *data,
    uint16_t len
);

// 注册 GATT 相关回调
typedef void (*wq_gatts_register_done_callback_t)(void);
typedef void (*wq_gatts_send_complete_callback_t)(const BD_ADDR_T *addr, bool success);

WQ_RET wq_gatts_register_send_complete_callback(wq_gatts_send_complete_callback_t cbk);
```

### 底层 GATT API（`wq_bt_gatt_api.h`）

位于 `/home/ys/wq7036a/wq-audio/wqcore/components/bluetooth/host/bbb/inc/wq_bt_gatt_api.h`，定义了底层 GATT 协议的结构体：

```c
// Service 信息结构体
typedef struct wq_gatt_service_param {
    WQ_ATT_UUID uuid;          // Service UUID
    uint8_t uuid_type;         // UUID 类型（16-bit 或 128-bit）
    WQ_ATT_HANDLE_RANGE range; // Service 的 Handle 范围
} WQ_GATT_SERVICE_PARAM;

// Characteristic 信息结构体
typedef struct wq_gatt_characteristic_param {
    WQ_ATT_ATTR_HANDLE handle;       // 声明 Handle
    WQ_ATT_UUID uuid;                // Characteristic UUID
    uint8_t uuid_type;               // UUID 类型
    uint8_t properties;              // 属性（Read/Write/Notify/Indicate）
    WQ_ATT_ATTR_HANDLE value_handle; // 值 Handle
} WQ_GATT_CHARACTERISTIC_PARAM;

// GATT 操作标识
#define WQ_GATT_EXCHANGE_MTU        0x0200  // MTU 交换操作
#define WQ_GATT_CHAR_READ           0x0020  // 读操作
#define WQ_GATT_CHAR_WRITE          0x0080  // 写操作

// Handle Value 操作类型
#define WQ_GATT_HV_NTF          0x01  // Notify
#define WQ_GATT_HV_IND          0x02  // Indicate
```

## 第四层正常/异常路径

### 正常路径

```
手机连接 → 发现 Service → 发现 Characteristic
  → 手机写入 CCCD = 0x0001（使能 Notify）
  → 手机读写 Characteristic 数据
  ↓
设备调用 wq_gatts_send_notify() 推送数据
  → BCORE 通过 RPC 收到通知请求
  → Controller 在下一个连接事件中发送通知包
  → 手机收到数据
```

### 异常路径

| 异常 | 现象 | 原因 | 排查方法 |
|------|------|------|---------|
| GATT Write 无响应 | 手机写成功但设备无反应 | Characteristic 的 write_callback 未注册 | 检查注册时是否传递了 write_callback |
| Notify 发不出 | 设备调用 send_notify 但手机收不到 | 手机未写入 CCCD | 检查手机端是否使能了通知 |
| MTU 协商失败 | 大包数据被截断 | 手机不支持大的 MTU | 检查 MTU 协商回调的值 |
| Handle 错误 | ATT Error Response 0x0A | 使用错误的 Handle 访问 | 检查注册时返回的 Handle 值 |
| 权限不足 | ATT Error Response 0x05 | 加密/授权检查不通过 | 检查 Characteristic 的权限设置 |

## 第五层调试方法

### 使用 HCI Log 分析 GATT 通信

```bash
# 抓取 HCI 日志
sudo btmon -w gatt_trace.log
# 执行操作后查看 GATT 交互
btmon -r gatt_trace.log | grep -E "ATT|GATT"
```

### Wireshark 过滤语法

```
# 只看 GATT 写操作
btatt.opcode == 0x12  # Write Request
btatt.opcode == 0x52  # Write Command

# 只看 ATT 错误
btatt.opcode == 0x01  # Error Response

# 只看 Notify
btatt.opcode == 0x1B  # Handle Value Notification
```

### WQ7036AX 日志

```c
// 在 Write 回调中添加日志
static WQ_RET write_callback(uint16_t conn_handle, uint16_t char_handle,
                              const uint8_t *data, uint16_t len)
{
    LOGI("[GATT] Write received: conn=0x%04X, char=0x%04X, len=%d",
         conn_handle, char_handle, len);
    LOG_BUFFER("[GATT] Data:", data, len);
    // 处理数据...
    return WQ_RET_OK;
}
```

### 常见 ATT 错误码

| 错误码 | 含义 | 说明 |
|--------|------|------|
| 0x01 | Invalid Handle | Handle 超出范围 |
| 0x02 | Read Not Permitted | 该 Characteristic 不允许读 |
| 0x03 | Write Not Permitted | 该 Characteristic 不允许写 |
| 0x05 | Insufficient Authentication | 需要配对/加密才能访问 |
| 0x0A | Attribute Not Found | 找不到对应的 Attribute |

## 第六层实战练习

### 练习1：实现自定义 GATT Service

参照 `ota_transport_ble.c` 中的 `ble_init()` 函数，编写代码注册一个 reGlasses 自定义 Service，包含 Device Control（Write）和 Device Status（Notify）两个 Characteristic：

```c
// Service UUID (128-bit): 454C4753-5245-474C-4153-534553000001
// Device Control UUID: ...0002 (Write, 最大长度 244)
// Device Status UUID: ...0003 (Notify, 最大长度 64)
// 请补全代码
void reglasses_gatt_init(void) {
    // 1. 注册连接回调

    // 2. 定义 Service

    // 3. 注册 Service

    // 4. 注册 Device Control Characteristic

    // 5. 注册 Device Status Characteristic
}
```

### 练习2：阅读 SDK 源码分析 GATT 回调机制

在 `/home/ys/wq7036a/wq-audio/wq-adk/components/apps/acore/ota/src/ota_transport_ble.c` 中查找 `gatt_connection_callback` 函数，分析：
- 连接回调的参数有哪些（连接状态、连接句柄、地址等）
- 连接建立后 SDK 做了什么（是否重新开启广播？是否开启 MTU 协商？）
- 断开连接后 SDK 如何处理（是否清理资源？是否重新进入可发现模式？）

### 练习3：实现 Notify 状态上报

编写代码，在电池电量变化时通过 GATT Notify 上报给手机：

```c
// 假设已经注册了 Device Status Characteristic，存储在 device_status_char 中
// 手机蓝牙地址存储在 remote_addr 中
// 要求：组装状态数据包，调用 wq_gatts_send_notify 发送

typedef struct {
    uint8_t battery_level;   // 0-100
    uint8_t temperature;     // 摄氏度
    uint8_t status_flags;    // 位标志
} __attribute__((packed)) device_status_t;

void report_device_status(void) {
    device_status_t status = {
        .battery_level = 85,
        .temperature = 36,
        .status_flags = 0x01,
    };
    // 请补全：调用 wq_gatts_send_notify 发送状态数据
}
```

## 自测与验收

1. GATT 的层级结构是什么？Service 和 Characteristic 是什么关系？
2. BLE MTU 的默认值是多少？协商后建议值是多少？有效 Payload 如何计算？
3. Notify 和 Indicate 有什么区别？什么场景下应该用 Indicate？
4. 手机要收到 GATT Notify 需要先做什么操作？为什么？
5. WQ7036AX 的 GATT Server 最多支持多少个 Characteristic？这个限制在哪里定义的？

## 延伸阅读

- [[ble-gap-BLE-GAP广播]] — 连接建立前：广播让手机发现你
- [[ble-gatt-service-BLE-GATT-Service]] — reGlasses 自定义的 7 个 Characteristic 详解
- [[ble-smp-BLE-SMP配对]] — 安全配对和链路加密
- [[bt-debug-蓝牙调试]] — 蓝牙调试工具链
- `/home/ys/wq7036a/wq-audio/wq-adk/components/bt_rpc/inc/acore/wq_gatts.h` — GATT Server API 完整定义
- `/home/ys/wq7036a/wq-audio/wqcore/components/bluetooth/host/bbb/inc/wq_bt_gatt_api.h` — 底层 GATT 协议定义
- `/home/ys/wq7036a/wq-audio/wq-adk/components/apps/acore/ota/src/ota_transport_ble.c` — GATT 使用示例

#flashcard
问：GATT 中 Service 和 Characteristic 是什么关系？
答：一对多。一个 Service（店铺）包含多个 Characteristic（柜台）。每个 Characteristic 有独立的 UUID 和属性（Read/Write/Notify）。

问：BLE MTU 默认值是多少？协商建议值是多少？
答：默认 23 字节（有效 payload 20B），建议协商到 247 字节（有效 payload 244B）。

问：手机要收到 GATT Notify 需要先做什么？
答：写入 CCCD（Client Characteristic Configuration Descriptor）= 0x0001，相当于"订阅"这个 Characteristic 的推送。

问：WQ7036AX 的 GATT Server 最多支持多少个 Characteristic？
答：最多 14 个，定义在 wq_bt_gatt_api.h 的 WQ_GATT_MAX_CHARACTERISTICS 宏中。

问：Notify 和 Indicate 的核心区别是什么？
答：Notify 不需要确认，不保证送达；Indicate 需要 Client 确认，保证送达但延迟更高。