---
type: project
created: 2026-07-16
tags: [project, reglasses, learning, plan, roadmap, 学习计划]
aliases: [学习计划, 8 周路线图, 学习路线]
---

# reGlasses 学习计划

## 这是什么

一份 **8 周学习计划**，带你从零开始，按顺序学完 WQ7036AX 涉及的所有协议。每周有明确目标、要看的 SI 文件、和验收标准。

> ⚠️ 这份计划和 [[reGlasses 协议学习]] MOC 的阶段一一对应。MOC 里的 checkbox 就是你的进度追踪。

## 第 1 周：搞清楚全局

> 目标：能画出 WQ7036AX ↔ V881 ↔ 手机 的三方拓扑图，说出每条链路用什么协议

| 任务 | 笔记 | 怎么做 |
|------|------|--------|
| 1 | [[reGlasses 协议架构]] | 读完整篇，画出拓扑图 |
| 2 | [[reGlasses 带宽约束]] | 记住 BLE ~1.4Mbps, WiFi ~100Mbps |
| 3 | [[WQ7036AX 芯片]] | SI 打开 `cores.h`，认识 GPIO 引脚 |

**周末自检**：不看笔记，能画出拓扑图 + 说出 5 个引脚功能 → 过关。

## 第 2 周：UART 命令协议

> 目标：在 SI 中跟踪一条 UART 命令从发送到接收

| 任务 | 笔记 | SI 文件 |
|------|------|---------|
| 1 | [[UART 基础]] | `wq_uart.c` → `wq_uart_init` / `wq_uart_write` |
| 2 | [[UART 命令协议]] | `app_uart_cmd.c` → `uart_cmd_send` / `parse_byte` |
| 3 | [[Ext Trans 框架]] | `ext_trans_io.c` → `ext_trans_io_create` |
| 4 | [[STTP 协议]] (了解旧设计) | `sttp.c` → 作为对比参考 |

**周末自检**：能在 SI 中从 `STTP_Send` 一路跟到 UART FIFO 写入 → 过关。

## 第 3-4 周：音频管道

> 目标：追踪一个声音从麦克风到手机的完整路径

| 周 | 任务 | SI 文件 |
|----|------|---------|
| W3 | [[I2S 协议]] + [[I2S 时钟树]] | `audsys.h`, I2S 驱动 |
| W3 | [[PDM 麦克风]] | PDM 驱动, `CONFIG_AUDIO_SPK_FB_REF_PDM_CLK_ENABLE` |
| W3 | [[MAX98357A 功放]] + [[SDM0103B 数字麦]] | 硬件连接 |
| W4 | [[WQ7036AX 音频管道]] | `aud_sv_api.h`, `app_trans_down.c` |
| W4 | [[I2C 基础]] + [[ELM2713 光传感器]] | `wq_i2c.c`, ELM2713 驱动 |
| W4 | [[GPIO 配置]] | GPIO 驱动, 按键/LED 组件 |

**周末自检**：能说出 PDM → PCM → DSP → Opus → BLE 的 5 步 → 过关。

## 第 5-6 周：BLE 蓝牙

> 目标：用手机 nRF Connect 看到眼镜广播，读写 GATT Characteristic

| 周 | 任务 | SI 文件 |
|----|------|---------|
| W5 | [[BLE GAP 广播]] | `wq_adv.c` → `wq_adv_set_adv_data` |
| W5 | [[BLE GATT]] | `ota_transport_ble.c` → `ble_init` |
| W6 | [[BLE GATT Service]] | `ota_transport_ble.c` → GATT 回调 |
| W6 | [[BLE SMP 配对]] | `BT_smp_api.h` |

**周末自检**：手机 nRF Connect 能搜到 reGlasses、能读 Write Characteristic → 过关。

## 第 7-8 周：应用层 + 系统集成

> 目标：独立添加一条新命令，从手机到 V881 跑通

| 周 | 任务 | SI 文件 |
|----|------|---------|
| W7 | [[WQ Audio Protocol]] | `wq_protocol.h` → `wq_proto_pkt_pack/unpack` |
| W7 | [[WQ Protocol 帧结构]] + [[WQ Protocol 服务类型]] | `wq_protocol.h` 结构体 |
| W7 | [[帧协议对比：STTP vs WQ Protocol]] | 对比理解 |
| W8 | [[reGlasses 扩展命令集]] | 新增命令 payload 设计 |
| W8 | [[reGlasses 跨芯片指令转发]] | `app_trans.c` → 路由逻辑 |
| W8 | [[数据流：手机指令到 V881]] + [[数据流：声音从麦到手机]] | 端到端串联 |

**周末自检**：能画出"手机按下录制→V881 启动摄像头"的完整时序图 → 毕业。

## 每日学习流程

```
开始 (5 分钟):
  1. 打开 MOC → 看今天要学哪个
  2. 打开对应笔记 → 读"一句话理解"

学习 (1-2 小时):
  3. 按笔记中的"第 N 步"在 SI 中操作
  4. 不理解的名词 → Ctrl+Click 跳到关联笔记
  5. 记录不懂的问题 → Daily Note

结束 (10 分钟):
  6. 做验收标准 checklist
  7. 复习 #flashcard
  8. MOC 上打 ✅
```

## 关联概念

- [[reGlasses 协议学习]] — MOC 主索引 (有 checkbox)
- [[学习方法论与二八定律]] — 学习策略
- [[reGlasses 协议架构]] — 全局地图
