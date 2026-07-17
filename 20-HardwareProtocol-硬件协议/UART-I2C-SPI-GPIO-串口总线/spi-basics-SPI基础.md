---
type: concept
created: 2026-07-17
tags: [protocol, spi, bus, flash, 总线, 高速接口]
aliases: [SPI, Serial Peripheral Interface, 串行外设接口]
---

# SPI 基础：从四线全双工到真实 DMA 传输

> **一句话结论**：SPI（Serial Peripheral Interface，串行外设接口）不是"四根线各发各的"，它是一套由推挽电气结构、时钟极性和相位（CPOL/CPHA）、帧格式、片选时序、FIFO 缓冲和 DMA 链式传输共同组成的高速全双工总线协议。真正会用 SPI，意味着你能从 CPOL/CPHA 配置、波形、SDK API 和 DMA 回调一直追到外部芯片的寄存器读写结果。

本篇的代码锚点来自一个真实工程：

- **WQ7036AX**：`/home/ys/wq7036a/wq-audio/wqcore/driver/periph/common/hal/spi/wq_spi.h`、`wq_spi.c`，`wqcore/driver/periph/bbb/hw/spi.h/.c`，`wq-adk/components/ext_trans/src/ext_trans_dev_spi.c`，以及 `wq-adk/examples/ext_loopback/acore/app/src/app_spi_trans.c`。
- **V861/reGlasses**：当前可编辑 BSP（`/home/ys/aiglass/reglasses/`）中未发现 SPI 外设的实际使用。`board.dts` 中的 `hwspinlock` 是硬件自旋锁，不是 SPI 总线。reGlasses 的 SPI 证据标记为"当前 SDK 缺口"。

文中"通用原理"是 SPI 协议本身；"SDK 事实"只针对上述 WQ 源码和配置；"待确认"标记表示尚未由当前源码或板级资料证实。

## 学完以后应该能做什么

1. 解释为什么 SPI 用推挽输出（push-pull）而不是开漏，以及这如何影响速度和布线距离。
2. 从波形中区分 SCK 空闲电平、数据采样边沿，并判断 CPOL 和 CPHA。
3. 根据器件手册选择正确的 SPI 模式（Mode 0/1/2/3）、帧大小（8/16 bit）和频率。
4. 看懂 WQ HAL 的 `wq_spi_poll_transfer`、`wq_spi_poll_duplex_transfer` 和 DMA 版本的区别，知道什么时候用哪个。
5. 理解 simplex（先发后收）和 duplex（同时收发）两种传输模式在硬件层的实现差异。
6. 追踪 `ext_trans_dev_spi` 如何将 SPI 抽象为芯片间通信通道，以及 `app_spi_trans` 如何通过自定义协议加载外部 DSP 固件。
7. 面对模式不匹配、数据偏移、DMA 超时、时钟频率不符合要求等故障，能提出可验证的假设。

## 前置知识

- 会读十六进制、位运算和 C 函数声明；可先看 [[c-core-C语言核心]]。
- 知道 GPIO 的输入、输出、推挽/开漏、复用和上下拉；可先看 [[gpio-config-GPIO配置]]。
- 理解 I2C 的开漏结构和上拉计算会帮助理解"为什么 SPI 比 I2C 快"；可先看 [[i2c-basics-I2C基础]]。
- 如果要理解 DMA 回调，需要 [[dma-basics-DMA基础]]。
- 如果要理解芯片间通信协议栈，需要 [[ext-trans-外部传输协议]]。

## 术语先讲清楚

| 术语 | 英文 | 在 SPI 中具体指什么 |
|---|---|---|
| 控制器 | controller/master | 产生 SCK、决定片选、发起传输的一方。旧资料常写 master。控制器不一定是 CPU——DMA 引擎也可以充当控制器，把内存数据直接推入 SPI FIFO |
| 外设 | peripheral/slave | 被片选选中、响应控制器时钟的一方。旧资料常写 slave。外设的 MISO 在 CS 拉高后必须释放为高阻态，否则多个外设的 MISO 会互相冲突 |
| 推挽 | push-pull | 输出级用两个晶体管：上管导通时引脚直连 VDD（输出高电平），下管导通时引脚直连 GND（输出低电平）。两个推挽输出不能直接并联——如果一个输出高、另一个输出低，VDD 和 GND 之间会形成短路。这是 SPI 的 MISO 必须用三态（CS 拉高后释放）而不能直接并联的根本原因 |
| 片选 | CS（Chip Select）/ SS（Slave Select） | 控制器拉低某个外设的 CS，该外设被选中——它的 MISO 从高阻态变为驱动状态，开始响应 SCK。拉高则释放。WQ SDK 支持两种 CS 控制：硬件自动（`auto_cs=true`）和驱动手动（`auto_cs=false`，由 `wq_spi_chip_select`/`chip_dis_select` 操作 GPIO） |
| 全双工 | full-duplex | MOSI 和 MISO 是两根独立的数据线，每个 SCK 周期内控制器在 MOSI 上发一个 bit 的同时，外设在 MISO 上回一个 bit。但"同时"不等于"内容相关"——MOSI 上发的是命令/地址/dummy，MISO 上回的是状态/数据，两者语义独立 |
| 时钟极性 | CPOL（Clock Polarity） | SCK 空闲时是低电平（CPOL=0）还是高电平（CPOL=1）。WQ 驱动在 `wq_spi_gpio_config()` 中根据 CPOL 自动配置 CLK 引脚的上下拉：CPOL=0 时拉低，CPOL=1 时拉高——这是为了让空闲时 CLK 保持在明确电平，避免悬空导致外设误判 |
| 时钟相位 | CPHA（Clock Phase） | 数据在 SCK 的第一个边沿（CPHA=0）还是第二个边沿（CPHA=1）被采样。注意：哪个边沿是"第一个"取决于 CPOL——CPOL=0 时第一个边沿是上升沿，CPOL=1 时第一个边沿是下降沿 |
| 帧大小 | frame size / DFS | 一个 SCK 连续脉冲组传输的 bit 数。WQ 硬件寄存器值为 n-1：`SPI_DFRAME_SIZE_8` = 0x7，`SPI_DFRAME_SIZE_16` = 0xF。`ext_trans_dev_spi.c` 在 SPI 频率 ≥ 24 MHz 时自动切换到 16-bit 帧，以减少帧开销 |
| dummy 字节 | dummy byte | 控制器为了产生 SCK 时钟而发送的占位数据。WQ `wq_spi_cfg_t.dummy_data` 字段指定占位值。纯接收模式（`inbuf_len>0` 且 `outbuf_len==0`）时，`wq_spi_poll_transfer` 先发一个 dummy frame 启动传输，然后读数据 |
| simplex | simplex transfer | 先发后收，两阶段不重叠。WQ 对应 `wq_spi_poll_transfer` / `wq_spi_dma_transfer`，硬件层使用 `SPI_TMOD_EEPROM`（读写都有时）或 `SPI_TMOD_TRANSMITER`/`RECIEVER`（单向时） |
| duplex | duplex transfer | 收发在每个 SCK 周期同时进行。WQ 对应 `wq_spi_poll_duplex_transfer` / `wq_spi_dma_duplex_transfer`，硬件层使用 `SPI_TMOD_TRANCIEVER`。收发长度不等时，较短的一侧用 `dummy_data` 补齐 |

