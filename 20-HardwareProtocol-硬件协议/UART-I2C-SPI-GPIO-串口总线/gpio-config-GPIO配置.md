---
type: concept
created: 2026-07-17
tags: [mcu, gpio, peripheral, 引脚, 中断, pinmux, 低功耗]
aliases: [GPIO, General Purpose Input/Output, 通用IO, 引脚配置]
---

# GPIO 配置：从引脚电平到低功耗唤醒

> **一句话结论**：GPIO（General Purpose Input/Output，通用输入输出）不是"设为输出就能控 LED"这么简单，它是一组由方向控制、推挽/开漏输出结构、上下拉电阻、引脚复用（pinmux）、边沿/电平中断、去抖、驱动强度、资源占用和低功耗唤醒共同组成的引脚管理系统。真正会用 GPIO，意味着你能从芯片手册的引脚矩阵、SDK 的 claim/release 机制和中断回调一直追到真实的板级信号行为。

## 30 秒先看懂

GPIO 解决的是"芯片引脚怎么用"的问题，就像配电箱里的可编程开关——可以设为输出（控制灯亮灭）或输入（读按键状态）。但引脚的电气行为（推挽还是开漏、要不要上拉、能不能触发中断）远比想象中复杂。初学者先记住：输入引脚不能浮空（必须配上拉或下拉），输出引脚要先设电平再切方向，否则会有毛刺。

本篇的代码锚点来自两个真实工程：

- **WQ7036AX**：`/home/ys/wq7036a/wq-audio/wqcore/driver/periph/common/hal/gpio/wq_gpio.h`、`wq_gpio.c`，以及 I2C/SPI/UART 等驱动中调用 `wq_gpio_*` 和 `gpio_claim_*` 的实际使用点。
- **V861/reGlasses**：`/home/ys/aiglass/reglasses/device/configs/reglasses/linux-6.6-xuantie/board.dts` 中的 pinctrl 配置、GPIO 扩展器（TCA9539）、按键/LED/中断引脚的设备树描述。

文中"通用原理"是 GPIO 硬件本身；"SDK 事实"只针对上述源码和配置；"待确认"标记表示尚未由当前源码或板级资料证实。

## 学完以后应该能做什么

1. 解释推挽输出和开漏输出的电气区别，以及为什么 I2C 用开漏而 SPI 用推挽。
2. 区分边沿中断和电平中断的触发条件和适用场景，避免中断风暴。
3. 说出为什么输出引脚要先设电平再切方向，以及不这样做会产生的毛刺风险。
4. 看懂 WQ HAL 的 `wq_gpio_open`、`wq_gpio_open_as_interrupt`、`wq_gpio_set_pull_mode`、`wq_gpio_wakeup_enable` 的调用契约和限制。
5. 理解 `gpio_claim` / `gpio_claim_group` / `gpio_release` 的资源管理机制，以及为什么两个驱动不能同时 claim 同一个 GPIO。
6. 看懂 V861 设备树中 pinctrl 节点如何将 GPIO 配置为特定功能（uart、twi、gpio_in）或中断输入。
7. 面对按键抖动、中断误触发、电平浮空、唤醒失败等故障，能提出可验证的假设。

## 前置知识

- 会读十六进制、位运算和 C 函数声明；可先看 [[c-core-C语言核心]]。
- 理解中断服务程序（ISR）的基本约束；可先看 [[interrupt-concurrency-中断并发同步]]。
- 知道 I2C/SPI/UART 的 GPIO 复用关系；可先看 [[i2c-basics-I2C基础]]、[[spi-basics-SPI基础]]、[[uart-basics-UART基础]]。
- 如果要理解 Linux 侧的 GPIO 和 pinctrl，需要 [[devicetree-DeviceTree设备树]] 和 [[platform-driver-外设驱动框架]]。

## 术语先讲清楚

