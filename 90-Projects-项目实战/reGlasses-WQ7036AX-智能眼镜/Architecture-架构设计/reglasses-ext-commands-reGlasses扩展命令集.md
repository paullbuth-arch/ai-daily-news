---
type: project
created: 2026-07-16
tags: [project, reglasses, command, control, 命令, 扩展]
aliases: [扩展命令, 新增命令集, reGlasses 命令]
---

# reGlasses 扩展命令集

## 一句话理解

[[wq-audio-protocol-WQ-Audio-Protocol SDK 已经有 4 类 Service (工具/音频下行/音频上行/录制)]]，但 reGlasses 项目需要**再加 4 类**：设备控制、配置管理、遥测上报、IMU 数据流。这里定义了每一类里有哪些命令、每个命令的 payload 长什么样。

## 30 秒先看懂

WQ 协议 SDK 自带了 4 类服务，但 reGlasses 项目需要摄像头控制、配置管理、遥测和 IMU 数据等新功能，所以需要扩展 4 类新的服务。就像手机系统自带了电话和短信，但你需要安装微信和支付宝才能拍照和支付。初学者先记住：新增 4 类服务的编号是 0x04 到 0x07，命令 ID 编码规则是请求用 0x00-0x7F，响应用 0x80-0xFF。

## 学完以后应该能做什么

1. 能在 Source Insight 中找到 `wq_protocol.h` 的已有命令定义。
2. 能说出新增 4 类 Service 的编号（0x04-0x07）。
3. 能画出 `ctrl_record_start_req_t` 的字段结构。
4. 能解释命令 ID 编码规则（请求 0x00-0x7F，响应 = 请求 + 0x80）。

## 为什么你需要看这个

这是你**最终要写代码实现的东西**。手机发"开始录制"指令 → WQ7036AX 收到 → 解析出 `service_type=CONTROL, command_id=RECORD_START` → 执行对应逻辑。你得知道有哪些 command_id、每个的 payload 格式。

## 前置知识

- 理解 WQ Audio Protocol 的基本帧格式和 service_type/command_id 体系；可先看 [[wq-audio-protocol-WQ-Audio-Protocol]]。
- 知道 reGlasses 的跨芯片转发机制；可先看 [[reglasses-cross-chip-reGlasses跨芯片转发]]。
- 了解 reGlasses 的 GATT Service 设计；可先看 [[reglasses-gatt-service-reGlasses-GATT设计]]。
- 如果要写代码实现，需要 [[snippet-wq-protocol-WQ-Protocol打包解包]]。

## 术语先讲清楚

| 术语 | 英文 | 在扩展命令集中具体指什么 |
|---|---|---|
| 服务类型 | service_type | 帧头中的字段，标识命令属于哪个服务类别。SDK 内置 4 类（0x00-0x03），reGlasses 新增 4 类（0x04-0x07） |
| 命令 ID | command_id | 每个服务类型下的具体命令编号。0x00-0x7F 为请求，0x80-0xFF 为响应 |
| 载荷 | payload | 命令携带的具体数据，由 service_type + command_id 决定解析方式 |
| 遥测 | telemetry | 设备定期上报的运行状态数据，如电量、温度、存储空间 |

## 第一步：在 Source Insight 中看已有的命令

1. **`Ctrl+Comma`** 搜索 `wq_trans_down_cmd_t` → `wq_protocol.h`
2. 看已有的命令定义：

```c
typedef enum {
    TRANS_DOWN_START_REQ = 0x01,  // 请求开始音频下行
    TRANS_DOWN_START_RSP = 0x81,  // 响应
    TRANS_DOWN_STOP_REQ  = 0x02,  // 请求停止
    TRANS_DOWN_STOP_RSP  = 0x82,  // 响应
    TRANS_DOWN_DATA_REQ  = 0x10,  // 数据请求
    TRANS_DOWN_DATA_ACK  = 0x90,  // 数据确认
} wq_trans_down_cmd_t;
```

