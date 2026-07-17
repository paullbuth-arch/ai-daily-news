---
type: moc
tags: [moc, bluetooth, ble, hfp, a2dp, gatt]
---

# 70-Bluetooth：蓝牙协议栈

> WQ7036AX 是双模蓝牙芯片（经典蓝牙 + BLE）。经典蓝牙（HFP/A2DP）管通话和音乐，BLE（GATT）管控制和数据。理解蓝牙协议栈是理解 reGlasses 通信架构的基础。

## 学习路线

BLE GAP 广播（设备怎么被发现）→ BLE GATT（设备怎么交换数据）→ BLE SMP 配对（安全连接）→ 经典蓝牙 HFP/A2DP（通话和音乐）→ 蓝牙调试

## 已有文档

| 文件 | 核心内容 |
|------|---------|
| [[ble-gap-BLE-GAP广播]] | 广播包/扫描/连接建立——设备怎么被发现 |
| [[ble-gatt-BLE-GATT]] | Service/Characteristic/Read/Write/Notify——数据怎么交换 |
| [[ble-gatt-service-BLE-GATT-Service]] | reGlasses 自定义的 7 个 Characteristic |
| [[ble-smp-BLE-SMP配对]] | Just Works/绑定/加密——安全连接 |
| [[ble-vs-wifi-无线对比]] | 带宽/功耗/适用场景对比 |
| [[classic-bluetooth-经典蓝牙]] | HFP 免提通话、A2DP 高质量音频 |
| [[bt-debug-蓝牙调试]] | HCI log、btmon、Wireshark 抓包 |

## 核心问题

- BLE 广播包最大多少字节？37 字节（PDU 部分）。
- GATT 中 Service 和 Characteristic 的关系？Service 是容器，Characteristic 是数据项。
- HFP 和 A2DP 的区别？HFP 是双向通话（低质量），A2DP 是单向音乐（高质量）。