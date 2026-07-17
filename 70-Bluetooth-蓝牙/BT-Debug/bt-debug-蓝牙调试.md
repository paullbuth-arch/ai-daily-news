---
type: concept
created: 2026-07-17
tags: [debug, bluetooth, hci, sniffer, wireshark, 调试]
aliases: [蓝牙调试, BT Debug, HCI Log, Bluetooth Sniffer]
---

# 蓝牙调试

## 一句话结论

蓝牙调试比有线协议调试难一个数量级——空中包看不见、时序是微秒级、问题可能是射频干扰。三层工具由浅入深：HCI Log（看协议栈内部，最常用）、btmon/Wireshark（抓空中包分析协议交互）、nRF Sniffer（独立硬件抓包，第三方验证）。GATT 通信问题先看 HCI Log，连接/配对问题抓空中包分析，射频问题用频谱仪。

## 30秒先看懂

- HCI（Host Controller Interface）是蓝牙 Host（ACORE）和 Controller（BCORE）之间的标准接口，所有蓝牙操作都通过 HCI 命令和事件完成。
- HCI Log 记录 Host 和 Controller 之间的通信，不需要额外硬件，所有平台都有，是最常用的调试手段。
- btmon 是 Linux 上抓取 HCI 和空中包的工具，支持导出为 Wireshark 可读的 pcap 格式。
- nRF Sniffer 用独立硬件（nRF52840 Dongle）抓取空中包，不依赖被调试设备，最客观。
- 蓝牙调试的核心方法论：先确定问题层次（GATT 通信 / 连接 / 配对 / 射频），再选择对应工具。

## 学完以后应该能做什么

### 第一遍
- 抓取 HCI Log 并分析基本的蓝牙命令和事件
- 用 btmon 抓取空中包并用 Wireshark 分析
- 根据问题现象判断应该用哪层调试工具

### 进阶
- 用 Wireshark 过滤语法精确分析 GATT、SMP、L2CAP 各层协议
- 配置 nRF Sniffer 独立抓包分析复杂问题
- 通过 HCI Log 排查连接断开、配对失败、GATT 通信异常等问题

## 前置知识

- [[ble-gatt-BLE-GATT]]：GATT 通信协议和常见错误码
- [[ble-smp-BLE-SMP配对]]：配对过程和 SMP 协商
- [[classic-bluetooth-经典蓝牙]]：经典蓝牙的 SCO/ACL 链路
- [[debug-methodology-嵌入式调试方法论]]：通用调试方法论

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 主机控制器接口 | HCI (Host Controller Interface) | 蓝牙 Host（应用处理器）和 Controller（射频芯片）之间的标准通信接口 |
| HCI 命令 | HCI Command | Host 发送给 Controller 的指令，如"扫描 BLE 设备" |
| HCI 事件 | HCI Event | Controller 发送给 Host 的事件通知，如"发现设备" |
| 空中包 | Air Packet | 蓝牙设备间通过射频实际传输的数据包 |
| 抓包器 | Sniffer | 监听空中蓝牙数据包的硬件或软件工具 |
| 蓝牙监视器 | btmon (Bluetooth Monitor) | Linux 上的蓝牙协议分析工具 |
| 接收信号强度指示 | RSSI (Received Signal Strength Indicator) | 表示接收信号强弱的指标，dBm 单位 |
| 逻辑链路控制与适配协议 | L2CAP (Logical Link Control and Adaptation Protocol) | 蓝牙协议栈中负责数据分段和协议复用的层 |
| 错误响应 | Error Response | ATT 协议中表示操作失败的响应包 |

## 第一层费曼心智模型

### 类比：监听电话线

蓝牙调试就像监听两个人打电话，但通话内容被加密、时序是微秒级、而且你只有一个监听点：

- **HCI Log** = 你站在其中一个人旁边，听到他对电话说的每句话——命令和事件。你能听到他说了什么，但听不到对方说了什么（只能通过他的反应推断）。
- **btmon/Wireshark** = 你在电话线上装了窃听器，听到双方的对话——空中包的全部内容。但需要电话线支持"监听模式"。
- **nRF Sniffer** = 你请了第三方在旁边用录音笔独立录音，完全独立于被调试设备——最客观，但需要额外设备。

### 边界

