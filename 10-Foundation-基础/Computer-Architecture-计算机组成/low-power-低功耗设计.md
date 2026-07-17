---
type: concept
tags: [embedded, low-power, power-management, clock-gating, dvfs, tickless]
aliases: [低功耗设计, 省电, 睡眠模式, 电源管理]
---

# 低功耗设计

## 一句话结论

低功耗设计的核心思想是"能关则关、能慢则慢、能睡则睡"——让 MCU 在不工作的时候进入低功耗模式，只在需要时被唤醒。功耗 = 动态功耗（跑的时候耗电） + 静态功耗（睡着也耗电），两者都要优化。

## 30秒先看懂

- 功耗分为动态功耗（CPU 运行、总线传输、外设工作时产生）和静态功耗（晶体管漏电，即使不工作也存在）。动态功耗公式 P = C x V^2 x f，降低电压比降低频率更有效（电压是平方关系）。MCU 常见低功耗模式从高到低依次是：运行模式、睡眠模式（CPU 停，RAM 保持，唤醒快）、深度睡眠模式（大部分电路断电，RAM 部分保持，唤醒慢）和待机模式（几乎完全断电，唤醒最慢）。WQ7036A 作为音频 SoC 有一套完整的低功耗策略：核级关断（DCORE 不用时完全断电）、外设时钟门控、音频 DMA 低功耗模式、BLE 低功耗广播和 KWS 低功耗唤醒。

## 学完以后应该能做什么

**第一遍看完后可以：**
- 理解功耗的两个组成部分和优化方法
- 知道 MCU 的几种低功耗模式及其区别
- 学会使用时钟门控关掉不用的外设
- 理解 FreeRTOS Tickless Idle 的原理

**进阶后可以：**
- 为电池供电产品做功耗预算
- 设计 DVFS 策略，根据负载动态调整频率
- 配置 WQ7036A 的 KWS 低功耗唤醒
- 使用功耗分析仪测量和优化功耗

## 前置知识

- MCU 的基本组成（CPU、时钟、外设）
- 中断和唤醒源的概念
- FreeRTOS 空闲任务

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 时钟门控 | Clock Gating | 关闭不用外设的时钟，减少动态功耗 |
| 电源门控 | Power Gating | 切断不用模块的电源，消除静态功耗 |
| 动态电压频率调整 | DVFS | Dynamic Voltage and Frequency Scaling，根据负载调整电压和频率 |
| 睡眠模式 | Sleep Mode | CPU 停止执行，但 RAM 和 CPU 状态保持，唤醒快 |
| 深度睡眠 | Deep Sleep | 大部分电路断电，仅保留部分 RAM 和唤醒逻辑 |
| 等待中断 | WFI | Wait For Interrupt，CPU 暂停直到中断唤醒 |
| 唤醒源 | Wake-up Source | 能够从睡眠模式唤醒 CPU 的事件（如 RTC、GPIO 中断） |
| 无 Tick 空闲 | Tickless Idle | RTOS 在空闲时不再周期性触发 Tick 中断 |
| 语音活动检测 | VAD | Voice Activity Detection，检测到人声才启动音频处理 |
| 唤醒词检测 | KWS | Keyword Spotting，低功耗模式下检测特定唤醒词 |

## 第一层：费曼心智模型

### 类比：省电生活

低功耗就像日常省电：

| 省电行为 | MCU 低功耗策略 |
|---------|---------------|
| 不用的电器拔掉插头 | 关闭不用外设的时钟（Clock Gating） |
| 夏天空调开 26 度不用 16 度 | 降低 CPU 主频（DVFS） |
| 人不在家就关灯 | 进入睡眠模式（Sleep / Deep Sleep） |
| 闹钟响了再起床 | 配置唤醒源（Wake-up Source） |

**边界：**
- 省电和性能是 trade-off——睡得太深，唤醒就慢；频率太低，任务可能来不及处理
- 不是所有外设都能随便关——有些外设虽然你不用，但系统需要（如看门狗）
- 不要频繁进出睡眠——进出睡眠有功耗开销，太频繁反而不省电

### 场景演练：蓝牙耳机播放音乐

1. 用户按下播放键
2. ACORE 唤醒 DCORE（电源门控开启）
3. DCORE 加载音频算法，开始处理音频流
4. DMA 从 PDM 麦克风搬运音频数据到 DSP 缓冲区
5. DSP 处理完数据，通过 DMA 送到 I2S 输出
6. 在 DMA 搬运期间，ACORE 进入睡眠（WFI）
7. DMA 传输完成中断唤醒 ACORE
8. 歌曲播完，DCORE 断电，系统进入深度睡眠
9. 只有 BLE 保持低功耗连接，等待手机命令

