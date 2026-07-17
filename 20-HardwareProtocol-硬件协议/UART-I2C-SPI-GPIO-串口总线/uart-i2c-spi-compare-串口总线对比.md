---
type: concept
created: 2026-07-17
tags: [comparison, uart, i2c, spi, 对比, 总线, 选型]
aliases: [串口对比, 总线对比, 串行总线选型]
---

# 串口总线对比：UART vs I2C vs SPI

> **一句话结论**：三种总线不是"谁更快就用谁"。选型取决于三个约束的交集——电气结构（推挽/开漏决定了一对多能力和速度上限）、时钟模型（异步/同步决定了误差容忍度）、以及工程成本（线数、GPIO 开销、驱动复杂度、板级布线）。reGlasses 选择了 UART（WQ↔V861 跨芯片链路）和 I2C（传感器、GPIO 扩展器），没有用 SPI——每个选择都有可追溯的工程理由。

本篇是 [[uart-basics-UART基础]]、[[i2c-basics-I2C基础]]、[[spi-basics-SPI基础]] 的横向对比。具体协议细节参见各篇，这里只讲对比和选型。

## 学完以后应该能做什么

1. 给定一个外设（传感器、Flash、显示屏、芯片间通信），根据其数据手册中的电气特性、速率要求和引脚数，选择合适的总线。
2. 解释为什么不能用 I2C 替代 SPI 连接 Flash，也不能用 SPI 替代 I2C 连接 8 个传感器。
3. 说出 UART、I2C、SPI 各自在 WQ7036AX 和 reGlasses 中的真实使用位置和对应的 SDK 驱动路径。
4. 在选型时，能列出至少 5 个需要同时考虑的约束（不仅是速度）。

## 术语先讲清楚

| 术语 | 英文 | 在总线对比中具体指什么 |
|---|---|---|
| 推挽输出 | push-pull | 用两个晶体管主动驱动高低电平。SPI 四根线和 UART TX/RX 用推挽。优点：边沿陡峭，速度快。缺点：多个输出不能直接并联 |
| 开漏输出 | open-drain | 只主动拉低，高电平靠上拉电阻恢复。I2C 的 SDA/SCL 用开漏。优点：多设备可安全共享（线与）。缺点：上升时间受 RC 限制，速度受限 |
| 线与 | wired-AND | 开漏输出的自然特性：任意一个设备拉低，总线就是低电平；所有设备都释放，总线才是高电平。这是 I2C 多设备共享和时钟拉伸的物理基础 |
| 异步 | asynchronous | 没有独立时钟线，收发双方用各自的本地时钟按约定频率采样。UART 是异步的，依赖起始位下降沿校准和双方时钟的匹配度 |
| 同步 | synchronous | 有一根独立的时钟线（SCK/SCL），由控制器/主设备提供。SPI 和 I2C 都是同步的，外设只在时钟边沿上动作 |
| 片选 | CS（Chip Select） | 控制器拉低某个外设的 CS 来选中它。SPI 用片选做硬件寻址，每个外设需要一根独立的 CS 线 |
| 地址寻址 | address-based | 在数据线上发送地址字节来选中目标设备。I2C 用 7-bit 或 10-bit 地址，所有设备共享 SDA/SCL 两根线 |
| 全双工 | full-duplex | 收发可以同时进行。SPI 和 UART 是全双工（SPI 同时收发、UART 有独立 TX 和 RX 线） |
| 半双工 | half-duplex | 收发不能同时进行，同一时刻只能单向。I2C 是半双工（SDA 只有一根线，方向需要切换） |

---

## 第一层：从物理结构理解为什么它们不同

三种总线的一切差异，根源在于两个物理选择：

**选择一：谁驱动时钟？**

- UART：没有时钟线。双方各用自己的时钟，靠起始位校准。代价是速度受限于时钟匹配精度，不能太快（通常 ≤ 4 Mbps）。好处是只要两根线，抗干扰能力强，可以传很远（RS-232 15m，RS-485 1200m）。
- I2C：控制器驱动 SCL。外设可以通过时钟拉伸（把 SCL 拉低）让控制器等待。代价是 SCL 速度受限于开漏的 RC 上升时间（通常 ≤ 400 kHz 或 1 MHz）。好处是多设备共享两根线，每个设备有唯一地址。
- SPI：控制器驱动 SCK。外设不能控制时钟速度，只能跟上或跟不上。代价是每个外设需要一根 CS 线。好处是 SCK 可以到几十 MHz，因为推挽驱动边沿陡峭。

