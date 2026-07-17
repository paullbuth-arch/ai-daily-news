---
type: concept
tags: [LinuxDriver, 驱动框架, Platform Driver, 外设驱动, probe, 设备模型, WQ7036A]
aliases: [platform driver, 外设驱动框架, 驱动模型, 设备驱动, probe, platform]
---

# 外设驱动通用框架

## 一句话结论

所有外设驱动的本质都是五步：使能时钟 → 配置引脚 → 设置工作模式 → 启动外设 → 读写数据。不管是 GPIO、UART、I2C、SPI 还是 ADC，流程都一样，只是寄存器和参数不同。

## 30秒先看懂

- 任何外设驱动的初始化都可以归纳为五步：开时钟、配引脚、设模式、使能、读写数据，这个流程在任何芯片平台上都通用。
- 数据传输有三种方式：轮询（CPU 循环查状态）、中断（硬件通知 CPU）、DMA（外设直接搬数据到内存），选择依据是数据量和实时性要求。
- 好的驱动代码分为三层：硬件驱动层（HAL，操作寄存器）、驱动抽象层（API，统一接口）、应用层（业务逻辑），层间解耦便于移植。
- 外设选择的黄金法则：调试用 UART，多低速传感器共享用 I2C，高速数据传输用 SPI。
- WQ7036A 的驱动代码在 `wqcore/driver/periph/` 下，按芯片系列（bbb/hornet/emu）分目录组织。

## 学完以后应该能做什么

**第一遍**
- 能说出外设初始化的通用五步流程
- 能区分轮询、中断、DMA 三种传输方式的选择场景
- 能读懂 WQ7036A SDK 中的 UART/I2C/GPIO 驱动代码

**进阶**
- 能自己写一个外设驱动（从寄存器手册到 API 封装）
- 能设计驱动分层架构，实现代码复用
- 能用逻辑分析仪调试外设通信问题

## 前置知识

- C 语言基础：指针、结构体、位操作
- 计算机组成：寄存器、中断、内存映射
- GPIO 基础概念：输入、输出、复用功能

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|----------|
| 通用输入输出 | GPIO (General Purpose I/O) | 最基本的引脚控制，可以读输入电平或写输出电平 |
| 引脚复用 | Pin Mux (Pin Multiplexing) | 一个引脚可以配置为多种功能，通过寄存器选择 |
| 时钟使能 | Clock Enable | 外设必须有时钟才能工作，不使能时钟则寄存器读写无效 |
| 波特率 | Baud Rate | UART 每秒传输的符号数，单位 bps（bits per second） |
| 中断服务程序 | ISR (Interrupt Service Routine) | 硬件触发中断时 CPU 自动执行的函数 |
| 直接内存访问 | DMA (Direct Memory Access) | 外设直接读写内存，不需要 CPU 逐字节搬运 |
| 硬件抽象层 | HAL (Hardware Abstraction Layer) | 封装底层寄存器操作的中间层，方便驱动在不同芯片间移植 |
| 推挽输出 | Push-Pull Output | 可以输出高电平或低电平的 GPIO 模式 |
| 开漏输出 | Open Drain Output | 只能拉低不能拉高，需要外部上拉电阻的 GPIO 模式 |

## 第一层：费曼心智模型

### 类比：家电使用流程

外设就像家里的电器，使用流程完全一致：

| 步骤 | 电器类比 | MCU 外设 |
|------|---------|----------|
| 1. 使能时钟 | 打开空气开关 | `clk_enable(UART1)` |
| 2. 配置引脚 | 把电器插到正确的插座 | `pin_set_func(PIN, FUNC_UART)` |
| 3. 配置模式 | 设置电器的档位（温度/风速） | `uart_init(115200, 8N1)` |
| 4. 使能外设 | 按下电源按钮 | `uart_enable(UART1)` |
| 5. 读写数据 | 真正使用电器 | `uart_send('A')` |

### 边界在哪里

- 驱动代码不处理业务逻辑——它只负责让硬件正确工作，业务逻辑在应用层
- 驱动层和应用层的接口要保持稳定——换芯片时只改底层 HAL，不改变上层 API
- 轮询、中断、DMA 不是互斥的——可以混合使用（如 DMA 传大数据，中断处理完成事件）
- 外设初始化顺序很重要——某些外设依赖其他外设先初始化（如 I2C 设备依赖 I2C 控制器）