---

## 第一层：用费曼技巧建立心智模型

### 1.1 SPI 像一条双向传送带——类比及其边界

把 SPI 想成工厂里的一条双向传送带，但这条传送带不是"一直开着"，而是只有控制器按下启动键（拉低 CS）后才开始运转：

- **SCK** 是传送带的节拍器。控制器决定传送带的速度，但速度不能超过外设能跟上的最大值。
- **MOSI** 是控制器往传送带上放零件（命令、地址），外设从传送带上取走。
- **MISO** 是外设同时往反向传送带上放零件（状态、数据），控制器取走。关键：外设只有在 CS 被拉低（被选中）时才往传送带上放东西，CS 拉高后外设必须把手从传送带上拿开（释放为高阻态），否则下一个被选中的外设放东西时会撞车。
- **CS** 是控制器指着某个外设说"轮到你"。同一时刻只有一个外设被选中。

这个类比有三个关键边界：

**边界一：传送带的速度（SCK 频率）受限于最慢的那个环节。** 控制器可能想跑 50 MHz，但如果外设的数据手册写最大 10 MHz，或者 PCB 走线太长导致信号边沿变形，实际能稳定工作的频率可能远低于控制器的能力。WQ SDK 的 `spi_clock_check()` 只检查 DCORE 频率是否 ≥ 4× SPI 频率，不检查外设和 PCB 的承受能力。

**边界二：控制器"读数据"时也必须往传送带上放东西。** 传送带的动力来自 SCK，而 SCK 是控制器产生的。如果控制器停止往 MOSI 上放数据，SCK 就停了，外设的 MISO 也不会更新。所以读数据时，控制器发的是 dummy 字节——占位数据，外设忽略，但保证了 SCK 持续运转。

**边界三：传送带两端放的东西互相独立，但时间上同步。** 控制器发第 1 个字节的同时，外设回第 1 个字节——但控制器发的是"命令 0x9F"，外设回的是"不管你在发什么，我先给你一个 0xFF（因为我还没收到完整命令）"。这个时间差是理解 SPI 读操作的关键。

### 1.2 四根线的电气角色

```
控制器（Master）                         外设（Slave）
    SCK  ──── 推挽输出 ────→              SCK 输入
    MOSI ──── 推挽输出 ────→              MOSI 输入
    MISO ←──── 三态输出 ────              MISO 推挽（仅 CS 低时驱动）
    CS   ──── 推挽输出 ────→              CS 输入（低有效）
```

- **SCK**：控制器推挽输出。空闲时电平由 CPOL 决定。WQ 驱动在 `wq_spi_gpio_config()` 中为 CLK 引脚配置上下拉：CPOL=0 时拉低（`GPIO_PULL_MODE_DOWN`），CPOL=1 时拉高（`GPIO_PULL_MODE_UP`）。驱动强度设置为 `GPIO_DRIVE_MODE_HIGH`。
- **MOSI**：控制器推挽输出，驱动强度 `HIGH`。外设端为输入。
- **MISO**：外设推挽输出，但带有三态控制——CS 为高时，外设的 MISO 输出级关断（高阻态），引脚由外部上下拉决定电平。这就是为什么多个外设的 MISO 可以共享控制器同一根引脚：只要同一时刻只有一个 CS 为低，就只有一个外设驱动 MISO。WQ 的 `bbb/hw/spi.c:272` 为 MISO 也设了 `GPIO_DRIVE_MODE_HIGH`。
- **CS**：控制器推挽输出，低有效。WQ 驱动为 CS 配置上拉（`GPIO_PULL_MODE_UP`），确保芯片复位时（GPIO 默认为输入）CS 被上拉电阻保持为高，外设不会被误选中。

### 1.3 完整场景演算：用 SPI 读一个外设寄存器的每一步

这是理解 SPI 最关键的具体场景。假设我们要从一个 SPI Flash（W25Q32，Mode 0）读取 JEDEC ID（命令 0x9F，返回 3 字节：Manufacturer ID、Memory Type、Capacity）。

**硬件配置**：WQ7036AX SPI_PORT0，Mode 0（CPOL=0, CPHA=0），8-bit 帧，CS 手动控制。

**第一步：控制器拉低 CS，外设被唤醒。**

```text
物理信号：CS 引脚从 3.3V 跳变到 0V。
外设动作：W25Q32 检测到 CS 下降沿，MISO 从高阻态切换为驱动状态，准备接收命令。
WQ 代码：wq_spi_chip_select(port) → gpio_write(cs, 0)
```

**第二步：控制器发送命令字节 0x9F（JEDEC ID）。**

```text
SCK 上产生 8 个脉冲（Mode 0：空闲低，上升沿采样）。
MOSI 依次输出：1, 0, 0, 1, 1, 1, 1, 1（0x9F 的二进制，MSB 先发）。
MISO 同时输出：外设收到第一个 bit 时还不知道命令是什么，所以回 0xFF（或全 1）。
          等第 8 个 bit 发完，外设才完整收到 0x9F，知道"这是读 ID 命令"。

控制器读到的第一字节：通常是 0xFF（外设在收到命令期间回的占位数据）。
WQ 代码：wq_spi_poll_transfer(port, tx_buf, 1, rx_buf, 3)
         硬件层用 SPI_TMOD_EEPROM 模式：先发 tx_buf[0]=0x9F，再发 3 个 dummy 读 3 字节。
```