## 第二层：原理/时序/约束

### 功耗公式

动态功耗：P = C x V^2 x f
- C = 负载电容（芯片设计决定，不可调）
- V = 供电电压（可调，但受限于工艺和频率）
- f = 时钟频率（可调，降低频率线性降低功耗）

**结论**：降电压比降频率更有效（V 是平方关系）。但电压不能无限降低——频率越高，所需的最低电压也越高。

### 低功耗模式对比

| 模式 | 功耗 | 唤醒速度 | 保留内容 | 唤醒源 |
|------|------|---------|---------|--------|
| 运行（Run） | 最高 | 无 | 全部 | — |
| 睡眠（Sleep） | 较低（mA 级） | 快（μs） | CPU 状态、RAM | 任何中断 |
| 深度睡眠（Deep Sleep） | 很低（μA 级） | 较慢（ms） | RAM | RTC/GPIO 中断 |
| 待机（Standby） | 最低（nA 级） | 最慢（等同于上电） | 部分寄存器/RTC | RTC/GPIO |

### FreeRTOS Tickless Idle

```c
// FreeRTOSConfig.h
#define configUSE_TICKLESS_IDLE 1

// 效果：如果所有任务都在等待，CPU 进入睡眠直到最近的任务需要运行
// 比如最近的任务 100ms 后才就绪，CPU 就睡 100ms，不再每 1ms 醒一次
```

### 时钟门控示例

```c
// 初始化时只开需要的外设
void system_init(void) {
    clk_enable(CLK_GPIO);   // GPIO 必须开
    clk_enable(CLK_UART1);  // 调试串口
    // 其他不用外设的时钟不开
}

// 使用某个外设时才开时钟，用完立即关
void use_sensor(void) {
    clk_enable(CLK_I2C1);
    i2c_read(sensor_addr);
    clk_disable(CLK_I2C1);
}
```

## 第三层：真实 SDK 代码

### WQ7036A 电源管理

WQ7036A 的电源管理模块在 `/home/ys/wq7036a/wq-audio/wqcore/components/power_mgnt/` 下：

```c
// /home/ys/wq7036a/wq-audio/wqcore/components/power_mgnt/inc/power_mgnt.h
// 核心电源管理 API

// 系统睡眠
void power_enter_sleep(void);

// 深度睡眠
void power_enter_deep_sleep(uint32_t wakeup_pins);

// 配置唤醒源
void power_set_wakeup_source(uint32_t source_mask);

// 复位原因查询
uint32_t power_get_reset_reason(void);
```

### 外设时钟门控

外设时钟控制通过写寄存器实现，参考 `/home/ys/wq7036a/wq-audio/wqcore/chipset/bbb/regs/pmu_pin_reg.h`：

```c
// 时钟使能寄存器
#define CLK_ENABLE_REG    (PMU_BASE + 0x00)
#define CLK_DISABLE_REG   (PMU_BASE + 0x04)

#define CLK_UART1_BIT     (1 << 0)
#define CLK_I2C1_BIT      (1 << 1)
#define CLK_SPI1_BIT      (1 << 2)
#define CLK_I2S_BIT       (1 << 3)

static inline void clk_enable(uint32_t clk_bit) {
    *(volatile uint32_t *)CLK_ENABLE_REG = clk_bit;
}

static inline void clk_disable(uint32_t clk_bit) {
    *(volatile uint32_t *)CLK_DISABLE_REG = clk_bit;
}
```

### 看门狗与低功耗

低功耗模式下看门狗的处理，参考 `/home/ys/wq7036a/wq-audio/wqcore/driver/periph/common/hal/wdt/wq_wdt.h`：

```c
// 进入睡眠前暂停看门狗
void wq_wdt_disable(void);

// 唤醒后重新开启看门狗
void wq_wdt_enable(void);
```

## 第四层：正常/异常路径

### 正常路径

系统运行 → 检测到空闲 → 进入睡眠 → 中断唤醒 → 继续运行

### 异常路径

| 异常场景 | 现象 | 原因 | 处理方式 |
|---------|------|------|---------|
| 频繁被唤醒 | 功耗居高不下 | 中断使能配置过多，无关中断频繁唤醒 | 关闭不必要的唤醒源 |
| 唤醒后外设不工作 | 功能异常 | 寄存器内容在睡眠时丢失，未重新配置 | 唤醒后重新初始化外设 |
| GPIO 悬空耗电 | 静态功耗偏高 | 未使用的 GPIO 引脚悬空，电平来回跳变 | 配置为模拟输入或固定输出 |
| 看门狗误复位 | 系统反复重启 | 睡眠期间看门狗未暂停 | 进入睡眠前暂停看门狗 |
| 电源门控恢复失败 | 模块无法唤醒 | 电源门控的上下电时序不对 | 检查电源域控制器的时序配置 |