### 场景演练：WQ7036A 初始化 UART1 与 V881 通信

1. 查阅芯片手册，找到 UART1 的基地址（`APB_UART1_BASEADDR`）和时钟 ID（`APB_CLK_UART1`）
2. 调用 `clk_enable(APB_CLK_UART1)` 使能 UART1 时钟
3. 调用 `pin_set_func(tx_pin, FUNC_UART1_TX)` 和 `pin_set_func(rx_pin, FUNC_UART1_RX)` 配置引脚
4. 调用 `uart_init(UART1, 115200, 8, UART_PARITY_NONE, 1)` 设置波特率 115200、8 数据位、无校验、1 停止位
5. 调用 `uart_enable(UART1)` 使能 UART1
6. 调用 `uart_send_byte(UART1, 'A')` 发送数据
7. 调用 `uart_read_byte(UART1)` 接收数据（或注册中断回调）

## 第二层：原理/时序/约束

### 通用初始化流程

```
┌───────────────────┐
│ 1. 使能外设时钟     │  ← 不开时钟，寄存器读写无效
├───────────────────┤
│ 2. 配置 GPIO/引脚   │  ← 引脚复用（Pin Mux），选对功能
├───────────────────┤
│ 3. 配置工作模式     │  ← 波特率/极性/采样率等
├───────────────────┤
│ 4. 配置中断/DMA     │  ← 可选：轮询 or 中断 or DMA
├───────────────────┤
│ 5. 使能外设         │  ← 打开使能位
├───────────────────┤
│ 6. 读写数据         │  ← 业务逻辑
└───────────────────┘
```

### UART / I2C / SPI 对比

| 特性 | UART | I2C | SPI |
|------|------|-----|-----|
| 线数 | 2（TX/RX） | 2（SDA/SCL） | 4+（MOSI/MISO/CLK/CS） |
| 速度 | 低（9600~115200 常见） | 中（100k/400k/1M） | 高（可达数十 MHz） |
| 主从 | 点对点（无主从概念） | 多从（7位/10位地址） | 一主多从（CS 选择） |
| 同步/异步 | 异步（无时钟线） | 同步（有 SCL） | 同步（有 CLK） |
| 全双工 | 是（TX/RX 独立） | 半双工（SDA 双向） | 全双工（MOSI/MISO 独立） |
| 典型用途 | 调试打印、模块通信 | 传感器、EEPROM | Flash、显示屏、高速 ADC |

### 轮询 vs 中断 vs DMA

| 方式 | 工作方式 | CPU 占用 | 适用场景 |
|------|---------|---------|----------|
| **轮询 (Polling)** | CPU 循环查"有数据吗？" | 高 | 初始化、简单场景 |
| **中断 (Interrupt)** | 有数据时硬件通知 CPU | 低 | 中低速、事件驱动 |
| **DMA** | 外设直接搬数据到内存 | 极低 | 高速、大数据量（音频/ADC） |

### 驱动分层设计

```
┌─────────────────────┐
│  应用层（App）        │  业务逻辑：读温度、显示数据
├─────────────────────┤
│  驱动抽象层（API）    │  统一接口：sensor_read()、uart_send()
├─────────────────────┤
│  硬件驱动层（HAL）    │  具体寄存器操作：GPIO、时钟、中断
└─────────────────────┘
```

## 第三层：真实 SDK 代码

### WQ7036AX 的 UART 驱动

文件路径：`/home/ys/wq7036a/wq-audio/wqcore/driver/periph/bbb/hw/uart.c`

```c
// UART 基地址表（每个端口对应一个寄存器基地址）
static uart_reg_t *const uart_bases[WQ_UART_PORT_MAX] = {
    (uart_reg_t *)APB_UART0_BASEADDR,
    (uart_reg_t *)APB_UART1_BASEADDR,
    (uart_reg_t *)APB_UART2_BASEADDR,
    (uart_reg_t *)APB_UART3_BASEADDR,
};

// UART 时钟表（每个端口对应的 APB 时钟）
static const APB_CLK uart_apb_clk[WQ_UART_PORT_MAX] = {
    APB_CLK_UART0,
    APB_CLK_UART1,
    APB_CLK_UART2,
    APB_CLK_UART3,
};
```