**命令 ID 编码规则**：`0x00-0x7F` = 请求，`0x80-0xFF` = 响应 (= 请求 ID + 0x80)

## 已有的 4 类 Service

| Service | 值 | 命令数 | 用途 |
|---------|---|--------|------|
| UTILS | 0x00 | 2 | 设备信息查询 |
| TRANS_DOWN | 0x01 | 6 | 音频下行 (眼镜→手机) |
| TRANS_UP | 0x02 | 4 | 音频上行 (手机→眼镜) |
| RECORD | 0x03 | 4 | 录制控制 |

## 新增 4 类 Service (你需要实现的)

### CONTROL (0x04) — 设备控制

| 命令 | ID | 方向 | Payload | 执行位置 |
|------|----|------|---------|----------|
| RECORD_START_REQ | 0x01 | → | `ctrl_record_start_req_t` | **V881** |
| RECORD_START_RSP | 0x81 | ← | `ctrl_cmd_rsp_t` | |
| RECORD_STOP_REQ | 0x02 | → | 无 | **V881** |
| RECORD_STOP_RSP | 0x82 | ← | `ctrl_record_stop_rsp_t` | |
| TAKE_PHOTO_REQ | 0x03 | → | `ctrl_photo_req_t` | **V881** |
| TAKE_PHOTO_RSP | 0x83 | ← | `ctrl_cmd_rsp_t` | |
| SWITCH_LENS_REQ | 0x04 | → | `ctrl_lens_req_t` | **V881** |
| SWITCH_LENS_RSP | 0x84 | ← | `ctrl_cmd_rsp_t` | |
| TOF_REQ | 0x05 | → | `ctrl_tof_req_t` | **V881** |
| TOF_RSP | 0x85 | ← | `ctrl_cmd_rsp_t` | |
| VOICE_REQ | 0x06 | → | `ctrl_voice_req_t` | **WQ 本地** |
| VOICE_RSP | 0x86 | ← | `ctrl_cmd_rsp_t` | |
| STATUS_QUERY_REQ | 0x07 | → | 无 | WQ + V881 |
| STATUS_QUERY_RSP | 0x87 | ← | `ctrl_status_rsp_t` | |

### Payload 结构体

```c
// 录制启动
typedef struct {
    uint8_t  camera_mask;     // bit0=广角, bit1=长焦, bit2=TOF
    uint16_t max_duration_s;  // 最大时长(秒), 0=不限
    uint8_t  audio_enable;    // 1=录音频
} ctrl_record_start_req_t;

// 录制停止响应
typedef struct {
    uint8_t  result;          // 0=成功
    uint32_t file_size;       // 文件大小 (bytes)
    uint32_t duration_ms;     // 录制时长 (ms)
    uint32_t storage_remain;  // 剩余存储 (bytes)
} ctrl_record_stop_rsp_t;

// 设备状态查询响应
typedef struct {
    uint8_t  battery_pct;     // 电量 (0-100%)
    uint8_t  charge_state;    // 0=未充电, 1=充电中, 2=充满
    uint32_t storage_total;   // 总存储
    uint32_t storage_used;    // 已用存储
    uint8_t  record_state;    // 0=空闲, 1=录制中
    uint8_t  active_lens;     // 0=广角, 1=长焦
    uint8_t  tof_state;       // 0=关, 1=开
    uint8_t  wifi_state;      // 0=断, 1=连
    uint8_t  ble_state;       // 0=断, 1=连
    int8_t   temperature;     // 芯片温度 °C
    uint32_t uptime_s;        // 运行时间 (秒)
    char     fw_version[16];  // 固件版本
} ctrl_status_rsp_t;
```

### CONFIG (0x05) — 配置管理

