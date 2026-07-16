---
type: moc
tags: [moc, bluetooth, ble, hfp, a2dp, gatt]
---

# 70-Bluetooth: 蓝牙协议栈

> WQ7036AX 是双模蓝牙芯片（经典蓝牙 + BLE）。经典蓝牙（HFP/A2DP）管通话和音乐，BLE（GATT）管控制和数据。理解蓝牙协议栈是理解 reGlasses 通信架构的基础。

---

## 学习路线

```
BLE GAP 广播（设备怎么被发现）
    │
    └──→ BLE GATT（设备怎么交换数据）
          │
          ├──→ BLE SMP 配对（怎么安全连接）
          │
          └──→ 经典蓝牙 HFP/A2DP（通话和音乐）
```

---

## 已有笔记

| 文件 | 一句话 | 什么时候学 |
|------|--------|-----------|
| [[BLE GAP 广播]] | 广播包/扫描/连接建立——设备怎么被发现 | **最先学** |
| [[BLE GATT]] | Service/Characteristic/Read/Write/Notify——数据怎么交换 | **第二个学** |
| [[BLE GATT Service]] | reGlasses 自定义的 7 个 Characteristic | 理解项目蓝牙设计 |
| [[BLE SMP 配对]] | Just Works/绑定/加密——安全连接 | 需要实现配对时 |
| [[无线对比：BLE vs WiFi]] | 带宽/功耗/适用场景对比 | 建立全局认知 |

## 待创建（按需补充）

| 主题 | 一句话 |
|------|--------|
| 经典蓝牙 HFP | 免提通话协议，SCO/eSCO 音频链路 |
| 经典蓝牙 A2DP | 高质量音频传输，SBC/AAC 编解码 |
| 蓝牙调试 | HCI log、btmon、Wireshark 抓包 |

## 面试高频问题

- BLE 广播包最大多少字节？37 字节（PDU 部分）。
- GATT 中 Service 和 Characteristic 的关系？Service 是容器，Characteristic 是数据项。
- HFP 和 A2DP 的区别？HFP 是双向通话（低质量），A2DP 是单向音乐（高质量）。
- BLE 配对方式有哪些？Just Works、Passkey、Numeric Comparison、OOB。