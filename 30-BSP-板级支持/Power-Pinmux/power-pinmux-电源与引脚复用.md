---
type: concept
tags: [BSP, 电源管理, 引脚复用, Pinmux, pinctrl, GPIO, 低功耗, WQ7036A, V881]
aliases: [电源管理, 引脚复用, pinmux, 电源域, 时钟门控, 功耗, power, pinmux]
---

# 电源管理与引脚复用

## 一句话结论

电源管理决定芯片的功耗和续航，引脚复用让一个物理引脚在不同时间扮演不同角色（GPIO/UART/I2C）。两者都是 BSP 工程师的日常：配电源让板子稳定运行，配引脚避免功能冲突。

## 30秒先看懂

- 电源管理分三个层次：时钟门控（关外设时钟，~1μs 唤醒）、电源门控（关电源域，~10μs 唤醒）、休眠（整机休眠，~1ms 唤醒）。
- 引脚复用是一个物理引脚可以配置为多种功能（如 GPIO/UART/I2C），但同一时刻只能选一个。
- WQ7036AX 的引脚通过 `pin_set_func()` API 配置，V881 的引脚通过设备树 pinctrl 配置。
- 引脚复用冲突是 BSP 开发中最常见的硬件问题之一，后初始化的设备会抢占引脚。
- 休眠唤醒后，引脚状态可能丢失，需要在唤醒时重新配置引脚功能。

## 学完以后应该能做什么

**第一遍**
- 能说清电源管理的三个层次和各自的唤醒时间
- 能理解引脚复用的原理，识别引脚冲突
- 能在 WQ7036AX SDK 中用 `pin_set_func` 配置引脚功能

**进阶**
- 能分析系统的功耗分布，找到功耗热点
- 能设计低功耗模式下的引脚保持策略
- 能读懂 V881 设备树中的 pinctrl 配置，并自己添加新的引脚配置

## 前置知识

- GPIO 基本概念（输入、输出、上拉、下拉）
- 嵌入式系统时钟树
- 设备树基础（pinctrl 章节）

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|----------|
| 时钟门控 | Clock Gating | 关闭不用的外设时钟，最细粒度的省电方式，唤醒最快 |
| 电源门控 | Power Gating | 切断整个电源域的供电，省电效果更好，唤醒稍慢 |
| 休眠模式 | Sleep/DeepSleep | 整机进入低功耗状态，CPU 停止执行，只保留 32kHz 时钟 |
| 引脚复用 | Pin Mux (Pin Multiplexing) | 一个物理引脚在寄存器层面配置为不同的功能 |
| 引脚配置 | Pin Configuration | 设置引脚的驱动能力、上拉/下拉、施密特触发等电气特性 |
| 电源域 | Power Domain | 芯片中一组可以独立供电的模块集合 |
| 唤醒源 | Wake-up Source | 能使芯片从休眠状态唤醒的事件源（如 GPIO 中断、定时器） |

## 第一层：费曼心智模型

### 类比：家里的配电箱和多功能插座

**电源管理** = 家里的配电箱：客厅、卧室、厨房各有独立的空气开关。不用的时候关掉（省电），用的时候打开。关掉客厅的灯（时钟门控）比关掉整个客厅的电源（电源门控）快，但省电少。晚上睡觉（休眠）把所有灯都关了，只留一个夜灯（32kHz 时钟）。

**引脚复用** = 多功能插座：同一个插孔，可以插台灯（GPIO），也可以插空调（UART），但不能同时插两个。你需要在插东西之前先决定这个插孔今天是什么用途。

### 边界在哪里

- 时钟门控只关外设时钟，不关电源——外设寄存器值保留，但无法操作
- 电源门控会丢失寄存器状态——唤醒后需要重新初始化外设
- 休眠模式需要唤醒源来恢复——如果唤醒源配错，芯片可能永远醒不来
- 引脚复用是全局的——一个引脚被 A 外设占用后，B 外设不能再用，系统不会报错，只会行为异常

### 场景演练：WQ7036AX 低功耗耳机

