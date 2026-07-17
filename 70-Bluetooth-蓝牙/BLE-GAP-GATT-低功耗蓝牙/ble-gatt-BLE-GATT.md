---
type: concept
created: 2026-07-16
tags: [protocol, ble, gatt, service, characteristic, 蓝牙, 属性]
aliases: [GATT, BLE GATT, Generic Attribute Profile]
---

# BLE GATT

## 一句话理解

GATT (Generic Attribute Profile，通用属性配置文件) 就像**自动售货机**：BLE 连接建立后，手机看到的是一个个"货道" (Characteristic，特征)，每个货道有编号 (UUID)、能投币取货 (Read/Write)、或者售货机主动推货出来 (Notify)。

## 为什么重要

GATT 是 WQ7036AX 和手机 APP 之间**唯一的数据通道**。手机下发的每一个指令（开始录制、拍照、切镜头），眼镜上报的每一个状态（电量、温度），音频流、IMU 数据流——**全部通过 GATT 传输**。

## 第一步：在 Source Insight 中找到 GATT 注册代码

1. **`Ctrl+Comma`** 搜索 `ble_init` → 跳到 `ota_transport_ble.c`
2. 这是 SDK 里**已有的** GATT Service 注册示例（OTA 升级用的），我们要仿照它来写 reGlasses 自己的 Service

```c
static void ble_init(void)
{
    // ① 注册连接回调
    wq_gatt_register_connection_callback(gatt_connection_callback);

    // ② 定义 Service (服务)
    gatts_service_t service_param = {0};
    service_param.uuid.uuid_type = UUID_TYPE_16;
    service_param.uuid.uuid_union.uuid_16 = OTA_UUID_SERVICE; // 0x7033
    service_param.handle = 0xFFFF;  // 让 SDK 自动分配 handle
    gatts_service_t *service = wq_gatts_register_service(service_param);

    // ③ 定义 Characteristic (特征) —— RX (接收手机数据)
    gatts_characteristic_t char_rx_param = {0};
    char_rx_param.uuid.uuid_union.uuid_16 = OTA_UUID_CHARACTER_RX; // 0x2001
    char_rx_param.props = GATT_PROP_WRITE_WITHOUT_RSP;  // 手机写，不需要回复
    char_rx_param.write_callback = write_callback;       // 收到数据时的回调
    character_rx = wq_gatts_register_characteristic(service, char_rx_param);

    // ④ 定义 Characteristic —— TX (推送数据给手机)
    gatts_characteristic_t char_tx_param = {0};
    char_tx_param.uuid.uuid_union.uuid_16 = OTA_UUID_CHARACTER_TX; // 0x2002
    char_tx_param.props = GATT_PROP_NOTIFY;  // 通知 (设备→手机)
    character_tx = wq_gatts_register_characteristic(service, char_tx_param);
}
```

> 💡 **SI 技巧**：选中 `gatts_service_t` 按 `Ctrl+Comma` 可以跳到结构体定义，看它有哪些字段。`0xFFFF` 是告诉 SDK "你帮我选一个 handle (句柄) 编号"。

## 第二步：理解 GATT 的层级结构

```
Profile (应用规范，比如"智能眼镜")
 └── Service (服务，比如 reGlasses Main Service)
      │   UUID: 454C4753-5245-474C-4153-534553000001
      │
      ├── Characteristic 1: Device Control (设备控制)
      │     UUID: ...0002  属性: Write (手机写指令给眼镜)
      │
      ├── Characteristic 2: Device Status (设备状态)
      │     UUID: ...0003  属性: Read + Notify (眼镜推送状态给手机)
      │
      ├── Characteristic 3: Audio Stream (音频流)
      │     UUID: ...0004  属性: Notify (眼镜推送音频给手机)
      │
      └── ... 共 7 个 Characteristic
```

**类比理解**：
- **Service** = 一家店铺 (有唯一地址 UUID)
- **Characteristic** = 店铺里的柜台 (每个柜台卖不同的东西)
- **UUID** (Universally Unique Identifier，通用唯一标识符) = 地址编号
- **Handle** (句柄) = 柜台编号 (连接后由系统分配)

## 第三步：理解三种数据交互方式

| 方式 | 方向 | 类比 | 适用场景 |
|------|------|------|----------|
| **Read** (读) | 手机→读→眼镜 | 你看一下自动售货机的价格标签 | 读固件版本、读配置 |
| **Write** (写) | 手机→写→眼镜 | 你投币+按按钮买饮料 | 下发控制指令 (录制/拍照) |
| **Notify** (通知) | 眼镜→推→手机 | 售货机自动把饮料推出来 | 状态上报、音频流、IMU |

