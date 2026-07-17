# 蓝牙调试

**一句话结论（20% 核心）**：蓝牙调试比有线协议难一个数量级——你看不到空中包，时序是微秒级，问题可能是射频干扰。三层工具：HCI Log（看协议栈内部，最常用）、btmon/Wireshark（抓空中包，看实际交互）、nRF Sniffer（独立硬件抓包，第三方验证）。GATT 通信问题看 HCI Log，连接/配对问题抓空中包，射频问题用频谱仪。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：监听电话线

蓝牙调试 = 你在监听两个人打电话，但通话内容被加密、时序是微秒级、而且你只有一个监听点：

- **HCI Log** = 你站在其中一个人旁边，听到他对电话说的每句话（Host→Controller 的命令和事件）
- **btmon/Wireshark** = 你在电话线上装了窃听器，听到双方的对话（空中包，但需要硬件支持 sniffer 模式）
- **nRF Sniffer** = 你请了第三方在旁边用录音笔独立录音（完全独立于被调试设备，最客观）

**为什么蓝牙调试这么难？** 因为：（1）空中包你看不到，不像 UART 可以用逻辑分析仪夹线看；（2）时序是微秒级，加日志会破坏时序；（3）很多问题（连接断开、配对失败）是协议栈内部的时序问题，不是逻辑错误。

### 1.2 三层调试工具对比

| 工具 | 层次 | 能看到什么 | 优点 | 缺点 |
|------|------|-----------|------|------|
| **HCI Log** | Host↔Controller | 命令、事件、ACL 数据 | 无需额外硬件，所有平台都有 | 看不到空中包，看不到 Controller 内部状态 |
| **btmon** | 空中包 | 完整的 BLE/经典蓝牙包 | Linux 自带，免费 | 需要蓝牙芯片支持 monitor 模式 |
| **Wireshark** | 空中包 | 可视化解析所有协议层 | 图形界面，协议解析最全 | 需要抓包文件，实时性差 |
| **nRF Sniffer** | 空中包 | 独立硬件抓包 | 不依赖被调试设备，客观 | 需要额外硬件（~$50），只能抓 BLE |
| **Ellisys** | 空中包 | 全协议抓包 | 专业级，同时抓 BLE+经典蓝牙+WiFi | 贵（>$10k） |

### 1.3 HCI：Host Controller Interface 详解

HCI 是蓝牙 Host（应用层）和 Controller（射频层）之间的标准接口。所有蓝牙操作都通过 HCI 命令和事件完成：

```
Host (ACORE, FreeRTOS)          Controller (BCORE, 固件)
    │                                │
    │── HCI Command ────────────────→│  "扫描 BLE 设备"
    │←── HCI Event ─────────────────│  "命令已收到"
    │←── HCI Event ─────────────────│  "发现设备: AA:BB:CC:DD:EE:FF"
    │                                │
    │── HCI ACL Data ───────────────→│  GATT 写请求数据
    │←── HCI ACL Data ──────────────│  GATT 通知数据
```

**HCI Log 的格式**（用 btmon 解析后）：
```
> HCI Command: LE Set Scan Parameters (0x08|0x000b)
    Type: Active (0x01)
    Interval: 10.000 ms
    Window: 10.000 ms

< HCI Event: Command Complete (0x0e)
    LE Set Scan Parameters (0x08|0x000b)
    Status: Success (0x00)

> HCI Event: LE Meta Event (0x3e)
    LE Advertising Report
      Address: 66:55:44:33:22:11
      RSSI: -45 dBm
      Data: 02 01 06 03 03 0F 18 ...
```

### 1.4 如果只记得一件事

> 蓝牙调试 = HCI Log（看协议栈内部，最常用）+ btmon/Wireshark（抓空中包）+ nRF Sniffer（独立验证）。GATT 通信问题看 HCI Log，连接/配对问题抓空中包，射频问题用频谱仪。

---

## 第二层：实战理解

### 2.1 抓取 HCI Log

```bash
# Linux 上启用 btmon 抓包
sudo btmon -w hci.log &
# 执行蓝牙操作...
sudo pkill btmon

# 查看日志
btmon -r hci.log

# 导出为 Wireshark 可读格式
btmon -r hci.log -w hci.pcap
wireshark hci.pcap
```