**选择二：输出级是推挽还是开漏？**

- UART：推挽。TX 和 RX 是点对点的，不存在多设备共享的冲突问题，所以用推挽。
- I2C：开漏。多设备共享 SDA 和 SCL，必须用开漏的线与特性来避免短路。
- SPI：推挽。每个外设的 MISO 通过 CS 做三态隔离，同一时刻只有一个外设驱动 MISO，所以 MOSI/SCK/CS 都可以用推挽。

这两个选择直接决定了速度上限、设备数量和 GPIO 开销：

| 总线 | 输出结构 | 时钟模型 | 速度上限 | 多设备方式 | 每增一个外设的 GPIO 成本 |
|---|---|---|---|---|---|
| UART | 推挽 | 异步（无时钟） | ~4 Mbps | 不支持（点对点） | +2 根 GPIO（需额外 UART 端口） |
| I2C | 开漏 | 同步（控制器驱动 SCL） | ~400k/1M/3.4M | 地址寻址 | 0（共享 SDA/SCL） |
| SPI | 推挽（MISO 三态） | 同步（控制器驱动 SCK） | ~10-50 MHz | 片选（CS） | +1 根 GPIO（CS） |

---

## 第二层：真实 SDK 中的选型证据

### 2.1 reGlasses 为什么 UART 连接 WQ7036AX 而不是 SPI

reGlasses 的 V861 和 WQ7036AX 之间通过 UART2（PD18=TX, PD19=RX）通信，跑 STTP 协议。如果换 SPI，需要 4 根线（SCK/MOSI/MISO/CS），在眼镜的紧凑 FPC 上多 2 根线是物理负担。而且 UART 的 ~1 Mbps（STTP 的实际速率）足够传输控制指令和压缩音频，不需要 SPI 的几十 MHz。

**SDK 证据**：WQ 侧 `wq-adk/components/ext_trans/src/ext_trans_dev_uart.c` 使用 DMA 驱动的 UART（`wq_uart_write` + `wq_uart_read_dma`），V861 侧在 `board.dts` 中配置 `uart2` 引脚为 PD18/PD19。

### 2.2 reGlasses 为什么 I2C 连接 TCA9539 GPIO 扩展器而不是 SPI

TCA9539 是一个 I2C GPIO 扩展器（地址 0x74），为 V861 提供额外的 16 个 GPIO（用于摄像头 reset/pwdn 和 LED）。选 I2C 的原因：

1. **GPIO 扩展器本身就是 I2C 接口的**——这不是选择，是器件决定的。
2. 如果存在 SPI 版本的 GPIO 扩展器，在 reGlasses 场景下 I2C 仍然更优——因为 TWI1 总线上已经挂了其他设备，新增一个 I2C 设备不需要额外 GPIO（只需共享 SDA/SCL），而 SPI 需要额外一根 CS 线。
3. I2C 的 400 kHz 对于 GPIO 控制（不需要高速切换）完全够用。

**SDK 证据**：`board.dts` 中 `tca9539@74` 设备节点挂在 `&twi1` 上，`clock-frequency = <400000>`。WQ 侧的 I2C 驱动在 `wq_i2c.h/.c` 中。

### 2.3 WQ7036AX 为什么 SPI 加载外部 DSP 固件

WQ 的 `app_spi_trans.c` 使用 SPI 从外部 Flash 加载 DSP 固件。选 SPI 的原因：

1. **速度**：DSP 固件可能有几十 KB，UART 115200 需要几秒，SPI 8 MHz 只需要几十毫秒。
2. **全双工**：SPI 发命令的同时可以收回确认，不需要像 UART 那样等发完再收。
3. **外设是 SPI Flash**——器件决定的。

**SDK 证据**：`wq-adk/examples/ext_loopback/acore/app/src/app_spi_trans.c`，配置 Mode 1、8 MHz、8-bit 帧，自定义协议头（0xF8D6 flag + CRC-CCITT + 包序号）。

### 2.4 WQ7036AX 为什么 I2C 连接光传感器

WQ glass 应用通过 I2C 连接光传感器（ALS/PS）。选 I2C 的原因：