1. 耳机在播放音乐时：ACORE、BCORE、DCORE 全开，音频 I2S 和功放时钟全开
2. 用户暂停音乐 30 秒：系统进入"轻度空闲"——关闭音频 I2S 的时钟门控（`clk_gate(I2S_CLK)`）
3. 暂停超过 5 分钟：系统进入"深度空闲"——关闭 DCORE 电源域（电源门控），ACORE 进入睡眠
4. 用户按下播放键：GPIO 中断唤醒 ACORE，ACORE 重新使能 DCORE 电源域，恢复 I2S 时钟
5. 引脚配置：I2S 的引脚（BCLK、LRCK、DATA）在休眠时通过 `pin_set_slp_sel_enable()` 保持输出状态，防止休眠后电平变化导致功放产生噪音

## 第二层：原理/时序/约束

### 电源管理的三层次

| 层次 | 控制粒度 | 功耗降低 | 唤醒时间 | 唤醒后状态 |
|------|---------|----------|---------|-----------|
| **Clock Gating** | 单个外设模块 | 低（只省动态功耗） | ~1μs | 寄存器保留，立即恢复 |
| **Power Gating** | 整个电源域 | 中（省动态+静态功耗） | ~10μs | 寄存器丢失，需重新初始化 |
| **Sleep/DeepSleep** | 整个芯片 | 高（几乎所有模块断电） | ~1ms | 系统状态需全部恢复 |

### 引脚复用的原理

```
一个物理引脚（如 WQ7036A 的 GPIO50）可以配置为：
  ├── GPIO50（通用输入输出）
  ├── UART1_TX（串口发送）
  ├── I2C2_SCL（I2C 时钟）
  └── PWM0（脉宽调制输出）

功能选择通过 func_sel 寄存器位（3 bits）设置：
  func_sel = 0 → GPIO
  func_sel = 1 → UART1_TX
  func_sel = 2 → I2C2_SCL
  func_sel = 3 → PWM0

同一时刻只能选一个功能！
```

### 关键约束

- 引脚功能选择在芯片设计时固定，不能自定义——只能从芯片手册支持的选项中选择
- 休眠唤醒后引脚配置寄存器可能丢失（取决于电源域是否断电），需要在唤醒时重新配置
- 同一个引脚不能同时被两个外设占用——BSP 工程师需要规划引脚分配表
- 电源域的开关顺序有严格的时序要求，不能随意开关

## 第三层：真实 SDK 代码

### WQ7036AX 的引脚配置寄存器定义

文件路径：`/home/ys/wq7036a/wq-audio/wqcore/driver/periph/bbb/hw/pin.c`

```c
typedef union gpio_pin_cfg_union {
    uint32_t w;

    struct gpio_pin_cfg_field {
        uint32_t slp_oe   : 1;    // [0] 休眠时输出使能
        uint32_t slp_ie   : 1;    // [1] 休眠时输入使能
        uint32_t slp_wpd  : 1;    // [2] 休眠时下拉
        uint32_t slp_wpu  : 1;    // [3] 休眠时上拉
        uint32_t func_sel : 3;    // [4,6] 功能选择（0=GPIO, 1=UART, 2=I2C...）
        uint32_t func_wpd : 1;    // [7] 功能模式下下拉
        uint32_t func_wpu : 1;    // [8] 功能模式下上拉
        uint32_t ire      : 1;    // [9] 输入使能
        uint32_t ore      : 1;    // [10] 输出使能
        uint32_t ineg     : 1;    // [11] 输入反相
        uint32_t ipos     : 1;    // [12] 输入施密特触发
        uint32_t oneg     : 1;    // [13] 输出反相
        uint32_t opos     : 1;    // [14] 输出施密特触发
        uint32_t oinv     : 1;    // [15] 输出反相
        uint32_t iinv     : 1;    // [16] 输入反相
        uint32_t odrv     : 1;    // [17] 开漏输出
        uint32_t slp_sel  : 1;    // [18] 休眠时是否保持配置
        uint32_t drv      : 2;    // [19,20] 驱动能力
        uint32_t sec      : 1;    // [21] 安全模式
        uint32_t reserved : 10;   // [22,31]
    } _b;
} gpio_pin_cfg_u;
```

