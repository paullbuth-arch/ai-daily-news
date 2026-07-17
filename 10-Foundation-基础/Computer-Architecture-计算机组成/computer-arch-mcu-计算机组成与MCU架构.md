---
type: concept
tags: [embedded, mcu, computer-architecture, riscv, wq7036a, soc]
aliases: [计算机组成, MCU架构, 单片机, SoC]
---

# 计算机组成与 MCU 架构

## 一句话结论

MCU（单片机）就是一颗把 CPU、内存、外设控制器全部塞进一个封装里的芯片。你写的每一行代码最终都是在操控这三样东西：CPU 执行指令，内存存数据，外设控制器和外面的世界交互。

## 30秒先看懂

- MCU 内部由 CPU（执行指令）、Flash（存代码，断电不丢）、SRAM（存变量，断电清零）、外设控制器（UART/I2C/GPIO）和总线（连接所有部件）组成。芯片上电后不会直接跳到 `main()`——先要经过启动代码初始化栈指针、搬移 .data 段、清零 .bss 段、配置中断向量表，然后才进入 `main()`。操作外设的方式是读写寄存器——每个外设有一组寄存器，被映射到特定的内存地址（MMIO），用 `volatile` 指针访问。WQ7036AX 是一颗三核异构 SoC（ACORE RISC-V 跑应用 + BCORE RISC-V 跑蓝牙 + DCORE Xtensa HiFi5 跑音频 DSP），三个核通过共享内存和软中断通信。

## 学完以后应该能做什么

**第一遍看完后可以：**
- 理解 MCU 上电后到 main() 的完整流程
- 知道如何通过读写寄存器操控外设
- 理解 Flash、SRAM、寄存器在地址空间中的布局
- 知道 WQ7036AX 三个核的分工和启动顺序

**进阶后可以：**
- 阅读芯片参考手册中的内存映射表和寄存器描述
- 编写启动代码（startup.S）移植到新芯片
- 配置时钟树，计算各外设总线时钟频率
- 分析流水线对性能的影响，优化关键循环

## 前置知识

- C 语言指针、volatile 关键字
- 二进制、十六进制数制转换
- 基本的数字电路知识（电平、时钟）

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 微控制器 | MCU / Microcontroller | CPU+内存+外设集成在单芯片上的嵌入式处理器 |
| 片上系统 | SoC / System on Chip | 比 MCU 更复杂，集成更多功能（如 WQ7036AX 含三核+蓝牙+音频 DSP） |
| 指令集架构 | ISA / Instruction Set Architecture | CPU 认识的指令集合，如 RISC-V、ARM、x86 |
| 内存映射 IO | MMIO / Memory-Mapped IO | 把外设寄存器映射到内存地址空间，用指针访问 |
| 哈佛架构 | Harvard Architecture | 指令和数据走独立的总线，可同时访问 |
| 中断控制器 | NVIC / PLIC | 管理多个中断源，决定优先级和分发 |
| 时钟树 | Clock Tree | 从晶振到各模块的时钟分发网络，含 PLL 倍频和分频 |
| 寄存器 | Register | CPU 内部的高速存储单元，或外设的控制/状态寄存器 |

## 第一层：费曼心智模型

### 类比：芯片就像一个小公司

把一颗 MCU 芯片想象成一个小公司：

| 芯片部件 | 类比 | 干什么 | WQ7036AX 里实际是什么 |
|---------|------|--------|---------------------|
| CPU | 公司里的员工 | 执行指令，做计算和判断 | RISC-V 核，240MHz |
| Flash（闪存） | 档案柜 | 永久存放程序代码，断电不丢 | ~4MB，存你的固件 |
| SRAM（静态内存） | 工作台 | 临时存放运行中的数据，断电清零 | ~1MB，存变量和栈 |
| 总线（Bus） | 走廊 | 连接所有部件，数据在走廊上跑 | AHB/APB 总线 |
| 外设控制器 | 对外窗口 | 和外面的芯片/传感器通信 | UART/I2C/I2S/GPIO/PDM |
| 中断控制器 | 门铃系统 | 外设有事就按门铃通知 CPU | NVIC/PLIC |
| 时钟树 | 节拍器 | 给每个部件提供工作节奏 | 32MHz 晶振 → PLL 倍频 |

**关键理解**：CPU 是唯一的员工。它从 Flash（档案柜）取指令，在 SRAM（工作台）上处理数据，通过外设（窗口）和外界交互。工作台很小（~1MB），所以你不能像在 PC 上那样随便 malloc 大块内存。

**边界：**
- MCU 不等于 SoC——MCU 偏控制，资源少，跑 RTOS/裸机；SoC 偏计算，资源多，能跑 Linux
- 哈佛架构 vs 冯诺依曼架构：WQ7036AX 的三核都是哈佛架构，指令和数据走不同总线
- 不是所有芯片上电后都从地址 0 启动——有些芯片有 Boot ROM 先从内部 ROM 启动