在 SI 搜索 `wq_gatts_notify` → 这就是"售货机推饮料"的函数：

```c
// 发送 Notify：眼镜主动推送数据给手机
WQ_RET wq_gatts_notify(
    uint16_t conn_handle,           // 连接句柄 (哪台手机)
    gatts_characteristic_t *character, // 哪个 Characteristic
    const uint8_t *data,            // 数据内容
    uint16_t len                    // 数据长度
);
```

## 第四步：理解 MTU (Maximum Transmission Unit，最大传输单元)

MTU 决定了**每个 BLE 包能装多少数据**：

| 阶段 | MTU | 有效载荷 (Payload) |
|------|-----|-------------------|
| 刚连接 (默认) | 23 字节 | 20 字节 (扣 3 字节 ATT 头) |
| 协商后 | 247 字节 (我们请求的值) | 244 字节 |
| 实际值 | min(247, 手机支持值) | MTU - 3 |

**为什么要协商 MTU？** 默认 23 字节太小了——一个 Opus 音频帧压缩后也有 ~80 字节，要分 4 个包。协商到 247 字节后，一个包就能装下。

在 SI 搜索 `GATTSRegServiceAndCharaEvt_T` 看 MTU 相关字段：

```c
typedef struct {
    bool enable_mtu_exchange;  // 是否启用 MTU 协商
    uint16_t mtu;              // 请求的 MTU 值
    // ...
} GATTSRegServiceAndCharaEvt_T;
```

## 第五步：理解 CCCD (Client Characteristic Configuration Descriptor)

手机要收到 Notify，必须先**使能 CCCD**：

```
手机连接 → 发现 Service → 发现 Characteristic
    → 写入 CCCD = 0x0001 (使能 Notification)
    → 之后就能收到 Notify 推送了
```

这就像**订阅公众号**：先点"关注" (写 CCCD)，之后才能收到推送 (Notify)。

## reGlasses 的 7 个 Characteristic

详见 [[ble-gatt-service-BLE-GATT-Service]]，简版：

| # | 名称 | 属性 | 用途 |
|---|------|------|------|
| C1 | Device Control | Write | 手机→眼镜：控制指令 |
| C2 | Device Status | Notify | 眼镜→手机：状态上报 |
| C3 | Audio Stream | Notify | 眼镜→手机：Opus 音频 |
| C4 | IMU Data | Notify | 眼镜→手机：IMU 数据 |
| C5 | OTA Data RX | WriteNoResp | 手机→眼镜：OTA 固件 |
| C6 | OTA Data TX | Notify | 眼镜→手机：OTA 进度 |
| C7 | Config Params | Read/Write | 双向：配置参数 |

## 验收标准

- [ ] 能在 SI 中找到 `ota_transport_ble.c` 的 `ble_init()` 并解释每一步
- [ ] 能说出 Service 和 Characteristic 的关系 (一对多)
- [ ] 能区分 Read / Write / Notify 三种交互方式
- [ ] 能解释 MTU 协商的目的 (增大单包 payload)
- [ ] 能解释 CCCD 是什么 (手机订阅 Notify 的开关)

## 下一步

GATT 基础搞懂了 → 去看 [[ble-gatt-service-BLE-GATT-Service 了解 reGlasses 具体定义了哪些 Characteristic]]。
或者 → 去看 [[ble-gap-BLE-GAP广播 了解连接建立前的广播阶段]]。

## 关联概念

- [[ble-gap-BLE-GAP广播]] — 连接建立前：广播让手机发现你
- [[ble-gatt-service-BLE-GATT-Service]] — reGlasses 自定义的 7 个 Characteristic
- [[ble-smp-BLE-SMP配对]] — 安全配对和加密
- [[wq-audio-protocol-WQ-Audio-Protocol]] — 通过 GATT 传输的帧协议
- [[snippet-ble-gatt-BLE-GATT注册模板]] — 写新 Service 的代码模板
- [[rtos-freertos-RTOS原理与FreeRTOS]] — GATT 回调函数运行在哪个任务上下文
- [[interrupt-concurrency-中断并发同步]] — BLE 回调与主任务之间的同步

#flashcard
问：GATT 中 Service 和 Characteristic 是什么关系？
答：一对多。一个 Service (店铺) 包含多个 Characteristic (柜台)。每个 Characteristic 有独立的 UUID 和属性 (Read/Write/Notify)。

问：BLE MTU 默认值是多少？协商建议值是多少？
答：默认 23 字节（有效 payload 20B），建议协商到 247 字节（有效 payload 244B）。

问：手机要收到 GATT Notify 需要先做什么？
答：写入 CCCD (Client Characteristic Configuration Descriptor) = 0x0001，相当于"订阅"这个 Characteristic 的推送。
