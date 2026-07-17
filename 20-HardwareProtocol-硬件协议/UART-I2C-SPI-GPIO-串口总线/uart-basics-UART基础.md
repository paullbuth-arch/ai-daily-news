---
type: concept
created: 2026-07-17
tags: [protocol, uart, serial, async, 串口, 异步]
aliases: [UART, 串口, Universal Asynchronous Receiver-Transmitter]
---

# UART 基础：从异步采样到 DMA 链表发送

> **一句话结论**：UART（Universal Asynchronous Receiver-Transmitter，通用异步收发器）不是"约定好波特率就能通信"这么简单，它是一套由异步采样时钟恢复、起始/停止位帧定界、FIFO（先进先出缓冲）和中断阈值、DMA 传输、流控（RTS/CTS）以及共享 I/O 半双工共同组成的异步串行协议。真正会用 UART，意味着你能从波特率误差、帧格式、中断状态机和 DMA 回调一直追到芯片间可靠通信的每一字节。

## 30 秒先看懂

UART 解决的是"两个设备在没有时钟线的情况下通信"的问题，就像两个人用对讲机通话，约定好语速（波特率），一方开始说话前先按一下通话键（起始位）让对方准备好。因为没有时钟线，双方必须靠各自的时钟按约定速度采样，所以速度不能太快。初学者先记住：UART 只需要两根线，点对点通信，不需要时钟，但双方波特率必须一致。

本篇的代码锚点来自两个真实工程：

- **WQ7036AX**：`/home/ys/wq7036a/wq-audio/wqcore/driver/periph/common/hal/uart/wq_uart.h`、`wq_uart.c`，`wqcore/driver/periph/bbb/hw/uart.h/.c`，以及 `wq-adk/components/ext_trans/src/ext_trans_dev_uart.c`。
- **V861/reGlasses**：`/home/ys/aiglass/reglasses/device/configs/reglasses/linux-6.6-xuantie/board.dts` 中配置了 UART0（console）、UART2（BT/MCU STTP 连接 WQ7036AX，PD18=TX, PD19=RX）。

文中"通用原理"是 UART 协议本身；"SDK 事实"只针对上述源码和配置；"待确认"标记表示尚未由当前源码或板级资料证实。

## 学完以后应该能做什么

1. 解释异步通信为什么不需要时钟线，以及为什么这既是优点（线少）也是限制（速度上限、波特率误差敏感）。
2. 从波形中识别起始位、数据位（LSB 先发）、校验位和停止位的位置。
3. 计算给定波特率下的 bit 时间，判断特定波特率误差是否会导致帧错误。
4. 看懂 WQ HAL 的 `wq_uart_write`（链表队列+DMA/中断）、`wq_uart_register_rx_callback`（中断驱动接收）和 `wq_uart_read_dma`（DMA 接收）的调用路径和缓冲区生命周期。
5. 区分 FIFO 满中断、接收超时中断、帧错误中断、溢出中断和断线检测中断的触发条件和处理方式。
6. 理解 RTS/CTS 硬件流控如何防止接收方 FIFO 溢出，以及共享 I/O 半双工模式的适用场景。
7. 追踪 V861 UART2 → WQ7036AX UART 的跨芯片通信链路，理解 ext_trans UART 如何封装为统一传输接口。

## 前置知识

- 会读十六进制、位运算和 C 函数声明；可先看 [[c-core-C语言核心]]。
- 知道 GPIO 的输入、输出、推挽和复用；可先看 [[gpio-config-GPIO配置]]。
- 理解中断服务程序（ISR）的基本约束；可先看 [[interrupt-concurrency-中断并发同步]]。
- 如果要理解 DMA 传输，需要 [[dma-basics-DMA基础]]。
- 如果要理解 WQ-V861 跨芯片通信，需要 [[dataflow-cmd-to-v881-手机指令到V881]]。

## 术语先讲清楚

| 术语 | 英文 | 在 UART 中具体指什么 |
|---|---|---|
| 异步 | asynchronous | 没有独立的时钟线，收发双方各自用本地时钟按约定频率采样数据。接收方通过起始位的下降沿确定"何时开始采样"，之后依赖双方时钟的匹配度维持同步 |
| 波特率 | baud rate | 每秒传输的符号数。UART 中每个符号 = 1 bit，所以波特率数值上等于 bit/s。WQ 硬件使用分数分频器（`div_frag` 字段）产生波特率时钟，不是简单的整数除法 |
| 16× 过采样 | 16× oversampling | 接收方内部用 16 倍波特率的时钟去采样每一个 bit。每个 bit 的 16 个采样点中，取第 7/8/9 三个点的多数值作为最终 bit 值——这比只采一个点更抗噪声 |
| 起始位 | start bit | 数据线从空闲高电平拉低，持续 1 个 bit 时间。接收方检测到这个下降沿后，启动内部采样状态机，等 0.5 bit 时间（8 个过采样周期）后采样第一个数据位 D0 |
| 停止位 | stop bit | 数据线恢复高电平，持续 1/1.5/2 个 bit 时间。如果接收方在停止位采样点读到低电平，产生帧错误（frame error）。WQ `wq_uart_configuration_t.stop_bits` 支持 1/1.5/2 |
| LSB 先发 | LSB first | 数据字节的最低位（D0，bit 0）先发送，最高位（D7，bit 7）最后发送。例如发送 0x41（'A'，二进制 01000001），线上顺序是 1,0,0,0,0,0,1,0 |
| 校验位 | parity bit | 可选的额外 bit，用于检测单 bit 错误。奇校验（odd）：数据位+校验位中 1 的总数为奇数；偶校验（even）：总数为偶数。WQ 支持 NONE/EVEN/ODD 三种 |
| FIFO | First In First Out | 硬件缓冲队列。WQ UART 有 TX FIFO 和 RX FIFO，CPU 可以一次写入多个字节到 TX FIFO，硬件逐个移出；RX FIFO 收满阈值后触发中断通知 CPU 批量读取 |
| 流控 | flow control | RTS（Request To Send）和 CTS（Clear To Send）两根额外信号线。接收方 FIFO 快满时拉高 RTS，发送方检测到 CTS 为高时暂停发送。WQ 支持仅 RTS、仅 CTS、或 CTS+RTS 三种模式 |
| 帧错误 | frame error | 接收方在预期的停止位位置没有读到高电平。WQ ISR 中 `FRM_ERR` 中断触发时，驱动复位 RX FIFO（`wq_uart_rx_break_handler`）。帧错误通常是波特率不匹配的第一个信号 |
| 断线检测 | break detection | 数据线持续低电平超过一个完整帧的时间（起始+数据+校验+停止）。可能是对方故意发 Break，也可能是线路物理断开。WQ ISR 中 `BRK_DET` 中断触发时同样复位 RX FIFO |
| 共享 I/O | share IO | TX 和 RX 使用同一根 GPIO 引脚，方向可切换，实现半双工单线通信。WQ 在 `wq_uart_gpio_config()` 中检测到 `tx == rx` 时自动启用共享 I/O 模式 |
| 8N1 | 8 data bits, No parity, 1 stop bit | 最常见的 UART 帧格式，每帧 10 bit。WQ ext_trans 和 reGlasses V861 console 均使用此配置 |

