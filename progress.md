# 进度日志

## 2026-07-17

### SPI 基础深度重写

- 修改文件：`20-HardwareProtocol-硬件协议/UART-I2C-SPI-GPIO-串口总线/spi-basics-SPI基础.md`
- 新增深度：
  - 原理：费曼传送带类比及边界、推挽 vs 开漏电气对比、全双工 dummy 字节原理
  - 约束：DCORE ≥ 4× SPI 频率、偶数分频、CPOL 决定 CLK 上下拉、auto_cs 手动/自动模式
  - SDK：真实 API `wq_spi_init/open/poll_transfer/poll_duplex_transfer/dma_transfer/dma_duplex_transfer/close/deinit`，替换了原文档中 5 个伪造 API（`spi_transfer`、`spi_init`、`spi_write`、`spi_read`、`gpio_set_level`）
  - 异常：DMA 超时检测机制、close 异步完成风险、RX FIFO 溢出、模式不匹配、字节序错误
  - 调试：7 步排查顺序、8 种典型故障表、信号完整性、DMA 超时诊断
  - 练习：5 个练习（波形分析、API 契约、ext_trans 数据流、模式不匹配分析、故障定位实验）
  - 自测：7 道题 + 5 张 flashcard
- SDK 证据：
  - `wqcore/driver/periph/common/hal/spi/wq_spi.h` — 全部真实 API 声明
  - `wqcore/driver/periph/common/hal/spi/wq_spi.c` — 状态机、DMA 管理、suspend/resume、ISR
  - `wqcore/driver/periph/bbb/hw/spi.h/.c` — 硬件层寄存器操作、FIFO、时序
  - `wq-adk/components/ext_trans/src/ext_trans_dev_spi.c` — 芯片间通信（Mode 1、DMA、手动 CS）
  - `wq-adk/examples/ext_loopback/acore/app/src/app_spi_trans.c` — 外部 DSP 固件加载（自定义协议、CRC、字节序）
- 验证：`git diff --check` 通过、24 围栏全部闭合、568 行
- 遗留缺口：reGlasses V861 当前 BSP 无 SPI 外设实例（`board.dts` 中无 SPI 设备节点），已在文档中明确标注

### UART 基础深度重写

- 修改文件：`20-HardwareProtocol-硬件协议/UART-I2C-SPI-GPIO-串口总线/uart-basics-UART基础.md`
- 新增深度：
  - 原理：异步采样时钟恢复、16× 过采样、起始位下降沿校准、波特率误差容忍度公式
  - 约束：FIFO 深度、中断阈值（RXFULL/RXTIMEOUT/TXEMPTY）、DMA vs 中断发送路径选择、共享 I/O 半双工方向切换
  - SDK：真实 API `wq_uart_init/open/write/register_rx_callback/read_dma/flow_control_config/dma_config/share_io_enable/close/deinit`，全部替换旧文档中的伪代码
  - 异常：RXFIFO 溢出、帧错误、断线检测、毛刺检测、DMA 超时、波特率误差累积
  - 调试：6 种中断的诊断价值表、7 步排查顺序、8 种典型故障表
  - 练习：5 个（波特率误差计算、TX 路径追踪、ext_trans 接收流程、V861 设备树分析、故障定位实验）
  - 自测：7 道题 + 4 张 flashcard
- SDK 证据：
  - `wqcore/driver/periph/common/hal/uart/wq_uart.h` — 全部真实 API 声明
  - `wqcore/driver/periph/common/hal/uart/wq_uart.c` — TX 链表队列、RX 中断状态机、DMA 路径、低功耗恢复、共享 I/O
  - `wq-adk/components/ext_trans/src/ext_trans_dev_uart.c` — 芯片间通信完整实现（DMA TX/RX、tx_list 管理）
  - `aiglass/reglasses/device/configs/reglasses/linux-6.6-xuantie/board.dts` — UART0 console、UART2 WQ-V861 桥接