### 场景演练：GPIO 点亮 LED

1. 芯片上电，启动代码运行，初始化硬件
2. 进入 main()，执行 `gpio_set_mode(LED_PIN, GPIO_MODE_OUTPUT)`
3. CPU 通过总线向 GPIO 控制器的模式寄存器写入配置值
4. 执行 `gpio_set_level(LED_PIN, 1)`
5. CPU 向 GPIO 控制器的输出寄存器写入 1
6. GPIO 控制器检测到输出寄存器变化，驱动引脚输出高电平
7. LED 亮

## 第二层：原理/时序/约束

### 上电到 main() 的完整流程

```
按下电源键
    │
    ▼
硬件复位：所有寄存器回到默认值
    │
    ▼
CPU 从 Flash 地址 0 读第一条指令（启动代码 startup.S）
    │
    ├── ① 初始化栈指针（SP）── 没有栈，C 函数无法调用
    ├── ② 把 .data 段从 Flash 拷到 SRAM（已初始化的全局变量）
    ├── ③ 把 .bss 段清零（未初始化的全局变量）
    ├── ④ 配置中断向量表（告诉 CPU 中断来了往哪跳）
    │
    ▼
system_init()：初始化时钟、电源、引脚
    │
    ▼
main()：终于到你的代码了！
```

### 内存映射

WQ7036AX 把 Flash、SRAM、外设寄存器全部放在同一个地址空间：

```
0x00000000 ┌────────────┐
           │   Flash    │  存代码（取指令）
0x00400000 ├────────────┤
           │   ...      │
0x20000000 ├────────────┤
           │   SRAM     │  存变量、栈、堆
0x20100000 ├────────────┤
           │   ...      │
0x40000000 ├────────────┤
           │   UART     │  串口控制器寄存器
0x40010000 ├────────────┤
           │   I2C      │  I2C 控制器寄存器
0x40020000 ├────────────┤
           │   GPIO     │  GPIO 控制器寄存器
           └────────────┘
```

### 寄存器操作

```c
// 这不是"普通的内存读写"，而是"摸到了 GPIO 控制器的开关面板"
volatile uint32_t *gpio_out = (uint32_t *)0x40000000;
*gpio_out = 0x01;  // 合上第 0 号开关 → LED 亮
```

`volatile` 的作用：告诉编译器"每次都要真的去拨开关，不许偷懒用缓存值"。

## 第三层：真实 SDK 代码

### 启动代码

WQ7036AX 的启动代码在 `/home/ys/wq7036a/wq-audio/wqcore/components/startup/` 下，每个 core 有独立的目录：

```asm
# startup.S 核心片段（简化）
.section .text.init
.global _start
_start:
    la   sp, _stack_top      # ① 初始化栈指针
    la   a0, _data_lma       # ② 拷贝 .data 段
    la   a1, _sdata
    la   a2, _edata
    call __data_copy         # 调用数据拷贝函数
    la   a0, _sbss           # ③ 清零 .bss 段
    la   a1, _ebss
    call __bss_clear
    call main                # ④ 进入 C 语言世界
```

### 寄存器定义

芯片寄存器定义在 `/home/ys/wq7036a/wq-audio/wqcore/chipset/bbb/regs/` 下，例如 GPIO 寄存器：

```c
// /home/ys/wq7036a/wq-audio/wqcore/chipset/bbb/regs/gpio_reg.h
#define GPIO_BASE           0x40020000
#define GPIO_OUT_REG        (GPIO_BASE + 0x00)
#define GPIO_IN_REG         (GPIO_BASE + 0x04)
#define GPIO_DIR_REG        (GPIO_BASE + 0x08)
```

### 外设初始化模式

SDK 中外设初始化的统一模式，参考 `/home/ys/wq7036a/wq-audio/wqcore/components/startup/bbb/acore/main.c`：

```c
// 1. 使能时钟
apb_clk_enable(CLK_UART1);

// 2. 配置引脚复用
gpio_set_mux(GPIO50, GPIO_MUX_UART1_TX);
gpio_set_mux(GPIO51, GPIO_MUX_UART1_RX);

// 3. 配置外设参数
uart_config_t cfg = {
    .baud_rate = 115200,
    .data_bits = 8,
    .stop_bits = 1,
    .parity    = UART_PARITY_NONE,
};
uart_init(UART_PORT_1, &cfg);

// 4. 注册中断回调
uart_register_rx_callback(UART_PORT_1, my_rx_handler);
```

## 第四层：正常/异常路径

### 正常路径

上电复位 → 启动代码（栈初始化、搬段、清 BSS、中断向量表）→ system_init（时钟/PLL/外设初始化）→ main() → 应用逻辑

### 异常路径

