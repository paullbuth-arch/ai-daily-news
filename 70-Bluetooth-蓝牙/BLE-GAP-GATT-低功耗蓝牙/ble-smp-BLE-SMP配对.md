# BLE SMP 配对

**一句话结论（20% 核心）**：SMP（Security Manager Protocol）是 BLE 的安全层，负责配对（Pairing，建立加密密钥）、绑定（Bonding，存储密钥供下次用）、链路加密。reGlasses 选择 Just Works 配对方式——最简单，用户只需点"配对"，配合 Bonding 实现下次免配对。非金融场景不需要高安全等级。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：门锁和钥匙

- **配对（Pairing）** = 第一次见面，双方交换钥匙（STK），建立加密通信
- **绑定（Bonding）** = 把对方的钥匙存起来（LTK），下次见面不用重新交换
- **加密（Encryption）** = 每次对话都用钥匙加密，旁人听不懂

**如果不配对**：通信是明文的，任何人在旁边都能窃听。BLE 的广播和 GATT 通信默认不加密。

### 1.2 四种配对方式

| 方式 | 安全性 | 用户体验 | 需要什么 | 适用场景 |
|------|--------|---------|---------|---------|
| **Just Works** | 中（无 MITM 保护） | 点"配对"即可 | 无 | 消费电子、耳机、**reGlasses** |
| **Passkey Entry** | 高 | 输入 6 位 PIN | 一方有键盘，一方有显示屏 | 键盘+手机配对 |
| **Numeric Comparison** | 高（BLE 4.2+） | 对比两个 6 位数字 | 双方都有显示屏 | 手机+手机 |
| **OOB** | 最高 | 通过 NFC 等外带通道 | 需要 NFC 硬件 | 金融、门禁 |

**MITM 保护**：防止中间人攻击（有人冒充对方和你配对）。Just Works 没有 MITM 保护——攻击者理论上可以截获配对过程。但消费电子场景（耳机、眼镜）不需要担心这个。

### 1.3 配对流程（Just Works + LE Secure Connections）

```
手机 (Central)                  WQ7036AX (Peripheral)
     │                                │
     │── Pairing Request ────────────→│  ① 交换 IO Capability
     │   IO=DisplayYesNo             │     (Just Works = NoInputNoOutput)
     │   Bonding=Yes                  │
     │   MITM=No                      │
     │                                │
     │←── Pairing Response ──────────│  ② 确认配对参数
     │   IO=NoInputNoOutput          │
     │                                │
     │   [ECDH 公钥交换]               │  ③ 椭圆曲线 Diffie-Hellman
     │   [生成共享密钥]                │     密钥协商（安全，不可窃听）
     │                                │
     │── Pairing Confirm ────────────→│  ④ 确认值（验证双方得到相同密钥）
     │←── Pairing Random ────────────│
     │                                │
     │   [生成 STK (Short Term Key)]  │  ⑤ 短期密钥用于当前连接加密
     │   [链路开始 AES-CCM 加密]       │
     │                                │
     │   [Bonding: 存储 LTK]          │  ⑥ 长期密钥存入 Flash
     │   [下次连接免配对]              │
```

### 1.4 密钥类型

| 密钥 | 全称 | 用途 | 存储位置 | 生命周期 |
|------|------|------|---------|---------|
| **STK** | Short Term Key | 当前连接的链路加密 | RAM | 连接断开即丢弃 |
| **LTK** | Long Term Key | 绑定后后续连接的加密 | Flash（持久化） | 直到用户删除配对 |
| **IRK** | Identity Resolving Key | 解析随机地址→真实地址 | Flash | 同上 |
| **CSRK** | Connection Signature Resolving Key | 数据签名验证 | Flash | 同上 |

### 1.5 如果只记得一件事

> BLE 配对 = 双方交换密钥建立加密通信。Just Works = 最简单，无 MITM 保护（消费电子够用）。Bonding = 存 LTK，下次免配对。SMP 协商失败 → 检查 IO Capability 是否匹配。

---

## 第二层：实战理解

### 2.1 WQ7036AX 的 SMP 配置

