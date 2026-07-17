---
type: project
created: 2026-07-16
updated: 2026-07-17
tags: [project, reglasses, learning, plan, roadmap, 学习计划, 路线图]
aliases: [学习计划, 8周路线图, 学习路线, reGlasses学习路线]
---

# reGlasses 学习计划

**一句话结论**：这是一份 8 周学习计划，按顺序带你从零学完 WQ7036AX 上 reGlasses 项目涉及的所有协议和 SDK 代码。每周有明确目标和验收标准，配合 MOC 中的 checkbox 追踪进度。

---

## 30 秒先看懂

- 计划分 8 周，每周 4 个阶段：全局地图（第 1 周）→ UART 命令协议（第 2 周）→ 音频管道（第 3-4 周）→ BLE 蓝牙（第 5-6 周）→ 应用层集成（第 7-8 周）。
- 每周任务包括：读笔记、在 Source Insight 中看代码、做验收自检。
- 每天的流程是：5 分钟看 MOC 规划 → 1-2 小时学习文档+代码 → 10 分钟做验收检查。
- 该计划与 `reGlasses 协议学习` MOC 的阶段一一对应，MOC 中的 checkbox 就是你的进度追踪。
- 终点目标：能独立添加一条新命令，从手机到 V881 完整跑通。

---

## 学完以后应该能做什么

**第一遍学完**：
- 能画出 WQ7036AX、V881、手机的三方拓扑图，标注每条链路的协议
- 能在 Source Insight 中追踪一条 UART 命令从发送到接收的完整路径
- 能从 Source Insight 中追踪声音从麦克风到手机的完整路径
- 能用 nRF Connect 手机 APP 看到眼镜广播并读写 GATT Characteristic

**进阶目标**：
- 能独立添加一条新命令，从手机到 V881 跑通
- 能分析音频管道中的带宽瓶颈并优化
- 能理解 BLE 连接间隔和 MTU 对传输性能的影响

---

## 前置知识

- [[learning-methodology-学习方法论]] — 学习策略和 80/20 法则
- [[reglasses-architecture-reGlasses协议架构]] — 全局地图，先看这篇
- [[wq7036ax-chip-WQ7036AX芯片]] — 硬件平台基础

---

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 学习 MOC | Map of Content | 内容地图，用 checkbox 追踪学习进度的索引页 |
| Source Insight | SI | 代码阅读工具，用于在 SDK 中搜索和追踪代码 |
| 验收标准 | Acceptance Criteria | 每个阶段结束后检查自己是否达标的 checklist |
| 拓扑图 | Topology Diagram | 系统各设备间的连接关系图 |
| 端到端追踪 | End-to-End Trace | 从数据源到数据目的地的完整路径追踪 |

---

## 第一层：费曼心智模型

### 类比：一张旅行地图

这份学习计划就像一张 8 天的旅行地图：

| 阶段 | 类比 | 说明 |
|------|------|------|
| 第 1 周 | 看地图 | 了解整个城市（系统）的布局，几个区（手机/眼镜/主控）怎么连通 |
| 第 2 周 | 学坐公交 | 学会 UART 这条公交线路怎么坐 |
| 第 3-4 周 | 学机场流程 | 学会音频管道这条"航线"从安检到登机的完整流程 |
| 第 5-6 周 | 学用手机导航 | 学会 BLE 蓝牙这个"导航系统"怎么用 |
| 第 7-8 周 | 自己规划路线 | 能独立设计一条新路线（新命令）并跑通 |

### 每日学习流程

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

---

## 第二层：详细计划

### 第 1 周：搞清楚全局

> 目标：能画出 WQ7036AX ↔ V881 ↔ 手机 的三方拓扑图，说出每条链路用什么协议

| 任务 | 笔记 | 怎么做 |
|------|------|--------|
| 1 | [[reglasses-architecture-reGlasses协议架构]] | 读完整篇，画出拓扑图 |
| 2 | [[reglasses-bandwidth-reGlasses带宽约束]] | 记住 BLE ~1.4Mbps, WiFi ~100Mbps |
| 3 | [[wq7036ax-chip-WQ7036AX芯片]] | SI 打开 `cores.h`，认识 GPIO 引脚 |

**周末自检**：不看笔记，能画出拓扑图 + 说出 5 个引脚功能 → 过关。