| 异常场景 | 现象 | 原因 | 处理方式 |
|---------|------|------|---------|
| 全局变量初值不对 | 变量值不是代码中赋的值 | .data 段拷贝失败 | 检查启动代码搬移逻辑 |
| 程序一启动就崩溃 | 卡在 HardFault_Handler | 栈指针未初始化或中断向量表错误 | 检查 _start 中的 SP 初始化 |
| 外设不工作 | 寄存器写进去读出来不对 | 时钟未使能 | 检查 `apb_clk_enable` 是否调用 |
| 总线错误 | 访问非法地址触发 HardFault | 地址越界或未映射 | 检查内存映射表 |
| 引脚无输出 | GPIO 电平写不进去 | 引脚复用未配置 | 检查 `gpio_set_mux` |

## 第五层：调试方法

### 启动代码调试

```bash
# 反汇编启动代码，确认 _start 入口地址
riscv64-unknown-elf-objdump -d build/acore/app_acore.elf | head -100

# 查看链接脚本，确认各段地址
cat build/acore/*.map | grep -E "\.text|\.data|\.bss|_stack"

# 用 GDB 单步调试启动代码
riscv64-unknown-elf-gdb build/acore/app_acore.elf
(gdb) target remote :3333
(gdb) monitor reset halt
(gdb) stepi  # 单步执行汇编指令
```

### 外设寄存器调试

```c
// 打印寄存器值
#define DUMP_REG(name) printf("%s (0x%08lx) = 0x%08lx\n", \
                              #name, (uint32_t)&name, (uint32_t)name)

// 检查时钟使能状态
void check_clk_status(void) {
    printf("CLK_UART1: %s\n", apb_clk_is_enabled(CLK_UART1) ? "ON" : "OFF");
    printf("CLK_I2C1: %s\n", apb_clk_is_enabled(CLK_I2C1) ? "ON" : "OFF");
}
```

## 第六层：实战练习

### 练习 1：LED 点亮实验（基础）

在 WQ7036AX 开发板上点亮一个 LED：
1. 找到 LED 对应的 GPIO 引脚号
2. 配置 GPIO 为输出模式
3. 设置 GPIO 输出高电平
4. 验证 LED 点亮
5. 实现 LED 闪烁（500ms 交替）

### 练习 2：分析启动代码（进阶）

阅读 `/home/ys/wq7036a/wq-audio/wqcore/components/startup/` 下的启动代码，回答：
1. 启动代码中如何初始化栈指针 SP？
2. .data 段从 Flash 拷贝到 SRAM 的地址范围是什么？
3. .bss 段清零的循环体内做了什么？
4. 中断向量表如何配置？

### 练习 3：内存映射分析（深入）

查看编译生成的 `.map` 文件和链接脚本（`.ld`）：
1. 找到 .text 段的起始地址和大小
2. 找到 .data 段的加载地址（LMA）和运行地址（VMA）
3. 找到栈顶地址（_stack_top）
4. 计算栈的大小
5. 验证所有段的总和不超过 SRAM 容量

## 自测与验收

1. 芯片上电后为什么不能直接跳到 main()？中间需要做什么？
2. volatile 关键字在外设寄存器操作中的作用是什么？
3. 哈佛架构和冯诺依曼架构的区别是什么？WQ7036AX 用的是哪种？
4. FLASH 和 SRAM 的区别有哪些？（至少 3 点）
5. 什么是 MMIO？为什么指针可以操控硬件？
6. WQ7036AX 的 ACORE、BCORE、DCORE 分别是什么架构？各自负责什么？
7. 什么是时钟树？为什么芯片需要多个不同的时钟频率？

## 延伸阅读

- [[c-core-C语言核心]] — 指针操作寄存器的具体技巧
- [[compile-link-startup-编译链接与启动流程]] — 上电到 main() 的完整链路
- [[ipc-multicore-多核通信与IPC]] — 三核之间如何协作
- [[wq7036ax-chip-WQ7036AX芯片]] — WQ7036AX 的具体引脚和电源域

## #flashcard

**Q: MCU 上电后第一件事做什么？**
A: 从 Flash 地址 0 读取第一条指令（启动代码 startup.S），初始化栈指针。

**Q: volatile 关键字的作用？**
A: 告诉编译器每次访问变量时都必须从内存读取，不能使用寄存器中的缓存值。

**Q: 哈佛架构和冯诺依曼架构的区别？**
A: 哈佛架构指令和数据走独立总线，可同时访问；冯诺依曼架构共用总线，不能同时访问。

**Q: WQ7036AX 的三个核是什么？**
A: ACORE（RISC-V，应用逻辑）、BCORE（RISC-V，蓝牙协议栈）、DCORE（Xtensa HiFi5，音频 DSP）。

**Q: 为什么降电压比降频率更省电？**
A: 动态功耗 P = C x V^2 x f，电压是平方关系，降低电压的效果更显著。