---

## 第一层：用费曼技巧建立心智模型

### 1.1 UART 像两个人用对讲机——类比及其边界

把 UART 想成两个人用对讲机通话，但需要把物理约束带入这个类比：

- 两个人不在同一个房间，看不到对方，也没有第三方给节拍。他们约定好语速：每分钟说 100 个字（波特率 115200 = 每秒 115200 个 bit）。
- A 按下通话键（TX 从空闲高电平拉到低电平，这就是起始位）。B 听到的不是"咔"的一声——B 听到的是**静默的开始**（从持续有背景音变成了突然安静），B 以此为基准开始计时。
- 起始位不仅告诉 B"我要开始说话了"，还给了 B 一个**精确的计时零点**。B 从这个下降沿开始，用自己的秒表（16× 过采样时钟）按约定的语速去记录 A 说的每个字。
- A 说完 8 个数据位后，必须把线拉高至少 1 个 bit 时间（停止位）——这会做两件事：一是告诉 B"我说完了"，二是**让线回到空闲状态**，为下一个起始位（下降沿）做准备。
- 如果 A 说完停止位后没有下一个起始位，线就保持高电平（空闲），B 知道"对方没在说话"。

这个类比的关键边界：

**边界一：对讲机 vs 全双工。** 类比中对讲机是半双工（一次只有一个人说）。但 UART 的 TX 和 RX 是两根独立的线，A 的 TX 接 B 的 RX，A 的 RX 接 B 的 TX——A 可以同时在 TX 上说、在 RX 上听，彼此不干扰。只有在共享 I/O 单线模式下，UART 才退化为半双工。

**边界二：B 的秒表必须和 A 的语速高度匹配。** 如果 A 说 100 字/分，B 按 102 字/分记录，B 会在每个字上越记越偏——第 1 个字可能还准，第 5 个字就偏了半个字的距离，第 10 个字（停止位）B 可能完全听错。这就是波特率误差的累积效应。具体误差分析见 1.4 节。

**边界三：UART 本身不提供错误检测。** 没有 ACK/NACK，没有 CRC，没有重传。如果 B 听错了，A 不知道。唯一的内建保护是：如果 B 在停止位位置没有读到高电平（帧错误），B 知道"这一帧可能坏了"，但 B 不会告诉 A。可靠性要靠上层协议（如 ext_trans 的包格式和校验和）。

### 1.2 完整场景演算：接收一个 8N1 字节 'A' (0x41) 的每一步

这是理解 UART 异步采样最关键的场景。假设发送方以 115200-8N1 发送字符 'A'（ASCII 0x41，二进制 01000001）。

**硬件配置**：WQ UART，16× 过采样，过采样时钟 = 115200 × 16 = 1.8432 MHz，每个过采样周期 ≈ 0.543 μs。

**空闲状态（T < 0）**：TX 线保持高电平（逻辑 1）。接收方的过采样计数器一直在运行，但因为没有检测到下降沿，状态机处于空闲。

**T = 0：起始位开始。**

```text
发送方：TX 从高电平拉到低电平。
物理信号：TX 引脚电压从 3.3V 跳变到 0V。
接收方：过采样时钟在 T ≈ 0.27 μs 时检测到下降沿（相邻两次采样：1→0）。
        接收方复位内部 bit 计数器，准备在 8 个过采样周期后（0.5 bit）开始采样 D0。
```

**T = 8.68 μs（1 bit 时间后）：D0（LSB，bit 0 = 1）采样。**

```text
发送方：继续保持 D0 的值。D0 是 0x41 的最低位 = 1，所以 TX 保持高电平。
接收方：在过采样计数 = 8 时（即起始位下降沿后 8+16×0 = 8 个周期），
        过采样计数 = 7/8/9 三个点的多数值决定采样结果。三个点都是高电平 → D0 = 1。
        多数表决的意义：如果有一个采样点被噪声干扰，其他两个点仍能保证正确结果。
```

**T = 17.36 μs ~ T = 60.76 μs：D1 ~ D6 依次采样。**

```text
D1 (bit 1 = 0)：过采样计数 = 8+16×1 = 24，三个采样点 → 0
D2 (bit 2 = 0)：过采样计数 = 8+16×2 = 40，三个采样点 → 0
D3 (bit 3 = 0)：过采样计数 = 8+16×3 = 56，三个采样点 → 0
D4 (bit 4 = 0)：过采样计数 = 8+16×4 = 72，三个采样点 → 0
D5 (bit 5 = 0)：过采样计数 = 8+16×5 = 88，三个采样点 → 0
D6 (bit 6 = 1)：过采样计数 = 8+16×6 = 104，三个采样点 → 1
```

