---
type: concept
created: 2026-07-16
tags: [protocol, wq-protocol, frame, 帧协议, 应用层]
aliases: [WQ Protocol, 0x5751, 物奇帧协议]
---

# WQ Audio Protocol

## 一句话理解

WQ Protocol (物奇音频协议) 就像**快递公司的标准包装箱**：不管里面装的是音频、指令还是传感器数据，外面都套同一个格式的箱子——箱子上印着 `0x5751`（"WQ"两个字母的 ASCII 码）作为品牌标识，贴着寄件人编号 (seq)、业务类型 (service_type) 和内容清单 (command_id)。

## 为什么重要

WQ Protocol 是**所有业务数据的封装格式**。你在 BLE GATT 里发的每一包数据、在 [[STTP 协议]] 里转发的每一条指令，**里面装的都是 WQ Protocol 帧**。不懂它，你就不知道数据打开后里面长什么样。

## 第一步：在 Source Insight 中找到帧定义

1. **`Ctrl+Comma`** 搜索 `wq_protocol.h` → 打开这个头文件
2. 找到 `frame_header_t` (帧头结构体)：

```c
typedef struct {
    uint16_t sync_word;   // 同步字: 固定 0x5751 ("WQ")
    uint8_t  checksum;    // 校验和: msg_header + payload 的字节累加
    uint8_t  reserved;    // 保留: 填 0
    uint8_t  frame_type : 3;  // 帧类型: REQ=1, RSP=2, IND=3, ACK=4
    uint8_t  need_ack   : 1;  // 是否需要确认
    uint8_t  reserved1  : 4;
    uint8_t  seq_number;      // 序列号 (0-255)
} frame_header_t;  // 共 7 字节
```

3. 紧接着看 `msg_header_t` (消息头)：

```c
typedef struct {
    uint8_t  service_type;  // 服务类型 (UTILS=0, TRANS_DOWN=1, ...)
    uint8_t  command_id;    // 命令 ID (START=0x01, STOP=0x02, ...)
    uint16_t payload_len;   // 载荷长度
} msg_header_t;  // 共 4 字节
```

画出来就是这样：

```
Offset  0    1    2    3    4    5    6    7    8    9   10   11+
      ┌────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬───┐
      │ W  │ Q  │chk │ 00 │flags   │seq │svc │cmd │ payload_len │
      │0x57│0x51│sum │    │ft│ack│r│num │type│ id │  (小端16位) │
      └────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴───┘
      |______ Frame Header (7B) ______|___ Message Header (4B) ___|

      ┌──────────────────────────────────────────────────────────┐
      │              Payload (载荷, 变长)                         │
      │  根据 service_type + command_id 解析为对应 C 结构体        │
      └──────────────────────────────────────────────────────────┘
```

> 💡 **小端 (Little-Endian)**：`payload_len` 是 uint16_t，低字节在前。比如长度 0x0100 (256)，在内存中存为 `00 01`。

## 第二步：理解帧类型 (frame_type)

| 值 | 名称 | 类比 | 说明 |
|----|------|------|------|
| 1 | REQ (Request) | "帮我做件事" | 请求对方执行操作 |
| 2 | RSP (Response) | "做完了，结果是..." | 回复 REQ 的执行结果 |
| 3 | IND (Indication) | "通知你一下" | 单向推送 (如音频流) |
| 4 | ACK (Acknowledgment) | "收到了" | 对 IND 的确认 |

```
典型 REQ-RSP 交互:
  手机 → REQ (开始录制, seq=5, need_ack=1) → WQ7036AX
  手机 ← RSP (成功, seq=3, ack for 5) ←── WQ7036AX

典型 IND 流 (音频):
  WQ7036AX → IND (音频帧, seq=10) → 手机
  WQ7036AX → IND (音频帧, seq=11) → 手机
  WQ7036AX → IND (音频帧, seq=12) → 手机
  ...持续推送...
```

## 第三步：理解 Service 和 Command

在 SI 搜索 `service_type_e`：

```c
typedef enum {
    SERVICE_TYPE_UTILS      = 0x00,  // 工具类 (查设备信息)
    SERVICE_TYPE_TRANS_DOWN = 0x01,  // 音频下行 (眼镜→手机)
    SERVICE_TYPE_TRANS_UP   = 0x02,  // 音频上行 (手机→眼镜)
    SERVICE_TYPE_RECORD     = 0x03,  // 录制控制
    SERVICE_TYPE_MAX        = 0x04,
} service_type_e;
```

**这是 SDK 已有的 4 类服务**。reGlasses 需要扩展 4 类新的（详见 [[reglasses-ext-commands-reGlasses扩展命令集）：]]