### 2.2 Wireshark 蓝牙过滤语法

```
# 只看 BLE 包
btle

# 只看特定设备的包
btle.advertising_address == 66:55:44:33:22:11

# 只看 GATT 写操作
btatt.opcode == 0x12  # Write Request
btatt.opcode == 0x52  # Write Command

# 只看 ATT 错误
btatt.opcode == 0x01  # Error Response

# 只看连接事件
btle.ll_opcode == 0x00  # CONNECT_IND
```

### 2.3 常见问题排查流程

**GATT 写失败**：
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

**连接突然断开**：
```
1. 看 HCI Log：确认 Disconnect Complete 事件
2. 看 Reason 字段：
   - 0x08: Connection Timeout（对方没回应）
   - 0x13: Remote User Terminated（对方主动断开）
   - 0x16: Connection Terminated by Local Host（本端断开）
3. 如果是 Timeout：抓空中包看最后收到的数据包时间
   - 检查 Connection Interval 和 Supervision Timeout
```

### 2.4 常见坑

| 问题 | 现象 | 排查方法 | 根因 |
|------|------|---------|------|
| GATT 写无响应 | 手机端 write 成功但设备无反应 | HCI Log 看 ATT Write Response | ATT 层的 handle 或权限不对 |
| 连接频繁断开 | 连接建立后几秒就断 | 空中包看最后通信时间 | Connection Interval 配太小，或 Supervision Timeout 太短 |
| 配对失败 | 配对流程中断 | HCI Log 看 SMP 协商过程 | IO Capability 不匹配，或 PIN 码错误 |
| 通信距离短 | 5 米外就连不上 | 频谱仪看射频功率 | 天线匹配不好，或 PCB 布局问题 |

### 2.5 在 reGlasses 项目中怎么用

WQ7036AX 的蓝牙调试链路：
- **ACORE → BCORE**：通过 HCI 接口通信，可以在 ACORE 侧抓 HCI Log
- **BCORE 固件**：封闭源码，不能直接调试，只能通过 HCI 交互间接推断
- **手机端**：用 **nRF Connect** App 读写 GATT，验证手机↔WQ7036AX 通信；用 **LightBlue** App 看 BLE 服务和特征值
- **空中包**：如果 WQ7036AX 的 BLE 芯片支持 monitor 模式，可以用 btmon 抓空中包；否则用 nRF52840 Dongle + Wireshark 独立抓包

---

## 第三层：深入扩展

### 3.1 nRF Sniffer 配置

```bash
# 用 nRF52840 Dongle 作为 BLE Sniffer
# 1. 刷入 sniffer 固件
nrfutil dfu usb-serial -pkg nrf_sniffer_for_bluetooth_le.zip -p /dev/ttyACM0

# 2. Wireshark 中配置 nRF Sniffer 接口
# Wireshark → Capture → Options → nRF Sniffer

# 3. 选择要抓取的 BLE 设备（通过 MAC 地址过滤）
# 开始抓包，所有空中包在 Wireshark 中可视化
```

### 3.2 常见问题

- **HCI Log 和 btmon 的区别？** HCI Log 是 Host 和 Controller 之间的通信记录，btmon 是 Linux 上抓取 HCI 和空中包的工具。btmon 可以同时抓 HCI 和空中包（如果硬件支持）。
- **为什么 WQ7036AX 的 BCORE 不能直接调试？** BCORE 运行的是厂商提供的封闭固件，没有源码，没有调试接口。只能通过 HCI 命令和事件间接观察其行为。
- **什么时候需要 nRF Sniffer？** 当怀疑问题在射频/Air Interface 层，且被调试设备不支持空中包抓取时。nRF Sniffer 是独立的第三方观察者，不受被调试设备限制。

### 3.3 延伸阅读

- [[ble-gatt-BLE-GATT]] — GATT 通信的常见错误码
- [[ble-smp-BLE-SMP配对]] — 配对过程的调试和 SMP 协商
- [[classic-bluetooth-经典蓝牙]] — 经典蓝牙的 HCI 调试
- [[debug-methodology-嵌入式调试方法论]] — 通用调试方法论