**T = 69.44 μs（8 bit 时间后）：D7（MSB，bit 7 = 0）采样。**

```text
发送方：D7 = 0，TX 保持低电平。
接收方：过采样计数 = 8+16×7 = 120，三个采样点 → 0
此时接收方已收完 8 个数据位，拼出字节：01000001 = 0x41 = 'A'。
```

**T = 78.12 μs（9 bit 时间后）：停止位采样。**

```text
发送方：拉高 TX，进入停止位。
接收方：过采样计数 = 8+16×8 = 136，三个采样点 → 1（停止位正确）。
        接收方产生 RXFIFO_FULL 或 RXTIMEOUT 中断，通知 CPU 取数据。
        如果这里读到 0（停止位为低），硬件置位 FRM_ERR（帧错误标志）。
```

**T = 86.8 μs（10 bit 时间后）：帧结束。**

```text
发送方：继续保持高电平（空闲）或开始下一个起始位。
接收方：状态机回到空闲，等待下一个下降沿。
```

**WQ SDK 映射**：上述过程在硬件中自动完成，CPU 不介入每个 bit 的采样。当 RX FIFO 达到阈值或超时，ISR 触发 `wq_uart_rx_int_handler` → 从 FIFO 读取字节 → 调用用户注册的 `rx.callback(buffer, read_size)`。整个 10 bit 帧的接收只产生一次 CPU 中断。

**SDK 事实**：WQ `bbb/hw/uart.c:198-216` 的 `uart_set_baudrate()` 使用分数分频器计算波特率。对于 ≤ 115200 的波特率，使用 systick 时钟（精度高）；对于更高波特率，切换到 core clock。分频公式为 `div_frag = (clock + (br/32)) / (br/16) & 0x0F`，整数部分 `div = clock / br`。以 115200 为例，如果 systick = 24 MHz，`div = 24000000/115200 = 208`，`div_frag = (24000000 + 3600) / 7200 ≈ 3333` 的低 4 位 = 某值。分数分频意味着实际波特率可以非常接近 115200，误差远小于 1%。

### 1.3 为什么"异步"不需要时钟线——以及它的代价

UART 的异步机制是"从数据中恢复时钟"的一种简化形式。不需要独立的时钟线，因为：

1. **空闲时线保持高电平**——接收方知道"没有通信"。
2. **起始位的下降沿提供了精确的计时零点**——接收方从这个边沿开始，用自己的时钟（16× 过采样）按约定的 bit 时间依次采样。
3. **每个 bit 在中间位置采样**——从起始位下降沿后等 0.5 bit（8 个过采样周期），然后每 16 个过采样周期采样下一个 bit。这保证了采样点始终在每个 bit 的眼图中心，离边沿最远，抗噪能力最强。
4. **停止位让线回到高电平**——这有两个作用：一是帧定界，二是**保证下一个起始位一定是下降沿**。如果停止位不在高电平，下一个起始位的下降沿就检测不到。

**代价**：这个机制依赖双方时钟在 10 个 bit 时间内保持足够一致。如果时钟偏差累积到约半个 bit 时间，停止位的采样点就会漂移到相邻 bit 的位置，导致帧错误。这就是为什么 UART 的波特率不能无限提高——速度越快，bit 时间越短，同样的时钟偏差比例下，留给采样窗口的绝对时间余量越小。

### 1.4 波特率误差的容忍度——精确计算

以 16× 过采样、8N1 帧格式为例，从起始位下降沿到停止位采样点的总时间 = 9.5 个 bit 时间。

```text
停止位采样点 = 起始位下降沿 + 8（等 0.5 bit）+ 16×8（8 个数据位）+ 8（停止位采样在 0.5 bit 处）
             = 起始位下降沿 + 136 个过采样周期
             = 9.5 个 bit 时间
```

如果接收方时钟比发送方快 ε（例如 ε = 2%），经过 9.5 个 bit 时间后，接收方的累计漂移 = 9.5 × ε 个 bit 时间。采样点偏离每个 bit 中心位置，当漂移超过约 0.5 个 bit 时间时，停止位可能被采样到相邻的数据位内。

```text
理论最大容忍误差：0.5 / 9.5 ≈ 5.26%
工程安全边界（考虑噪声、抖动、起始位检测精度）：~2%
```

**WQ 硬件事实**：`bbb/hw/uart.c` 的分数分频器（`div_frag` 为 4 位，即 1/16 精度）使实际波特率与目标值的偏差通常远小于 1%。例如 24 MHz 时钟产生 115200 波特率，`div × 16 + div_frag = 208 × 16 + 某值`，实际波特率 = 24M × 16 / (208 × 16 + div_frag) ≈ 115200 ± 0.1%。这意味着在 WQ 平台上，波特率误差通常不是通信失败的原因——更常见的问题是 TX/RX 未交叉、GPIO 复用配置错误、或未共地。

---

## 第二层：FIFO、中断和 DMA 的协作

### 2.1 为什么需要 FIFO

没有 FIFO 时，CPU 每发一个字节都要等到硬件把这个字节完全移出（以 115200 波特率，发送一个字节约 86.8 μs），这期间 CPU 只能空等。有 FIFO 后，CPU 可以一次写入 16 个字节，然后去做别的事，硬件自动逐个发出。

WQ UART 的 FIFO 深度由硬件层 `uart_get_tx_fifo_left()` 和 `uart_read()` 管理。HAL 层的 `wq_uart_write_fifo()` (wq_uart.c:583-595) 每次写入 `MIN(left, length)` 个字节，尽可能填满 FIFO。