### 第 2 周：UART 命令协议

> 目标：在 SI 中跟踪一条 UART 命令从发送到接收

| 任务 | 笔记 | SI 文件 |
|------|------|---------|
| 1 | [[uart-basics-UART基础]] | `wq_uart.c` → `wq_uart_init` / `wq_uart_write` |
| 2 | [[uart-basics-UART基础]] | `app_uart_cmd.c` → `uart_cmd_send` / `parse_byte` |
| 3 | [[ext-trans-Ext-Trans框架]] | `ext_trans_io.c` → `ext_trans_io_create` |
| 4 | STTP 协议（了解旧设计） | `sttp.c` → 作为对比参考 |

**周末自检**：能在 SI 中从 `STTP_Send` 一路跟到 UART FIFO 写入 → 过关。

### 第 3-4 周：音频管道

> 目标：追踪一个声音从麦克风到手机的完整路径

| 周 | 任务 | SI 文件 |
|----|------|---------|
| W3 | [[i2s-protocol-I2S协议]] + [[i2s-clock-tree-I2S时钟树]] | `audsys.h`, I2S 驱动 |
| W3 | [[pdm-mic-PDM麦克风]] | PDM 驱动, `CONFIG_AUDIO_SPK_FB_REF_PDM_CLK_ENABLE` |
| W3 | [[max98357a-MAX98357A功放]] + [[sdm0103b-SDM0103B数字麦]] | 硬件连接 |
| W4 | [[wq7036ax-audio-pipeline-WQ7036AX音频管道]] | `aud_sv_api.h`, `app_trans_down.c` |
| W4 | [[i2c-basics-I2C基础]] + [[elm2713-ELM2713光传感器]] | `wq_i2c.c`, ELM2713 驱动 |
| W4 | [[gpio-config-GPIO配置]] | GPIO 驱动, 按键/LED 组件 |

**周末自检**：能说出 PDM → PCM → DSP → Opus → BLE 的 5 步 → 过关。

### 第 5-6 周：BLE 蓝牙

> 目标：用手机 nRF Connect 看到眼镜广播，读写 GATT Characteristic

| 周 | 任务 | SI 文件 |
|----|------|---------|
| W5 | [[ble-gap-BLE-GAP广播]] | `wq_adv.c` → `wq_adv_set_adv_data` |
| W5 | [[ble-gatt-BLE-GATT]] | `ota_transport_ble.c` → `ble_init` |
| W6 | BLE GATT Service | `ota_transport_ble.c` → GATT 回调 |
| W6 | BLE SMP 配对 | `BT_smp_api.h` |

**周末自检**：手机 nRF Connect 能搜到 reGlasses、能读写 Characteristic → 过关。

### 第 7-8 周：应用层 + 系统集成

> 目标：独立添加一条新命令，从手机到 V881 跑通

| 周 | 任务 | SI 文件 |
|----|------|---------|
| W7 | [[wq-audio-protocol-WQ-Audio-Protocol]] | `wq_protocol.h` → `wq_proto_pkt_pack/unpack` |
| W7 | WQ Protocol 帧结构 + 服务类型 | `wq_protocol.h` 结构体 |
| W7 | 帧协议对比：STTP vs WQ Protocol | 对比理解 |
| W8 | [[reglasses-ext-commands-reGlasses扩展命令集]] | 新增命令 payload 设计 |
| W8 | [[reglasses-cross-chip-reGlasses跨芯片转发]] | `app_trans.c` → 路由逻辑 |
| W8 | [[dataflow-cmd-to-v881-手机指令到V881]] + [[dataflow-mic-to-phone-声音从麦到手机]] | 端到端串联 |

**周末自检**：能画出"手机按下录制→V881 启动摄像头"的完整时序图 → 毕业。

---

## 第三层：真实 SDK 代码路径

| 阶段 | 关键文件路径 |
|------|-------------|
| 全局 | `wqcore/chipset/bbb/include/cores.h` |
| UART | `wq-adk/examples/glass/acore/app/app_customer_ext_trans/app_uart_cmd.c` |
| 音频 | `wq-adk/components/audio_service/api/aud_sv_api.h` |
| 编解码 | `wqcore/components/codec_factory/` |
| BLE | `wq-adk/components/apps/acore/ota/src/ota_transport_ble.c` |
| 协议 | `wq-adk/components/wq_protocol/` |
| Ext Trans | `wq-adk/components/ext_trans/inc/ext_trans_io.h` |