## 第五层：调试方法

### 功耗测量

```bash
# 方法 1：串联万用表测量平均电流
# 万用表串接到电源线路，设为电流档

# 方法 2：示波器 + 电流探针看瞬态电流波形
# 在电源线上串联 1 欧姆采样电阻，示波器测电阻两端电压
# V = I x R，所以 1mV = 1mA

# 方法 3：专用功耗分析仪（如 Otii Arc）
# 可以精确测量每个运行的功耗曲线
```

### 代码级功耗调试

```c
// 用 GPIO 翻转测量关键路径的时间
void gpio_power_measure(void) {
    GPIO_SET(HIGH);   // 开始测量
    // ... 被测代码 ...
    GPIO_SET(LOW);    // 结束测量
    // 用示波器看 GPIO 拉高到拉低的时间
}

// 打印各外设时钟状态
void dump_clk_status(void) {
    printf("CLK_UART1: %s\n", clk_is_enabled(CLK_UART1) ? "ON" : "OFF");
    printf("CLK_I2C1:  %s\n", clk_is_enabled(CLK_I2C1)  ? "ON" : "OFF");
    printf("CLK_SPI1:  %s\n", clk_is_enabled(CLK_SPI1)  ? "ON" : "OFF");
}
```

## 第六层：实战练习

### 练习 1：功耗预算（基础）

为电池供电产品做功耗预算：
1. 列出产品的所有运行状态（播放、待机、深度睡眠）
2. 估算每个状态的电流和持续时间
3. 计算加权平均电流
4. 根据电池容量估算续航时间
5. 找出功耗最大的状态，思考优化方案

### 练习 2：实现 Tickless Idle（进阶）

在 FreeRTOS 项目中启用并验证 Tickless Idle：
1. 在 `FreeRTOSConfig.h` 中设置 `configUSE_TICKLESS_IDLE = 1`
2. 实现 `vPortSuppressTicksAndSleep()` 函数
3. 用 GPIO 翻转测量空闲时的功耗变化
4. 对比开启前后空闲电流的差异

### 练习 3：阅读电源管理源码（深入）

阅读 `/home/ys/wq7036a/wq-audio/wqcore/components/power_mgnt/inc/power_mgnt.h` 和相关实现，回答：
1. WQ7036A 支持哪几种低功耗模式？
2. 每种模式的唤醒源有哪些？
3. 进入深度睡眠前需要做哪些准备工作？
4. 唤醒后如何恢复外设状态？

## 自测与验收

1. 动态功耗和静态功耗有什么区别？分别怎么优化？
2. 为什么降电压比降频率更省电？
3. Sleep 和 Deep Sleep 的区别是什么？
4. 什么是 Tickless Idle？它解决了什么问题？
5. 时钟门控和电源门控的区别是什么？
6. 为什么 GPIO 悬空会耗电？
7. 电池供电产品怎么做功耗预算？

## 延伸阅读

- [[rtos-freertos-RTOS原理与FreeRTOS]] — Tickless Idle、空闲任务
- [[audio-system-音频系统基础]] — 音频场景的低功耗策略
- [[ipc-multicore-多核通信与IPC]] — 核级关断与唤醒
- [[reliability-exception-系统可靠性与异常处理]] — 低功耗下的看门狗策略

## #flashcard

**Q: 低功耗三板斧是什么？**
A: 关时钟（不用就关）、降频率（够用就慢）、进睡眠（没事就睡）。

**Q: 为什么降电压比降频率更省电？**
A: 动态功耗 P = C x V^2 x f，电压是平方关系，效果更显著。

**Q: Sleep 和 Deep Sleep 的主要区别？**
A: Sleep 保留全部 RAM 和 CPU 状态，唤醒快（μs）；Deep Sleep 只保留部分，唤醒慢（ms）但更省电。

**Q: 什么是 Tickless Idle？**
A: RTOS 空闲时不再每个 Tick 唤醒 CPU，而是睡到最近的任务需要运行的时间点。

**Q: 时钟门控和电源门控的区别？**
A: 时钟门控只关时钟，模块仍有供电（静态功耗存在）；电源门控切断供电（静态功耗几乎为 0）。