**第三步：控制器继续发 3 个 dummy 字节，同时接收 3 字节 ID。**

```text
控制器发 dummy 0xFF（或 dummy_data 配置的值），产生 3×8=24 个 SCK 脉冲。
外设收到 0x9F 后，准备 Manufacturer ID（W25Q32 为 0xEF）。
外设在第 2 个字节的 MISO 上输出 0xEF，第 3 个字节输出 Memory Type，第 4 个字节输出 Capacity。

控制器 rx_buf 中收到的数据：
  rx_buf[0] = 0xFF（或 0x00，取决于外设——这是发 0x9F 时外设回的）
  rx_buf[1] = 0xEF（Manufacturer ID）
  rx_buf[2] = 0x40（Memory Type，W25Q32 为 0x40）
  rx_buf[3] = 0x16（Capacity，W25Q32 为 0x16）

WQ 代码：wq_spi_poll_transfer 先发 tx_buf[0]=0x9F，再发 3 个 dummy（来自 cfg.dummy_data），
         同时读 3 字节到 rx_buf。注意：rx_buf[0] 不是 Manufacturer ID！
```

**第四步：控制器拉高 CS，释放外设。**

```text
物理信号：CS 引脚从 0V 跳变到 3.3V。
外设动作：W25Q32 检测到 CS 上升沿，MISO 从驱动状态切换为高阻态，结束本次事务。
WQ 代码：wq_spi_chip_dis_select(port) → gpio_write(cs, 1)
```

**为什么 rx_buf[0] 不是 Manufacturer ID？**

这是 SPI 全双工最容易被误解的地方。在控制器发 0x9F 的 8 个 SCK 周期内，外设同时在 MISO 上输出数据——但外设此时还不知道控制器在发什么命令（命令还没收完），所以它只能回一个占位值（通常是 0xFF 或最后一个状态寄存器的值）。真正的 Manufacturer ID 要从第二个字节开始看。

这就是为什么 `wq_spi_poll_transfer` 的 simplex 模式（先发 1 字节命令，再发 3 字节 dummy 读 3 字节数据）会产生 4 个接收字节，而有效数据在 rx_buf[1]~rx_buf[3]。如果要跳过第一个无效字节，可以用 `wq_spi_poll_transfer(port, tx_4bytes, 4, rx_4bytes, 4)` 然后忽略 rx_buf[0]，或者用 `wq_spi_poll_transfer(port, tx_cmd, 1, rx_id, 3)` 直接收 3 字节（此时硬件发第 1 个 dummy 产生的接收字节被丢弃）。

### 1.4 为什么 SPI 用推挽而 I2C 用开漏——因果链

I2C 用开漏，是因为 SDA 和 SCL 上挂载了多个设备，每个设备都可能主动拉低线路。如果某个设备用推挽输出高电平，另一个设备同时拉低，就会形成 VDD→GND 短路。开漏的"线与"特性保证了：只要有一个设备拉低，总线就是低电平；所有设备都释放，总线才是高电平。代价是：高电平靠上拉电阻和线路电容的 RC 充电过程，上升时间 = 0.8473 × R × C，限制了速度。

SPI 不需要开漏，因为 MISO 通过三态控制避免了冲突——同一时刻只有一个外设驱动 MISO。所以 SPI 的 MOSI、MISO、SCK 都可以用推挽输出：上管导通时引脚直连 VDD，下管导通时直连 GND，边沿仅受限于晶体管开关速度和 PCB 走线电容，通常可以达到几十 MHz。代价是：每个外设需要一根独立的 CS 线，外设多了 GPIO 开销大；没有协议层应答，控制器不知道外设是否真的收到了数据。

**WQ SDK 事实**：`bbb/hw/spi.c:486-489` 的 `spi_clock_check()` 约束 DCORE 频率 ≥ 4× SPI 频率，且 `spi_set_frequence()` 强制分频比为偶数。例如，DCORE=96 MHz，请求 SPI=10 MHz，分频比 = 96/10 = 9.6 → 向上取偶数 = 10，实际 SCK = 96/10 = 9.6 MHz。如果请求 25 MHz，分频比 = 96/25 = 3.84 → 向上取偶数 = 4，实际 SCK = 24 MHz。这意味着实际频率总是 ≤ 请求值，且非整除时偏差可能较大。

---

## 第二层：时钟模式和时序

### 2.1 CPOL 和 CPHA 的四种组合

SPI 没有标准规定"数据在哪个边沿采样"，这是由器件设计决定的。两个参数控制：

- **CPOL（Clock Polarity，时钟极性）**：SCK 空闲时是低（0）还是高（1）。
- **CPHA（Clock Phase，时钟相位）**：在 SCK 的第一个边沿（0）还是第二个边沿（1）采样数据。

```text
CPOL=0（空闲低电平）:
SCK: ──╮     ┌──┐     ┌──
       │     │  │     │
       └─────┘  └─────┘

CPOL=1（空闲高电平）:
SCK: ──┐     ┌──┐     ┌──
       │     │  │     │
       └─────┘  └─────┘

CPHA=0（第一个边沿采样）: ↑  ↑  ↑  ↑  （CPOL=0 时是上升沿，CPOL=1 时是下降沿）
CPHA=1（第二个边沿采样）:    ↑  ↑  ↑  ↑  （CPOL=0 时是下降沿，CPOL=1 时是上升沿）
```

| Mode | CPOL | CPHA | SCK 空闲 | 数据采样边沿 | 常见设备 |
|---|---|---|---|---|---|
| **0** | 0 | 0 | 低 | 上升沿 | 大多数 SPI Flash（W25Q 系列） |
| 1 | 0 | 1 | 低 | 下降沿 | 部分音频 Codec、WQ ext_trans |
| 2 | 1 | 0 | 高 | 下降沿 | 少见 |
| **3** | 1 | 1 | 高 | 上升沿 | SD 卡 SPI 模式、部分显示屏 |

