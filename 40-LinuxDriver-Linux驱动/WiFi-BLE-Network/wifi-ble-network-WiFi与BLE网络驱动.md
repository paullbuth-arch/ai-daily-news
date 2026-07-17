# WiFi 与 BLE 网络驱动

**一句话结论（20% 核心）**：Linux 的 WiFi 驱动走 mac80211/cfg80211 框架，BLE 驱动走 BlueZ 协议栈。WiFi 驱动通常通过 SDIO 或 USB 连接，BLE 驱动通常通过 UART（HCI）连接。WQ7036AX 是蓝牙芯片，V881 是 WiFi 芯片——两者分工。

---

## 第一层：核心认知（必须先看懂）

### 1.1 WiFi 驱动架构

```
用户空间:  wpa_supplicant / hostapd / iw
              │
内核空间:   cfg80211 (配置接口)
              │
           mac80211 (MAC 层框架)
              │
           驱动层 (SDIO/USB/PCIe 接口)
              │
           硬件 (WiFi 芯片)
```

### 1.2 BLE 驱动架构

```
用户空间:  bluetoothd / bluetoothctl / hcitool
              │
内核空间:   BlueZ (蓝牙协议栈)
              │
           HCI 层 (Host Controller Interface)
              │
           驱动层 (UART/USB)
              │
           硬件 (BLE 芯片，如 WQ7036AX)
```

### 1.3 reGlasses 的分工

| 功能 | 负责芯片 | 原因 |
|------|---------|------|
| **WiFi** | V881 | WiFi 芯片通过 SDIO 连在 V881 上 |
| **BLE** | WQ7036AX | WQ7036AX 是双模蓝牙芯片 |
| **经典蓝牙(HFP/A2DP)** | WQ7036AX | 同上 |

**手机和 V881 之间的高速数据走 WiFi（视频流），手机和 WQ7036AX 之间的控制+音频走 BLE。**

### 1.4 如果只记得一件事

> WiFi 驱动走 mac80211/cfg80211 框架，BLE 驱动通过 BlueZ + HCI 层。reGlasses 中 WiFi 在 V881 上，BLE 在 WQ7036AX 上，各司其职。

---

## 第二层：实战理解

### 2.1 查看 WiFi/BLE 状态

```bash
# WiFi
iw dev                    # 查看无线设备
iw dev wlan0 scan         # 扫描 AP
iw dev wlan0 link         # 查看连接状态

# BLE
hcitool dev               # 查看蓝牙设备
hcitool lescan             # BLE 扫描
bluetoothctl              # 交互式蓝牙管理
```

### 2.2 在 reGlasses 项目中怎么用

V881 的 WiFi 驱动在 `~/aiglass/tina-v861/kernel/linux/drivers/net/wireless/` 下。WQ7036AX 的 BLE 驱动在 `wqcore/components/bluetooth/` 下（BCORE 固件）。你写的应用层代码通过 BLE API 发送数据，不需要直接操作 WiFi/BLE 驱动。

---

## 第三层：延伸阅读

- [[ble-gap-BLE-GAP广播]] — BLE GAP 层详解
- [[ble-gatt-BLE-GATT]] — BLE GATT 数据交换
- [[reglasses-bandwidth-reGlasses带宽约束]] — WiFi 和 BLE 的带宽分配