**费曼类比**：FIFO 像一个传送带缓冲区。你往传送带前端放一叠包裹，传送带自动把包裹逐个送到后端发出。CPU 是"放包裹的人"，硬件是"传送带"。

### 2.2 中断驱动的发送流程

WQ UART 的发送路径（`wq_uart_write`，wq_uart.c:605-669）是一套精心设计的链表队列：

```text
wq_uart_write(port, string, length, cb)
  │
  ├─ DMA 已配置？
  │   └─ 是 → wq_uart_write_dma() → DMA 搬运 → 完成后 DMA 回调通知
  │
  └─ 否 → 中断模式：
        ├─ TX 队列为空？
        │   ├─ 是 → 直接写 FIFO
        │   │   ├─ 全部写入 → 立即调用 cb，返回
        │   │   └─ 部分写入 → 创建 tx_block，加入队列，使能 TX FIFO 空中断
        │   └─ 否 → 创建 tx_block，加入队列末尾
        │
        └─ TX FIFO 空中断（ISR）:
            └─ wq_uart_tx_fifo_empty_handler():
                ├─ 从当前 tx_block 剩余数据中写入 FIFO
                ├─ 当前 block 全部写完？→ 调用 block->cb，释放 block，移到下一个
                └─ 队列为空？→ 关闭 TX FIFO 空中断
```

关键实现细节：

- **互斥保护**：在 `CONFIG_OS_ENABLE` 下，`wq_uart_write` 使用 `os_acquire_mutex` 保护多任务并发写入（wq_uart.c:622）。
- **链表结构**：`wq_uart_tx_block_t`（wq_uart.c:56-62）包含 buffer 指针、length、回调函数和 `send_done` 标志。每个 block 代表一次 `wq_uart_write` 调用。
- **回调时机**：当前 block 的所有数据都写入 FIFO 后，回调在 ISR 中调用（wq_uart.c:812-813）。这意味着回调上下文是中断，不能做耗时操作。

### 2.3 中断驱动的接收流程

接收路径由 `wq_uart_register_rx_callback` 初始化（wq_uart.c:695-727）：

```text
wq_uart_register_rx_callback(port, buffer, length, callback)
  │
  ├─ 保存 buffer/length/callback 到端口状态
  ├─ 配置 RX 阈值：
  │   ├─ RXTIMEOUT（接收超时阈值）→ UART_TOUT_THRESH
  │   └─ RXFULL（FIFO 满阈值）→ UART_FULL_THRESH
  └─ 使能 6 种中断：
      ├─ RXFIFO_FULL   — FIFO 达到阈值，立即通知 CPU 取数据
      ├─ RXTIMEOUT     — 超过超时时间没有新字节，把已收到的数据交给上层
      ├─ RXFIFO_OVF    — 接收溢出，FIFO 满了又有新数据到达
      ├─ BRK_DET       — 检测到断线（Break）信号
      ├─ GLITCH_DET    — 检测到毛刺（噪音导致的假起始位）
      └─ FRM_ERR       — 帧错误（停止位不对）
```

**RX 中断处理**（`wq_uart_isr_handler`，wq_uart.c:858-901）：

1. `RXFIFO_FULL` 或 `RXTIMEOUT` → `wq_uart_rx_int_handler` 从 FIFO 读取数据，调用用户注册的 `rx.callback(buffer, read_size)`；
2. `RXFIFO_OVF` → `wq_uart_rx_fifo_overflow_handler` 复位 RX FIFO（丢弃溢出数据，从干净状态开始）；
3. `BRK_DET` / `GLITCH_DET` / `FRM_ERR` → `wq_uart_rx_break_handler` 复位 RX FIFO。

**缓冲区生命周期**：注册回调时传入的 buffer 必须保持有效，直到回调被取消。`wq_uart_set_rx_buffer`（wq_uart.c:729-743）可以在运行时动态替换 RX buffer，实现在临界区中安全切换。这是一个重要的设计——它允许上层在收到数据后立即更换 buffer，避免在处理当前数据时新数据覆盖旧数据。

### 2.4 DMA 模式

WQ UART 支持 TX 和 RX 各自独立配置 DMA（`wq_uart_dma_config_t`）：

- **TX DMA**：`wq_uart_write_dma`（wq_uart.c:190-200）通过 `wq_dma_mem2peri` 将内存数据直接搬运到 UART FIFO 地址。在 `CONFIG_OS_ENABLE` 下，如果 `tx_use_dma` 为 true，`wq_uart_write` 直接走 DMA 路径，跳过链表队列。
- **RX DMA**：`wq_uart_read_dma`（wq_uart.c:676-688）通过 `wq_dma_peri2mem` 将 UART FIFO 数据直接搬运到内存。完成后通过 DMA 回调通知上层。

**ext_trans 使用 DMA**：`ext_trans_dev_uart.c:110-111` 同时启用 TX DMA 和 RX DMA，优先级为 `WQ_DMA_CH_PRIORITY_HIGH`。这适合芯片间大量数据通信的场景。

### 2.5 流控：RTS/CTS

当接收方处理数据的速度跟不上发送方时，FIFO 可能溢出，导致数据丢失。硬件流控通过两根额外信号线解决这个问题：

- **RTS（Request To Send）**：WQ 作为接收方，当 FIFO 快满时拉高 RTS，告诉对方"暂停发送"；FIFO 有空间后拉低 RTS，告诉对方"可以继续"。
- **CTS（Clear To Send）**：WQ 作为发送方，发送前检查 CTS。如果 CTS 为高，说明对方还没准备好，WQ 暂停发送。

WQ 支持三种流控配置（`wq_uart_flow_control_cfg_t`）：
- `WQ_UART_FLOWCTRL_RTS`：仅使用 RTS 输出；
- `WQ_UART_FLOWCTRL_CTS`：仅使用 CTS 输入；
- `WQ_UART_FLOWCTRL_CTS_RTS`：同时使用 CTS 和 RTS。

