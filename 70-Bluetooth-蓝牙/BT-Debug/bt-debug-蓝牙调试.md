# 蓝牙调试

**一句话结论（20% 核心）**：蓝牙调试比有线协议难一个数量级——你看不到空中包，时序是微秒级，问题可能是射频干扰。三大工具：HCI Log（看协议栈内部）、btmon/Wireshark（抓空中包）、nRF Sniffer（第三方抓包）。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：监听电话线

蓝牙调试 = 你在监听两个人打电话：
- **HCI Log** = 你站在其中一个人旁边，听到他说的每句话
- **btmon/Wireshark** = 你在电话线上装了窃听器，听到双方的对话
- **nRF Sniffer** = 你请了第三方在旁边录音，三方独立验证

### 1.2 三层调试工具

| 工具 | 层次 | 能看到什么 |
|------|------|-----------|
| **HCI Log** | Host ↔ Controller | 主机发给控制器的命令、控制器返回的事件 |
| **btmon** | 空中包 | 完整的 BLE/经典蓝牙空中包（需要硬件支持） |
| **Wireshark** | 空中包 | 可视化抓包，解析所有协议层 |
| **nRF Sniffer** | 空中包 | 独立硬件抓包，不依赖被调试设备 |

### 1.3 如果只记得一件事

> 蓝牙调试 = HCI Log（看协议栈内部）+ btmon/Wireshark（抓空中包）+ nRF Sniffer（独立验证）。GATT 通信问题看 HCI Log，连接/配对问题抓空中包，射频问题用频谱仪。

---

## 第二层：实战理解

### 2.1 常见调试场景

```bash
# 启用 HCI Log（Linux）
btmon -w hci.log &
hcitool lescan  # 执行蓝牙操作

# 查看日志
btmon -r hci.log

# Wireshark 打开 hci.log 可视化分析
wireshark hci.log
```

### 2.2 常见问题排查

| 问题 | 先看什么 | 常见根因 |
|------|---------|---------|
| GATT 写失败 | HCI Log | ATT 错误码，permission 不够 |
| 连接断开 | 空中包 | 超时未收到数据包，监督超时 |
| 配对失败 | HCI Log + 空中包 | SMP 协商失败，IO Capability 不匹配 |
| 通信距离短 | 无法用软件查 | 射频问题：天线匹配、PCB 布局 |

### 2.3 在 reGlasses 项目中怎么用

WQ7036AX 的蓝牙调试主要通过 HCI 接口（ACORE 和 BCORE 之间的通信）。BCORE 是封闭固件，不能直接调试，只能通过 HCI log 看 ACORE 发了什么命令、BCORE 回了什么事件。手机端可以用 nRF Connect App 读写 GATT，验证手机↔WQ7036AX 通信。

---

## 第三层：延伸阅读

- [[ble-gatt-BLE-GATT]] — GATT 通信的常见问题
- [[ble-smp-BLE-SMP配对]] — 配对过程的调试
- [[debug-methodology-嵌入式调试方法论]] — 通用调试方法