| 命令 | ID | Payload |
|------|----|---------|
| CONFIG_SET_REQ | 0x01 | `config_set_req_t` (TLV: param_id + value) |
| CONFIG_SET_RSP | 0x81 | `ctrl_cmd_rsp_t` |
| CONFIG_GET_REQ | 0x02 | `config_get_req_t` |
| CONFIG_GET_RSP | 0x82 | `config_get_rsp_t` |
| CONFIG_WIFI_REQ | 0x03 | `config_wifi_req_t` (SSID + 密码) |
| CONFIG_WIFI_RSP | 0x83 | `ctrl_cmd_rsp_t` |

### TELEMETRY (0x06) — 遥测上报

| 命令 | ID | 说明 |
|------|----|------|
| PERIODIC_IND | 0x01 | 定期上报 (10秒一次): 电量/温度/存储/信号 |
| ALERT_IND | 0x02 | 告警: 低电量/过热/存储不足 |

### IMU (0x07) — IMU 数据流

| 命令 | ID | 说明 |
|------|----|------|
| IMU_START_REQ | 0x01 | 启动 IMU 上报 (指定频率) |
| IMU_STOP_REQ | 0x02 | 停止 IMU 上报 |
| IMU_DATA_IND | 0x10 | IMU 数据包 (多个采样打包发送) |

## 第二步：你要写的代码在哪里

```c
// app_trans.c — 消息分发总入口
// 你需要在这里加一个 case 处理新的 SERVICE_TYPE_CONTROL
switch (pkt.msg_header.service_type) {
    case SERVICE_TYPE_CONTROL:  // ← 你新增的
        handle_control_command(&pkt);
        break;
    // ...已有的 case
}
```

## 验收标准

- [ ] 能在 SI 中找到 `wq_protocol.h` 的已有命令定义
- [ ] 能说出新增 4 类 Service 的编号 (0x04-0x07)
- [ ] 能画出 `ctrl_record_start_req_t` 的字段
- [ ] 能解释命令 ID 编码规则 (请求 0x00-0x7F, 响应 = 请求 + 0x80)

## 练习

### 练习一：新增一个命令

假设需要新增一个 FACTORY_RESET 命令（恢复出厂设置），属于 CONFIG 服务。请写出它的命令 ID、方向、payload 结构体定义和帧类型。

**通过标准**：命令 ID 遵循编码规则，payload 包含必要的字段（如确认码）。

### 练习二：解析 payload

手机发来一个 CONTROL 服务的 RECORD_START 请求，payload 二进制为 `01 3C 00 01`。请解析出 camera_mask、max_duration_s 和 audio_enable 的值。

**通过标准**：能对照结构体定义逐字段解析。

## 自测题

1. **reGlasses 新增了几类 Service？编号分别是什么？**
   - 4 类：CONTROL(0x04)、CONFIG(0x05)、TELEMETRY(0x06)、IMU(0x07)。

2. **命令 ID 的编码规则是什么？**
   - 0x00-0x7F 为请求类（REQ/IND），0x80-0xFF 为响应类（RSP/ACK）。响应 ID = 请求 ID + 0x80。

3. **CONTROL 服务的 RECORD_START_REQ 的 command_id 是多少？**
   - 0x01（请求），响应 RECORD_START_RSP 为 0x81。

## 关联概念

- [[wq-audio-protocol-WQ-Audio-Protocol]] — 帧协议基础
- [[wq-protocol-service-WQ-Protocol服务类型]] — 已有 Service 列表
- [[reglasses-cross-chip-reGlasses跨芯片转发]] — 命令如何路由
- [[ble-gatt-service-BLE-GATT-Service]] — C1 Device Control 接收这些命令
- [[dataflow-cmd-to-v881-手机指令到V881]] — 完整指令追踪

#flashcard
问：reGlasses 新增了几类 Service？编号分别是什么？
答：4 类：CONTROL(0x04)、CONFIG(0x05)、TELEMETRY(0x06)、IMU(0x07)。

问：命令 ID 的编码规则是什么？
答：0x00-0x7F 为请求类 (REQ/IND)，0x80-0xFF 为响应类 (RSP/ACK)。响应 ID = 请求 ID + 0x80。
