---
type: concept
tags: [linux, wifi, ble, bluetooth, mac80211, cfg80211, bluez, driver]
aliases: [WiFi与BLE网络驱动, 无线网络, 蓝牙]
---

# WiFi 与 BLE 网络驱动

## 一句话结论

Linux 的 WiFi 驱动走 mac80211/cfg80211 框架，BLE 驱动走 BlueZ 协议栈。WiFi 驱动通常通过 SDIO 或 USB 连接，BLE 驱动通常通过 UART（HCI）连接。WQ7036AX 是蓝牙芯片，V881 是 WiFi 芯片——两者分工。

## 30秒先看懂

- WiFi 驱动架构从下到上分为三层：硬件层（WiFi 芯片通过 SDIO/USB 连接）、内核驱动层（mac80211 提供 MAC 层框架，cfg80211 提供配置接口）、用户空间层（wpa_supplicant 管理连接，iw 命令配置）。BLE 驱动架构类似：硬件层（BLE 芯片通过 UART/USB 连接）、内核层（BlueZ 协议栈通过 HCI 层与硬件通信）、用户空间层（bluetoothd/bluetoothctl 管理蓝牙设备）。在 reGlasses 项目中，WiFi 在 V881 上负责高速数据（视频流），BLE 在 WQ7036AX 上负责控制+音频，两者通过 UART 通信协调工作。

## 学完以后应该能做什么

**第一遍看完后可以：**
- 理解 WiFi 驱动架构（mac80211/cfg80211）和 BLE 驱动架构（BlueZ/HCI）
- 使用 `iw` 和 `bluetoothctl` 查看网络设备状态
- 知道 reGlasses 中 WiFi 和 BLE 的分工
- 理解 HCI 层的作用和连接方式

**进阶后可以：**
- 编写 WiFi 驱动的 SDIO 接口层
- 调试 BLE 驱动的 HCI 通信问题
- 配置 WiFi 的 AP/STA 模式切换
- 分析 WiFi 和 BLE 的共存干扰问题

## 前置知识

- Linux 网络协议栈基础知识
- SDIO/UART 总线协议
- 无线通信基本概念（SSID、BSSID、GATT、GAP）

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 介质访问控制 | MAC | Media Access Control，WiFi 数据链路层 |
| 802.11 配置框架 | cfg80211 | Linux 内核的 WiFi 配置管理接口 |
| MAC 层框架 | mac80211 | Linux 内核的 WiFi MAC 层软件实现 |
| 主机控制器接口 | HCI | Host Controller Interface，主机和蓝牙控制器之间的通信协议 |
| 蓝牙协议栈 | BlueZ | Linux 官方蓝牙协议栈 |
| 站 | STA | Station，WiFi 客户端模式 |
| 接入点 | AP | Access Point，WiFi 热点模式 |
| 服务集标识符 | SSID | Service Set Identifier，WiFi 网络名称 |
| 通用属性协议 | GATT | Generic Attribute Profile，BLE 数据传输协议 |
| 通用访问协议 | GAP | Generic Access Profile，BLE 广播和连接管理 |

## 第一层：费曼心智模型

### 类比：快递公司

- **WiFi = 卡车运输**：速度快、距离远、运量大，但耗油（费电），适合大批量数据（视频流）
- **BLE = 自行车快递**：速度慢、距离近、运量小，但省力（省电），适合小批量数据（控制命令、音频流）

**WiFi 驱动架构：**

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

**BLE 驱动架构：**

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

**边界：**
- WiFi 和 BLE 共用 2.4GHz 频段，同时使用时需要共存机制
- BLE 的 HCI 层通常通过 UART 连接，波特率限制了最大吞吐量
- WiFi 驱动需要固件加载——芯片内部有独立的 CPU 运行固件

### 场景演练：reGlasses 的无线通信

