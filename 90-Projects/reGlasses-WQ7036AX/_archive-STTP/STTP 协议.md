---
type: concept
created: 2026-07-16
tags: [protocol, sttp, uart, wq7036ax, 透传, 可靠传输, deprecated]
aliases: [STTP, SigmaStar Transparent Transfer Protocol]
---

# STTP 协议

> ⚠️ **已弃用**：commit `36c99d85` 已将 STTP 替换为 [[UART 命令协议]] (app_uart_cmd)。本笔记保留作为历史参考和设计对比。当前项目实际使用的是 [[UART 命令协议]]。

## 一句话理解

STTP (SigmaStar Transparent Transfer Protocol，星科技透传协议) 就像**发快递**：[[UART 基础|UART]] 是公路，STTP 是快递公司——它把你要发的数据打包成"包裹"（帧 Frame），贴上收件人标签（chn 通道号），编上序号（seq 序列号），如果对方没签收（ACK 超时），就重新发一份。

## 为什么要了解它 (虽然已弃用)

1. **理解设计演进**：知道为什么从 STTP 换成了 [[UART 命令协议]]——项目实际只需要传语音指令，STTP 的 256 通道、连接握手过于复杂
2. **对比学习**：STTP 和 [[UART 命令协议]] 的帧格式差异，帮你理解"通用透传"vs"专用命令"的设计取舍 (详见 [[帧协议对比：UART 命令协议 vs WQ Protocol]])
3. **历史代码**：git 历史中仍有 STTP 代码，看旧 commit 时会遇到

## 第一步：在 Source Insight 中找到 STTP

1. **`Ctrl+Comma`** 搜索 `STTP_New` → 跳到 `sttp.c`（约第 58 行）
2. 看函数签名：

```c
STTP_Obj_t* STTP_New(
    enum STTP_Mode_e mode,   // CLIENT 还是 SERVER
    const STTP_Info_t* info, // 收发缓冲区
    STTP_Io_t* io            // 底层读写函数
);
```

这就是"**开一家快递公司**"的入口：
- `mode` = `E_STTP_MODE_CLIENT` (WQ7036AX，主动发起连接) 或 `E_STTP_MODE_SERVER` (V881，等待连接)
- `info` = 告诉 STTP 用哪块内存做收发缓冲区
- `io` = 告诉 STTP 怎么读写底层 UART

3. **`Ctrl+Click`** 跳进函数体，看它做了什么：

```c
STTP_Obj_t* STTP_New(enum STTP_Mode_e mode, const STTP_Info_t* info, STTP_Io_t* io)
{
    STTP_Obj_t* sttp = _STTP_FindHandle();  // 找一个空闲的实例槽
    // ... 设置 mode、io、初始化收发 Ring Pool (环形缓冲区)
    sttp->mode = mode;
    sttp->io = *io;
    _STTP_RingPoolInit(&sttp->rxRingPool, info->rxBuf, info->rxLen);
    _STTP_RingPoolInit(&sttp->txRingPool, info->txBuf, info->txLen);
    return sttp;
}
```

> 💡 **SI 技巧**：选中函数名按 `Ctrl+=` 可以展开/折叠。搜索用 `Ctrl+Comma`，回退用 `Alt+Left`。

## 第二步：看帧长什么样

在 SI 搜索 `STTP_Header_u` → 看到一个 **union**（联合体，所有字段共享同一块内存）：

```c
union STTP_Header_u {
    struct {
        /* op byte — 操作标志 */
        uint8_t fin : 1;    // 分手信 (断开连接)
        uint8_t syn : 1;    // 加好友请求 (建立连接)
        uint8_t ack : 1;    // 签收回执 (确认)
        uint8_t obt : 1;    // 要求对方签收
        uint8_t crc : 1;    // 附带 CRC 校验码
        uint8_t rsv : 3;    // 保留

        /* num byte — 编号 */
        uint8_t seqNum : 4; // 我发的第几个包 (0-15)
        uint8_t ackNum : 4; // 我收到了你的第几个包

        /* chn byte — 通道号 */
        uint8_t chn;        // 哪个业务通道 (0-255)

        /* len byte — 载荷长度 */
        uint8_t len;        // 包裹里有多少数据
    } header;
    uint8_t raw[4];         // 也可以按 4 字节原始数据读
};
```

画出来就是这样：

```
Byte 0 (op):    [fin][syn][ack][obt][crc][rsv][rsv][rsv]
Byte 1 (num):   [  seqNum  ] [  ackNum  ]
Byte 2 (chn):   [        通道号          ]
Byte 3 (len):   [        载荷长度         ]
    ↓ (如果 len==253，追加 2 字节 Ext16Len)
    ↓ (如果 len==254，追加 4 字节 Ext32Len)
    ↓
[          Payload 载荷数据              ]
    ↓ (如果 crc==1，追加 2 字节 CRC16)
    ↓
[0x5A]  ← 结束标志 (End Flag，固定值)
```

> 💡 **bit field (位域)** 是 C 语言的特性：`uint8_t fin : 1` 表示只占 1 个 bit。8 个标志位挤在 1 个字节里。SI 里按 `F12` 可以看这个 union 被哪些地方使用。