- HCI Log 只能看到 Host 和 Controller 之间的通信，看不到空中的实际射频信号。
- 空中包抓取需要硬件支持 monitor 模式，WQ7036AX 的 BCORE 固件可能不支持。
- nRF Sniffer 只能抓 BLE，不能抓经典蓝牙。
- 很多蓝牙问题（连接断开、配对失败）是协议栈内部时序问题，不是逻辑错误，加日志可能破坏时序。

### 场景推演

**场景：手机 APP 写 GATT 数据但设备无响应**

1. 怀疑是 GATT 通信问题 → 选 HCI Log
2. 抓取 HCI Log，看到 ATT Write Request 发出去了
3. 继续看，没有看到 ATT Write Response
4. 看到 ATT Error Response（0x05: Insufficient Authentication）
5. 结论：Characteristic 需要加密才能访问，但链路未加密
6. 解决方案：先配对/加密，再访问该 Characteristic

## 第二层原理/时序/约束

### HCI 通信模型

```
应用层 (ACORE, FreeRTOS)
    ↓  GATT API (wq_gatts_register_service, wq_gatts_send_notify, ...)
bt_service / bt_rpc 层
    ↓  RPC 调用
HCI 层
    ↓  HCI 命令/事件/ACL 数据
BCORE 固件 (Controller)
    ↓  2.4GHz 射频
空中蓝牙包
```

### HCI 命令/事件格式

```
HCI 命令包格式:
┌──────────┬──────────┬──────────┬──────────┐
│ OpCode   │ OpCode   │ 参数总长  │ 参数...  │
│ (低字节)  │ (高字节)  │          │          │
└──────────┴──────────┴──────────┴──────────┘
   2 字节      1 字节    0-255 字节

HCI 事件包格式:
┌──────────┬──────────┬──────────┐
│ 事件码    │ 参数总长  │ 参数...  │
│ (1 字节)  │ (1 字节)  │          │
└──────────┴──────────┴──────────┘
```

### 各层调试工具对比

| 工具 | 层次 | 能看到什么 | 优点 | 缺点 | 适合场景 |
|------|------|-----------|------|------|---------|
| **HCI Log** | Host↔Controller | 命令、事件、ACL 数据 | 无需额外硬件，所有平台都有 | 看不到空中包 | GATT 通信、连接状态 |
| **btmon** | 空中包 | 完整的 BLE/经典蓝牙包 | Linux 自带，免费 | 需要硬件支持 monitor 模式 | 协议交互分析 |
| **Wireshark** | 空中包 | 可视化解析所有协议层 | 图形界面，协议解析最全 | 需要抓包文件，实时性差 | 深度协议分析 |
| **nRF Sniffer** | 空中包 | 独立硬件抓包，完全客观 | 不依赖被调试设备 | 需要额外硬件（~$50） | 复杂问题第三方验证 |
| **Ellisys** | 空中包 | 全协议抓包 | 专业级，同时抓 BLE+经典蓝牙+WiFi | 贵（>$10k） | 专业认证测试 |

## 第三层真实SDK代码

### HCI 命令定义

位于 `/home/ys/wq7036a/wq-audio/wqcore/components/bluetooth/host/bbb/inc/wq_bt_hci_api.h`：

```c
// HCI 命令和事件定义
// 命令示例：LE Set Scan Parameters
// OCF (OpCode Command Field): 0x000B
// OGF (OpCode Group Field): 0x08

// 事件示例：Command Complete
// 事件码: 0x0E

// 关键 HCI 命令
#define HCI_LE_SET_SCAN_PARAMETERS    0x200B  // 设置扫描参数
#define HCI_LE_SET_SCAN_ENABLE        0x200C  // 启用/禁用扫描
#define HCI_LE_CREATE_CONNECTION      0x200D  // 创建连接
#define HCI_DISCONNECT                0x0406  // 断开连接
```

### 蓝牙 LE API

位于 `/home/ys/wq7036a/wq-audio/wqcore/components/bluetooth/host/bbb/inc/wq_bt_le_api.h`：

```c
// LE 扩展广播命令
api_result_t wq_bt_hci_le_set_adv_set_random_address(
    uint8_t advertising_handle,
    uint8_t *random_address
);

// 设置扩展广播参数
api_result_t wq_bt_hci_le_set_ext_adv_params(
    uint8_t adv_handle,
    uint16_t adv_event_properties,
    uint32_t primary_advertising_interval_min,  // N * 0.625ms
    uint32_t primary_advertising_interval_max,  // N * 0.625ms
    uint8_t primary_advertising_channel_map,
    uint8_t own_address_type,
    // ...
);
```