1. 光传感器是低速设备（几十 Hz 采样率就够），I2C 100 kHz 完全够用。
2. 光传感器芯片本身是 I2C 接口的。
3. 传感器可能和其他 I2C 设备共享总线。

**SDK 证据**：`wq-adk/examples/glass/acore/app/src/app_light_sensor.c` 通过 `light_sensor_init` → I2C HAL 访问传感器。应用层不直接操作 I2C 总线，而是通过传感器抽象层接收事件回调。

---

## 第三层：选型决策框架

决策顺序（从最重要的约束开始）：

**1. 外设本身支持什么接口？**
这是硬约束。如果外设只有 I2C 接口，就没有选型空间。数据手册上会明确写"Interface: I2C"或"SPI-compatible"。

**2. 需要连接多少个设备？**
- 1 个设备：UART/SPI/I2C 都可以。
- 2-3 个设备：SPI（3 根 CS 线）或 I2C（共享总线，0 额外 GPIO）。
- 4+ 个设备：I2C 在 GPIO 成本上优势明显（始终只需 2 根线）。SPI 每增加一个外设就多一根 CS 线，8 个设备需要 8+4=12 根线。

**3. 需要多快的速度？**
- < 1 Mbps：UART 或 I2C 都可以。
- 1-10 Mbps：SPI（UART 理论上可以但不可靠，I2C 到不了这个速度）。
- > 10 Mbps：只有 SPI 能胜任。

**4. 传输距离？**
- PCB 板级（< 20 cm）：三者都可以。
- 板间/跨系统（> 20 cm）：UART（可加 RS-232/RS-485 收发器延长到数米乃至 1200m）。I2C 和 SPI 不适合长距离。
- 长距离：只有 UART（通过 RS-485 等差分收发器）。

**5. 需要全双工吗？**
- 需要同时收发：UART 或 SPI。I2C 是半双工。
- 半双工足够（如传感器轮询）：I2C 也可以。

**6. 有 GPIO 预算吗？**
- GPIO 紧张：I2C（2 根线，不限设备数）。
- GPIO 充裕：SPI 或 UART（每增加一个设备需要额外 GPIO）。

**7. 需要协议层应答吗？**
- 需要确认对方收到数据：I2C（有 ACK/NACK）或 UART/I2C+上层协议（STTP、CRC）。
- 不需要：SPI（控制器只管发，不知道外设是否收到）。

---

## 第四层：协议层的本质差异

### 4.1 数据帧结构对比

```text
UART 8N1 帧（10 bit）:
  [Start=0] [D0] [D1] [D2] [D3] [D4] [D5] [D6] [D7] [Stop=1]
  帧开销：2 bit / 10 bit = 20%

I2C 写寄存器帧（以 1 字节地址+1 字节数据为例）:
  [Start] [Addr7+W=0] [ACK] [RegAddr] [ACK] [Data] [ACK] [Stop]
  帧开销：Start+Stop+3×ACK+Addr = ~18 bit / 45 bit ≈ 40%

SPI 读寄存器帧（以 1 字节命令+3 字节数据为例）:
  [CS↓] [Cmd=0x9F] [Dummy] [Dummy] [Dummy] [CS↑]
  帧开销：CS 切换 + 1 byte dummy / 4 bytes = 25%
  但注意：控制器发 0x9F 的同时收到了 1 字节（可能是无效数据），
          所以"有效吞吐"要减去第一个字节的偏移。
```

### 4.2 错误检测能力对比

| 总线 | 内建错误检测 | 需要上层协议补充 |
|---|---|---|
| UART | 帧错误（停止位检查）、奇偶校验（可选） | CRC、包序号、超时重传 |
| I2C | ACK/NACK（每字节确认）、总线仲裁 | 设备超时、寄存器值校验 |
| SPI | 无 | 全部依赖上层——CRC、checksum、读回验证 |

**SDK 事实**：WQ 的 `app_spi_trans.c` 在 SPI 传输上自定义了完整的协议层——CRC-CCITT 校验、包序号、超时重试（1000 次/包，10 次整体）。这证明了 SPI 协议层没有内建保护，必须由上层补齐。

---

## 第五层：练习与验收

### 练习一：为新外设选总线

给定：一个温度传感器，I2C 和 SPI 双接口版本都可用。数据手册显示：
- I2C 版本：最大 400 kHz，地址 0x48，每次读数 2 字节
- SPI 版本：最大 10 MHz，Mode 0，每次读数需要发 1 字节命令 + 收 2 字节数据

