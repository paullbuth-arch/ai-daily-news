# 常用调试工具链

**一句话结论（20% 核心）**：嵌入式调试三件套是"串口日志（看流程）、GDB+JTAG/SWD（看代码和寄存器）、逻辑分析仪/示波器（看信号波形）"。三种工具覆盖了 95% 的嵌入式问题。

---

## 第一层：核心认知

### 1.1 费曼类比：看病

排查程序问题就像看病：

| 医疗手段 | 调试工具 | 能查什么 |
|---|---|---|
| 病人口述症状 | **串口打印/日志** | 程序跑到哪了、变量值是多少 |
| B 超/CT/验血 | **GDB + JTAG/SWD** | 寄存器值、内存内容、调用栈 |
| 心电图/脑电图 | **逻辑分析仪/示波器** | 信号波形、时序、电平 |

### 1.2 核心工具速查表

| 工具 | 用途 | 适合查什么 | 成本 |
|---|---|---|---|
| **串口打印** | printf 输出到 PC | 流程、变量值、错误码 | 极低（USB 转串口） |
| **GDB + OpenOCD** | 断点、单步、查看寄存器和内存 | 崩溃、死循环、变量异常 | 低（JTAG/SWD 调试器） |
| **逻辑分析仪** | 抓数字信号时序 | I2C/SPI/UART 波形、协议解码 | 中（几百~几千元） |
| **示波器** | 看模拟信号波形 | 电源纹波、时钟信号、模拟传感器 | 高（几千~几万元） |
| **万用表** | 测电压、电流、通断 | 电源、焊接、引脚连通性 | 低 |

### 1.3 如果只记得一件事

> 先用串口日志缩小范围，再用 GDB 精确定位代码行，最后用逻辑分析仪/示波器验证硬件信号。三层工具由粗到细。

---

## 第二层：实战理解

### 2.1 串口打印：最基础也最实用

串口打印是嵌入式开发中**用得最多**的调试手段，几乎每个项目都会用。

```c
// 最简单的串口打印
void debug_init(void) {
    uart_init(DEBUG_UART, 115200, 8, NONE, 1);
}

void debug_print(const char *fmt, ...) {
    char buf[128];
    va_list args;
    va_start(args, fmt);
    vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);
    uart_send_string(DEBUG_UART, buf);
}

// 使用
debug_print("Task started, free_heap=%zu\n", xPortGetFreeHeapSize());
debug_print("I2C read: addr=0x%02X, val=0x%04X\n", addr, value);
```

**在 PC 端接收**：
- Linux: `minicom -D /dev/ttyUSB0 -b 115200` 或 `picocom`
- Windows: PuTTY / MobaXterm / SSCOM
- macOS: `screen /dev/tty.usbserial 115200`

**实用技巧**：
1. **加时间戳**：`debug_print("[%lu] event=%d\n", xTaskGetTickCount(), evt);`
2. **加文件名行号**：`#define LOG(fmt, ...) debug_print("%s:%d " fmt, __FILE__, __LINE__, ...)`
3. **条件编译**：Release 版本去掉 DEBUG 日志
4. **环形日志缓冲**：日志先写到 RAM，满了覆盖旧的，崩溃后 GDB 导出

### 2.2 GDB + OpenOCD：断点调试

OpenOCD 是开源的 JTAG/SWD 调试服务器，GDB 通过它连接到目标芯片。

**启动流程**：

```bash
# 终端 1：启动 OpenOCD（连接调试器和芯片）
$ openocd -f interface/jlink.cfg -f target/wq7036a.cfg
Open On-Chip Debugger 0.11.0
Listening on port 3333 for gdb connections

# 终端 2：启动 GDB（连接到 OpenOCD）
$ riscv64-unknown-elf-gdb build/acore/acore.elf
(gdb) target remote :3333
(gdb) load          # 把 ELF 下载到芯片
(gdb) b main        # 在 main 函数设断点
(gdb) c             # 继续运行
```

**GDB 常用命令速查**：