文件路径：`/home/ys/wq7036a/wq-audio/wqcore/driver/periph/bbb/hw/uart.h`

```c
// UART 数据位配置
typedef enum {
    UART_DATA_BITS_5 = 0,
    UART_DATA_BITS_6 = 1,
    UART_DATA_BITS_7 = 2,
    UART_DATA_BITS_8 = 3,
} UART_DATA_BITS;

// UART 校验配置
typedef enum {
    UART_PARITY_NONE,
    UART_PARITY_EVEN,
    UART_PARITY_ODD,
} UART_PARITY;

// UART 停止位配置
typedef enum {
    UART_STOP_BITS_1 = 1,
    UART_STOP_BITS_1_5 = 2,
    UART_STOP_BITS_2 = 3,
} UART_STOP_BITS;
```

### WQ7036AX 的 I2C 驱动

文件路径：`/home/ys/wq7036a/wq-audio/wqcore/driver/periph/bbb/hw/i2c.c`

```c
// I2C 基地址表
static i2c_master_reg_t *const i2c_bases[] = {
    (i2c_master_reg_t *)I2C0_BASEADDR,
    (i2c_master_reg_t *)I2C1_BASEADDR,
    (i2c_master_reg_t *)I2C2_BASEADDR,
    (i2c_master_reg_t *)I2C3_BASEADDR,
};

// I2C 时钟表
static const APB_CLK i2c_apb_clk[WQ_I2C_PORT_MAX] = {
    APB_CLK_IIC0,
    APB_CLK_IIC1,
    APB_CLK_IIC2,
    APB_CLK_IIC3,
};

// I2C 中断向量表
static const uint32_t i2c_int_vector[WQ_I2C_PORT_MAX] = {
    I2C0_2_INT,
    I2C1_3_INT,
    I2C0_2_INT,
    I2C1_3_INT,
};
```

### 驱动抽象层接口设计

```c
// 驱动抽象层接口（设备无关）
typedef struct {
    int  (*init)(void *config);
    int  (*read)(uint8_t *buf, uint32_t len);
    int  (*write)(const uint8_t *buf, uint32_t len);
    void (*deinit)(void);
} device_ops_t;

// 应用层不需要知道底层是 I2C 还是 SPI
device_ops_t *sensor = &i2c_sensor_ops;
sensor->init(&config);
sensor->read(buf, len);
```

## 第四层：正常/异常路径

### 正常路径

1. 时钟使能成功 → 外设寄存器可正常读写
2. 引脚配置正确 → 功能正常，无冲突
3. 模式配置与外设匹配 → 通信正常
4. 中断/DMA 配置正确 → 数据收发高效

### 异常路径

| 问题 | 现象 | 根因 | 排查方法 |
|------|------|------|----------|
| 忘记使能时钟 | 外设寄存器读写全是 0 或 0xFF | 没调 clk_enable() | 检查初始化代码中是否有时钟使能 |
| 引脚复用配错 | 同一个引脚被两个外设抢，行为不确定 | 引脚功能表选错 | 检查芯片手册，确认该引脚支持的功能 |
| 波特率不匹配 | UART 通信收到乱码 | 两端波特率不一致 | 用示波器测 TX 引脚波形，计算波特率 |
| I2C 无上拉电阻 | I2C 总线无响应，SDA/SCL 空闲低电平 | I2C 是开漏总线，需要外部上拉 | 万用表测 SDA/SCL 空闲电平（应为高） |
| SPI 片选忘记控制 | 通信失败，设备无响应 | 每次通信前没有拉低 CS | 检查通信代码中 CS 控制逻辑 |
| SPI 模式不匹配 | 数据全错 | 主从的 CPOL/CPHA 配置不一致 | 检查 datasheet 确定设备支持的 SPI 模式 |

## 第五层：调试方法

### GPIO 调试

```c
// 用 GPIO 示波替代——在关键代码路径上翻转 GPIO 引脚
// 用示波器看 GPIO 波形，可以精确测量代码执行时间
gpio_write(DEBUG_PIN, GPIO_HIGH);
// ... 待测量的代码段 ...
gpio_write(DEBUG_PIN, GPIO_LOW);
```

### 寄存器调试