## 第四层正常/异常路径

### 常见问题排查流程

**GATT 写失败：**
```
1. 看 HCI Log：确认 ATT Write Request 发出去了
2. 看 HCI Log：确认 ATT Write Response 有没有收到
3. 如果收到 Error Response：看 ATT 错误码
   - 0x02: Read Not Permitted
   - 0x03: Write Not Permitted
   - 0x05: Insufficient Authentication
   - 0x0A: Attribute Not Found
4. 如果没收到 Response：检查连接是否还活着
```

**连接突然断开：**
```
1. 看 HCI Log：确认 Disconnect Complete 事件
2. 看 Reason 字段：
   - 0x08: Connection Timeout（对方没回应）
   - 0x13: Remote User Terminated（对方主动断开）
   - 0x16: Connection Terminated by Local Host（本端断开）
3. 如果是 Timeout：抓空中包看最后收到的数据包时间
   - 检查 Connection Interval 和 Supervision Timeout
```

**配对失败：**
```
1. 看 HCI Log：找到 SMP 相关事件
2. 检查 Pairing Request/Response 的 IO Capability
3. 确认 Pairing Confirm 和 Pairing Random 是否正确交换
4. 看 SMP 错误码（0x01-0x08）
5. 常见原因：IO Capability 不匹配、PIN 码错误、超时
```

### 调试工具选择速查

| 问题现象 | 首选工具 | 辅助工具 |
|---------|---------|---------|
| GATT 写数据无响应 | HCI Log | nRF Connect |
| 连接频繁断开 | HCI Log（看 Reason） | 空中包（看时序） |
| 配对失败 | HCI Log（看 SMP） | 空中包（看完整交互） |
| 通信距离短 | 频谱仪 | nRF Sniffer（看 RSSI） |
| 吞吐量低 | HCI Log（看连接间隔） | 空中包（看带宽占用） |
| 经典蓝牙通话卡顿 | HCI Log（看 SCO） | 示波器（看音频） |

## 第五层调试方法

### 抓取 HCI Log

```bash
# Linux 上启用 btmon 抓包
sudo btmon -w bt_trace.log &

# 执行蓝牙操作（连接、读写、配对等）
# ...

# 停止抓包
sudo pkill btmon

# 查看日志
btmon -r bt_trace.log

# 导出为 Wireshark 可读格式
btmon -r bt_trace.log -w bt_trace.pcap
wireshark bt_trace.pcap
```

### Wireshark 蓝牙过滤语法

```
# 只看 BLE 包
btle

# 只看特定设备的包（根据 MAC 地址）
btle.advertising_address == 66:55:44:33:22:11

# 只看 GATT 写操作
btatt.opcode == 0x12  # Write Request
btatt.opcode == 0x52  # Write Command (Without Response)

# 只看 ATT 错误
btatt.opcode == 0x01  # Error Response

# 只看连接事件
btle.ll_opcode == 0x00  # CONNECT_IND

# 只看 L2CAP 层
l2cap

# 只看 SMP 配对
bt-smp

# 只看 HCI 事件
hci.event
```

### nRF Sniffer 配置

```bash
# 用 nRF52840 Dongle 作为 BLE Sniffer
# 1. 刷入 sniffer 固件
nrfutil dfu usb-serial -pkg nrf_sniffer_for_bluetooth_le.zip -p /dev/ttyACM0

# 2. Wireshark 中配置 nRF Sniffer 接口
# Wireshark → Capture → Options → nRF Sniffer

# 3. 选择要抓取的 BLE 设备（通过 MAC 地址过滤）
# 开始抓包，所有空中包在 Wireshark 中可视化
```

### 常见 HCI 错误码

| 错误码 | 含义 | 说明 |
|--------|------|------|
| 0x00 | Success | 操作成功 |
| 0x01 | Unknown HCI Command | 不支持的 HCI 命令 |
| 0x08 | Connection Timeout | 连接超时（对方没有回应） |
| 0x0C | Command Disallowed | 命令不允许（当前状态不支持） |
| 0x13 | Remote User Terminated | 对方主动断开连接 |
| 0x16 | Connection Terminated by Local Host | 本地主动断开 |
| 0x3E | Connection Failed to be Established | 连接建立失败 |

### 在实际项目中调试