| 命令 | 作用 | 示例 |
|---|---|---|
| `b` (break) | 设断点 | `b main` / `b file.c:42` |
| `c` (continue) | 继续运行 | `c` |
| `n` (next) | 单步（不进入函数） | `n` |
| `s` (step) | 单步（进入函数） | `s` |
| `p` (print) | 打印变量值 | `p counter` / `p *ptr` |
| `bt` (backtrace) | 查看调用栈 | `bt` |
| `info registers` | 查看所有寄存器 | `info registers` |
| `info threads` | 查看所有任务 | `info threads` |
| `x` (examine) | 查看内存内容 | `x/16xb 0x20000000`（16 字节 hex） |
| `watch` | 监视点（变量被改时暂停） | `watch counter` |
| `delete` | 删除断点 | `delete 1` |

**实际调试案例**：

```bash
# 场景：程序崩了，想知道崩在哪里
(gdb) target remote :3333
(gdb) b HardFault_Handler
(gdb) c
# ... 程序崩溃，停在 HardFault_Handler ...
(gdb) info registers
pc    = 0x00012345    ← 崩溃地址
lr    = 0x00010abc    ← 调用者
(gdb) list *0x00012345
# 显示崩溃对应的源代码行
```

### 2.3 JTAG vs SWD 调试接口

| 特性 | JTAG | SWD |
|---|---|---|
| 线数 | 5 根（TCK/TMS/TDI/TDO/TRST） | 2 根（SWDIO/SWCLK） |
| 速度 | 快 | 略慢 |
| 功能 | 完整（边界扫描、多核调试） | 够用（断点、读写） |
| 适用 | 复杂 SoC、FPGA | MCU（大多数场景） |
| 常用调试器 | J-Link、FT2232 | J-Link、ST-Link、DAPLink |

WQ7036A 使用 **cJTAG**（Compact JTAG，2 线 JTAG）作为调试接口。

### 2.4 逻辑分析仪：看数字信号时序

逻辑分析仪可以同时抓取多路数字信号，显示高低电平随时间的变化。

**典型使用场景**：

1. **UART 通信异常**：抓 TX/RX 波形，检查波特率、数据位、起始/停止位。
2. **I2C 通信失败**：抓 SDA/SCL，检查地址、ACK/NACK、时序。
3. **SPI 模式不匹配**：抓 CLK/MOSI/MISO/CS，检查 CPOL/CPHA。
4. **GPIO 时序**：检查中断响应延迟、PWM 频率。

**使用步骤**：

```
1. 把逻辑分析仪的探头夹到目标信号线上
2. 设置采样率（至少是信号频率的 10 倍）
3. 设置触发条件（如 UART 起始位下降沿）
4. 采集 → 查看波形 → 用协议解码器解析数据
```

**推荐工具**：
- 入门：Saleae Logic（国产兼容版几十元）
- 进阶：Saleae Logic Pro、DSLogic
- 软件：PulseView（开源，支持协议解码）

### 2.5 示波器：看模拟信号

示波器显示电压随时间的变化，能看到逻辑分析仪看不到的细节：

| 检查项 | 示波器能看到什么 |
|---|---|
| 电源纹波 | 3.3V 电源上有多少 mV 的波动 |
| 时钟信号 | 时钟波形是否干净、频率是否准确 |
| 信号完整性 | 信号上升/下降沿是否陡峭、有没有振铃 |
| I2C 电平 | SDA/SCL 的高低电平是否达标 |

**什么时候用示波器而不是逻辑分析仪？**
- 信号"看起来对"但通信失败 → 可能是电平不够、上升沿太慢、有振铃
- 电源问题 → 只能用示波器看
- 模拟传感器信号 → 只能用示波器

### 2.6 项目中的调试配置

WQ7036A 项目的调试连接：

```
PC (GDB)
  ↕ TCP :3333
OpenOCD
  ↕ cJTAG
WQ7036A 芯片 (ACORE/BCORE/DCORE)

PC (串口终端)
  ↕ USB 转 UART
WQ7036A 调试串口 (115200 baud)
```

**调试时的编译选项**：
```bash
# 编译时加 -g 生成调试信息，-O0 关闭优化
./build.sh --chip=7036AX --config-file=defconfig.stereo.i2s --debug
```

---

## 第三层：深入扩展