**WQ SDK 事实**：`wq_spi.h` 定义了 `WQ_SPI_CLK_MODE_0` 到 `WQ_SPI_CLK_MODE_3`，直接对应上面四种模式。`wq_spi_gpio_config()` 在 `wq_spi.c:556-562` 中根据 CPOL 自动配置 CLK 引脚的上下拉：CPOL=0 时 CLK 拉低（`GPIO_PULL_MODE_DOWN`），CPOL=1 时 CLK 拉高（`GPIO_PULL_MODE_UP`）。这是为了在总线空闲时让 CLK 保持在明确的电平。

**真实应用**：`ext_trans_dev_spi.c:99` 使用 `WQ_SPI_CLK_MODE_1`（CPOL=0, CPHA=1），`app_spi_trans.c:300` 同样使用 Mode 1。这提醒我们：Mode 0 虽然最经典，但 WQ 的两个真实 SPI 应用都用 Mode 1。

### 2.2 帧大小：8-bit vs 16-bit

WQ SDK 支持两种帧大小：

| 枚举 | 硬件事 | 每帧 bit 数 |
|---|---|---|
| `WQ_SPI_DFRAME_SIZE_8` | `SPI_DFRAME_SIZE_8`（值 0x7） | 8 bit |
| `WQ_SPI_DFRAME_SIZE_16` | `SPI_DFRAME_SIZE_16`（值 0xF） | 16 bit |

注意：硬件寄存器中的值是 `n-1`，所以 `0x7` 表示 8 bit，`0xF` 表示 16 bit。

**WQ SDK 事实**：`ext_trans_dev_spi.c:94-98` 在 SPI 频率 ≥ 24 MHz 时切换到 16-bit 帧：
```c
#if EXT_TRANS_SPI_SPEED >= (24 * 1000 * 1000)
    spi_cfg.dframe_size = WQ_SPI_DFRAME_SIZE_16;
#else
    spi_cfg.dframe_size = WQ_SPI_DFRAME_SIZE_8;
#endif
```
这是因为高速传输时，16-bit 帧减少了每字节的帧开销（start/stop 条件），提高了有效带宽。

### 2.3 频率约束：DCORE 时钟 ≥ 4× SPI 频率

**WQ SDK 事实**：`wq_spi.h:57-59` 的注释明确写："DCORE frequency must be four times greater than this value"。`bbb/hw/spi.c:486-494` 的 `spi_clock_check()` 实现了这个检查：

```c
WQ_RET spi_clock_check(uint32_t frequency) {
    uint32_t dclock = clock_get_core_clock_mhz(WQ_CORES_DCORE) * CLOCK_MHZ;
    if (frequency * SPI_AND_DCORE_FREQUENCY_MULTIPLE > dclock) {
        return WQ_RET_NOSUPP;
    }
    return WQ_RET_OK;
}
```

其中 `SPI_AND_DCORE_FREQUENCY_MULTIPLE` = 4。如果 DCORE 跑 96 MHz，则 SPI 最大可配 24 MHz。此外，`bbb/hw/spi.c:103-106` 的 `spi_set_frequence()` 强制时钟分频为偶数——如果计算出的分频是奇数，自动加 1。

**实际案例**：`app_spi_trans.c:310-320` 在初始化前先检查 DCORE 时钟 ≥ 32 MHz，最多等 4 次（`SPI_CLK_CHECK_TIMES = 4`），不够则返回 `WQ_RET_NOSUPP`。这是因为它配置 SPI 为 8 MHz，需要 DCORE ≥ 32 MHz。

---

## 第三层：WQ7036AX SDK 实战

### 3.1 WQ SPI 的软件分层

```text
应用层
  ext_trans_dev_spi.c      芯片间通信传输通道
  app_spi_trans.c          外部 DSP 固件加载
    ↓ wq_spi_* HAL API
wqcore/driver/periph/common/hal/spi/wq_spi.c
    ↓ spi_* 硬件层 API
wqcore/driver/periph/bbb/hw/spi.c + spi_reg.h
    ↓ 寄存器操作
SPI 控制器硬件（Synopsys DW_apb_ssi 兼容）
```

HAL 层管理端口状态（`wq_spi_port_state_t`）、DMA 状态（`wq_spi_dma_state_t`）、中断和低功耗恢复。硬件层直接操作控制寄存器（`ctrlr0`、`baudr`、`ser`、`dr0` 等）。

### 3.2 真实 HAL 接口

以下是 `wqcore/driver/periph/common/hal/spi/wq_spi.h` 中的真实 API，省略版权头和注释：

```c
// 生命周期
WQ_RET wq_spi_init(WQ_SPI_PORT port);
WQ_RET wq_spi_deinit(WQ_SPI_PORT port);
WQ_RET wq_spi_open(WQ_SPI_PORT port, const wq_spi_cfg_t *cfg,
                   const wq_spi_gpio_cfg_t *gpio_cfg);
WQ_RET wq_spi_close(WQ_SPI_PORT port);

// 轮询模式：先发后收（simplex）
WQ_RET wq_spi_poll_transfer(WQ_SPI_PORT port,
    uint8_t *outbuf, size_t outbuf_len,
    uint8_t *inbuf,  size_t inbuf_len);

// 轮询模式：同时收发（duplex）
WQ_RET wq_spi_poll_duplex_transfer(WQ_SPI_PORT port,
    uint8_t *outbuf, size_t outbuf_len,
    uint8_t *inbuf,  size_t inbuf_len);

// DMA 模式：先发后收
WQ_RET wq_spi_dma_transfer(WQ_SPI_PORT port,
    uint8_t *outbuf, size_t outbuf_len,
    uint8_t *inbuf,  size_t inbuf_len,
    wq_spi_dma_callback cb);

// DMA 模式：同时收发
WQ_RET wq_spi_dma_duplex_transfer(WQ_SPI_PORT port,
    uint8_t *outbuf, size_t outbuf_len,
    uint8_t *inbuf,  size_t inbuf_len,
    wq_spi_dma_callback cb);

// 辅助接口
WQ_RET wq_spi_dma_config(WQ_SPI_PORT port);
WQ_RET wq_spi_gpio_config(WQ_SPI_PORT port,
    const wq_spi_gpio_cfg_t *gpio_cfg);
WQ_RET wq_spi_set_rx_sample_delay(WQ_SPI_PORT port,
    uint16_t sample_dly);
```