```c
// WQ7036AX BLE 配对参数配置（在 bt_service 中）
typedef struct {
    uint8_t  io_cap;        // IO Capability: 0x03 = NoInputNoOutput
    uint8_t  bonding;       // 0x01 = Bonding 使能
    uint8_t  mitm;          // 0x00 = 不需要 MITM 保护
    uint8_t  sc;            // 0x01 = LE Secure Connections 使能
    uint8_t  keypress;      // 0x00 = 不需要按键通知
} smp_config_t;

smp_config_t cfg = {
    .io_cap   = 0x03,       // NoInputNoOutput → Just Works
    .bonding  = 0x01,       // 存储 LTK，下次免配对
    .mitm     = 0x00,       // 不需要 MITM
    .sc       = 0x01,       // 使用 ECDH（BLE 4.2+）
};

bt_srv_smp_configure(&cfg);
```

### 2.2 IO Capability 组合决定配对方式

| Initiator IO | Responder IO | 配对方式 |
|-------------|-------------|---------|
| DisplayYesNo（手机） | NoInputNoOutput（耳机） | **Just Works** |
| KeyboardOnly（键盘） | DisplayOnly（显示屏） | Passkey Entry |
| DisplayYesNo（手机） | DisplayYesNo（手机） | Numeric Comparison |
| KeyboardOnly | KeyboardOnly | Just Works（回退） |

### 2.3 常见坑

| 问题 | 现象 | 排查方法 | 根因 |
|------|------|---------|------|
| 配对失败 | 手机端显示"配对失败" | HCI Log 看 SMP 协商过程 | IO Capability 组合不支持，或双方都 NoInputNoOutput 且设备不支持 Just Works |
| 绑定后重连失败 | 重连后无法加密 | 检查 LTK 是否存储正确 | 更换了绑定信息（如在手机端删除了配对），但设备端还保留旧 LTK |
| 加密后通信变慢 | 吞吐量下降 | 查看 ACL 包大小 | 加密后每个包有 4 字节 MIC，有效载荷减少 |
| 设备删除配对后无法重连 | 连接后无法加密 | 清除设备端绑定信息 | 手机端删除了配对，但设备端不知道，仍用旧 LTK 加密 |

### 2.4 在 reGlasses 项目中怎么用

reGlasses 的安全策略：**Just Works + Bonding + LE Secure Connections**。

这是消费电子产品的标准配置：
- 用户第一次连接：手机弹出"配对 reGlasses？" → 点"是" → 完成
- 之后每次连接：自动加密，无需任何操作
- 用户在手机端删除配对 → 下次需要重新配对

WQ7036AX 的 BCORE 固件负责 SMP 协议栈，ACORE 通过 bt_service API 配置配对参数。

---

## 第三层：深入扩展

### 3.1 LE Secure Connections vs LE Legacy Pairing

| | LE Legacy (BLE 4.0/4.1) | LE Secure Connections (BLE 4.2+) |
|---|---|---|
| 密钥交换 | AES-CMAC | **ECDH（椭圆曲线）** |
| MITM 保护 | 弱 | 强 |
| 密钥长度 | 128 bit | 128 bit（但 ECDH 强度更高） |
| reGlasses | 不推荐 | **使用** |

### 3.2 常见问题

- **Just Works 的安全性够吗？** 对于消费电子（耳机、眼镜、手环）足够。对于金融支付、医疗设备、门禁系统，需要 Passkey 或 OOB。Just Works 的主要风险是首次配对时被中间人攻击——但攻击者需要在物理附近，且配对窗口只有几十秒。
- **Bonding 存储的 LTK 会被窃取吗？** LTK 存储在芯片 Flash 的安全区域。如果攻击者能物理读取 Flash，那任何安全措施都没用。软件层面，LTK 不会通过任何 API 暴露给应用层。
- **为什么有些设备配对后 GATT 还是明文？** 配对只建立加密密钥，但加密是可选的。设备可以选择哪些 Characteristic 需要加密（通过 GATT 权限设置），其余的仍然明文。

### 3.3 延伸阅读

- [[ble-gatt-BLE-GATT]] — 配对后 GATT 通信自动加密
- [[ble-gap-BLE-GAP广播]] — 配对前广播使用 Random Address 保护隐私
- [[bt-debug-蓝牙调试]] — 用 HCI Log 排查配对失败问题