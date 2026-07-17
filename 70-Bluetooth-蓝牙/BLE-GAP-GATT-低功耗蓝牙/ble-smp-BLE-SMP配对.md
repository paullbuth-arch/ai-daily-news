---
type: concept
created: 2026-07-17
tags: [protocol, ble, smp, pairing, security, bonding, 蓝牙安全]
aliases: [BLE SMP, BLE 配对, 蓝牙配对, Security Manager Protocol]
---

# BLE SMP 配对

## 一句话结论

SMP（Security Manager Protocol，安全管理器协议）是 BLE 的安全层，负责配对（Pairing，建立加密密钥）、绑定（Bonding，存储密钥供下次使用）和链路加密。WQ7036AX 的 reGlasses 选择 Just Works 配对方式——用户只需点击"配对"，配合 Bonding 实现下次免配对。非金融场景下 Just Works 的安全性足够，IO Capability 配置为 NoInputNoOutput 触发 Just Works 流程。

## 30秒先看懂

- SMP 通过密钥交换实现 BLE 通信加密，默认 BLE 通信是明文的，任何人都可以监听。
- 配对流程分三个阶段：配对参数交换（IO Capability 协商）、密钥生成（STK/LTK）、可选的密钥分发。
- BLE 4.2+ 的 LE Secure Connections 使用 ECDH（椭圆曲线）密钥交换，比 Legacy 的 AES-CMAC 更安全。
- 绑定（Bonding）将 LTK 存储在 Flash 中，下次连接时自动加密，无需重新配对。
- Just Works 没有 MITM 保护，但对消费电子（耳机、眼镜）足够安全。

## 学完以后应该能做什么

### 第一遍
- 区分配对（Pairing）、绑定（Bonding）、加密（Encryption）三个概念
- 配置 WQ7036AX 的 SMP 参数（IO Capability、Bonding、SC）
- 理解 Just Works 配对流程的完整步骤

### 进阶
- 排查配对失败问题（IO Capability 不匹配、LTK 冲突）
- 实现安全级别的 GATT Characteristic（需要加密才能访问）
- 处理绑定信息冲突（手机端删除配对后设备端如何处理）

## 前置知识

- [[ble-gatt-BLE-GATT]]：配对成功后 GATT 通信自动加密
- [[ble-gap-BLE-GAP广播]]：配对前广播使用 Random Address 保护隐私
- [[wq7036ax-chip-WQ7036AX芯片]]：BCORE 固件实现 SMP 协议栈

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 安全管理器协议 | SMP (Security Manager Protocol) | BLE 协议栈中负责配对、密钥分发和加密的层 |
| 配对 | Pairing | 两个 BLE 设备建立共享密钥的过程 |
| 绑定 | Bonding | 将配对产生的密钥持久化存储，下次连接时复用 |
| 加密 | Encryption | 使用密钥对 BLE 通信进行 AES-CCM 加密 |
| 短期密钥 | STK (Short Term Key) | 当前连接使用的临时加密密钥，断开后丢弃 |
| 长期密钥 | LTK (Long Term Key) | 绑定后持久化存储的密钥，下次连接复用 |
| 中间人攻击 | MITM (Man-In-The-Middle) | 攻击者冒充通信双方截获或篡改数据 |
| 输入输出能力 | IO Capability | 设备的输入输出能力，决定配对方式 |
| 身份解析密钥 | IRK (Identity Resolving Key) | 用于解析随机地址对应真实设备身份的密钥 |
| 椭圆曲线 Diffie-Hellman | ECDH (Elliptic Curve Diffie-Hellman) | LE Secure Connections 使用的密钥交换算法 |

## 第一层费曼心智模型

### 类比：门锁和钥匙

SMP 就像给房子装门锁和配钥匙：

- **配对（Pairing）** = 第一次见面，你和室友互相交换家门钥匙（STK），约定以后用这把钥匙锁门
- **绑定（Bonding）** = 把对方的钥匙备份保存在保险箱（Flash）里，下次不用再见面交换
- **加密（Encryption）** = 每次出门都用钥匙锁门，别人打不开
- **Just Works** = 最简单的锁：你直接给室友一把钥匙，不需要验证他的身份（没有 MITM 保护）
- **Passkey Entry** = 你设了一个密码锁，室友输入正确密码才能拿到钥匙
- **Numeric Comparison** = 你和室友各自确认钥匙的指纹一致，确保没人调包
- **LTK** = 你家门锁的永久钥匙，只要不换锁就能一直用
- **STK** = 酒店临时房卡，退房（断开连接）后就失效了

### 边界

