---
type: concept
created: 2026-07-16
tags: [protocol, ble, smp, security, pairing, bluetooth]
aliases: [SMP, BLE 配对, BLE 安全]
---

# BLE SMP 配对

## 是什么

**Security Manager Protocol (SMP)** — BLE 协议栈中负责**配对 (Pairing)、绑定 (Bonding) 和链路加密**的安全层。

## 三种配对方式

| 方式 | 安全性 | 用户体验 | reGlasses 选择 |
|------|--------|----------|---------------|
| **Just Works** | 中 (无 MITM 保护) | 最简：点"配对"即可 | ✅ 选择此项 |
| Passkey Entry | 高 | 需输入 6 位 PIN | — |
| Numeric Comparison | 高 (BLE 4.2+) | 对比两个数字 | — |
| OOB | 最高 | NFC 等外带通道 | — |

## reGlasses 安全策略

| 参数 | 值 | 说明 |
|------|------|------|
| 配对方式 | Just Works | 消费电子级，最简单 |
| MITM 保护 | 否 | 非金融/医疗场景 |
| 绑定 (Bonding) | **是** | 存储 LTK，下次免配对 |
| LE Secure Connections | 是 | ECDH 密钥协商 (BLE 4.2+) |
| 加密 | AES-CCM | 链路层加密 |

## 配对流程

```
手机 (Central)                  WQ7036AX (Peripheral)
     │                                │
     │── Pairing Request ────────────→│
     │   (IO Capability, Bonding)    │
     │                                │
     │←── Pairing Response ──────────│
     │   (IO Capability)             │
     │                                │
     │   [Just Works: 自动生成密钥]    │
     │   [ECDH 密钥交换]              │
     │                                │
     │── Pairing Confirm ────────────→│
     │←── Pairing Random ────────────│
     │                                │
     │   [生成 STK (Short Term Key)]  │
     │   [链路开始加密]                │
     │                                │
     │   [Bonding: 存储 LTK]          │
     │   [下次连接免配对]              │
```

## 密钥类型

| 密钥 | 用途 | 存储 |
|------|------|------|
| STK (Short Term Key) | 当前连接加密 | 不持久化 |
| LTK (Long Term Key) | 绑定后后续连接 | 持久化 (Bonding) |
| IRK (Identity Resolving Key) | 解析随机地址 | 持久化 |
| CSRK (Connection Signature Resolving Key) | 数据签名 | 持久化 |

## 关联概念

- [[BLE GATT]] — 配对后 GATT 通信自动加密
- [[BLE GAP 广播]] — 配对前广播使用 Random Address 保护隐私
- [[mbedTLS]] — SDK 中加密库支持
- [[reGlasses 协议架构]] — 安全在整个系统中的位置

#flashcard
问：reGlasses 选择哪种 BLE 配对方式？为什么？
答：Just Works。因为消费电子场景不需要高安全等级，Just Works 用户体验最简单（点"配对"即可），配合 Bonding 存储 LTK 实现下次免配对。

问：Bonding 的作用是什么？
答：存储 LTK（Long Term Key），下次连接时自动加密，无需重新配对。