| 术语 | 英文 | 在 GPIO 中具体指什么 |
|---|---|---|
| 推挽输出 | push-pull output | 输出级用两个晶体管：上管导通时引脚直连 VDD，下管导通时直连 GND。两个推挽输出不能并联（会短路）。WQ GPIO 配置为普通输出时默认推挽 |
| 开漏输出 | open-drain output | 只有下拉晶体管，高电平靠外部上拉电阻恢复。允许多个开漏输出共享一根线（线与）——任一设备拉低，总线即为低。I2C 的 SDA/SCL 依赖开漏实现多设备共享 |
| 上拉电阻 | pull-up resistor | 将引脚通过电阻连接到 VDD。引脚悬空时被拉到高电平，提供确定的默认状态。WQ SDK 通过 `wq_gpio_set_pull_mode(gpio, WQ_GPIO_PULL_UP)` 使能内部上拉 |
| 下拉电阻 | pull-down resistor | 将引脚通过电阻连接到 GND。WQ SPI 驱动在 CPOL=0 时为 CLK 配置下拉（`GPIO_PULL_MODE_DOWN`），确保空闲时 SCK 保持在低电平 |
| 浮空 | floating | 引脚既没有上拉/下拉，也没有外部驱动。CMOS 输入阻抗极高（~MΩ），极易受电磁干扰耦合导致电平随机翻转。浮空输入的功耗也高于稳定电平 |
| 引脚复用 | pinmux | 一个物理引脚通过寄存器配置在 GPIO、UART、I2C、SPI 等功能之间切换。WQ 的 `gpio_claim(gpio, func)` 同时完成"占用声明"和"复用配置"，`gpio_mtx` 矩阵支持更灵活的任意映射 |
| 边沿中断 | edge interrupt | 电平从低到高（上升沿）或从高到低（下降沿）的跳变瞬间触发一次中断。WQ ISR 在回调执行后调用 `gpio_int_clear(io)` 清除中断状态，防止重复触发 |
| 电平中断 | level interrupt | 只要引脚保持符合条件（低或高）的电平，中断就持续触发。WQ ISR 同样在回调后清除中断状态——但如果引脚电平未改变，硬件会立即重新置位中断标志，形成中断风暴。因此电平中断的 ISR 中必须屏蔽中断或改变外部电平 |
| 去抖 | debounce | 过滤机械触点或噪声导致的短暂电平跳变（通常 10-20ms）。WQ SDK 没有内建去抖 API，需在应用层实现：ISR 中记录时间戳，30ms 后再次确认电平 |
| 驱动强度 | drive strength | 输出引脚能提供的最大电流，影响边沿斜率。WQ 支持 `LOW`/`MEDIUM`/`HIGH` 三档。高速信号（SPI CLK）用 HIGH，低速信号（LED）用 LOW 以降低 EMI 和功耗 |
| AON GPIO | Always-On GPIO | 在芯片深度睡眠/关机时仍保持供电的 GPIO 域。WQ 的 `wq_gpio_wakeup_enable` 仅支持 AON GPIO，且仅支持电平中断唤醒（边沿中断在睡眠时无时钟检测） |
| 中断风暴 | interrupt storm | 电平中断模式下，如果 ISR 退出后引脚电平仍符合触发条件，硬件立即重新触发中断，CPU 被锁在 ISR 中。WQ ISR 本身会清中断状态，但清完后硬件重新检测电平——如果电平没变，新一轮中断立刻开始 |

---

## 第一层：用费曼技巧建立心智模型

### 1.1 GPIO 像配电箱里的可编程开关——类比及其边界

把一个 GPIO 引脚想象成配电箱里的一个开关模块，但需要把物理约束带入：

- **设为输出**：你从手机 APP 控制这个开关。合上时，开关内部的上管导通，引脚直连 VDD（3.3V），电流从 VDD 经上管流出到外部设备。断开时，下管导通，引脚直连 GND（0V），外部设备的电流从引脚流入下管到地。关键：**开关的力气有限**——WQ 的驱动强度（LOW/MEDIUM/HIGH）决定了上管/下管导通时的电阻，从而决定了最大输出电流。LED 可以直驱，电机/继电器不行。
- **设为输入**：你看开关的状态。但这里有个关键区别——CMOS 输入端像一个极小电容（~pF），不是电阻。如果外部没有电路把这个电容充电到确定电压，它就保持上次的电荷，电压随机漂移。上拉/下拉电阻就是给这个电容一个"充电路径"，让它保持在确定的电压。
- **设为中断输入**：开关上装了报警器。但报警器有两种类型——"边沿报警器"只在状态变化瞬间响一声，"电平报警器"在状态持续期间一直响。WQ ISR 在每次报警响起后，先执行你的回调，然后**自动清除报警器状态**（`gpio_int_clear(io)`，wq_gpio.c:102）。但如果电平报警器对应的条件仍然存在（引脚还是低电平），清除后硬件会立刻重新置位——这就是中断风暴的根源。

这个类比的关键边界：

**边界一：输出方向切换有毛刺风险。** 当你把引脚从输入改为输出时，输出寄存器里可能残留着上次的值（或复位值 0）。如果这个值和你即将写的新值不同，从"切换方向"到"写新值"之间，引脚会短暂输出一个错误的电平。WQ 低功耗恢复代码（wq_gpio.c:143-144）展示了正确做法：**先写输出寄存器，再切方向**。注释写的是"Set the out register before output enable to prevent the keep level from changing"。

**边界二：输入引脚不配上拉/下拉不是"读 0"，而是"读随机值"。** 浮空引脚的电压取决于环境电磁场。如果手指靠近，可能读到 1；手指离开，可能读到 0。同一个引脚在不加任何外部驱动的情况下，连续读 10 次可能得到 5 个 1 和 5 个 0。

**边界三：中断不是"发生一次就处理一次"。** 边沿中断如其名，只在跳变瞬间触发。电平中断如其名，在电平保持期间反复触发。如果你用低电平中断监视故障信号，故障持续 1 秒，而你的 ISR 耗时 10 μs——在这 1 秒内中断会被触发约 100,000 次。正确的做法是：ISR 中立即屏蔽该中断，通知任务处理，故障解除后再重新使能。

### 1.2 完整场景演算一：按键按下到 CPU 收到数据的每一步

这是理解 GPIO 输入+中断+去抖最关键的场景。假设一个按键一端接 GPIO（WQ_GPIO_12），另一端接 GND。GPIO 配置为输入、上拉使能、下降沿中断。

**硬件连接：**
```text
VDD (3.3V) ──[内部上拉 ~50kΩ]──┐
                                 ├── GPIO12 ──[按键]── GND
```