- Just Works 没有 MITM 保护——攻击者理论上可以在首次配对时冒充设备。但攻击者需要在物理附近，且配对窗口只有几十秒。
- 绑定后 LTK 存储在 Flash 中，如果 Flash 被物理读取，LTK 会被窃取。
- 加密是可选的——Characteristic 可以选择是否需要加密访问。配对不意味着所有通信都自动加密。
- 手机端删除配对后，设备端并不知道，下次连接时设备仍用旧 LTK 尝试加密，导致加密失败。

### 场景推演

**场景：用户第一次使用 reGlasses**

1. 手机打开 APP，搜索到眼镜，点击连接
2. 手机弹出"配对 reGlasses？"对话框
3. 用户点击"配对"
4. SMP 开始 Just Works 配对流程：
   - 手机发送 Pairing Request（IO=DisplayYesNo, Bonding=Yes, MITM=No）
   - 眼镜回复 Pairing Response（IO=NoInputNoOutput, Bonding=Yes, MITM=No）
   - 双方交换 ECDH 公钥，计算共享密钥
   - 生成 STK，链路开始 AES-CCM 加密
5. 配对完成，生成 LTK，存入 Flash
6. 下次连接时，直接用 LTK 恢复加密，无需再次配对

## 第二层原理/时序/约束

### 配对流程详解（Just Works + LE Secure Connections）

```
手机 (Central)                          WQ7036AX (Peripheral)
     │                                        │
     │  [Phase 1: 配对参数交换]                 │
     │── Pairing Request ────────────────────→│  ① IO Capability / Bonding / MITM
     │   IO=DisplayYesNo                      │
     │   Bonding=Yes                          │
     │   MITM=No                              │
     │   SC=Yes (LE Secure Connections)       │
     │                                        │
     │←── Pairing Response ──────────────────│  ② 回复自己的能力
     │   IO=NoInputNoOutput                   │
     │   Bonding=Yes                          │
     │   MITM=No                              │
     │   SC=Yes                               │
     │                                        │
     │  [Phase 2: 密钥生成]                    │
     │   [ECDH 公钥交换]                       │  ③ 椭圆曲线密钥协商
     │   [生成 DHKey]                         │     (不可窃听)
     │                                        │
     │── Pairing Confirm ────────────────────→│  ④ 确认值验证
     │←── Pairing Random ────────────────────│
     │                                        │
     │   [生成 STK = 128-bit AES-CCM 密钥]     │  ⑤ 链路加密开始
     │   [所有后续通信加密]                     │
     │                                        │
     │  [Phase 3: 密钥分发 (可选, Bonding)]    │
     │←── LTK + IRK + CSRK ─────────────────│  ⑥ 设备分发密钥
     │── LTK + IRK + CSRK ──────────────────→│  ⑦ 手机分发密钥
     │                                        │
     │   [密钥存入 Flash]                      │  ⑧ 绑定完成
```

### 四种配对方式对比

| 方式 | 需要什么 | MITM 保护 | 用户体验 | 适用场景 |
|------|---------|-----------|---------|---------|
| Just Works | 无 | 无 | 点"配对"即可 | 耳机、眼镜、手环 |
| Passkey Entry | 一方有键盘，一方有显示屏 | 有 | 输入 6 位 PIN | 键盘+手机 |
| Numeric Comparison | 双方都有显示屏 | 有（BLE 4.2+） | 对比两个 6 位数字 | 手机+手机 |
| OOB (Out Of Band) | NFC 等外带通道 | 最高 | 靠近即可 | 金融、门禁 |

### IO Capability 组合决定配对方式

| Initiator IO | Responder IO | 配对方式 |
|-------------|-------------|---------|
| DisplayYesNo（手机） | **NoInputNoOutput（眼镜）** | **Just Works** |
| KeyboardOnly（键盘） | DisplayOnly（显示屏） | Passkey Entry |
| DisplayYesNo（手机） | DisplayYesNo（手机） | Numeric Comparison |
| KeyboardOnly | NoInputNoOutput | Just Works（回退） |

### 密钥类型

| 密钥 | 全称 | 用途 | 存储位置 | 生命周期 |
|------|------|------|---------|---------|
| STK | Short Term Key | 当前连接的链路加密 | RAM | 连接断开即丢弃 |
| LTK | Long Term Key | 绑定后后续连接的加密 | Flash（持久化） | 直到用户删除配对 |
| IRK | Identity Resolving Key | 解析随机地址→真实地址 | Flash | 同上 |
| CSRK | Connection Signature Resolving Key | 数据签名验证 | Flash | 同上 |

### LE Secure Connections vs LE Legacy Pairing