| Service | 值 | 用途 | 已有/新增 |
|---------|---|------|-----------|
| UTILS | 0x00 | 工具类 | 已有 |
| TRANS_DOWN | 0x01 | 音频下行 | 已有 |
| TRANS_UP | 0x02 | 音频上行 | 已有 |
| RECORD | 0x03 | 录制控制 | 已有 |
| **CONTROL** | **0x04** | **设备控制** (录制/拍照/切镜头/TOF/语音) | **新增** |
| **CONFIG** | **0x05** | **配置管理** (WiFi 配网/参数读写) | **新增** |
| **TELEMETRY** | **0x06** | **遥测上报** (电量/温度/存储) | **新增** |
| **IMU** | **0x07** | **IMU 数据流** | **新增** |

**命令 ID 编码规则**：`0x00-0x7F` = 请求类 (REQ/IND)，`0x80-0xFF` = 响应类 (RSP/ACK) = 请求 ID + 0x80。

## 第四步：看打包和解包函数

在 SI 搜索 `wq_proto_pkt_pack`：

```c
// 打包：把 service_type + command_id + payload 组装成一帧
bool wq_proto_pkt_pack(
    wq_proto_pkt_t *pkt,        // 输出: 打包好的帧
    uint8_t service_type,       // 服务类型
    uint8_t command_id,         // 命令 ID
    uint8_t frame_type,         // REQ/RSP/IND/ACK
    uint8_t seq_number,         // 序列号
    uint8_t need_ack,           // 是否需要确认
    uint8_t *data,              // payload 数据
    uint16_t len                // payload 长度
);
```

搜索 `wq_proto_pkt_unpack` → 反向操作：从收到的字节流中解析出帧结构。

```c
// 解包：从收到的字节流中解析
bool wq_proto_pkt_unpack(
    wq_proto_pkt_t *pkt,        // 输出: 解析后的帧
    const uint8_t *data,        // 输入: 收到的原始字节
    uint16_t len                // 字节长度
);
```

> 💡 **实际用法**：BLE GATT 的 `write_callback` 收到手机数据后，第一件事就是调 `wq_proto_pkt_unpack` 解析；要发数据给手机，先调 `wq_proto_pkt_pack` 打包再发。

## 第五步：BLE 传输时的分片

BLE GATT 协商后 MTU = 247 → payload = 244B → 减去帧头 11B = **233B 有效载荷上限**。

如果一个 Opus 音频帧有 400B 怎么办？**分片 (Fragmentation)**：

```
原始 400B 数据
  │
  ├─ Fragment 1: [seq=K,   frame_num=0, is_last=0, data[0..232]]
  ├─ Fragment 2: [seq=K+1, frame_num=1, is_last=0, data[233..399]]
  └─ Fragment 3: [seq=K+2, frame_num=2, is_last=1, data[剩余]]
```

接收方按 seq 排序，看到 `is_last=1` 就知道是最后一片。

## 验收标准

- [ ] 能在 SI 中找到 `wq_protocol.h` 并说出 `frame_header_t` 每个字段的含义
- [ ] 能解释 sync_word = 0x5751 的意义 (帧起始标识)
- [ ] 能区分 REQ/RSP/IND/ACK 四种帧类型
- [ ] 能说出已有 4 类 Service 和新增 4 类 Service 的编号
- [ ] 能解释 BLE 传输时的分片机制 (233B 上限)

## 下一步

WQ Protocol 搞懂了 → 去看 [[reglasses-ext-commands-reGlasses扩展命令集 了解你要新增哪些命令]]。
或者 → 去看 [[reglasses-cross-chip-reGlasses跨芯片转发 了解命令如何从 BLE 转到 STTP 到 V881]]。

## 关联概念

- [[wq-protocol-frame-WQ-Protocol帧结构]] — bit-level 详细解析
- [[wq-protocol-service-WQ-Protocol服务类型]] — 所有 Service/Command 列表
- [[reglasses-ext-commands-reGlasses扩展命令集]] — 新增的 4 类 Service 定义
- [[ble-gatt-BLE-GATT]] — WQ Protocol 帧通过 GATT 传输
- [[STTP 协议]] — WQ Protocol 帧也可通过 STTP 传输
- [[snippet-wq-protocol-WQ-Protocol打包解包]] — 代码模板

#flashcard
问：WQ Protocol 的 sync_word 是什么？占几个字节？
答：0x5751（ASCII "WQ"），占 2 字节 (uint16_t)。它是帧的起始标识，解包时首先检查。

问：frame_type=3 (IND) 和 frame_type=1 (REQ) 的区别？
答：REQ 是"请帮我做一件事"，需要对方回复 RSP。IND 是"通知你一下"，单向推送（如音频流），不需要回复。

问：BLE 传输时 WQ Protocol 的有效载荷上限是多少？怎么算的？
答：233 字节。算法：MTU(247) - ATT头(3) - 帧头(11) = 233B。超过需分片。