**初始状态（按键未按下）：**
```text
按键断开，GND 不连接。
电流路径：VDD → 上拉电阻 → GPIO12 输入缓冲器。
GPIO12 电压 ≈ 3.3V（上拉电阻的压降可忽略，因为 CMOS 输入阻抗极高）。
wq_gpio_read(GPIO12) 返回 1（高电平）。
中断状态：无触发。
```

**T = 0 ms：手指按下按键，触点开始闭合。**
```text
按键两端金属弹片接触，GPIO12 通过按键直接连接到 GND。
电流路径：VDD → 上拉电阻 → GPIO12 → 按键 → GND。
GPIO12 电压瞬间从 3.3V 跌到 0V（上拉电阻限制电流 = 3.3V/50kΩ = 66 μA）。
```

**T = 0~15 ms：触点弹跳期（bounce）。**
```text
机械弹片在接触后回弹 3-5 次，每次回弹约 1-2ms。
GPIO12 电平变化：0V → 3.3V → 0V → 3.3V → 0V（稳定）。
每次下降沿 + 上升沿都是一个完整的边沿事件。
如果直接用下降沿中断且没有去抖：这 15ms 内会触发 3-5 次中断。
```

**T ≈ 0.1 ms：第一次下降沿，硬件触发中断。**
```text
GPIO12 电平从高变低。
硬件检测到下降沿，置位中断状态寄存器。
wq_gpio_irq 触发，CPU 进入 wq_gpio_isr_handler()。
ISR 遍历 GPIO 状态寄存器，找到 GPIO12 的中断位。
调用用户注册的回调：cb(GPIO12, WQ_GPIO_INT_EDGE_FALLING)。
回调执行完毕后，ISR 调用 gpio_int_clear(GPIO12) 清除中断状态。
CPU 退出 ISR。
```

**应用层去抖处理：**
```c
// 回调在 ISR 上下文中执行，不能做延时
static void key_isr(WQ_GPIO_ID gpio, WQ_GPIO_INT_MODE mode) {
    // 记录时间戳，不做实际处理
    key_last_tick = os_get_ticks();
    // 通知一个任务去做去抖确认
    os_signal(key_task);
}

// 任务在 30ms 后确认电平
void key_task_handler(void) {
    os_wait_signal();
    os_delay_ms(30);  // 等待弹跳结束
    if (wq_gpio_read(GPIO12) == 0) {
        // 30ms 后仍然是低电平，确认按键有效
        on_key_pressed();
    }
    // 重新使能中断（如果之前屏蔽了）
    wq_gpio_int_enable(GPIO12);
}
```

**WQ SDK 映射**：`wq_gpio_open_as_interrupt(GPIO12, WQ_GPIO_INT_EDGE_FALLING, key_isr)` 内部做了三件事（wq_gpio.c:290-317）：
1. `gpio_open(gpio, GPIO_DIRECTION_INPUT)` — 配置为输入
2. 分配 `wq_gpio_info_t`，保存回调、方向、中断模式
3. `gpio_int_enable(gpio, mode)` — **直接使能中断**

所以调用 `wq_gpio_open_as_interrupt` 后不需要再调用 `wq_gpio_int_enable`——中断已经使能了。`wq_gpio_int_enable` 的用途是：当你在 ISR 中调用了 `wq_gpio_int_disable` 屏蔽中断后，在任务处理完重新使能。

### 1.3 完整场景演算二：用 GPIO 控制外设复位引脚的毛刺风险

假设一个 GPIO（WQ_GPIO_20）控制摄像头的复位信号（RSTn，低有效）。摄像头要求 RSTn 上电后保持高电平（不复位），需要复位时拉低 1ms 再拉高。

**错误做法：先切方向，再设电平。**
```c
// 错误！上电时输出寄存器的复位值可能是 0
wq_gpio_open(GPIO20, WQ_GPIO_DIRECTION_OUTPUT); // 引脚立刻输出 0V（RSTn 拉低！）
wq_gpio_write(GPIO20, 1);                       // 然后才拉到 3.3V
```
在 `open` 和 `write` 之间，GPIO20 输出 0V。如果摄像头已经上电，这个短暂的 0V 会让摄像头进入复位状态——这就是上电初始化毛刺。

**正确做法一：先写输出寄存器，再切方向（WQ 低功耗恢复的做法）。**
```c
// 在硬件层预先写输出值为 1
gpio_write(GPIO20, 1);                           // 先写输出寄存器
gpio_set_func(GPIO20, GPIO_FUNC_NORMAL_GPIO);     // 再配 GPIO 功能
gpio_config(GPIO20, GPIO_DIRECTION_OUTPUT);       // 最后切方向
```
这是 `wq_gpio_restore`（wq_gpio.c:143-146）中使用的模式——注释明确写"Set the out register before output enable to prevent the keep level from changing"。

**正确做法二：硬件设计上保证默认安全。**
在 GPIO20 和摄像头 RSTn 之间加一个上拉电阻到 VDD。即使 GPIO 短暂输出 0V，上拉电阻也会将 RSTn 保持在接近 VDD 的电平（取决于 GPIO 驱动强度和上拉电阻的分压比）。这不是软件能解决的——需要硬件配合。