流控由硬件自动处理——CPU 不需要介入每个字节的握手。`wq_uart_flow_control_config`（wq_uart.c:435-476）配置 GPIO 复用（通过 `gpio_mtx` 矩阵）和硬件流控使能。

---

## 第三层：WQ7036AX SDK 实战

### 3.1 真实 HAL 接口

以下是 `wqcore/driver/periph/common/hal/uart/wq_uart.h` 中的真实 API：

```c
// 生命周期
void wq_uart_init(WQ_UART_PORT port);
void wq_uart_deinit(WQ_UART_PORT port);
void wq_uart_open(WQ_UART_PORT port,
    const wq_uart_configuration_t *cfg,
    const wq_uart_gpio_configuration_t *gpio_cfg);
void wq_uart_close(WQ_UART_PORT port);

// 发送（中断模式，队列化）
WQ_RET wq_uart_write(WQ_UART_PORT port, const char *string,
    uint32_t length, wq_uart_write_done_callback cb);
// 发送（阻塞模式，直接写 FIFO）
void wq_uart_write_buffer(WQ_UART_PORT port,
    const char *buffer, uint32_t length);

// 接收（中断模式，需先注册回调）
WQ_RET wq_uart_register_rx_callback(WQ_UART_PORT port,
    uint8_t *buffer, uint32_t length, wq_uart_rx_callback callback);
WQ_RET wq_uart_set_rx_buffer(WQ_UART_PORT port,
    uint8_t *buffer, uint32_t length);
void wq_uart_unregister_rx_callback(WQ_UART_PORT port);

// 接收（DMA 模式）
WQ_RET wq_uart_read_dma(WQ_UART_PORT port,
    char *string, uint32_t length, wq_uart_rx_callback cb);

// 接收（直接读 FIFO，不经过 ISR）
uint32_t wq_uart_read(WQ_UART_PORT port,
    uint8_t *buffer, uint32_t length);

// 辅助
void wq_uart_putc(WQ_UART_PORT port, char c);
void wq_uart_puts(WQ_UART_PORT port, const char *s);
void wq_uart_flush(WQ_UART_PORT port);
void wq_uart_rx_reset(WQ_UART_PORT port);
void wq_uart_set_threshold(WQ_UART_PORT port,
    WQ_UART_THR thr, uint32_t value);

// 流控
WQ_RET wq_uart_flow_control_config(WQ_UART_PORT port,
    const wq_uart_flow_control_cfg_t *cfg);

// DMA 配置
WQ_RET wq_uart_dma_config(WQ_UART_PORT port,
    const wq_uart_dma_config_t *cfg);

// 共享 I/O（半双工单线模式）
void wq_uart_share_io_enable(WQ_UART_PORT port);
void wq_uart_share_io_disable(WQ_UART_PORT port);
WQ_RET wq_uart_force_set_direction(WQ_UART_PORT port,
    WQ_UART_DIRECTION direction);
void wq_uart_disable_force_direction_mode(WQ_UART_PORT port);
```

从这组声明可以读出几个工程约束：

1. **init 和 open 都可以重复调用**——`wq_uart_init` 检查 `port_initialized` 位（wq_uart.c:354），`wq_uart_open` 检查 `port_opened` 位（wq_uart.c:518），不会重复操作。
2. **`wq_uart_write` 和 `wq_uart_write_buffer` 是不同的**。前者在 OS 模式下是队列化+中断驱动，后者是阻塞循环写 FIFO。关键区别：`write_buffer` 不返回直到所有数据写入 FIFO，`write` 可能部分写入后排队。
3. **RX 回调只能注册一个**。`wq_uart_register_rx_callback` 如果已有 callback 注册，返回 `WQ_RET_AGAIN`（wq_uart.c:702-705）。
4. **共享 I/O 模式**：TX 和 RX 使用同一 GPIO 时（`cfg->rx == cfg->tx`），驱动自动启用共享 I/O（wq_uart.c:237-238）。此时 `wq_uart_force_set_direction` 可以强制切换方向（发或收）。
5. **TX/RX 都默认配置上拉**（wq_uart.c:526-527），这符合 UART 空闲时线拉高的习惯。

### 3.2 配置结构体

```c
typedef struct wq_uart_configuration {
    uint32_t baud_rate;          // 波特率（如 115200）
    WQ_UART_DATA_BITS data_bits; // 5/6/7/8 bit
    WQ_UART_PARITY parity;       // NONE / EVEN / ODD
    WQ_UART_STOP_BITS stop_bits; // 1 / 1.5 / 2
} wq_uart_configuration_t;

typedef struct wq_uart_gpio_configuration {
    WQ_GPIO_ID tx; // TX 引脚
    WQ_GPIO_ID rx; // RX 引脚，如果与 tx 相同则自动启用共享 I/O
} wq_uart_gpio_configuration_t;

typedef struct wq_uart_dma_config {
    bool tx_use_dma;
    bool rx_use_dma;
    WQ_DMA_CH_PRIORITY tx_priority;
    WQ_DMA_CH_PRIORITY rx_priority;
} wq_uart_dma_config_t;
```

### 3.3 真实应用：ext_trans UART 芯片间通信

`wq-adk/components/ext_trans/src/ext_trans_dev_uart.c` 将 UART 封装为统一的芯片间传输接口：

```c
static ext_trans_dev_func_t uart_io_func = {
    .init   = ext_trans_dev_uart_init,
    .deinit = ext_trans_dev_uart_deinit,
    .open   = ext_trans_dev_uart_open,
    .close  = ext_trans_dev_uart_close,
    .out    = ext_trans_dev_uart_data_tx,
    .in     = ext_trans_dev_uart_data_rx,
    .duplex = NULL,  // UART 不支持 duplex 模式
};
```