- 验证：`git diff --check` 通过、18 围栏全部闭合、559 行

### GPIO 配置深度重写

- 修改文件：`20-HardwareProtocol-硬件协议/UART-I2C-SPI-GPIO-串口总线/gpio-config-GPIO配置.md`
- 新增深度：
  - 原理：推挽 vs 开漏输出结构（晶体管级解释）、浮空输入风险、上拉/下拉电阻计算、pinmux 复用矩阵
  - 约束：边沿中断 vs 电平中断选择、中断风暴原因与处理、去抖（硬件 RC + 软件定时器）、输出方向切换毛刺、AON GPIO 唤醒限制
  - SDK：真实 API `wq_gpio_init/open/open_as_interrupt/write/read/toggle/set_pull_mode/set_drive/int_enable/int_disable/wakeup_enable/get_wakeup_source/close/deinit`，替换旧文档中不存在的 API（`gpio_set_func`、`gpio_set_level`、`gpio_register_interrupt`）
  - 异常：中断风暴、GPIO 资源冲突（claim BUSY）、浮空误读、输出毛刺、唤醒失败
  - 调试：6 步排查顺序、7 种典型故障表、资源冲突诊断方法
  - 练习：5 个（万用表验证、资源管理追踪、按键电路分析、V861 设备树分析、毛刺定位实验）
  - 自测：7 道题 + 4 张 flashcard
- SDK 证据：
  - `wqcore/driver/periph/common/hal/gpio/wq_gpio.h` — 全部真实 API 声明
  - `wqcore/driver/periph/common/hal/gpio/wq_gpio.c` — ISR 遍历逻辑、状态管理、唤醒源查询
  - `wq_i2c.c` / `bbb/hw/spi.c` 中的 `gpio_claim`/`gpio_claim_group` 调用点 — 资源管理实战
  - `aiglass/reglasses/device/configs/reglasses/linux-6.6-xuantie/board.dts` — pinctrl 配置、TCA9539 GPIO 扩展器、按键/LED/中断引脚
- 验证：`git diff --check` 通过、22 围栏全部闭合、504 行

### 串口总线对比深度重写

- 修改文件：`20-HardwareProtocol-硬件协议/UART-I2C-SPI-GPIO-串口总线/uart-i2c-spi-compare-串口总线对比.md`
- 新增深度：电气结构对比（推挽/开漏决定速度上限和多设备能力）、真实 SDK 选型证据（4 个场景）、7 步选型决策框架、协议帧开销对比、错误检测能力对比
- 验证：`git diff --check` 通过、230 行

### I2S 协议深度重写

- 修改文件：`20-HardwareProtocol-硬件协议/I2S-PDM-Audio-音频接口/i2s-protocol-I2S协议.md`
- 新增深度：完整场景演算（16kHz/16-bit 逐拍时序）、四种数据格式 LRCK-DATA 时序图、Master/Slave 时钟责任、DMA 乒乓缓冲与欠载/溢出、reGlasses I2S0 设备树配置（PH7-PH10, no MCLK, V861 Master）
- SDK 证据：`wq_i2s_declare.h`（API）、`aud_i2s.c`（音频设备层）、`board.dts`（I2S0 配置）
- 验证：`git diff --check` 通过、329 行

### PDM 麦克风深度重写

- 修改文件：`20-HardwareProtocol-硬件协议/I2S-PDM-Audio-音频接口/pdm-mic-PDM麦克风.md`
- 新增深度：完整场景演算（声波→PDM 1-bit→抽取滤波→PCM 样本，含密度百分比计算）、L/R 边沿复用与 I2S LRCK 的概念区分、`wq_rx_pdm_sample_rate_set` 切换后需丢弃 10 个样本的 SDK 约束
- SDK 证据：`wq_pdm_declare.h`（API）、`aud_pdm.c`（音频设备层）
- 验证：`git diff --check` 通过、260 行

### I2S 时钟树和音频接口对比重写