1. 手机通过 BLE 连接到 WQ7036AX（眼镜上的蓝牙芯片）
2. 用户通过手机 APP 发出"开始视频通话"命令
3. WQ7036AX 通过 UART 把命令转发给 V881
4. V881 上的 WiFi 连接到家庭路由器
5. 视频流通过 WiFi 从 V881 传到手机
6. 音频流通过 BLE 从 WQ7036AX 传到手机
7. 控制命令（音量、拍照）通过 BLE 低延迟传输

## 第二层：原理/时序/约束

### WiFi 驱动核心流程

```
驱动加载:
  probe() → 初始化 SDIO/USB → 加载固件 → 注册 mac80211 → 创建虚拟接口

连接流程:
  wpa_supplicant → cfg80211 connect → mac80211 扫描 → 认证 → 关联 → 4 次握手 → 连接建立

数据传输:
  应用 socket → 网络协议栈 → mac80211 TX → 驱动发送 → 硬件发送
```

### BLE 驱动核心流程

```
驱动加载:
  probe() → 初始化 UART → 注册 HCI 设备 → BlueZ 协议栈初始化

BLE 连接:
  bluetoothctl scan → 发现设备 → 发起连接 → 配对 → GATT 服务发现 → 数据交换

数据传输:
  GATT write → BlueZ → HCI 命令 → UART → BLE 芯片 → 空中发送
```

### reGlasses 的分工

| 功能 | 负责芯片 | 传输方式 | 原因 |
|------|---------|---------|------|
| WiFi | V881 | SDIO | WiFi 芯片通过 SDIO 连在 V881 上 |
| BLE | WQ7036AX | UART (HCI) | WQ7036AX 是双模蓝牙芯片 |
| 经典蓝牙 (HFP/A2DP) | WQ7036AX | 内置 | 同上 |
| 核间通信 | 两者之间 | UART | 命令和数据转发 |

## 第三层：真实 SDK 代码

### reGlasses 的 WiFi 驱动

V881 的 WiFi 驱动在 `/home/ys/aiglass/tina-v861/bsp/drivers/net/wireless/` 下，使用标准 mac80211 框架：

```c
// WiFi 驱动 probe 示例
static int wifi_probe(struct sdio_func *func, const struct sdio_device_id *id) {
    struct ieee80211_hw *hw = ieee80211_alloc_hw(sizeof(struct wifi_priv),
                                                  &wifi_ops);
    // 初始化硬件
    sdio_claim_host(func);
    sdio_enable_func(func);
    // 注册 mac80211
    ieee80211_register_hw(hw);
    return 0;
}
```

### reGlasses 的 BLE 驱动

WQ7036AX 的 BLE 驱动在 `wqcore/components/bluetooth/` 下（BCORE 固件），V881 侧的 BlueZ 驱动在 `/home/ys/aiglass/tina-v861/bsp/drivers/bluetooth/` 下：

```c
// /home/ys/aiglass/tina-v861/bsp/drivers/bluetooth/bcm_btlpm.c
// 蓝牙低功耗管理
static int bcm_btlpm_probe(struct platform_device *pdev) {
    // 配置蓝牙唤醒引脚
    // 注册 HCI 设备
    // 初始化 Runtime PM
}
```

### 调试命令

```bash
# WiFi
iw dev                    # 查看无线设备
iw dev wlan0 scan         # 扫描 AP
iw dev wlan0 link         # 查看连接状态
iw dev wlan0 set power_save on  # 开启 WiFi 省电

# BLE
hcitool dev               # 查看蓝牙设备
hcitool lescan            # BLE 扫描
bluetoothctl              # 交互式蓝牙管理
bluetoothctl show         # 查看蓝牙控制器状态
```

## 第四层：正常/异常路径

### 正常路径

WiFi：驱动加载 → 固件下载 → 扫描 → 连接 → 数据传输 → 断开
BLE：驱动加载 → HCI 初始化 → 广播 → 连接 → 数据交换 → 断开

### 异常路径