场景 A：系统已有 3 个 I2C 传感器挂在同一总线，GPIO 剩余 2 根。
场景 B：系统需要每秒读 10000 次温度值，GPIO 充裕。

分别选哪个版本？为什么？

### 练习二：追踪 WQ 的 ext_trans 总线选择

打开 `wq-adk/components/ext_trans/src/` 目录，回答：
1. ext_trans 支持哪几种总线？每种对应哪个源文件？
2. 为什么 `ext_trans_dev_uart` 的 `duplex` 函数指针是 NULL，而 `ext_trans_dev_spi` 的 `duplex` 不为 NULL？
3. 如果要从 UART 切换到 SPI，需要改哪些配置？

### 练习三：分析 I2C 和 SPI 的 GPIO 成本

计算：连接 1 个、2 个、4 个、8 个外设时，I2C 和 SPI 分别需要多少根 GPIO（含数据线、时钟线、片选线）。

**通过标准**：能解释为什么"外设数量"是 SPU/I2C 选型中最重要的约束之一，而不仅仅是"速度"。

## 自测题

1. **UART 和 I2C 的最大区别是什么？**
   - UART 是异步的（无时钟线，靠约定波特率），I2C 是同步的（有 SCL 时钟线）。UART 点对点，I2C 支持地址寻址一主多从。UART 推挽，I2C 开漏。这三个区别是因果关系——因为多从需要地址寻址，因为多设备共享需要开漏，因为开漏限制了速度。

2. **为什么 I2C 不能替代 SPI 连接 Flash？**
   - Flash 需要高速读取（SPI 10-50 MHz vs I2C ≤ 400 kHz），速度差 100 倍+。I2C 的半双工和每字节 ACK 开销使有效吞吐更低。Flash 芯片通常只提供 SPI 接口。

3. **为什么 SPI 不能替代 I2C 连接 8 个传感器？**
   - SPI 每个传感器需要一根 CS 线，8 个传感器 = 8 根 CS + 4 根总线 = 12 根 GPIO。I2C 只需 2 根线。在 GPIO 紧张的 SoC 上，这是不可接受的。

4. **reGlasses 为什么 UART 连 WQ 而不是 I2C？**
   - I2C 是半双工，不能同时收发，且速度上限（400 kHz）限制了双向通信吞吐量。WQ-V861 之间需要双向传输控制指令和音频数据，UART 的全双工更适合。此外，UART 的异步特性意味着不需要处理 I2C 的时钟拉伸和总线仲裁。

5. **WQ ext_trans 为什么同时支持 UART 和 SPI？**
   - 不同场景需要不同总线。UART 适合长距离、简单布线的芯片间通信。SPI 适合高速、大量数据传输。ext_trans 作为抽象层，通过统一的 `ext_trans_dev_func_t` 接口隐藏了底层总线差异。

## 参考资料

- [[uart-basics-UART基础]] — UART 异步采样、FIFO、DMA、流控
- [[i2c-basics-I2C基础]] — I2C 开漏电气、地址、ACK/NACK、总线恢复
- [[spi-basics-SPI基础]] — SPI 推挽、CPOL/CPHA、全双工、DMA 链式传输
- [[gpio-config-GPIO配置]] — GPIO 复用、推挽/开漏、上下拉
- [[dataflow-cmd-to-v881-手机指令到V881]] — UART 在 reGlasses 中的跨芯片角色

#flashcard

问：UART、I2C、SPI 的电气结构分别是什么？为什么？
答：UART 推挽（点对点，无多设备冲突）；I2C 开漏（多设备共享 SDA/SCL，需要线与）；SPI 推挽+MISO 三态（每个外设通过 CS 隔离，同一时刻只有一个驱动 MISO）。

问：连接 8 个外设，I2C 和 SPI 分别需要多少根 GPIO？
答：I2C 需要 2 根（SDA+SCL）；SPI 需要 4+8=12 根（SCK/MOSI/MISO + 8×CS）。

问：reGlasses 中哪些地方用了 UART？哪些地方用了 I2C？
答：UART：V861 UART2（PD18/PD19）连接 WQ7036AX，跑 STTP 协议。I2C：TWI1 连接 TCA9539 GPIO 扩展器（0x74），TWI0 连接 ELM2713 光传感器和充电 IC。