从这组声明可以读出几个工程约束：

1. **init → open → transfer → close → deinit** 是固定生命周期。`open` 前必须 `init`，`close` 后可以重新 `open` 或 `deinit`。
2. **两种传输模式**：simplex（先发后收，`poll_transfer`/`dma_transfer`）和 duplex（同时收发，`poll_duplex_transfer`/`dma_duplex_transfer`）。它们对应不同的硬件传输模式（`SPI_TMOD_EEPROM` vs `SPI_TMOD_TRANCIEVER`）。
3. **poll vs DMA**：`app_spi_trans.c:165-173` 的策略是：TX ≥ 4 字节且 TX+RX ≥ 8 字节用 DMA，否则用轮询。这反映了小数据量时 DMA 的 setup 开销可能超过传输本身。
4. **DMA 回调**在中断上下文中执行（`IRAM_TEXT`），不能在回调中做耗时操作。
5. `wq_spi_close()` 的注释明确警告：如果关闭时有未完成的 DMA 传输，函数会触发 DMA 停止流程然后立即返回，但 SPI 硬件真正停止可能要等到 DMA 停止完成后。这意味着调用 `close` 后不能立即重新 `open` 同一端口。

### 3.3 配置结构体

```c
typedef struct wq_spi_cfg {
    WQ_SPI_DFRAME_SIZE dframe_size;  // 8 或 16 bit
    WQ_SPI_CLK_MODE clk_mode;        // Mode 0/1/2/3
    uint32_t frequency;              // 目标频率（Hz），受 DCORE/4 限制
    uint32_t dummy_data;             // 仅发数据时用作占位，8-bit 模式用低 8 位
} wq_spi_cfg_t;

typedef struct wq_spi_gpio_cfg {
    WQ_GPIO_ID clk;
    WQ_GPIO_ID cs;       // WQ_GPIO_INVALID 表示硬件自动控制 CS
    WQ_GPIO_ID mosi;
    WQ_GPIO_ID miso;
    bool auto_cs;        // true = 硬件自动 CS，false = 驱动手动控制
} wq_spi_gpio_cfg_t;
```

`dummy_data` 字段的作用：当 SPI 处于"只收不发"模式时（`inbuf_len > 0` 且 `outbuf_len == 0`），硬件需要发送 dummy 数据来产生 SCK 时钟。`dummy_data` 就是此时发送的占位值。`wq_spi.c:659` 中，轮询纯接收模式先发一个 dummy frame 启动传输，然后读数据。

`auto_cs` 的作用：如果设为 `true` 且 CS 引脚不是 `WQ_GPIO_INVALID`，硬件自动在传输开始前拉低 CS、传输结束后拉高 CS。如果设为 `false`，驱动通过 `wq_spi_chip_select()` 和 `wq_spi_chip_dis_select()` 手动控制 CS 引脚电平。手动模式适合需要在一次 CS 低电平期间完成多段操作的场景（如发命令+读数据+再发命令）。WQ 的两个真实应用都使用手动 CS（`auto_cs = false`）。

### 3.4 真实应用一：ext_trans 芯片间通信

`wq-adk/components/ext_trans/src/ext_trans_dev_spi.c` 将 SPI 抽象为统一的外部传输接口（`ext_trans_dev_func_t`）：

```c
static ext_trans_dev_func_t spi_io_func = {
    .init   = ext_trans_dev_spi_init,
    .deinit = ext_trans_dev_spi_deinit,
    .open   = ext_trans_dev_spi_open,
    .close  = ext_trans_dev_spi_close,
    .out    = ext_trans_dev_spi_data_tx,    // 纯发送
    .in     = ext_trans_dev_spi_data_rx,    // 纯接收
    .duplex = ext_trans_dev_spi_data_duplex, // 全双工
};
```

关键实现细节：

- **TX**（`ext_trans_dev_spi_data_tx`）：调用 `wq_spi_dma_transfer(port, buf, length, NULL, 0, tx_done_cb)`——只发不收，`inbuf` 为 NULL，`inbuf_len` 为 0。硬件层使用 `SPI_TMOD_TRANSMITER` 模式。
- **RX**（`ext_trans_dev_spi_data_rx`）：调用 `wq_spi_dma_transfer(port, NULL, 0, buf, length, rx_done_cb)`——只收不发，`outbuf` 为 NULL。硬件使用 `SPI_TMOD_RECIEVER` 模式，并自动发送 dummy 数据来产生 SCK。
- **Duplex**（`ext_trans_dev_spi_data_duplex`）：调用 `wq_spi_dma_duplex_transfer()`——同时收发。硬件使用 `SPI_TMOD_TRANCIEVER` 模式。

GPIO 通过 `wq_resource_lookup_gpio()` 从资源系统动态获取，而不是硬编码。这允许同一套代码在不同硬件配置上使用不同的引脚。

### 3.5 真实应用二：外部 DSP 固件加载

`wq-adk/examples/ext_loopback/acore/app/src/app_spi_trans.c` 展示了一个完整的自定义 SPI 协议实现：

1. **初始化**（`spi_trans_init`）：配置 Mode 1、8 MHz、8-bit 帧、手动 CS，GPIO 为 CS=54、MISO=52、MOSI=51、CLK=53。先检查 DCORE 时钟 ≥ 32 MHz，再 `wq_spi_init` → `wq_spi_open`。

2. **数据包协议**：自定义头部 `spi_protocol_header_t`（16-bit flag `0xF8D6`、8-bit packet_length、16-bit CRC-CCITT、24-bit packet_num），有效载荷 24 字节，总包 32 字节。接收端通过 `spi_packet_find()` 搜索 flag 定位包头。

3. **传输策略**（`app_spi_duplex_transfer`）：TX ≥ 4 字节且 TX+RX ≥ 8 字节时用 DMA，否则用轮询。DMA 传输后忙等 `test_dma_flag` 被回调置 1。这是简单的同步化处理，生产代码中应使用信号量。

4. **字节序处理**：`spi_send_receive_packet` 在收完数据后对每 4 字节调用 `bswap_32()` 翻转字节序。这说明 SPI 传输的字节序与 CPU 的字节序不一致，需要软件处理。