## 第三步：理解通道 (chn)

STTP 的 **chn (channel，通道)** 就像快递公司的**不同业务线**：

```
UART 物理链路 (一条 TX/RX)
         │
    ┌────┴────┐
    │  STTP   │
    └────┬────┘
         │ 按 chn 分发
    ┌────┼────┬────┬────┬────┐
    ▼    ▼    ▼    ▼    ▼    ▼
  chn0 chn1 chn2 chn3 chn4 chn5 ...
  心跳 控制  音频↑ 音频↓ 遥测  配置
```

在 SI 搜索 `STTP_AddReceiver`：

```c
// 注册某个通道的接收回调函数
int32_t STTP_AddReceiver(
    STTP_Obj_t *sttp,
    uint8_t chn,
    int32_t (*recv)(void *usr, const void *data, uint32_t len),
    void *usr
);
```

这就是"告诉快递公司：chn=1 的包裹送到 `control_recv_cb` 这个地址"。

## 第四步：理解连接和重传

在 SI 搜索 `STTP_Connect` → 看连接建立流程：

```
WQ7036AX (Client)                    V881 (Server)
     │                                    │
     │── SYN (syn=1, seqNum=0) ──────────→│  "你好，我想建交"
     │                                    │
     │←── SYN+ACK (syn=1, ack=1, ────────│  "好，我也同意"
     │     seqNum=0, ackNum=1)            │
     │                                    │
     │── ACK (ack=1, ackNum=1) ──────────→│  "确认，连接建立"
     │                                    │
     │── DATA (obt=1, seqNum=1, ─────────→│  "这是数据，请签收"
     │     chn=1, payload)                │
     │                                    │
     │←── ACK (ack=1, ackNum=2) ─────────│  "已签收"
     │                                    │
     │   [如果 100ms 内没收到 ACK ...]     │
     │── DATA (obt=1, seqNum=1) ─────────→│  "重发！"
```

关键参数：
- **ACK 超时** = 100ms (`STTP_TIMEOUT_NS = 100000000` 纳秒)
- **序列号** = 0-15 循环 (`NEXT_NUM(x) = (x+1) % 16`)
- **结束标志** = `0x5A` (每个帧最后必须看到这个字节)

搜索 `STTP_Process` → 这是**主循环中必须定期调用**的函数，它处理：
1. 从 UART 读取数据 → 解析帧
2. 检查超时 → 触发重传
3. 分发数据到对应 chn 的回调

## reGlasses 通道分配

| chn | 业务 | 方向 | 要 ACK | 理由 |
|-----|------|------|--------|------|
| 0 | 心跳 | 双向 | 否 | 周期发送，丢了无所谓 |
| 1 | 控制指令 | 双向 | **是** | 录制/拍照不能丢 |
| 2 | 音频上行 | WQ→V881 | 否 | 实时流，重传会卡顿 |
| 3 | 音频下行 | V881→WQ | 否 | 同上 |
| 4 | 遥测/状态 | V881→WQ | 否 | 周期上报 |
| 5 | 配置 | 双向 | **是** | 配置不能丢 |
| 6 | IMU 数据 | V881→WQ | 否 | 高频流 |
| 7 | OTA 升级 | 双向 | **是** | 固件不能丢 |

**设计原则**：控制类要 ACK (不能丢)，流数据不要 ACK (不能卡)。

## 验收标准

- [ ] 能在 SI 中找到 `sttp.c` 并搜索到 `STTP_New` / `STTP_Send` / `STTP_Process`
- [ ] 能画出 STTP 帧的 4 字节 Header，说出每个 bit field 的含义
- [ ] 能解释 chn (通道号) 的作用：同一条 UART 跑多种业务
- [ ] 能解释为什么音频通道 (chn 2/3) 不需要 ACK
- [ ] 能说出 STTP 的 ACK 超时时间 (100ms) 和结束标志 (0x5A)

## 下一步

STTP 搞懂了 → 去看 [[I2S 协议]] (音频总线) 或 [[BLE GATT]] (蓝牙)，看你当前任务需要哪个。

## 关联概念

- [[STTP 帧格式]] — 帧结构的 bit-level 详细解析
- [[STTP 连接管理]] — SYN/ACK/FIN 状态机
- [[STTP 通道分配]] — 通道设计细节
- [[UART 基础]] — STTP 跑的物理层
- [[Ext Trans 框架]] — STTP 在 SDK 中的集成方式
- [[reGlasses 跨芯片指令转发]] — STTP 在项目中的实际用途

#flashcard
问：STTP 帧的结束标志字节是什么？
答：0x5A。每个帧的最后必须看到这个字节，否则帧不完整。

问：STTP 的 obt 标志位是什么意思？
答：obt (obtain) = "需要对方确认"。设 obt=1 表示要求接收方回复 ACK。

问：STTP 的 chn 字段占多少字节？最多支持多少个通道？
答：chn 占 1 字节 (uint8_t)，范围 0-255，最多 256 个逻辑通道。

问：为什么 STTP_Process() 必须在主循环中定期调用？
答：因为它负责两件事：①从 UART 读取并解析接收数据 ②检查发送超时并重传。不调用 = 不收不发。