- 修改文件：`i2s-clock-tree-I2S时钟树.md`（87 行）、`i2s-vs-pdm-音频接口对比.md`（79 行）
- 时钟树：PLL→分频器→BCLK/LRCK 链路、44.1k vs 48k 家族 PLL 匹配约束、Master/Slave 两种场景的时钟流向
- 对比：物理层对比、选型决策框架、reGlasses 三条音频链路的选择理由
- 已确认工作区为 `/home/ys/wq7036a/obsidian/嵌入式知识库2.0`。
- 已创建 `task_plan.md`、`findings.md`、`progress.md`。
- 已读取目标文档第 1—320 行，提炼出 9 类能力要求及嵌入式场景验收重点，记录到 `findings.md`。
- 已读完目标文档第 321—445 行，补充其对硬件事实、测试证据、AI 交付溯源、团队模板和高风险场景的要求。
- 已完成知识库初步统计：113 个 Markdown 文件，主题覆盖较广，但测试/踩坑入口明显偏薄。
- 统计项目目录时因文件名含空格导致一次 `wc` 报错，已记录并将改用 NUL 分隔统计。
- 已抽样阅读路线图、学习方法、数据手册阅读、测试、调试、OTA、可靠性、项目架构和 AI 推理等内容；确认教学结构较成熟，但真实硬件/测试/复盘/AI 交付证据不足。
- 已确认当前 vault 没有 reComputer/XIAO/SG2002/sscma/Node-RED 条目，主项目是 reGlasses/WQ7036AX + V881。
- 已完成目标能力与知识库现状的匹配矩阵：基础知识和当前项目教学较强，AI 委托、真实硬件证据、测试/复盘、变更治理和目标平台覆盖不足。
- 已形成 P0—P3 扩展规划：先建 AI 工程与证据闭环，再补硬件上下文/测试资产，随后用跨层垂直案例验收，最后持续维护。
- 已检查规划与目标文档要求的对应关系：问题意识、委托边界、验证前置、高风险治理、知识库上下文化、交付溯源六项均有对应动作。
- 根据对 I2C 原文的复核，校正整体判断：当前 2.0 是广度较好的高密度入门—中级提纲，不能称为各知识点都已讲透；后续路线应优先做核心知识深挖和配套实验，硬件资料作为后续验证上下文。
- 已运行 `git diff --check`，规划文件无空白错误；保留了工作区原有的 `.obsidian/workspace.json` 修改，未改动目标文档内容。
- 用户已授权全库文档重构；明确要求为费曼解释、术语解析和真实 SDK 代码讲解，代码来源为 `~/wq7036a` 与 `~/aiglass`。用户随后要求停止使用 DeepSeek，改由 Codex 直接修改。
- 已读取两套 SDK 的规则：WQ 代码根是 `wq-audio`；reGlasses 可编辑来源是 `/home/ys/aiglass/reglasses`，`tina-v861` 只能只读检索。
- 已记录三次模型调用编排失败；确认首批硬件协议目录没有留下改动，并清理了本次残留的 Claude/DeepSeek 进程。
- 已提取真实 SDK 锚点：WQ 的 `wq_i2c.h/.c`、`bbb/hw/i2c.h/.c`、glass 示例的 `app_light_sensor.c`；V861 的 `ov13b10_mipi.c`、reGlasses `board.dts` 和 TCA9539/TWI 配置。
- 当前开始直接重写首个深度样板：I2C 基础文档。
- 用户决定将后续工作交接给另一个 AI；已准备创建完整交接文档，明确改写规范、范围、SDK 证据、验收门槛和剩余执行顺序。
- 已创建《嵌入式知识库2.0-全库重构交接规范.md》（328 行）：包含目标能力链、全库范围、固定文档结构、费曼/术语/SDK 溯源标准、各协议最低深度、逐篇验收清单、执行顺序、操作纪律和交付报告格式。
- 已将任务计划中的后续执行者改为接手 AI，明确不再调用 DeepSeek；交接文档和计划均已通过 `git diff --check`。