| 异常场景 | 现象 | 原因 | 处理方式 |
|---------|------|------|---------|
| WiFi 固件加载失败 | 网络设备未创建 | 固件文件缺失或损坏 | 检查固件路径和版本 |
| BLE HCI 通信失败 | 蓝牙设备不可用 | UART 波特率不对或引脚连接错误 | 检查 HCI UART 配置 |
| WiFi 连接断开 | 网络不通 | 信号弱或 AP 端问题 | 启用自动重连机制 |
| BLE 连接间隔不稳定 | 数据传输延迟抖动 | 射频干扰或共存问题 | 调整连接参数 |
| 吞吐量不足 | 视频卡顿 | WiFi 信号弱或 BLE 带宽限制 | 切换信道或降低码率 |

## 第五层：调试方法

```bash
# WiFi 调试
iw dev wlan0 link          # 查看连接状态和信号强度
iw dev wlan0 station dump  # 查看连接统计（丢包、重传）
cat /proc/net/wireless     # 查看无线网络统计

# 抓 WiFi 包
tcpdump -i wlan0 -w wifi.pcap

# BLE 调试
btmon                     # 监控蓝牙 HCI 日志
hcitool cmd 0x03 0x05     # 发送 HCI 命令
gatttool -b MAC -I        # 交互式 GATT 操作

# 查看蓝牙日志
cat /sys/kernel/debug/bluetooth/hci0/...
```

## 第六层：实战练习

### 练习 1：WiFi 扫描（基础）

使用 Linux 命令行工具完成 WiFi 扫描：
1. 使用 `iw dev wlan0 scan` 扫描周围 AP
2. 解析扫描结果（SSID、信号强度、加密方式、信道）
3. 连接到指定 AP
4. 验证连接成功（ping 外部服务器）
5. 查看连接状态和信号强度

### 练习 2：BLE 数据收发（进阶）

使用 `bluetoothctl` 和 `gatttool` 完成 BLE 数据收发：
1. 用 `bluetoothctl` 扫描并连接 BLE 设备
3. 用 `gatttool` 发现服务和特征值
4. 读取/写入特征值
5. 订阅通知（Notification）

### 练习 3：阅读 BLE 驱动源码（深入）

阅读 `/home/ys/wq7036a/wq-audio/wqcore/components/bluetooth/` 下的 BLE 驱动代码，回答：
1. BCORE 的蓝牙协议栈是如何与 ACORE 的应用层通信的？
2. HCI 命令是如何从 ACORE 传递到 BCORE 的？
3. BLE 广播和扫描的流程是什么？
4. GATT 服务和特征值是如何注册的？

## 自测与验收

1. WiFi 驱动架构中 mac80211 和 cfg80211 的分工是什么？
2. BLE 驱动架构中 HCI 层的作用是什么？
3. reGlasses 项目中 WiFi 和 BLE 分别由哪个芯片负责？为什么这样分工？
4. 什么是 wpa_supplicant？它是用户空间还是内核空间的？
5. 蓝牙的 HCI 通常通过什么物理接口连接？
6. WiFi 和 BLE 为什么需要共存机制？
7. 如何查看 BLE 芯片的 HCI 日志？

## 延伸阅读

- [[ble-gap-BLE-GAP广播]] — BLE GAP 层详解
- [[ble-gatt-BLE-GATT]] — BLE GATT 数据交换
- [[reglasses-bandwidth-reGlasses带宽约束]] — WiFi 和 BLE 的带宽分配

## #flashcard

**Q: Linux WiFi 驱动使用什么框架？**
A: mac80211（MAC 层框架）+ cfg80211（配置接口）。

**Q: Linux BLE 驱动使用什么协议栈？**
A: BlueZ，通过 HCI 层与蓝牙硬件通信。

**Q: reGlasses 中 WiFi 和 BLE 的分工？**
A: WiFi 在 V881 上负责高速数据（视频流），BLE 在 WQ7036AX 上负责控制+音频。

**Q: HCI 层通常通过什么物理接口连接？**
A: UART（最常见）或 USB。

**Q: wpa_supplicant 的作用？**
A: 用户空间的 WiFi 连接管理工具，处理认证、密钥协商、扫描等。