关键实现：

1. **初始化**：`wq_uart_init(port)` → 分配 `ext_trans_uart_t` 结构体 → 初始化 `tx_list` 链表。
2. **打开**：配置 8N1 + 波特率（来自 `CONFIG_EXT_TRANS_UART_BAUDRATE`）→ GPIO 从 `wq_resource_lookup_gpio` 动态获取 → 启用 TX/RX DMA → `wq_uart_open`。
3. **TX**：创建 `uart_ext_trans_node_t` 节点加入 `tx_list` → 调用 `wq_uart_write`。DMA 完成后回调从链表中取出节点并调用上层回调。注意 `wq_uart_write` 的回调 buffer 参数和 `ext_trans` 的回调参数不同，ext_trans 通过 `tx_list` 链表自己管理回调，而不是依赖 `wq_uart_write` 的回调。
4. **RX**：调用 `wq_uart_read_dma` 启动 DMA 接收，DMA 完成后回调通知上层。
5. **关闭**：遍历 `tx_list` 链表，调用所有未完成节点的回调（通知失败），释放所有节点，然后 `wq_uart_close`。

ext_trans 的 UART 实现只支持 `out`（纯发送）和 `in`（纯接收），`duplex` 函数指针为 NULL——因为 UART 的 TX 和 RX 是独立通道，不存在"同时收发"的单一 API。

### 3.4 低功耗恢复

`wq_uart_restore`（wq_uart.c:271-334）在系统从低功耗唤醒后恢复所有 UART 端口：

1. 重新初始化 UART 内存（`uart_enable_mem`）；
2. 遍历所有已打开的端口：
   - 重新初始化 UART 控制器；
   - 恢复 GPIO 配置（先设为普通 GPIO 再重新配置复用）；
   - 恢复波特率、数据位、校验、停止位；
   - 复位 TX/RX FIFO；
   - 恢复 TX 空中断阈值；
   - 如果注册了 RX 回调，重新使能 RX 相关中断（RXFIFO_FULL、RXTIMEOUT、RXFIFO_OVF、BRK_DET、GLITCH_DET、FRM_ERR）；
   - 如果配置了 DMA，重新配置 DMA 通道。

`wq_uart_busy`（wq_uart.c:336-343）在低功耗前检查所有端口是否有未完成的发送（TX 链表非空或 FIFO 非空），如果有则阻止进入低功耗。

---

## 第四层：V861/reGlasses 的 UART 配置

### 4.1 设备树中的 UART 分配

`/home/ys/aiglass/reglasses/device/configs/reglasses/linux-6.6-xuantie/board.dts` 中配置了 4 个 UART：

| UART | 用途 | 关键配置 |
|---|---|---|
| UART0 | Linux console | `console=ttyS0,115200`，pinmux 为 `s_uart0` |
| UART1 | 通用 | pinmux 已定义 active/sleep |
| UART2 | BT/MCU STTP → WQ7036AX | PD18=TX, PD19=RX，这是 WQ 和 V861 之间的核心通信链路 |
| UART3 | 通用 | pinmux 已定义 active/sleep |

### 4.2 UART2 作为 WQ-V861 桥接

`board.dts:220-221` 的注释明确写："UART2 - BT/MCU STTP link to WQ7036AX (PD18=TX, PD19=RX)"。这说明：

- WQ7036AX 和 V861 之间的所有命令（拍照、录像、TOF 传感器控制等）和数据都通过这条 UART 链路传输；
- STTP（Smart Things Transfer Protocol）是跑在 UART 之上的应用层协议；
- 在 WQ 一侧，这条链路通过 `ext_trans_dev_uart` 管理，与 V861 侧的 Linux UART 驱动（`ttyS2`）配对。

### 4.3 WQ HAL 和 Linux UART 的本质区别

| 对比维度 | WQ HAL（`wq_uart_*`） | Linux UART（`ttyS*`） |
|---|---|---|
| 编程模型 | 直接 HAL API + 回调 | 文件描述符 + read/write + poll/select |
| 缓冲 | 用户指定 buffer + 中断/FIFO | 内核 tty 层缓冲 + line discipline |
| DMA | 显式 DMA 配置（`wq_uart_dma_config`） | 由内核 DMA engine 子系统管理 |
| 流控 | `wq_uart_flow_control_config` 硬件配置 | termios 设置 CRTSCTS |
| 共享 I/O | API 原生支持（`share_io_enable`） | 需配置为半双工模式 |

---

## 第五层：常见故障与诊断

### 5.1 故障排查顺序

```text
UART 通信失败？
  ├─ 双方共地了吗？
  │   └─ 没有 → UART 电压基准不同，信号无法正确识别
  ├─ TX/RX 交叉连接了吗？
  │   └─ 检查：A.TX → B.RX，A.RX ← B.TX
  ├─ 空闲时线是高电平吗？
  │   ├─ 一直低 → 检查上拉、对方是否在发送 Break、线路是否短路
  │   └─ 是高 → 看起始位有吗？
  ├─ 起始位有吗？
  │   ├─ 没有 → 检查 GPIO 配置、wq_uart_open 是否成功、TX 是否被使能
  │   └─ 有但数据乱码 → 波特率匹配吗？
  ├─ 波特率匹配吗？
  │   ├─ 检查双方配置的实际波特率（不是"期望值"）
  │   └─ 用逻辑分析仪或示波器测量实际 bit 宽度
  ├─ 帧格式一致吗？
  │   └─ 数据位数、校验、停止位数是否完全一致
  └─ 数据部分正确但偶发丢失？
      ├─ 检查 FIFO 溢出 → 降低波特率或启用流控
      ├─ 检查帧错误中断 → 可能存在噪声或时钟偏差
      └─ 检查 RX buffer 处理速度 → 回调耗时过长导致来不及读
```

### 5.2 典型故障表