这个寄存器定义展示了 WQ7036A 引脚配置的完整能力：可以独立配置正常模式和休眠模式下的引脚状态，包括功能选择、上拉/下拉、驱动能力、输入/输出使能等。

### WQ7036AX 的引脚控制 API

文件路径：`/home/ys/wq7036a/wq-audio/wqcore/driver/periph/bbb/hw/pin.h`

```c
// 声明引脚功能
WQ_RET pin_claim_as_func(uint16_t pin, uint8_t func);

// 设置引脚功能
WQ_RET pin_set_func(uint16_t pin, uint8_t func);

// 设置驱动能力
WQ_RET pin_set_drv_strength(uint16_t pin, PIN_DRV_STRENGTH drv);

// 设置上拉/下拉
WQ_RET pin_set_pull_mode(uint16_t pin, PIN_PULL_MODE mode);

// 获取休眠时的引脚配置
PIN_PULL_MODE pin_get_slp_pull_mode(uint16_t pin);

// 使能休眠时的引脚保持
WQ_RET pin_set_slp_sel_enable(uint16_t pin);

// 读取完整引脚配置
uint32_t pin_get_pin_config(uint16_t pin);
```

### V881 设备树中的 pinctrl 配置

文件路径：`/home/ys/aiglass/tina-v861/device/config/chips/v861/configs/reglasses/uboot-board.dts`

```dts
&pio {
    uart0_ph_pins: uart0-ph-pins {
        pins = "PH9", "PH10";
        function = "mux@5";
    };

    spi0_pins_default: spi0@0 {
        pins = "PC0", "PC2", "PC3"; /* clk, mosi, miso */
        function = "spi0";
        drive-strength = <20>;
    };

    spi0_pins_cs: spi0@1 {
        pins = "PC1", "PC4", "PC5", "PC6";
        function = "spi0";
        drive-strength = <20>;
        bias-pull-up;
    };
};
```

## 第四层：正常/异常路径

### 正常路径

1. BSP 工程师规划引脚分配表，确保无冲突
2. 在代码中调用 `pin_claim_as_func(pin, func)` 配置引脚
3. 外设正常工作
4. 进入休眠时，通过 `pin_set_slp_sel_enable()` 保持引脚状态
5. 唤醒后，重新配置引脚功能

### 异常路径

| 问题 | 现象 | 根因 | 排查方法 |
|------|------|------|----------|
| 两个外设复用同一引脚 | 后初始化的抢占成功，前一个外设不工作 | 引脚复用冲突，规划时没检查 | 检查芯片手册的引脚分配表，确认没有重叠 |
| 电源域没开 | 外设寄存器写入无效 | 忘了使能外设的电源域 | 检查外设初始化代码，确认 `clk_enable()` 调用 |
| 休眠后引脚状态丢失 | 唤醒后引脚电平恢复默认，外设异常 | 休眠时引脚所在的电源域断电 | 使用 `pin_set_slp_sel_enable()` 让引脚在休眠时保持状态 |
| 驱动能力不足 | 高速信号传输错误 | drive-strength 配置太低 | 增加驱动能力，或检查 PCB 走线 |
| 休眠唤醒源没配 | 芯片无法唤醒 | 唤醒源配置错误 | 检查唤醒 GPIO 的中断配置 |

## 第五层：调试方法

### 引脚状态检查

```c
// 读取引脚当前配置
uint32_t cfg = pin_get_pin_config(gpio_pin);
// 解析 cfg 确认 func_sel 是否正确

// 检查引脚是否被其他外设占用
// 查看芯片手册的引脚功能表
```

### 电源调试

```c
// 检查当前时钟状态
clk_get_status(APB_CLK_UART1);  // 返回 enable/disable

// 检查电源域状态
power_domain_get_status(PD_DCORE);  // 返回 on/off
```

### 调试建议