| | LE Legacy (BLE 4.0/4.1) | LE Secure Connections (BLE 4.2+) |
|---|---|---|
| 密钥交换 | AES-CMAC（对称） | **ECDH（椭圆曲线，非对称）** |
| MITM 保护 | 弱（容易被破解） | 强（数学上安全） |
| 密钥长度 | 128 bit | 128 bit（但 ECDH 强度更高） |
| WQ7036AX | 不推荐 | **使用** |

## 第三层真实SDK代码

### WQ7036AX SMP 配置

WQ7036AX 的 SMP 参数通过 bt_service 层配置，参数结构体定义在 BCORE 固件中，ACORE 通过 API 配置：

```c
// SMP 配置参数结构体
typedef struct {
    uint8_t  io_cap;        // IO Capability: 0x03 = NoInputNoOutput
    uint8_t  bonding;       // 0x01 = Bonding 使能
    uint8_t  mitm;          // 0x00 = 不需要 MITM 保护
    uint8_t  sc;            // 0x01 = LE Secure Connections 使能
    uint8_t  keypress;      // 0x00 = 不需要按键通知
} smp_config_t;

// reGlasses 的 SMP 配置（Just Works + Bonding + SC）
smp_config_t cfg = {
    .io_cap   = 0x03,       // NoInputNoOutput → Just Works
    .bonding  = 0x01,       // 存储 LTK，下次免配对
    .mitm     = 0x00,       // 不需要 MITM 保护
    .sc       = 0x01,       // 使用 ECDH（BLE 4.2+ Secure Connections）
};

// 应用配置
bt_srv_smp_configure(&cfg);
```

### GATT Characteristic 加密权限设置

某些 Characteristic 可能需要加密才能访问，通过 GATT 权限字段控制：

```c
// 在注册 Characteristic 时设置权限
gatts_characteristic_t char_param = {0};
char_param.uuid.uuid_union.uuid_16 = 0x2001;
char_param.props = GATT_PROP_WRITE_WITHOUT_RSP;
char_param.permission = GATT_PERM_ENC;  // 需要加密才能访问
char_param.write_callback = write_callback;
character_rx = wq_gatts_register_characteristic(service, char_param);
```

### 底层 GATT API 中的密钥相关定义

位于 `/home/ys/wq7036a/wq-audio/wqcore/components/bluetooth/host/bbb/inc/wq_bt_gatt_api.h`：

```c
// GATT 权限定义（加密相关）
#define GATT_PERM_NONE      0x00  // 无加密要求
#define GATT_PERM_ENC       0x01  // 需要加密
#define GATT_PERM_AUTH      0x02  // 需要授权（配对验证）
#define GATT_PERM_ENC_MITM  0x03  // 需要加密 + MITM 保护
```

## 第四层正常/异常路径

### 正常路径

```
手机连接眼镜 → 发起配对请求
  → IO Capability 协商（Just Works）
  → ECDH 密钥交换
  → 生成 STK，链路加密
  → 分发 LTK/IRK/CSRK
  → 绑定完成
  ↓
下次连接：
  → 连接建立 → 加密恢复（使用 LTK）→ 无需重新配对
```

### 异常路径

| 异常 | 现象 | 原因 | 排查方法 |
|------|------|------|---------|
| 配对失败 | 手机显示"配对失败" | IO Capability 组合不支持 | HCI Log 看 SMP 协商过程 |
| 绑定后重连失败 | 重连后无法加密 | 手机端删除了配对，但设备端还保留旧 LTK | 清除设备端绑定信息 |
| 加密后通信变慢 | 吞吐量下降 | 加密后每个包增加 4 字节 MIC | 查看 ACL 包大小，调整 MTU |
| 设备删除配对后无法重连 | 连接后无法加密 | 设备端还不知道手机端已删除配对 | 实现配对信息冲突检测 |
| 配对窗口超时 | 配对流程中断 | 用户未在超时前操作 | 延长配对超时时间 |

## 第五层调试方法

### HCI Log 分析 SMP 协商

```bash
# 抓取 HCI 日志
sudo btmon -w smp_trace.log

# 过滤 SMP 相关事件
btmon -r smp_trace.log | grep -A 5 "Pairing"
```

### 常见 SMP 错误码

| 错误码 | 含义 | 说明 |
|--------|------|------|
| 0x01 | 密码错误 | Passkey Entry 时 PIN 不匹配 |
| 0x02 | OOB 数据不可用 | OOB 配对时缺少数据 |
| 0x03 | 认证要求 | 对方要求的认证方式不支持 |
| 0x04 | 确认值失败 | 密钥协商不一致 |
| 0x05 | 配对不支持 | 对方不支持配对 |
| 0x06 | 加密密钥大小 | 密钥长度不符合要求 |
| 0x07 | 命令不支持 | 不支持的 SMP 命令 |
| 0x08 | 配对失败 | 未指定原因 |