5. **错误处理**：每个包有 1000 次超时重试，整个传输有 10 次整体重试。CRC 校验失败时丢弃当前包并重试。

### 3.6 低功耗恢复

`wq_spi.c:164-202` 实现了低功耗（`CONFIG_LOWPOWER_ENABLE`）下的 suspend/resume：

- **suspend**（`spi_trans_suspend`）：遍历所有 SPI 端口，检查是否有未完成的 DMA 传输。如果有，等待 DMA 完成或超时（按传输长度和频率计算超时时间），然后才允许系统进入低功耗。
- **resume**（`wq_spi_restore`）：重新初始化 SPI 控制器、恢复 GPIO 配置、重新配置 DMA、恢复中断。

这意味着：如果系统在 SPI 传输期间进入低功耗，硬件状态可能丢失。suspend hook 确保传输完成或超时后才挂起。

---

## 第四层：传输模式的硬件实现

### 4.1 四种硬件传输模式

WQ 硬件层（`bbb/hw/spi.h:35-39`）定义了四种传输模式：

| 模式 | 枚举 | 说明 | 对应 HAL API |
|---|---|---|---|
| 全双工 | `SPI_TMOD_TRANCIEVER` | MOSI 和 MISO 同时工作 | `poll_duplex_transfer` / `dma_duplex_transfer` |
| 仅发送 | `SPI_TMOD_TRANSMITER` | 只发不收，MISO 被忽略 | `poll_transfer`(inbuf_len=0) / `dma_transfer`(inbuf_len=0) |
| 仅接收 | `SPI_TMOD_RECIEVER` | 只收不发，MOSI 发 dummy | `poll_transfer`(outbuf_len=0) / `dma_transfer`(outbuf_len=0) |
| EEPROM | `SPI_TMOD_EEPROM` | 先发后收（如先发寄存器地址，再读数据） | `poll_transfer`(outbuf_len>0, inbuf_len>0) / `dma_transfer`(both>0) |

### 4.2 Duplex 传输的 DMA 细节

`wq_spi_dma_duplex_transfer` 的注释（`wq_spi.c:1039-1052`）详细说明了三种情况：

```text
1) outbuf_len < inbuf_len:
   send   : DDDDDDXXXXX   (数据 + dummy 补齐)
   receive: DDDDDDDDDDD

2) outbuf_len == inbuf_len:
   send   : DDDDDDDDDDD   (完全对齐)
   receive: DDDDDDDDDDD

3) outbuf_len > inbuf_len:
   send   : DDDDDDDDDDD
   receive: DDDXXXXXXXX   (数据 + 忽略补齐)
```

实现中，较短的一侧用 `trans->tmpbuf`（内容为 `dummy_data`）补齐，较长的一侧用 DMA 搬运实际数据。两侧都完成后，DMA 回调通知上层。

### 4.3 RX 采样延迟

`wq_spi_set_rx_sample_delay(port, sample_dly)` 允许微调 MISO 的采样点。参数 `sample_dly` 的单位是 SPI 时钟周期的 1/1000，范围 0-1000。默认值为 500，表示在时钟周期的中间位置采样。

`bbb/hw/spi.c:90-95` 的 `spi_set_rx_sampledly()` 将采样延迟转换为硬件寄存器值（0-4），转换公式为 `rx_delay = (sample_dly * clk_div + 500) / 1000`，结果限制在 0-4。

高速传输或长走线时，MISO 数据到达控制器可能有延迟，调整采样点可以避免在数据不稳定时采样。

---

## 第五层：常见故障与诊断

### 5.1 故障排查顺序

```text
SPI 通信失败？
  ├─ CS 有变化吗？
  │   ├─ 没有 → 查 GPIO 配置、auto_cs 设置、wq_spi_open 是否成功
  │   └─ 有 → 看 SCK 有波形吗？
  ├─ SCK 有波形吗？
  │   ├─ 没有 → 查 wq_spi_open 返回、频率配置、DCORE 时钟检查
  │   └─ 有 → 看 SCK 频率和模式对吗？
  ├─ SCK 频率和模式对吗？
  │   ├─ 不对 → 查 clk_mode、frequency 配置、分频计算
  │   └─ 对 → 看 MOSI 数据对吗？
  ├─ MOSI 数据对吗？
  │   ├─ 不对 → 查 dframe_size、dummy_data、字节序
  │   └─ 对 → 看 MISO 有数据吗？
  └─ MISO 有数据吗？
      ├─ 没有 → 查外设供电、复位、CS 时序、外设是否被正确选中
      └─ 有但不对 → 查 CPOL/CPHA、采样延迟、信号完整性、帧格式
```

### 5.2 典型故障表

| 现象 | 第一假设 | 需要的证据 | 不要先做什么 |
|---|---|---|---|
| MISO 全 0x00 或 0xFF | CPOL/CPHA 与外设不匹配 | 逻辑分析仪波形、外设手册 | 不要只改频率 |
| 数据偏移（读到的字节错位） | dummy 字节数不对，或 CS 提前拉高 | 波形上看 CS 持续时间 vs 数据帧数 | 不要只改缓冲区大小 |
| 高频下偶发错误 | 信号完整性、采样延迟 | 降频测试、调整 sample_dly、示波器看边沿 | 不要只加 retry |
| 首次字节错误 | CS 拉低到 SCK 开始的时间不够 | 外设手册的 CS setup time 要求 | 不要把第一个字节当 dummy |
| wq_spi_open 返回 WQ_RET_NOSUPP | SPI 频率 × 4 > DCORE 频率 | DCORE 时钟值、SPI 配置频率 | 不要直接改大频率 |
| wq_spi_poll_transfer 返回 WQ_RET_BUSY | 同一端口有未完成的 DMA 传输 | is_busy 状态、DMA enable 标志 | 不要直接重置全局状态 |
| DMA 传输不触发回调 | RX FIFO 溢出中断未触发或 DMA 描述符异常 | 中断状态寄存器、DMA 描述符 owner 位 | 不要在回调中做耗时操作 |
| 读回数据每 4 字节反转 | 发送端和接收端字节序不一致 | 原始字节 vs 期望值，用已知固定值测试 | 不要只改 bswap 调用 |