**WQ SDK 事实**：`wq_gpio_open` 不提供"初始输出电平"参数。`wq_gpio_write` 内部做了 `io_info->st.b.out_value = value` 然后 `gpio_write(gpio, value)`（wq_gpio.c:379-380）。如果需要在 `open` 前设电平，需要通过硬件层 `gpio_write()` 操作——但这是绕过 HAL 层，破坏了分层。

### 1.4 wq_gpio_toggle 不是原子操作

`wq_gpio_toggle`（wq_gpio.c:394-408）的实现是：
```c
io_info->st.b.out_value ^= 1;  // 步骤1：翻转 HAL 状态变量
gpio_toggle(gpio);             // 步骤2：硬件翻转引脚
```
这是两个独立的操作，不是原子的"读-改-写"硬件操作。如果两个任务同时调用 `wq_gpio_toggle` 操作同一个 GPIO，由于步骤 1 和步骤 2 之间存在窗口，状态变量可能和实际引脚电平不一致。对于需要精确翻转的场景（如 LED 闪烁），用 `wq_gpio_write(gpio, !wq_gpio_read(gpio))` 反而更正确——至少它读的是真实硬件电平。

---

## 第二层：中断模式的选择

### 2.1 边沿中断 vs 电平中断

WQ GPIO 支持 5 种有效中断模式（`wq_gpio.h:39-52`）：

| 模式 | 枚举 | 触发条件 | 典型用途 | 风险 |
|---|---|---|---|---|
| 上升沿 | `WQ_GPIO_INT_EDGE_RAISING` | 从低变高 | 按键释放检测 | 如果上升沿有毛刺，可能多次触发 |
| 下降沿 | `WQ_GPIO_INT_EDGE_FALLING` | 从高变低 | 按键按下检测、传感器就绪 | 同上 |
| 双边沿 | `WQ_GPIO_INT_EDGE_BOTH` | 任意变化 | 监测任何状态变化 | 频繁触发，CPU 占用高 |
| 低电平 | `WQ_GPIO_INT_LEVEL_LOW` | 保持低电平 | 紧急停机信号、电源故障 | 如不处理会持续触发（中断风暴） |
| 高电平 | `WQ_GPIO_INT_LEVEL_HIGH` | 保持高电平 | 外设就绪持续检测 | 同上 |

**关键选择原则**：

- **按键**用下降沿中断（按下瞬间触发一次），在 ISR 中启动定时器做去抖；
- **传感器就绪信号**（如"数据准备好了"）如果是电平信号（持续高表示就绪），用高电平中断，ISR 中读完数据后信号自动清除；
- **故障信号**（如电源故障、过温）用低电平中断，因为故障期间信号一直有效，CPU 会被持续唤醒，直到故障解除；
- **双边沿中断**慎用——它会在每次电平变化时触发，信号抖动时会频繁进入 ISR。

### 2.2 中断风暴：为什么电平中断需要立即处理

电平中断的触发条件是"当前电平符合条件"，不是"电平变化的一瞬间"。WQ ISR 在回调后调用 `gpio_int_clear(io)` 清除中断状态（wq_gpio.c:102），但如果引脚电平仍然符合触发条件，硬件会立即重新置位中断标志。CPU 的行为是：

1. 进入 ISR → 调用回调 → 清除中断状态 → 退出 ISR；
2. 硬件发现引脚还是低电平 → 立即重新置位中断标志 → 再次触发中断；
3. 返回步骤 1。

这就是中断风暴——CPU 被锁在 ISR 中，无法执行正常任务。处理方法：

- ISR 中立即屏蔽该中断（`wq_gpio_int_disable`），然后通知任务处理，处理完再重新使能；
- 或者 ISR 中做最少处理（读状态、清除外部中断源），然后退出。

### 2.3 去抖：硬件 vs 软件

机械按键在按下和释放时，金属弹片会弹跳（bounce）10-20ms，产生多次高低电平切换。如果直接用下降沿中断，按一次键可能触发 5-10 次中断。

**软件去抖**：ISR 中记录时间戳，如果距离上次中断小于去抖窗口（如 30ms），忽略。然后启动一个定时器，30ms 后再读一次电平，如果电平稳定，才确认按键有效。

**硬件去抖**：在引脚上并联一个电容（如 0.1μF），与上拉电阻形成 RC 低通滤波，滤除高频抖动。缺点是增加了上升/下降时间，不适合高速信号。

WQ SDK 没有内建的去抖 API，软件去抖需要在应用层实现。这是值得注意的——如果看到按键 ISR 中没有去抖逻辑，按一次按键触发多次就是预期行为，不是硬件故障。

---

## 第三层：WQ7036AX SDK 实战

### 3.1 真实 HAL 接口

以下是 `wqcore/driver/periph/common/hal/gpio/wq_gpio.h` 中的真实 API：

