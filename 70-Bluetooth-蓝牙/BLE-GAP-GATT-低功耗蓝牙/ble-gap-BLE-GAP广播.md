---
type: concept
created: 2026-07-16
tags: [protocol, ble, gap, advertising, 广播, 蓝牙]
aliases: [BLE 广播, BLE Advertising, GAP, Generic Access Profile]
---

# BLE GAP 广播

## 一句话理解

GAP (Generic Access Profile，通用访问配置文件) 中的广播 (Advertising) 就像**在街上举着招牌走路**：你的眼镜不停向周围喊"我是 reGlasses-XXXX，我能连接！"，附近的手机"看到"你的招牌就能主动过来建立连接。

## 为什么学它

广播是 BLE 通信的**第一步**——手机必须先"发现"你的眼镜，才能建立连接、才能用 [[ble-gatt-BLE-GATT 交换数据]]。广播没配对，后面全白搭。

## 第一步：在 Source Insight 中找到广播代码

1. **`Ctrl+Comma`** 搜索 `wq_adv_create_adv_handle` → 跳到 `wq_adv.c`
2. 看广播创建的完整流程：

```c
// ① 创建广播句柄
uint8_t adv_handle = wq_adv_create_adv_handle();

// ② 设置广播数据 (最多 31 字节)
uint8_t adv_data[] = {
    0x02, 0x01, 0x06,                       // AD1: Flags (必须)
    0x03, 0x03, 0x33, 0x70,                 // AD2: Service UUID (0x7033)
    0x0D, 0x09, 'r','e','G','l','a','s',    // AD3: 设备名
              's','e','s','-'
};
wq_adv_set_adv_data(adv_handle, adv_data, sizeof(adv_data));

// ③ 开始广播
wq_adv_set_enabled(adv_handle, true);
```

3. 搜索 `ble_open` → `ota_transport_ble.c` 中已有完整的广播启动示例

## 第二步：理解广播数据结构

广播包最大 **31 字节**，由多个 AD Structure (Advertising Data Structure，广播数据结构) 拼接而成：

```
┌──────────────────────────────────────────────────┐
│ AD1: Flags (固定必须有)                           │
│   [长度=0x02] [类型=0x01] [值=0x06]              │
│   0x06 = LE General Discoverable + BR/EDR Not    │
│                                                  │
│ AD2: Service UUID (告诉手机我有什么服务)           │
│   [长度=0x03] [类型=0x03] [UUID低字节] [UUID高字节]│
│                                                  │
│ AD3: Complete Local Name (设备名)                 │
│   [长度=N] [类型=0x09] ['r']['e']['G']...        │
└──────────────────────────────────────────────────┘
```

每个 AD 结构的格式：`[长度] [类型] [值...]`

### Scan Response (扫描响应, 额外 31 字节)

手机可以发送 Scan Request (扫描请求)，眼镜回复 Scan Response 携带更多信息：

```
┌──────────────────────────────────────────────────┐
│ AD1: Manufacturer Specific Data (厂商数据)         │
│   Company ID: 0x076E (WuQi 物奇)                  │
│   Product ID: 0x7033                              │
│   Version: 固件版本号                               │
│   Battery: 当前电量 (%)                             │
│   Status: 设备状态字节                              │
└──────────────────────────────────────────────────┘
```

## 第三步：广播参数配置

| 参数 | 正常模式 | 配网模式 (按键 B 长按 5s) |
|------|----------|--------------------------|
| 广播间隔 | 100ms | 30ms (更快被发现) |
| 广播类型 | Connectable Undirected | 同左 |
| 地址类型 | Public (公开地址) | Random (随机地址，保护隐私) |
| 超时 | 持续广播 | 120 秒后停止 |

**广播间隔**决定了功耗和发现速度的平衡：
- 间隔短 → 手机发现快 → 但耗电
- 间隔长 → 省电 → 但手机发现慢

## 第四步：连接建立后的参数

广播只是"举招牌"，手机决定连接后，进入 [[ble-gatt-BLE-GATT 阶段]]。连接参数：

| 参数 | 建议值 | 说明 |
|------|--------|------|
| Connection Interval (连接间隔) | 15-30ms | 每 15-30ms 通信一次 |
| Slave Latency (从机延迟) | 0-4 | 允许跳过几次通信以省电 |
| Supervision Timeout (监控超时) | 4000ms | 4 秒没通信就断开 |

## 验收标准

- [ ] 能在 SI 中找到 `wq_adv.c` 并说出 `wq_adv_create_adv_handle` / `wq_adv_set_adv_data` / `wq_adv_set_enabled` 的作用
- [ ] 能解释广播包的结构 (AD Structure 拼接)
- [ ] 能说出广播间隔对功耗和发现速度的影响
- [ ] 能解释 reGlasses 配网模式的触发方式 (按键 B 长按 5s)

## 下一步

广播搞懂了 → 去看 [[ble-gatt-BLE-GATT]] — 连接建立后的数据交互。
或者 → 去看 [[ble-smp-BLE-SMP配对]] — 安全配对和加密。

## 关联概念

- [[ble-gatt-BLE-GATT]] — 连接建立后的数据交互层
- [[ble-smp-BLE-SMP配对]] — 安全配对和链路加密
- [[ble-gatt-service-BLE-GATT-Service]] — 广播中通告的 Service UUID
- [[reglasses-architecture-reGlasses协议架构]] — BLE 在系统中的位置
- [[wq7036ax-chip-WQ7036AX芯片]] — BLE 射频硬件

#flashcard
问：BLE 广播包最大多少字节？
答：31 字节 (Advertising Data) + 31 字节 (Scan Response) = 总计 62 字节。

问：广播间隔短和长各有什么优缺点？
答：间隔短 → 手机发现快但耗电多。间隔长 → 省电但手机发现慢。reGlasses 正常模式 100ms，配网模式 30ms。

问：reGlasses 如何进入配网模式？
答：按键 B 长按 5 秒 → 广播间隔缩短到 30ms → 使用随机地址 → 120 秒后自动停止广播。