### WQ7036AX 日志

```c
// 在配对回调中添加日志
#define LOG_TAG "[smp] "
#include "app_log.h"

void on_pairing_state_change(pairing_state_t state) {
    switch (state) {
    case PAIRING_STARTED:
        LOGI("Pairing started");
        break;
    case PAIRING_COMPLETE:
        LOGI("Pairing complete");
        break;
    case PAIRING_FAILED:
        LOGE("Pairing failed");
        break;
    case ENCRYPTION_CHANGED:
        LOGI("Encryption changed");
        break;
    }
}
```

## 第六层实战练习

### 练习1：修改 SMP 配置

编写代码将 reGlasses 的 SMP 配置从 Just Works 改为 Passkey Entry（固定 PIN 码 123456）：

```c
// 提示：IO Capability 需要改为 KeyboardOnly（Initiator）或 DisplayOnly（Responder）
// 请补全
void configure_passkey_pairing(void) {
    smp_config_t cfg = {
        // 设置 IO Capability 为 DisplayOnly（0x01）
        // 使能 Bonding
        // 使能 MITM 保护
        // 使用 LE Secure Connections
    };
    // 设置固定 PIN 码为 123456
    bt_srv_smp_configure(&cfg);
}
```

### 练习2：阅读 SDK 源码分析配对信息存储

在 `/home/ys/wq7036a/wq-audio/wqcore/components/bluetooth/` 目录下搜索与 bonding 和 LTK 存储相关的代码，分析：
- 绑定信息存储在 Flash 的哪个分区？
- 如何手动清除设备端的绑定信息？
- 重新配对时旧 LTK 如何处理？

### 练习3：实现加密 Characteristic 访问控制

编写代码，创建一个需要加密才能访问的 Characteristic，并在未加密访问时返回错误：

```c
// 注册一个需要加密的 Characteristic（GATT_PERM_ENC）
// 在 read_callback 中检查当前连接是否已加密
// 如果未加密，返回错误码 0x05 (Insufficient Authentication)
// 请补全
static WQ_RET encrypted_read_callback(uint16_t conn_handle, uint16_t char_handle) {
    // 检查连接是否已加密
    // 如果未加密，返回 WQ_RET_ERR_AUTH
    // 如果已加密，返回敏感数据
}
```

## 自测与验收

1. 配对（Pairing）、绑定（Bonding）、加密（Encryption）三个概念有什么区别？
2. Just Works 配对方式有什么安全风险？reGlasses 为什么选择 Just Works？
3. LE Secure Connections 和 LE Legacy Pairing 的核心区别是什么？
4. WQ7036AX 的 SMP 配置中，IO Capability 设置为 0x03 代表什么？会触发哪种配对方式？
5. 手机端删除配对后，设备端为什么可能无法重新连接？如何解决？

## 延伸阅读

- [[ble-gatt-BLE-GATT]] — 配对后 GATT 通信自动加密
- [[ble-gap-BLE-GAP广播]] — 配对前广播使用 Random Address 保护隐私
- [[bt-debug-蓝牙调试]] — 用 HCI Log 排查配对失败问题
- [[classic-bluetooth-经典蓝牙]] — 经典蓝牙的配对方式
- `/home/ys/wq7036a/wq-audio/wqcore/components/bluetooth/` — 蓝牙协议栈源码
- `/home/ys/wq7036a/wq-audio/wq-adk/components/bt_service/` — BT 服务层 API

#flashcard
问：配对、绑定、加密三个概念的区别？
答：配对 = 建立共享密钥的过程。绑定 = 将密钥持久化存储。加密 = 使用密钥对通信进行加密。

问：Just Works 有什么安全风险？
答：没有 MITM 保护，攻击者理论上可以在首次配对时冒充设备。但攻击者需要在物理附近，且配对窗口短。

问：LE Secure Connections 相比 Legacy 的改进是什么？
答：使用 ECDH（椭圆曲线）非对称密钥交换代替 AES-CMAC 对称密钥，MITM 保护在数学上安全。

问：IO Capability 为 NoInputNoOutput 时触发哪种配对方式？
答：触发 Just Works 配对方式，不需要用户输入，是最简单的配对方式。

问：STK 和 LTK 的区别是什么？
答：STK 是短期密钥，当前连接使用，断开即丢弃。LTK 是长期密钥，绑定后持久化存储，下次连接复用。