```c
// 模块生命周期
void wq_gpio_init(void);
void wq_gpio_deinit(void);

// GPIO 打开/关闭
WQ_RET wq_gpio_open(WQ_GPIO_ID gpio, WQ_GPIO_DIRECTION dir);
WQ_RET wq_gpio_open_as_interrupt(WQ_GPIO_ID gpio,
    WQ_GPIO_INT_MODE mode, wq_gpio_int_callback cb);
WQ_RET wq_gpio_close(WQ_GPIO_ID gpio);

// 读写
WQ_RET wq_gpio_write(WQ_GPIO_ID gpio, uint8_t value);
uint8_t wq_gpio_read(WQ_GPIO_ID gpio);
WQ_RET wq_gpio_toggle(WQ_GPIO_ID gpio);

// 上下拉和驱动强度
WQ_RET wq_gpio_set_pull_mode(WQ_GPIO_ID gpio, WQ_GPIO_PULL_MODE mode);
WQ_RET wq_gpio_set_drive(WQ_GPIO_ID gpio, WQ_GPIO_DRIVE_MODE drv);

// 中断控制
WQ_RET wq_gpio_int_enable(WQ_GPIO_ID gpio);
WQ_RET wq_gpio_int_disable(WQ_GPIO_ID gpio);

// 低功耗唤醒（仅 AON GPIO，仅电平中断）
WQ_RET wq_gpio_wakeup_enable(WQ_GPIO_ID gpio);
WQ_RET wq_gpio_wakeup_disable(WQ_GPIO_ID gpio);
void wq_gpio_get_wakeup_source(WQ_GPIO_ID *gpio, uint8_t *level);
```

从这组声明可以读出几个工程约束：

1. **`open` 和 `open_as_interrupt` 是互斥的**。一个 GPIO 不能同时 open 为普通输入和中断输入。`wq_gpio_open_as_interrupt` 内部会设置方向和中断模式，不需要先调用 `wq_gpio_open`。
2. **中断回调签名**：`void (*cb)(WQ_GPIO_ID gpio, WQ_GPIO_INT_MODE mode)`。回调接收 GPIO 号和触发模式，这样多个 GPIO 可以共享同一个回调函数，通过 `gpio` 参数区分。
3. **唤醒仅支持 AON GPIO**。不是所有 GPIO 都能在深度睡眠时唤醒芯片——只有 Always-On 域的 GPIO 有此能力。且唤醒只支持电平中断（`LEVEL_LOW` 或 `LEVEL_HIGH`），边沿中断不能作为唤醒源。
4. **`wq_gpio_set_drive` 支持三种驱动强度**：`LOW`、`MEDIUM`、`HIGH`。高速信号（如 SPI CLK）需要 HIGH，低速信号（如 LED）用 LOW 即可，降低 EMI。
5. **`wq_gpio_toggle` 不是原子操作**——它先翻转 HAL 状态变量 `out_value ^= 1`，再调用硬件 `gpio_toggle(gpio)`。两个操作之间存在窗口，多任务并发时状态变量可能和实际引脚电平不一致（wq_gpio.c:394-408）。

### 3.2 资源管理：claim 和 release

WQ 的 GPIO 资源管理有两层：HAL 层的 `wq_gpio_open`/`close` 和硬件层的 `gpio_claim`/`release`。区别在于：

- `wq_gpio_open`：HAL 层记录 GPIO 的方向和状态，调用硬件层 `gpio_set_direction`。
- `gpio_claim(gpio, func)`：在硬件层注册"这个 GPIO 被占用了，复用功能是 func"。如果已被其他驱动 claim，返回 `WQ_RET_BUSY`。
- `gpio_claim_group(gpios, count, allow_share)`：批量 claim 一组 GPIO。`allow_share=true` 时允许部分 GPIO 已被 claim（只要功能兼容）。

**调用链示例**（来自 I2C 驱动 `wq_i2c.c`）：
```c
// I2C 驱动 claim SCL 和 SDA
if (gpio_claim_group(gpio_group, 2, false) != WQ_RET_OK) {
    return WQ_RET_INVAL;
}
```

**调用链示例**（来自 SPI 驱动 `spi_gpio_config`）：
```c
// SPI0 的特定引脚组合使用专用复用功能号
if (port == WQ_SPI_PORT0 && gpio_cfg->clk == WQ_GPO_32
    && gpio_cfg->miso == WQ_GPIO_33 && gpio_cfg->mosi == WQ_GPIO_35) {
    gpio_claim(gpio_cfg->clk, SPI_IO_FUNC_SEL);
    // ...
}
```

这意味着：不同驱动之间通过 claim 机制互斥，防止两个外设同时抢占同一个 GPIO。如果 `wq_spi_open` 返回 `WQ_RET_BUSY`，很可能是因为 GPIO 已被其他驱动占用。

### 3.3 输出引脚的毛刺风险

先设方向，再设电平——这是最常见的 GPIO 错误。考虑以下场景：

```c
// 错误：先设方向为输出，再设电平
wq_gpio_open(gpio, WQ_GPIO_DIRECTION_OUTPUT); // 此时输出电平不确定！
wq_gpio_write(gpio, 0);                       // 然后才拉到低电平
```

在 `open` 和 `write` 之间，GPIO 输出电平是寄存器复位值（可能是高电平），如果这个引脚控制了外部电源或复位信号，就会产生一次意外的毛刺（glitch）。

**正确的做法**：如果硬件支持，先设输出电平，再切方向。WQ HAL 的 `wq_gpio_open` 不提供"初始电平"参数，所以在调用前需要通过硬件层直接写输出寄存器，或者在设计硬件时确保外部电路能容忍短暂的毛刺（如用下拉电阻保证默认低电平）。