### 5.3 信号完整性

SPI 速度快（10-50 MHz），信号完整性（Signal Integrity，信号质量）变得重要：

- **反射**：走线阻抗不连续导致信号边沿出现过冲和振铃。长走线或未端接的 PCB 走线更容易出现。在 SCK/MOSI 上串联一个小电阻（通常 22-100 Ω）可以抑制反射。
- **串扰**：相邻走线之间的电磁耦合。高速 SCK 可能耦合到 MISO 上，导致数据错误。增加线间距、使用地线隔离、减少平行走线长度都可以减轻。
- **地弹**：多个输出同时切换时，芯片内部地电位瞬时波动，影响逻辑电平识别。这是板级设计问题，不是软件能解决的。
- **探头负载**：示波器或逻辑分析仪探头会增加总线电容，可能改变信号边沿。如果接入探头后问题消失，说明探头改变了电路特性；如果问题出现，说明探头负载过大。

### 5.4 DMA 超时诊断

WQ SPI 驱动在 `spi_trans_suspend` 中实现了 DMA 超时检测（`wq_spi.c:230-278`）：

```c
uint32_t delay_ms = (trans->inbuf_len + trans->outbuf_len) * 10
    / (wq_spi_status.port[port].cfg.frequency / 1000) + 1;
```

超时时间 = 总 bit 数 × 10 / 频率，再加 1ms 余量。如果传输在这个时间内没有完成，打印错误日志并放弃等待。出现这种超时，可能原因：

1. SPI 外设没有响应（未上电、复位、CS 未选中）；
2. SCK 频率配置错误，实际远低于预期；
3. DMA 描述符配置错误，传输停在了中间状态；
4. 中断被屏蔽，RX FIFO 溢出中断没有触发。

---

## 第六层：SPI 与 I2C/UART 的对比

| | SPI | I2C | UART |
|---|---|---|---|
| 线数 | 4（SCK/MOSI/MISO/CS） | 2（SDA/SCL） | 2（TX/RX） |
| 最高速度 | 10-50 MHz | 100k-400k-1M-3.4M | 通常 ≤ 4 Mbps |
| 全双工 | 是 | 否（半双工） | 是 |
| 多设备 | 是（独立 CS，每设备一根线） | 是（地址寻址，共享两根线） | 否（点对点） |
| 电气结构 | 推挽 | 开漏 | 推挽 |
| 应答机制 | 无 | ACK/NACK | 无（需上层协议） |
| 设备枚举 | 无标准方法 | 无标准方法（可扫描地址） | 无 |
| 传输距离 | 短（PCB 级，通常 < 20 cm） | 中等（可达数米） | 长（RS-232 15m，RS-485 1200m） |
| 典型用途 | Flash、显示屏、WiFi、高速传感器 | 传感器、PMIC、EEPROM、GPIO 扩展 | 调试、命令、GPS、蓝牙模块 |

---

## 第七层：练习与验收

### 练习一：从波形判断 SPI 模式

获取一份逻辑分析仪抓取的 SPI 波形（或使用 WQ 开发板自发自收），标出：

- SCK 空闲电平；
- 数据采样的边沿位置；
- 判断 CPOL 和 CPHA，写出 Mode 值；
- 标出 CS 拉低到第一个 SCK 边沿的时间间隔；
- 标出最后一个 SCK 边沿到 CS 拉高的时间间隔。

**通过标准**：能解释为什么选择这个 Mode，以及如果 Mode 错了，收到数据会有什么表现。

### 练习二：读 WQ HAL 的 SPI API 契约

打开 `wqcore/driver/periph/common/hal/spi/wq_spi.h`，回答：

1. `wq_spi_init` 和 `wq_spi_open` 的先后顺序是什么？为什么分行？
2. `poll_transfer` 和 `poll_duplex_transfer` 的区别是什么？对应哪些硬件传输模式？
3. `dummy_data` 字段在什么场景下使用？`dframe_size` 为 16 时它用多少位？
4. `auto_cs` 为 true 和 false 时，CS 的控制行为有什么不同？

**通过标准**：能把头文件声明对应到 `wq_spi.c` 中的状态机、传输模式选择和硬件层调用。

### 练习三：追踪 ext_trans SPI 数据流

从 `wq-adk/components/ext_trans/src/ext_trans_dev_spi.c` 开始，画出：

```text
ext_trans_dev_spi_data_tx(buf, length, cb)
  → wq_spi_dma_transfer(port, buf, length, NULL, 0, tx_done_cb)
  → DMA 控制器 → SPI FIFO → MOSI 引脚
  → DMA 完成中断 → ISR → tx_done_cb
  → ext_trans 上层回调
```

**通过标准**：能说出 TX、RX、Duplex 三种路径分别对应哪些硬件传输模式，以及 DMA 回调在哪个上下文中执行。

### 练习四：分析 SPI 模式不匹配的后果

给定：外设要求 Mode 0（CPOL=0, CPHA=0），但 WQ 配置为 Mode 1（CPOL=0, CPHA=1）。写出：

1. 控制器发出的数据在外设看来会是什么样子？
2. 外设回的数据在控制器看来会是什么样子？
3. 逻辑分析仪上会看到什么异常？
4. 如果外设支持两种模式，如何验证当前配置是否正确？

**通过标准**：能用时序图说明数据采样点偏移半拍带来的后果。

### 练习五：设计故障定位实验

现象：SPI 通信在 8 MHz 时正常，提高到 16 MHz 后偶发数据错误。要求写出至少三个可证伪假设：

- 16 MHz 时 DCORE 频率不满足 4× 约束，实际 SCK 不是 16 MHz；
- 信号完整性问题（反射、串扰），16 MHz 时边沿质量变差；
- MISO 采样延迟不匹配，16 MHz 的采样窗口更窄。

每个假设都要写出要抓的波形、寄存器值或代码证据。

## 自测题

1. **为什么 SPI 用推挽而不是开漏？**
   - 推挽主动驱动高低电平，边沿陡峭，适合高速传输。开漏的高电平靠电阻充电，RC 时间常数限制速度。SPI 不需要多设备共享数据线（MISO 通过 CS 做三态隔离），所以不需要开漏的"线与"特性。

