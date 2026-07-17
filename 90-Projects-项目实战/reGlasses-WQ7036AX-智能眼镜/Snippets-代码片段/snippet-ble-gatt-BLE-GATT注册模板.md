---
type: snippet
created: 2026-07-16
tags: [snippet, ble, gatt, service, template]
aliases: [GATT 模板, BLE Service 代码]
---

# Snippet - BLE GATT Service 注册模板

> 参考 SDK 中 `ota_transport_ble.c` → `ble_init()` 的已有实现。

## 完整模板

```c
#include "wq_gatts.h"
#include "wq_adv.h"
#include "wq_gatt.h"

// ============ UUID 定义 ============
#define REGLESS_SERVICE_UUID    0x0001  // 16-bit (或使用 128-bit)
#define REGLESS_CHAR_CTRL_UUID  0x0002  // Device Control
#define REGLESS_CHAR_STAT_UUID  0x0003  // Device Status
#define REGLESS_CHAR_AUDIO_UUID 0x0004  // Audio Stream

static gatts_characteristic_t *char_ctrl;
static gatts_characteristic_t *char_stat;
static gatts_characteristic_t *char_audio;
static uint8_t adv_handle;

// ============ 回调函数 ============

// 连接状态回调
static void gatt_connection_callback(uint8_t index, bool connected, const BD_ADDR_T *addr)
{
    LOGI("BLE %s, addr: %02X:%02X:%02X:%02X:%02X:%02X\n",
         connected ? "connected" : "disconnected",
         ADDR_PRINT_DUMP(addr));
    if (!connected) {
        // 断开处理: 停止音频流等
    }
}

// Device Control Write 回调
static void ctrl_write_callback(uint8_t index, const uint8_t *data, uint16_t len)
{
    LOGI("Device Control write, len=%d\n", len);
    // 解析 WQ Protocol 帧
    wq_proto_pkt_t pkt;
    if (wq_proto_pkt_unpack(&pkt, data, len)) {
        // 根据 service_type + command_id 分发
        handle_control_command(&pkt);
    }
}

// ============ 初始化 ============

static void ble_init(void)
{
    // 1. 注册连接回调
    wq_gatt_register_connection_callback(gatt_connection_callback);

    // 2. 注册 Service
    gatts_service_t service_param = {0};
    service_param.uuid.uuid_type = UUID_TYPE_16;
    service_param.uuid.uuid_union.uuid_16 = REGLESS_SERVICE_UUID;
    service_param.desc = GATT_SERVICE_DESC_NO_SECURITY_PROPERTY
                       | GATT_SERVICE_DESC_SUPPORT_ANY_LINK_TYPE;
    service_param.handle = 0xFFFF;
    gatts_service_t *service = wq_gatts_register_service(service_param);
    assert(service);

    // 3. 注册 Device Control (Write)
    gatts_characteristic_t ctrl_param = {0};
    ctrl_param.uuid.uuid_type = UUID_TYPE_16;
    ctrl_param.uuid.uuid_union.uuid_16 = REGLESS_CHAR_CTRL_UUID;
    ctrl_param.props = GATT_PROP_WRITE | GATT_PROP_WRITE_WITHOUT_RSP;
    ctrl_param.write_callback = ctrl_write_callback;
    ctrl_param.handle = 0xFFFF;
    char_ctrl = wq_gatts_register_characteristic(service, ctrl_param);
    assert(char_ctrl);

    // 4. 注册 Device Status (Notify)
    gatts_characteristic_t stat_param = {0};
    stat_param.uuid.uuid_type = UUID_TYPE_16;
    stat_param.uuid.uuid_union.uuid_16 = REGLESS_CHAR_STAT_UUID;
    stat_param.props = GATT_PROP_READ | GATT_PROP_NOTIFY;
    stat_param.handle = 0xFFFF;
    char_stat = wq_gatts_register_characteristic(service, stat_param);
    assert(char_stat);

    // 5. 注册 Audio Stream (Notify)
    gatts_characteristic_t audio_param = {0};
    audio_param.uuid.uuid_type = UUID_TYPE_16;
    audio_param.uuid.uuid_union.uuid_16 = REGLESS_CHAR_AUDIO_UUID;
    audio_param.props = GATT_PROP_NOTIFY;
    audio_param.handle = 0xFFFF;
    char_audio = wq_gatts_register_characteristic(service, audio_param);
    assert(char_audio);

    // 6. 创建广播句柄
    adv_handle = wq_adv_create_adv_handle();
}

// ============ 广播控制 ============

static void ble_start_advertising(void)
{
    // 广播数据
    uint8_t adv_data[] = {
        0x02, 0x01, 0x06,                       // Flags
        0x03, 0x03, 0x01, 0x00,                 // Service UUID
        0x0D, 0x09, 'r','e','G','l','a','s',    // Local Name
              's','e','s','-'
    };
    wq_adv_set_adv_data(adv_handle, adv_data, sizeof(adv_data));
    wq_adv_set_enabled(adv_handle, true);
}

// ============ 发送 Notify ============

static void send_status_notify(uint8_t conn_handle, const uint8_t *data, uint16_t len)
{
    wq_gatts_notify(conn_handle, char_stat, data, len);
}

static void send_audio_notify(uint8_t conn_handle, const uint8_t *data, uint16_t len)
{
    wq_gatts_notify(conn_handle, char_audio, data, len);
}
```

## 关键注意点

1. `handle = 0xFFFF` 表示让 SDK 自动分配 handle
2. `GATT_PROP_NOTIFY` 需要手机端使能 CCCD 才能收到通知
3. Write 回调在 BLE 线程执行，不要在回调中做耗时操作
4. 广播数据最大 31 字节

## 关联概念

- [[ble-gatt-service-BLE-GATT-Service]] — 7 个 Characteristic 定义
- [[ble-gatt-BLE-GATT]] — GATT 基础
- [[wq-audio-protocol-WQ-Audio-Protocol]] — ctrl_write_callback 中解析的帧协议