这个问题在 SPI CS 和 I2C 的 GPIO 控制中尤为关键——CS 毛刺可能误触发外设，I2C 的 GPIO 复位可能拉低 SDA 导致总线被锁死。

### 3.4 低功耗唤醒的完整流程

`wq_gpio_wakeup_enable` 的注释（wq_gpio.h:169-176）明确写：

> Only support AON gpio, need config gpio as interrupt first, and enable GPIO wakeup source. Only support LEVEL interrupt wakeup.

正确的唤醒配置流程：

```c
// 1. 先配置为中断输入（内部已使能中断，不需要再调 wq_gpio_int_enable）
wq_gpio_open_as_interrupt(AON_GPIO, WQ_GPIO_INT_LEVEL_LOW, wakeup_cb);
// 2. 使能唤醒（仅 AON GPIO，仅电平中断）
wq_gpio_wakeup_enable(AON_GPIO);
// 4. 进入深度睡眠
// ...
// 5. 唤醒后，获取唤醒源
WQ_GPIO_ID wakeup_gpio;
uint8_t wakeup_level;
wq_gpio_get_wakeup_source(&wakeup_gpio, &wakeup_level);
```

唤醒后，`wq_gpio_get_wakeup_source` 可以查出是哪个 GPIO 唤醒了芯片，以及唤醒时的电平状态。这对于区分"按键唤醒"和"充电器插入唤醒"非常重要。

---

## 第四层：V861/reGlasses 的 GPIO 和 pinctrl

### 4.1 Linux 设备树中的 GPIO 配置

V861 的 GPIO 通过 Linux pinctrl 子系统管理。在 `board.dts` 中，每个引脚功能通过 pinctrl 节点定义：

```dts
/* GPIO 输入模式（按键、中断） */
key_pin: key-pin@0 {
    pins = "PH2";
    function = "gpio_in";
};

/* 外设复用模式 */
uart2_pins_active: uart2_pins@0 {
    pins = "PD18", "PD19";
    function = "uart2";
};

/* GPIO 扩展器中断输入 */
gpio_ext_irq_pin: gpio-ext-irq@0 {
    pins = "PL1";
    function = "gpio_in";
};
```

### 4.2 GPIO 扩展器：TCA9539

reGlasses 使用 TCA9539（兼容 PCA9539）作为 GPIO 扩展器，通过 I2C 总线（TWI1，地址 0x74）提供额外的 16 个 GPIO。在 `board.dts` 中：

```dts
gpio_ext: tca9539@74 {
    compatible = "nxp,pca9539";
    reg = <0x74>;
    gpio-controller;
    #gpio-cells = <2>;
    vcc-supply = <&vcc1v8_gpio_ext>;
    reset-gpios = <&rtc_pio PL 1 GPIO_ACTIVE_LOW>;
};
```

TCA9539 的 GPIO 用于摄像头 reset/pwdn 控制和 LED 驱动。这是通过 I2C 间接控制的 GPIO——不是 SoC 引脚，而是总线上的另一个芯片。在调试时，逻辑分析仪抓 I2C 总线比测 GPIO 引脚更能说明问题。

### 4.3 WQ HAL 和 Linux pinctrl 的本质区别

| 对比维度 | WQ HAL（`wq_gpio_*`） | Linux pinctrl + gpiolib |
|---|---|---|
| 资源管理 | `gpio_claim`/`release` 软件互斥 | pinctrl 框架 + `gpio_request`/`free` |
| 复用配置 | `gpio_mtx_set_out_signal` 矩阵 | pinctrl 节点 + `function` 属性 |
| 中断 | `wq_gpio_open_as_interrupt` + 回调 | `request_irq` + `gpio_to_irq` |
| 上下拉 | `wq_gpio_set_pull_mode` | pinctrl 的 `bias-pull-up`/`bias-pull-down` |
| 驱动强度 | `wq_gpio_set_drive` | `drive-strength` 属性 |
| 唤醒 | `wq_gpio_wakeup_enable`（仅 AON） | `wakeup-source` 属性 |

---

## 第五层：常见故障与诊断

### 5.1 故障排查顺序

```text
GPIO 不工作？
  ├─ 引脚被 claim 了吗？
  │   └─ 检查 wq_gpio_open 返回值、gpio_claim 是否返回 BUSY
  ├─ 复用功能对吗？
  │   └─ 引脚是否被其他驱动复用为 UART/I2C/SPI 了？
  ├─ 方向对吗？
  │   └─ 输入输出方向是否与预期一致？
  ├─ 上下拉配置了吗？
  │   └─ 浮空输入的电平是否稳定？用万用表测引脚电压
  ├─ 输出电平对吗？
  │   └─ 用万用表或示波器直接测引脚
  └─ 中断触发了吗？
      ├─ 中断模式（边沿/电平）是否匹配信号特征？
      ├─ 回调是否已注册？
      └─ 中断是否被屏蔽（wq_gpio_int_disable）？
```

### 5.2 典型故障表