| 现象 | 第一假设 | 需要的证据 | 不要先做什么 |
|---|---|---|---|
| 收不到任何数据 | TX/RX 未交叉，或 RX 引脚未正确配置 | 万用表测连通性，示波器看 RX 引脚波形 | 不要只改波特率 |
| 收到乱码 | 波特率不匹配 | 逻辑分析仪测实际 bit 宽度，对比双方配置 | 不要只改帧格式 |
| 偶发丢字节 | RX FIFO 溢出（处理速度跟不上） | 检查 RXFIFO_OVF 中断触发次数，检查回调耗时 | 不要只加 retry |
| 数据前半段正确后半段错误 | 波特率误差累积导致采样点偏移 | 示波器看最后一个停止位的波形 | 不要只改起始位配置 |
| 发送方返回成功但对方没收到 | TX FIFO 中的数据未实际发出（如流控被阻塞） | 检查 CTS 状态、TX FIFO 空标志 | 不要只重发 |
| ISR 中频繁触发 FRM_ERR | 噪声或时钟偏差 | 示波器长时间抓取，看是否有毛刺 | 不要在 ISR 中加 print |
| DMA 传输不触发回调 | DMA 配置错误或通道被占用 | 检查 `wq_dma_claim_channel` 返回值、DMA 描述符 | 不要直接改 DMA 优先级 |
| 共享 I/O 模式下方向切换后丢数据 | 方向切换后硬件还没来得及完成 TX | 在方向切换前确保 TX FIFO 为空 | 不要缩短切换延迟 |

### 5.3 诊断中断状态

WQ UART 的 ISR 处理 6 种中断（wq_uart.c:858-901），每种中断的含义和诊断价值：

| 中断 | 触发条件 | 诊断价值 |
|---|---|---|
| `RXFIFO_FULL` | RX FIFO 达到阈值 | 正常数据接收，说明通信链路通畅 |
| `RXTIMEOUT` | 接收超时（一段时间没有新字节） | 最后一个字节到达后的收尾，正常 |
| `RXFIFO_OVF` | RX FIFO 溢出 | 数据丢失的信号，说明 CPU 处理太慢或缓冲太小 |
| `BRK_DET` | 检测到 Break 信号（线持续低电平 > 1 帧） | 对方可能发送了 Break，或线路断开 |
| `GLITCH_DET` | 检测到假起始位（毛刺） | 线路噪声，检查信号完整性 |
| `FRM_ERR` | 停止位不是高电平 | 波特率偏差或噪声，最直接的通信质量信号 |

如果 `FRM_ERR` 和 `GLITCH_DET` 频繁触发，首先要怀疑波特率配置——而不是先改 PCB 布线。

---

## 第六层：练习与验收

### 练习一：计算波特率误差

给定：双方配置波特率 115200。WQ 的 APB 时钟为 96 MHz，分频比 = 96M / 115200 ≈ 833.33，实际取整为 833（或最近的偶数），实际波特率 = 96M / 833 ≈ 115246。

计算：
1. 实际波特率与标称值的偏差百分比；
2. 10 bit 帧中，停止位采样点的漂移量；
3. 判断这种偏差是否会导致帧错误。

**通过标准**：能解释为什么 115200 在 96 MHz 时钟下几乎是安全的（偏差 < 0.05%），而某些冷门波特率（如 123456）在同样时钟下可能偏差超过 2%。

### 练习二：追踪 WQ UART 的 TX 路径

打开 `wqcore/driver/periph/common/hal/uart/wq_uart.c`，回答：

1. `wq_uart_write` 在 DMA 使能时和未使能时的执行路径有什么不同？
2. `wq_uart_write_buffer` 和 `wq_uart_write` 的区别是什么？什么时候用哪个？
3. TX 链表中的 `wq_uart_tx_block_t` 的 `send_done` 字段在什么场景下被设置？
4. 为什么 TX 回调在 ISR 中调用，这对回调函数有什么限制？

**通过标准**：能画出 DMA 和中断两种模式的完整调用链，标注每个函数在哪个上下文中执行。

### 练习三：追踪 ext_trans UART 的接收流程

从 `wq-adk/components/ext_trans/src/ext_trans_dev_uart.c` 开始，追踪：

```text
ext_trans_dev_uart_data_rx(port, buffer, length, cb)
  → wq_uart_read_dma(port, buffer, length, rx_done_cb)
  → DMA 控制器 → UART FIFO → 内存 buffer
  → DMA 完成 → rx_done_cb → ext_trans 上层回调
```

**通过标准**：能说出 DMA 接收和中断接收（`wq_uart_register_rx_callback`）的区别，以及为什么 ext_trans 选择 DMA 而不是中断。

### 练习四：分析 V861 UART 设备树

阅读 `aiglass/reglasses/device/configs/reglasses/linux-6.6-xuantie/board.dts` 中 UART2 的配置，回答：

1. UART2 使用哪两个 GPIO（PD18/PD19）？哪个是 TX，哪个是 RX？
2. 为什么 UART2 的 pinmux 同时定义了 `active` 和 `sleep` 两种状态？
3. UART2 作为 WQ-V861 通信链路，不经过流控（RTS/CTS）会有什么风险？
4. 如果要添加 UART2 的 DMA 配置，在 Linux 设备树中需要修改什么？

**通过标准**：能解释 active/sleep pinmux 的作用（省电），以及无流控时需要在应用层协议中处理速率匹配。

### 练习五：设计故障定位实验

现象：WQ 通过 UART 向 V861 发送命令，V861 偶尔收到乱码，但频率不高（约 1%）。要求在 WQ 侧设计诊断方案：

1. 如何判断是 WQ 发送问题还是 V861 接收问题？
2. 如何在 WQ 侧检查 FRM_ERR 是否触发？
3. 如果用逻辑分析仪抓取，应该设置什么触发条件？
4. 如果怀疑是波特率误差，如何验证？