---

## 第四层：常见学习障碍

| 问题 | 表现 | 建议 |
|------|------|------|
| 笔记太多看不完 | 焦虑、无从下手 | 先只看"一句话理解"和"30 秒先看懂" |
| SI 找不到文件 | 搜索无结果 | 先确认 project 路径配置正确，用 `Ctrl+Comma` 搜索 |
| 概念太多记不住 | 学完就忘 | 用 #flashcard 复习，做验收 checklist |
| 代码看不懂 | 函数调用链太深 | 先看 API 头文件注释，不要深入底层实现 |
| 缺乏实践 | 只看不练 | 一定要做"实战练习"中的题目 |

---

## 第五层：调试学习方法

- 每天花 5 分钟回顾前一天学的内容（用 #flashcard 自测）
- 每周日做周末自检，不过关的不要急着进入下一周
- 遇到不懂的概念用 `Ctrl+Click` 跳到关联笔记
- 对照笔记在 SI 中实际操作，不要只看不练
- 每学完一篇笔记，在 MOC 上打 ✅

---

## 第六层：实战练习

### 练习 1：制定本周计划

根据当前进度，从 8 周计划中选择本周应该完成的任务，列出：
- 本周要读的 3-5 篇笔记
- 本周要在 SI 中查看的 3 个关键文件
- 本周末的验收标准

### 练习 2：在 SI 中建立追踪路径

在 Source Insight 中建立一个"命令追踪"的路径，从 `ota_transport_ble.c` 的 `write_callback` 到 `app_uart_cmd.c` 的 `uart_cmd_send`，标注每个中间函数。

### 练习 3：验收自测

不看笔记，回答以下问题：
- 画出手机、WQ7036AX、V881 的三方拓扑图
- 画出声音从麦克风到手机的 5 个阶段
- 说出 BLE 连接后，控制指令和音频数据分别走哪个 Characteristic

### 练习 4：阅读真实源代码

打开 `wq-adk/components/apps/acore/ota/src/ota_transport_ble.c`，找到 `ble_init` 函数，分析 GATT Service 的注册流程。列出注册了哪些 Characteristic，以及每个 Characteristic 的用途。

---

## 自测与验收

1. 8 周计划分为哪几个阶段？每个阶段的核心目标是什么？
2. 每天的学习流程是什么？
3. 第 1 周结束后，你应该能做什么？
4. 第 8 周结束后，你应该能做什么？
5. 如果概念太多记不住，应该用什么方法复习？
6. 遇到看不懂的代码，应该怎么做？
7. 周末自检不过关怎么办？
8. 学习计划中提到的 Source Insight 文件搜索快捷键是什么？
9. 学习计划和 MOC 之间是什么关系？
10. 如何追踪自己的学习进度？

---

## 延伸阅读

- [[reGlasses 协议学习]] — MOC 主索引（有 checkbox）
- [[learning-methodology-学习方法论]] — 学习策略和 80/20 法则
- [[reglasses-architecture-reGlasses协议架构]] — 全局地图
- [[reglasses-bandwidth-reGlasses带宽约束]] — 带宽约束

#flashcard
问：8 周学习计划分为哪几个阶段？
答：第 1 周全局地图 → 第 2 周 UART 命令协议 → 第 3-4 周音频管道 → 第 5-6 周 BLE 蓝牙 → 第 7-8 周应用层集成。

问：每天的学习流程是什么？
答：开始 5 分钟（看 MOC + 读一句话理解）→ 学习 1-2 小时（按笔记操作 SI + 跳转关联笔记）→ 结束 10 分钟（做验收 checklist + 复习 flashcard + MOC 打勾）。

问：第 1 周结束后的验收标准是什么？
答：不看笔记，能画出手机、WQ7036AX、V881 的三方拓扑图，说出每条链路的协议，能说出 5 个引脚功能。

问：第 8 周结束后的验收标准是什么？
答：能画出"手机按下录制→V881 启动摄像头"的完整时序图，能独立添加一条新命令。

问：概念太多记不住怎么办？
答：用 #flashcard 复习，做验收 checklist，每天花 5 分钟回顾前一天的内容。