| 现象 | 第一假设 | 需要的证据 | 不要先做什么 |
|---|---|---|---|
| 输入读到随机值 | 引脚浮空，没有上下拉 | 万用表测引脚电压是否稳定 | 不要在代码中加多次读取取平均 |
| 按键按一次触发多次 | 机械抖动，没做去抖 | 示波器看按键引脚波形，观察抖动持续时间 | 不要直接改中断模式 |
| 中断不触发 | 中断模式错误或中断被屏蔽 | 检查 `int_mode` 配置、`int_en` 状态位 | 不要只加打印看是否进入 ISR |
| 中断持续触发（风暴） | 电平中断但中断源未清除 | 检查中断模式、ISR 中是否清除了中断源 | 不要只关全局中断 |
| 输出电平不对 | 方向未设或引脚被其他驱动占用 | 检查 `dir` 字段、`gpio_claim` 返回值 | 不要只改输出值 |
| 唤醒不工作 | 不是 AON GPIO 或用了边沿中断 | 检查 GPIO 是否在 AON 域、中断模式是否电平 | 不要在唤醒后不读唤醒源 |
| gpio_claim 返回 BUSY | 引脚已被其他驱动占用 | 搜索代码中谁 claim 了这个 GPIO | 不要绕过 claim 直接操作寄存器 |
| 输出毛刺导致外设异常 | 先设方向后设电平 | 检查 open 和 write 的顺序 | 不要只加延迟 |

### 5.3 诊断 GPIO 资源冲突

当多个驱动争抢同一个 GPIO 时，`gpio_claim` 返回 `WQ_RET_BUSY`。诊断方法：

1. 搜索代码中所有 `gpio_claim` 和 `gpio_claim_group` 调用点；
2. 检查每个调用点传入的 GPIO 号；
3. 检查 `allow_share` 参数——如果为 `true`，部分共享可能不报错但行为异常；
4. 查看 `gpio_mtx` 配置——同一个物理引脚可能通过矩阵被多个内部信号驱动。

---

## 第六层：练习与验收

### 练习一：用万用表验证 GPIO 配置

找一块 WQ 开发板，写一段代码：
1. 配置一个 GPIO 为输出，输出高电平，用万用表测电压；
2. 输出低电平，再测；
3. 配置为输入，接上拉电阻到 3.3V，读电平；
4. 去掉上拉，读 10 次电平，观察是否随机变化。

**通过标准**：能解释为什么浮空输入的电平不稳定，以及上拉电阻如何解决这个问题。

### 练习二：追踪 WQ 的 GPIO 资源管理

打开 `wqcore/driver/periph/common/hal/gpio/wq_gpio.c`，回答：

1. `wq_gpio_open` 和 `wq_gpio_open_as_interrupt` 分别设置了哪些状态字段？
2. `wq_gpio_isr_handler` 如何找到触发中断的 GPIO？为什么遍历所有 GPIO 而不是只读一个寄存器？
3. `wq_gpio_wakeup_enable` 为什么只支持 AON GPIO 和电平中断？

**通过标准**：能画出 GPIO 状态结构体（`wq_gpio_info_t`）的字段和它们的含义。

### 练习三：分析按键电路

给定：按键一端接 GPIO，另一端接 GND。GPIO 配置为输入，上拉使能。

1. 画出电路原理图，标注不按和按下时的电流路径；
2. 如果上拉电阻是 10kΩ，VDD=3.3V，按下时流过按键的电流是多少？
3. 如果上拉电阻改为 100kΩ，会有什么问题？
4. 如果 GPIO 误配为下拉，不按和按下时分别读到什么？

**通过标准**：能计算上拉电阻的功耗和输入电压，以及解释为什么内部上拉（通常 ~50kΩ）比外部上拉（通常 4.7kΩ-10kΩ）弱。

### 练习四：分析 V861 设备树的 GPIO 配置

阅读 `aiglass/reglasses/device/configs/reglasses/linux-6.6-xuantie/board.dts`，回答：

1. TCA9539 的 `reset-gpios` 是哪个引脚？为什么是 `GPIO_ACTIVE_LOW`？
2. `gpio_ext_irq_pin` 的作用是什么？它连接到 TCA9539 的哪个引脚？
3. `cd-gpios`（SD 卡检测）的配置为什么同时有 `GPIO_ACTIVE_LOW` 和 `GPIO_PULL_UP`？

**通过标准**：能解释 Linux 设备树中 GPIO 标志的组合含义，以及为什么某些配置需要同时指定有效电平（active low/high）和上下拉。

### 练习五：设计毛刺故障定位实验

现象：系统上电后，某个外设（如摄像头）偶尔不工作，但复位后正常。假设是 GPIO 初始化时的毛刺导致。

1. 如何用示波器抓取这个毛刺？（触发条件、时间刻度、探头位置）
2. 如何修改代码验证"先设电平再切方向"是否解决了问题？
3. 如果硬件不支持先设电平，如何从硬件上保护外设不受毛刺影响？

**通过标准**：能设计一个可重复的实验，区分"软件初始化顺序问题"和"硬件上电时序问题"。

## 自测题

1. **推挽输出和开漏输出有什么区别？为什么 I2C 用开漏？**
   - 推挽主动驱动高低电平，开漏只拉低、高电平靠上拉。I2C 用开漏是因为多个设备共享 SDA/SCL，需要"线与"特性——任何一个设备拉低，总线就是低电平，不会出现短路。