### 3.1 CoreSight 调试架构（ARM）

ARM Cortex-M 系列内置的调试功能：

| 组件 | 功能 |
|---|---|
| **FPB** (Flash Patch and Breakpoint) | 硬件断点（最多 4-8 个） |
| **DWT** (Data Watchpoint and Trace) | 数据监视点 + 周期计数器 |
| **ITM** (Instrumentation Trace Macrocell) | 无侵入式日志输出（通过 SWO 引脚） |
| **ETM** (Embedded Trace Macrocell) | 指令流跟踪（不需要暂停 CPU） |

**ITM 日志（无侵入式打印）**：

```c
// 通过 ITM 输出日志，不影响程序执行，不需要 UART
void itm_putchar(char c) {
    while ((ITM_STIM0 & ITM_STIM_FIFOREADY) == 0);  // 等待 FIFO 就绪
    ITM_STIM0 = c;
}

// 在 GDB 或 OpenOCD 中配置 ITM 后，可以在 PC 端看到日志
```

**优势**：不需要 UART、不占 CPU 时间、不影响程序时序。

### 3.2 RTOS 感知调试

FreeRTOS + GDB 配合可以查看所有任务的状态：

```bash
# 需要 FreeRTOS 的 GDB 脚本或 OpenOCD RTOS 支持
(gdb) info threads
  1  Thread "idle"       (running)
  2  Thread "audio_task" (blocked on semaphore)
  3  Thread "bt_task"    (running)
  4  Thread "app_task"   (delayed 100ms)

(gdb) thread 2
(gdb) bt
#0  xQueueReceive (queue=0x20001234, buffer=0x20002000, timeout=0xffffffff)
#1  audio_task (p=0x0) at src/audio.c:45
```

### 3.3 无侵入式调试（Trace / SWO）

当断点会严重影响程序行为时（如音频实时处理），需要用 Trace 技术：

- **SWO（Serial Wire Output）**：通过 SWD 的 SWO 引脚输出 ITM 日志。
- **ETM Trace**：记录 CPU 执行过的每条指令，可以回溯到崩溃前的完整路径。
- **Performance Counter**：统计 Cache 命中率、分支预测失败率等。

### 3.4 常见问题

- **JTAG 和 SWD 的区别？** JTAG 5 线功能全，SWD 2 线更省引脚，MCU 调试通常够用。
- **GDB 硬件断点为什么有数量限制？** 因为硬件断点需要 CPU 内部的比较器资源，数量有限（通常 4-8 个）。
- **逻辑分析仪和示波器的区别？** 逻辑分析仪只看高低电平（数字），示波器看电压波形（模拟）。逻辑分析仪通道多、适合协议解码；示波器精度高能看信号质量。
- **什么是 ITM？** ARM 的 Instrumentation Trace Macrocell，可以通过 SWO 引脚无侵入地输出日志。

### 3.5 核心术语表

| 英文 | 中文 | 说明 |
|---|---|---|
| JTAG | 联合测试行动组 | Joint Test Action Group，调试接口标准 |
| SWD | 串行线调试 | Serial Wire Debug，ARM 的 2 线调试协议 |
| GDB | GNU 调试器 | GNU Debugger |
| OpenOCD | 开源片上调试器 | Open On-Chip Debugger |
| Breakpoint | 断点 | 暂停程序执行的位置 |
| Watchpoint | 监视点 | 变量被读/写时暂停 |
| CoreSight | ARM 调试架构 | 包含 FPB/DWT/ITM/ETM |
| ITM | 仪表跟踪宏单元 | 无侵入式日志输出 |
| SWO | 串行线输出 | Serial Wire Output |
| Logic Analyzer | 逻辑分析仪 | 多通道数字信号分析 |
| Oscilloscope | 示波器 | 模拟电压波形显示 |

### 3.6 延伸阅读

- [[debug-methodology-嵌入式调试方法论]] —— 系统化的调试思路
- [[c-core-C语言核心]] —— 指针和内存相关的常见 bug
- [[interrupt-concurrency-中断并发同步]] —— 并发问题的排查
- [[reliability-exception-系统可靠性与异常处理]] —— HardFault 和看门狗