```c
// 直接读取外设寄存器确认状态
uint32_t status = *(volatile uint32_t *)(UART1_BASEADDR + UART_SR_OFFSET);
// 检查状态寄存器中的 TX_EMPTY、RX_FULL 等标志位
```

### 逻辑分析仪调试

```bash
# 抓取 I2C/SPI/UART 波形
# 用逻辑分析仪（如 Saleae、PulseView）连接信号线和 GND
# 设置适当的采样率（至少信号频率的 4 倍）
# 观察：
# - UART: 波特率、数据位、停止位是否正确
# - I2C: 地址是否正确、是否有 ACK、SCL 频率
# - SPI: 模式（CPOL/CPHA）、CS 时序、数据内容
```

## 第六层：实战练习

### 练习 1：阅读 WQ7036A 的 UART 驱动代码

阅读 `/home/ys/wq7036a/wq-audio/wqcore/driver/periph/bbb/hw/uart.c` 和 `uart.h`，回答：
- UART 驱动如何管理多个端口（UART0-UART3）？
- 波特率是如何配置的？找到波特率寄存器设置代码
- 中断处理函数在哪里注册？支持哪些中断类型？

### 练习 2：实现一个 GPIO 按键驱动

写一个 GPIO 按键驱动（伪代码），要求：
- 支持按键消抖（按下后等待 20ms 再确认）
- 支持下降沿中断触发
- 按键按下时打印"KEY_PRESSED"，释放时打印"KEY_RELEASED"
- 包含完整的五步初始化流程

### 练习 3：I2C 传感器读写

假设你有一个 I2C 温度传感器，地址 0x48，温度寄存器地址 0x00（16 位，大端），写一个函数 `int read_temperature(int i2c_port, float *temp)`，返回温度值。提示：`i2c_smbus_read_word_data()`。

### 练习 4：分析 WQ7036A 的 I2C 驱动数据流

阅读 `/home/ys/wq7036a/wq-audio/wqcore/driver/periph/bbb/hw/i2c.c`，回答：
- I2C 中断处理函数如何处理收发完成事件？
- TX FIFO 和 RX FIFO 的阈值设置是多少？
- 不支持 SMBus 的 I2C 从设备时，驱动如何兼容？

## 自测与验收

1. 外设初始化的通用五步流程是什么？每一步的作用是什么？
2. 轮询、中断、DMA 三种数据传输方式的区别是什么？分别适用于什么场景？
3. 驱动分层设计中，HAL 层、API 层、应用层各负责什么？
4. I2C 为什么需要上拉电阻？SPI 为什么不需要？
5. UART 通信收到乱码时，最可能的原因是什么？如何排查？

## 延伸阅读

- [[c-core-C语言核心]] — 位运算、volatile、寄存器操作
- [[interrupt-concurrency-中断并发同步]] — 外设中断的使用
- [[memory-dma-内存管理与DMA]] — DMA 传输
- [[debug-tools-常用调试工具链]] — 用逻辑分析仪抓外设波形
- [[i2c-spi-gpio-subsys-I2C-SPI-GPIO子系统]] — Linux 子系统封装

## #flashcard

Q: 外设初始化的通用五步流程是什么？
A: 使能时钟 → 配置引脚（Pin Mux）→ 设置工作模式（波特率/采样率等）→ 配置中断/DMA（可选）→ 使能外设 → 读写数据。

Q: 轮询、中断、DMA 三种方式分别适用于什么场景？
A: 轮询：初始化、数据量小、低实时性；中断：中低速、事件驱动；DMA：高速、大数据量（音频/ADC/显示）。

Q: 驱动分层设计的三层是什么？各层职责是什么？
A: HAL 层（硬件驱动层）：操作寄存器，与具体芯片相关；API 层（驱动抽象层）：统一接口，设备无关；应用层：业务逻辑。

Q: 为什么 I2C 需要上拉电阻而 SPI 不需要？
A: I2C 是开漏（Open Drain）总线，引脚只能拉低不能拉高，需要外部上拉电阻提供高电平。SPI 是推挽输出，可以直接输出高/低电平。

Q: UART 乱码的最可能原因是什么？
A: 两端波特率不一致。用示波器测量 TX 引脚波形，计算一个 bit 的宽度，反推实际波特率。