**通过标准**：每个假设都有可执行的验证步骤和预期的证据。

## 自测题

1. **为什么 UART 叫"异步"？异步有什么代价？**
   - 因为没有独立的时钟线，收发双方用各自的本地时钟采样。代价是双方时钟必须足够精确，波特率误差不能超过约 5%（10 bit 帧），否则停止位采样错误。

2. **8N1 帧格式每帧多少 bit？115200 波特率下每秒最多发多少字节？**
   - 1 start + 8 data + 0 parity + 1 stop = 10 bit。115200 / 10 = 11520 字节/秒。

3. **WQ UART 的 RX 中断有哪几种？RXFIFO_FULL 和 RXTIMEOUT 的区别是什么？**
   - 6 种：RXFIFO_FULL（FIFO 达到阈值）、RXTIMEOUT（超时没有新字节）、RXFIFO_OVF（溢出）、BRK_DET（断线）、GLITCH_DET（毛刺）、FRM_ERR（帧错误）。RXFIFO_FULL 是批量收数据时触发，RXTIMEOUT 是最后一个字节到达后超时触发，确保数据不会无限期等在 FIFO 中。

4. **`wq_uart_write` 和 `wq_uart_write_buffer` 的区别是什么？**
   - `write` 在 OS 模式下是队列化+中断/DMA 驱动，非阻塞；`write_buffer` 是阻塞循环写 FIFO，直到所有数据写入。`write` 适合多任务环境，`write_buffer` 适合调试输出或裸机环境。

5. **共享 I/O 模式下，TX 和 RX 用同一根 GPIO，如何避免自己发的同时又收到自己的数据？**
   - 方向控制：发送时强制设为 TX 方向（`wq_uart_force_set_direction(TX)`），接收时切换为 RX 方向。切换前必须确保 TX FIFO 为空（`wq_uart_flush`）。共享 I/O 本质上是半双工。

6. **RTS/CTS 流控解决什么问题？WQ 支持哪几种流控模式？**
   - 防止接收方 FIFO 溢出。当接收方处理速度跟不上发送速度时，RTS 拉高通知对方暂停。WQ 支持 RTS only、CTS only、CTS+RTS 三种。

7. **V861 的 UART2 和 WQ7036AX 的哪个 UART 端口通信？**
   - V861 的 UART2（PD18=TX, PD19=RX）通过 STTP 协议与 WQ7036AX 通信。在 WQ 一侧，由 `ext_trans_dev_uart` 管理对应的 UART 端口。具体是 WQ 的 UART0 还是 UART1 取决于 `CONFIG_EXT_TRANS_IO_UART_ENABLE` 的配置和资源表中的 GPIO 映射。

## 常见反例

- UART 的 TX 接 TX、RX 接 RX。应该交叉连接：TX→RX、RX←TX。
- 不接地线。UART 需要共地作为电压参考，只接 TX/RX 不接 GND 会导致信号无法正确识别。
- 在 ISR 回调中做耗时操作。`wq_uart_write` 的回调和 `rx_callback` 都在 ISR 上下文中执行，做耗时操作会导致其他中断被阻塞，甚至触发看门狗。
- 配置波特率但不检查实际值。由于时钟分频取整，实际波特率可能与请求值不同，冷门波特率尤其容易出问题。
- 不检查 `wq_uart_register_rx_callback` 的返回值。如果已有 callback 注册，返回 `WQ_RET_AGAIN`，新的 callback 不会生效。
- 在共享 I/O 模式下发完数据后立即切换方向。应确保 TX FIFO 为空后再切换。
- 认为 UART 自带错误检测。UART 没有 ACK、CRC 或重传机制，只有可选的奇偶校验——它只能检测单 bit 错误，不能纠正。

## 参考资料

- WQ7036AX UART HAL：`wqcore/driver/periph/common/hal/uart/wq_uart.h`、`wq_uart.c`
- WQ7036AX UART 硬件层：`wqcore/driver/periph/bbb/hw/uart.h`、`uart.c`
- WQ ext_trans UART：`wq-adk/components/ext_trans/src/ext_trans_dev_uart.c`
- V861 UART 设备树：`aiglass/reglasses/device/configs/reglasses/linux-6.6-xuantie/board.dts`
- [[i2c-basics-I2C基础]] — 对比：同步两线总线，有 ACK 应答
- [[spi-basics-SPI基础]] — 对比：同步四线总线，推挽全双工
- [[uart-i2c-spi-compare-串口总线对比]] — 四种总线全面对比
- [[gpio-config-GPIO配置]] — GPIO 复用和上下拉
- [[dma-basics-DMA基础]] — DMA 传输与回调机制
- [[dataflow-cmd-to-v881-手机指令到V881]] — UART 在 reGlasses 中的跨芯片角色

#flashcard

问：UART 为什么叫"异步"？
答：因为没有独立的时钟线，收发双方各自用本地时钟按约定波特率采样数据。接收方通过起始位的下降沿校准采样时刻，之后按本地时钟每隔 1 bit 时间采样一次。

问：8N1 帧格式每帧多少 bit？115200 波特率下每秒最多发多少字节？
答：1 start + 8 data + 1 stop = 10 bit。115200 / 10 = 11520 字节/秒 ≈ 11.25 KB/s。

问：WQ UART 的 `wq_uart_write` 在 DMA 和中断模式下的执行路径有什么不同？
答：DMA 模式直接启动 DMA 搬运，不走链表队列；中断模式先尝试直接写 FIFO，如果写不完则创建 tx_block 加入链表，由 TX FIFO 空中断逐个完成。

问：V861 通过哪个 UART 与 WQ7036AX 通信？
答：V861 的 UART2（PD18=TX, PD19=RX），运行 STTP 协议。WQ 侧由 ext_trans UART 模块管理。