2. **边沿中断和电平中断各适合什么场景？**
   - 边沿中断适合"事件"型信号（按键按下、传感器就绪的瞬间），触发一次即结束。电平中断适合"状态"型信号（故障、电源异常），需要持续响应直到状态解除。但电平中断有中断风暴风险。

3. **WQ 的 `wq_gpio_open_as_interrupt` 之后还需要调用 `wq_gpio_int_enable` 吗？**
   - 不需要。`wq_gpio_open_as_interrupt` 内部（wq_gpio.c:314）已经调用了 `gpio_int_enable(gpio, mode)`。`wq_gpio_int_enable` 的用途是在 ISR 中调用了 `wq_gpio_int_disable` 屏蔽中断后，重新使能中断。

4. **为什么输出引脚要先设电平再切方向？**
   - 如果先切方向（变为输出），引脚立刻输出当前寄存器的值（可能是复位值），这个值可能不是目标电平。先设电平可以保证方向切换瞬间引脚已经在目标电平。这在控制电源使能、复位信号时尤为关键。

5. **WQ 的 `wq_gpio_wakeup_enable` 有什么限制？**
   - 仅支持 AON GPIO（Always-On 域），且仅支持电平中断唤醒。边沿中断在深度睡眠时无法捕获，因为睡眠时没有时钟来检测边沿。

6. **V861 的 TCA9539 GPIO 扩展器和 SoC 原生 GPIO 有什么区别？**
   - TCA9539 通过 I2C 总线间接控制，每个 GPIO 操作需要一次 I2C 事务（约 100-400 kHz 总线速度），速度远慢于 SoC 原生 GPIO（直接寄存器操作）。不能用 TCA9539 的 GPIO 做精确时序控制或高速信号。

7. **`gpio_claim` 返回 `WQ_RET_BUSY` 通常是什么原因？**
   - 该 GPIO 已被其他驱动 claim。可能原因：两个外设驱动配置了相同的 GPIO 引脚、I2C/SPI/UART 的 GPIO 复用配置冲突、之前打开的外设未正确关闭。

## 常见反例

- 把 GPIO 的输入浮空当作"默认低电平"。浮空不等于低电平，电磁干扰会使其随机翻转。
- 在 ISR 中做耗时操作（如打印 log、延时去抖）。应该只记录时间戳和 GPIO 号，交给任务处理。
- 用 `gpio_set_level` 和 `gpio_set_direction` 这种不存在的 API。WQ 的真实 API 是 `wq_gpio_write` 和 `wq_gpio_open`。
- 认为所有 GPIO 都能做唤醒源。只有 AON 域的 GPIO 有此能力。
- 在电平中断的 ISR 中不清除中断源也不屏蔽中断。会导致中断风暴。
- 多个驱动同时 claim 同一个 GPIO 但不检查返回值。`gpio_claim` 失败时静默返回 BUSY，后续操作会异常。
- 忽略 TCA9539 的 I2C 延迟。通过 I2C 扩展的 GPIO 写入后，需要等 I2C 事务完成，不能立即读回。

## 参考资料

- WQ7036AX GPIO HAL：`wqcore/driver/periph/common/hal/gpio/wq_gpio.h`、`wq_gpio.c`
- WQ7036AX GPIO 硬件层：`wqcore/driver/periph/bbb/hw/gpio.h`、`gpio.c`
- V861 设备树：`aiglass/reglasses/device/configs/reglasses/linux-6.6-xuantie/board.dts`
- [[i2c-basics-I2C基础]] — I2C 的开漏结构依赖 GPIO 的上拉配置
- [[spi-basics-SPI基础]] — SPI 的 CS 和 CLK 依赖 GPIO 的上下拉和驱动强度
- [[uart-basics-UART基础]] — UART 的 TX/RX 是 GPIO 的复用功能
- [[interrupt-concurrency-中断并发同步]] — GPIO 中断的 ISR 编写约束
- [[devicetree-DeviceTree设备树]] — V861 的 pinctrl 和 GPIO 配置
- [[elm2713-ELM2713光传感器]] — LS_INT 中断源

#flashcard

问：推挽输出和开漏输出的本质区别是什么？
答：推挽用两个晶体管主动驱动高低电平，边沿陡峭但多个输出不能并联。开漏只有一个下拉晶体管，高电平靠上拉电阻恢复，多个开漏输出可以安全并联（线与）。

问：WQ 的 `wq_gpio_open_as_interrupt` 支持哪几种中断模式？
答：5 种——上升沿、下降沿、双边沿、低电平、高电平。唤醒仅支持电平中断。

问：为什么按键要用上拉电阻？
答：按键一端接 GPIO、另一端接 GND。不按时，上拉电阻将 GPIO 拉到高电平（逻辑 1）；按下时，GPIO 被 GND 拉到低电平（逻辑 0）。没有上拉时，不按的 GPIO 浮空，电平不确定。

问：WQ 的 `wq_gpio_wakeup_enable` 有什么限制？
答：仅支持 AON GPIO（Always-On 域），且仅支持电平中断（LEVEL_LOW 或 LEVEL_HIGH）。必须先配置为中断输入并使能中断，再使能唤醒。边沿中断不能作为唤醒源，因为睡眠时没有时钟检测边沿。