WQ7036AX 的蓝牙调试链路：
- **ACORE → BCORE**：通过 HCI 接口通信，可在 ACORE 侧抓 HCI Log
- **BCORE 固件**：封闭源码，不能直接调试，只能通过 HCI 交互间接推断
- **手机端**：用 **nRF Connect** App 读写 GATT，验证通信；用 **LightBlue** 看 BLE 服务和特征值
- **空中包**：如果芯片支持 monitor 模式可用 btmon，否则用 nRF52840 Dongle + Wireshark

## 第六层实战练习

### 练习1：抓取并分析 HCI Log

执行以下步骤，抓取 BLE 通信的 HCI Log 并分析：

```bash
# 1. 启动 btmon 抓包
sudo btmon -w hci_analysis.log

# 2. 用手机连接设备，执行一次 GATT 读写操作

# 3. 停止抓包，查看日志
btmon -r hci_analysis.log

# 4. 回答以下问题：
#    - 连接建立用了哪些 HCI 命令？
#    - GATT Write 的 ATT 操作码是什么？
#    - 连接断开的原因是什么？
```

### 练习2：阅读 SDK 源码分析 HCI 命令封装

在 `/home/ys/wq7036a/wq-audio/wqcore/components/bluetooth/host/bbb/inc/wq_bt_hci_api.h` 中查找 HCI 命令定义，分析：
- HCI 命令的 OGF 和 OCF 如何组合成 OpCode？
- Command Complete 事件和 Command Status 事件有什么区别？
- 如何判断一个 HCI 命令是否成功执行？

### 练习3：模拟 GATT 错误场景

使用 nRF Connect App 模拟以下场景并分析 HCI Log：

```
场景 A：读取一个不允许读的 Characteristic
  - 预期：收到 ATT Error Response (0x02: Read Not Permitted)
  - 在 HCI Log 中找到对应的错误包

场景 B：写入 CCCD 但不使能 Notify
  - 写入 CCCD = 0x0000
  - 设备发送 Notify，预期手机不处理
  - 观察 HCI Log 中 Notify 是否仍然发出

场景 C：在未配对状态下访问需要加密的 Characteristic
  - 预期：收到 ATT Error Response (0x05: Insufficient Authentication)
  - 在 HCI Log 中找到对应的错误码
```

## 自测与验收

1. HCI Log、btmon、nRF Sniffer 三种工具分别能看到什么？各有什么优缺点？
2. GATT Write 失败时，应该先看哪个工具？如何定位问题？
3. 连接断开事件中，Reason=0x08、0x13、0x16 分别代表什么？
4. WQ7036AX 的 BCORE 固件为什么不能直接调试？
5. 什么情况下需要使用 nRF Sniffer 而不是 btmon？

## 延伸阅读

- [[ble-gatt-BLE-GATT]] — GATT 通信的常见错误码
- [[ble-smp-BLE-SMP配对]] — 配对过程的调试和 SMP 协商
- [[classic-bluetooth-经典蓝牙]] — 经典蓝牙的 HCI 调试
- [[debug-methodology-嵌入式调试方法论]] — 通用调试方法论
- `/home/ys/wq7036a/wq-audio/wqcore/components/bluetooth/host/bbb/inc/wq_bt_hci_api.h` — HCI API 定义
- `/home/ys/wq7036a/wq-audio/wqcore/components/bluetooth/host/bbb/inc/wq_bt_le_api.h` — LE API 定义

#flashcard
问：HCI Log 和 btmon 有什么不同？
答：HCI Log 记录 Host 和 Controller 之间的通信（命令和事件），btmon 可以同时抓 HCI 和空中包（如果硬件支持）。

问：连接断开事件中 Reason=0x08 代表什么？
答：Connection Timeout（连接超时），表示对方没有在规定时间内回应，通常是因为距离太远或干扰大。

问：GATT Error Response 0x05 代表什么？
答：Insufficient Authentication，表示该 Characteristic 需要配对/加密才能访问，但链路未加密。

问：WQ7036AX 的 BCORE 为什么不能直接调试？
答：BCORE 运行的是厂商提供的封闭固件，没有源码，没有调试接口。只能通过 HCI 命令和事件间接观察。

问：什么时候需要 nRF Sniffer？
答：当怀疑问题在射频/Air Interface 层，且被调试设备不支持空中包抓取时。nRF Sniffer 是独立的第三方观察者。