```bash
# 在 Linux 中查看 GPIO 使用情况
cat /sys/kernel/debug/gpio

# 查看引脚复用状态
cat /sys/kernel/debug/pinctrl/*/pinmux-pins
```

## 第六层：实战练习

### 练习 1：阅读 WQ7036A 的引脚驱动代码

阅读 `/home/ys/wq7036a/wq-audio/wqcore/driver/periph/bbb/hw/pin.c` 和 `pin.h`，回答：
- `pin_claim_as_func()` 和 `pin_set_func()` 有什么区别？
- 休眠时引脚保持功能是如何实现的？
- 驱动能力（drv 字段）有几种可选值？

### 练习 2：规划引脚分配

假设你需要在 WQ7036A 上同时使用以下外设，但只有以下可用引脚（GPIO 编号 0-100），请规划引脚分配：
- UART1（需要 TX、RX 两个引脚）
- I2C0（需要 SCL、SDA 两个引脚）
- I2S0（需要 BCLK、LRCK、DATA 三个引脚）
- 2 个 GPIO 按键
- 1 个 GPIO LED

需要注意：每个引脚只能分配给一个功能，你需要参考芯片手册查看每个引脚支持的复用功能选项。

### 练习 3：V881 设备树 pinctrl 分析

阅读 `/home/ys/aiglass/tina-v861/device/config/chips/v861/configs/reglasses/uboot-board.dts` 中的 pinctrl 配置，回答：
- 定义了哪些引脚组？每个组包含哪些引脚？
- `drive-strength` 和 `bias-pull-up` 分别代表什么？
- 如果要把 SPI0 的 CS 引脚从 PC1 改为 PC7，需要怎么修改？

### 练习 4：低功耗场景设计

设计一个蓝牙耳机的电源管理策略，包括：
- 播放音乐时：哪些模块需要开启？
- 暂停时：哪些模块可以关闭？
- 休眠时：哪些模块保持供电？
- 唤醒源：使用什么事件唤醒？
- 给出每个状态切换的代码伪代码

## 自测与验收

1. 电源管理的三个层次是什么？各自的唤醒时间是多少？
2. 引脚复用冲突会造成什么现象？如何排查？
3. 休眠唤醒后引脚状态为什么会丢失？如何避免？
4. WQ7036A 的 `pin_set_slp_sel_enable()` 函数的作用是什么？
5. V881 设备树中 `drive-strength` 和 `bias-pull-up` 分别配置什么？

## 延伸阅读

- [[gpio-config-GPIO配置]] — WQ7036AX 的 GPIO 引脚映射
- [[low-power-低功耗设计]] — 时钟门控、休眠模式详解
- [[devicetree-DeviceTree设备树]] — Linux 侧的 pinctrl 配置
- [[platform-driver-外设驱动框架]] — 外设驱动的通用初始化流程

## #flashcard

Q: 电源管理的三个层次是什么？
A: 时钟门控（Clock Gating，~1μs 唤醒，关外设时钟）、电源门控（Power Gating，~10μs 唤醒，关电源域）、休眠（Sleep/DeepSleep，~1ms 唤醒，整机休眠）。

Q: 引脚复用冲突会有什么现象？
A: 后初始化的设备抢占成功，前一个设备行为异常。系统不会报错，需要人工检查引脚分配表。

Q: 休眠唤醒后引脚状态为什么会丢失？
A: 如果引脚所在的电源域在休眠时断电，引脚配置寄存器的值会丢失，唤醒后恢复默认状态。需要用 `pin_set_slp_sel_enable()` 让引脚在休眠时保持配置。

Q: WQ7036A 的 `pin_claim_as_func()` 和 `pin_set_func()` 有什么区别？
A: `pin_claim_as_func()` 会先检查引脚是否已被占用（防止冲突），`pin_set_func()` 直接设置功能，不做检查。

Q: 设备树中 `drive-strength` 和 `bias-pull-up` 分别配置什么？
A: `drive-strength` 配置引脚的驱动能力（电流大小），`bias-pull-up` 配置内部上拉电阻。