2. **CPOL=0, CPHA=0 和 CPOL=0, CPHA=1 的区别是什么？**
   - CPHA=0 在 SCK 的第一个边沿（上升沿）采样数据，CPHA=1 在第二个边沿（下降沿）采样。数据在非采样边沿改变。Mode 1 相比 Mode 0，采样点延迟了半个 SCK 周期。

3. **`wq_spi_poll_transfer` 和 `wq_spi_poll_duplex_transfer` 什么时候用哪个？**
   - 如果外设协议是"先发命令/地址，再收数据"（如 EEPROM 读），用 `poll_transfer`（simplex 模式）。如果外设协议是"发一个字节的同时收回一个字节"（如全双工数据交换），用 `poll_duplex_transfer`。simplex 对应硬件 `TMOD_EEPROM`，duplex 对应 `TMOD_TRANCIEVER`。

4. **WQ SPI 的 DCORE 频率约束是什么？违反会怎样？**
   - DCORE 频率必须 ≥ 4× SPI 频率。`wq_spi_open` 时 `spi_clock_check()` 会检查，不满足则返回 `WQ_RET_NOSUPP`。强制绕过可能导致 SCK 实际频率不是配置值、时序不满足外设要求。

5. **`auto_cs = false` 时，CS 引脚由谁控制？**
   - 由驱动代码通过 `wq_spi_chip_select()`（拉低）和 `wq_spi_chip_dis_select()`（拉高）手动控制。底层调用 `wq_gpio_write(cs, 0/1)` 直接操作 GPIO。这允许在 CS 拉低期间完成多段 SPI 操作。

6. **WQ DMA 传输的回调在什么上下文中执行？有什么限制？**
   - 在中断上下文中执行（`IRAM_TEXT`）。不能在回调中做耗时操作、不能调用会阻塞的 API。`ext_trans_dev_spi` 的回调只是保存 buffer 指针然后调用上层回调，不做实际数据处理。

7. **reGlasses V861 当前有 SPI 外设的使用吗？**
   - 根据当前可编辑 BSP 源码（`/home/ys/aiglass/reglasses/`），未发现 SPI 外设的实际使用。`board.dts` 中没有配置 SPI 设备节点。如果后续项目需要 SPI，应作为新增功能从设备树、pinmux 和驱动开始实现。此条为"当前 SDK 证据缺口"。

## 常见反例

- 把 SCK 写成 SCL。SCL 是 I2C 的时钟线；SPI 的时钟线是 SCK。
- 把 SPI 的 CS 当成 I2C 的设备地址。SPI 没有地址概念，只有硬件片选。
- 用 `spi_transfer()` 这种不存在的 API。WQ 的真实 API 是 `wq_spi_poll_transfer` 和 `wq_spi_dma_transfer`。
- 认为 Mode 0 是所有设备的默认模式。WQ 的两个真实应用都用 Mode 1。
- 在 DMA 回调中调用 `wq_spi_close`。`wq_spi_close` 会触发 DMA 停止，而 DMA 停止的回调中不能再嵌套 close。
- 用 `wq_spi_close` 后立即 `wq_spi_open`。`close` 可能因未完成的 DMA 停止而异步完成，端口可能仍处于 busy 状态。
- 认为 SPI 不需要上拉/下拉。SCK 和 CS 在空闲时需要明确电平：WQ 驱动为 CS 和 CLK 配置了上下拉，以防悬空时误触发。
- 在 reGlasses 项目中假设有可用的 SPI 驱动。当前 BSP 无 SPI 实例，需从设备树和驱动开始实现。

## 参考资料

- WQ7036AX SPI HAL：`wqcore/driver/periph/common/hal/spi/wq_spi.h`、`wq_spi.c`
- WQ7036AX SPI 硬件层：`wqcore/driver/periph/bbb/hw/spi.h`、`spi.c`
- WQ SPI 寄存器定义：`wqcore/chipset/bbb/regs/spi_reg.h`
- WQ ext_trans SPI：`wq-adk/components/ext_trans/src/ext_trans_dev_spi.c`
- WQ SPI 外部 DSP 加载：`wq-adk/examples/ext_loopback/acore/app/src/app_spi_trans.c`
- [[i2c-basics-I2C基础]] — 对比：开漏两线总线
- [[uart-basics-UART基础]] — 对比：异步串口
- [[uart-i2c-spi-compare-串口总线对比]] — 四种总线全面对比
- [[gpio-config-GPIO配置]] — GPIO 复用、推挽/开漏和上下拉
- [[dma-basics-DMA基础]] — DMA 传输与回调机制

#flashcard

问：SPI 的四种模式由哪两个参数决定？
答：CPOL（时钟极性，空闲电平高低）和 CPHA（时钟相位，在第一个还是第二个边沿采样）。Mode 0=CPOL0/CPHA0，Mode 1=CPOL0/CPHA1，Mode 2=CPOL1/CPHA0，Mode 3=CPOL1/CPHA1。

问：为什么 SPI 读数据也必须发数据？
答：SCK 由控制器产生，外设只在 SCK 边沿上输出 MISO 数据。控制器不发数据就不产生 SCK，外设就无法回数据。纯接收时，控制器发送 dummy 字节来产生时钟。

问：WQ 的 `wq_spi_poll_transfer` 和 `wq_spi_poll_duplex_transfer` 的区别是什么？
答：前者是 simplex（先发后收，对应硬件 TMOD_EEPROM 或 TMOD_TRANSMITER/RECIEVER），后者是 duplex（同时收发，对应硬件 TMOD_TRANCIEVER）。simplex 适合"先发命令再读数据"的器件，duplex 适合"收发同时进行"的场景。

问：WQ SPI 的 DCORE 频率约束是什么？
答：DCORE 频率必须 ≥ 4× SPI 频率。`wq_spi_open` 时由 `spi_clock_check()` 检查，不满足返回 `WQ_RET_NOSUPP`。分频器只能产生偶数分频比。

问：SPI 设备的 MISO 为什么可以共享控制器的同一根引脚？
答：每个外设的 MISO 是三态输出，只有在自己的 CS 被拉低时才驱动 MISO，CS 拉高后释放为高阻态。只要同一时刻只有一个 CS 被选中，多个外设的 MISO 就不会冲突。