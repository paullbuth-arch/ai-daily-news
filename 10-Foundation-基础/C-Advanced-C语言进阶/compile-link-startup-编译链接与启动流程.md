---
type: concept
tags: [编译, 链接, 启动, 嵌入式, GCC, 链接脚本, 内存布局]
aliases: [编译链接启动, 编译流程, 启动流程]
---

# 编译链接与启动流程

## 一句话结论

你写的 C 代码要变成芯片上跑的固件，需要两步：编译链接（C 到机器码的翻译）和启动（芯片上电后把机器码跑起来）。编译链接是翻译过程，启动是"把舞台搭好，让 C 代码能在上面表演"。

## 30 秒先看懂

编译链接分四步：预处理（头文件展开和宏替换）、编译（C 到汇编）、汇编（汇编到机器码 .o 文件）、链接（把所有 .o 拼成可执行文件，分配地址）。芯片上电后，启动代码（汇编编写）执行：设置栈指针、拷贝 .data 段从 Flash 到 RAM、清零 .bss 段、最后调用 main()。链接脚本告诉链接器 Flash 和 RAM 的地址范围，以及每个段放在哪里。.map 文件是编译后的内存账单，用来确认 Flash 和 RAM 的使用量。

## 学完以后应该能做什么

**第一遍：**
- 能够区分编译错误和链接错误，快速定位问题来源
- 能够看懂 .map 文件，确认 Flash 和 RAM 占用是否超标
- 能够解释启动代码为什么必须用汇编写
- 能够使用 `riscv64-unknown-elf-size` 查看各段大小
- 能够理解链接脚本中 FLASH 和 RAM 区域的定义

**进阶：**
- 能够阅读和修改链接脚本，自定义段的位置
- 能够使用 `objdump -d` 反汇编分析代码
- 能够理解 `__attribute__((section()))` 自定义段属性
- 能够分析启动代码中异常向量表、栈指针初始化等关键细节

## 前置知识

- 了解 C 语言的基本结构（变量、函数、头文件），参见 [[c-fundamentals-C语言夯实基础]]
- 了解 MCU 的基本概念：Flash（断电不丢）、RAM（断电清零）
- 了解二进制和十六进制

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 预处理 | Preprocessing | 编译前将 `#include` 头文件展开、`#define` 宏替换的文本处理阶段 |
| 编译 | Compilation | 将 C 语言翻译成汇编语言的阶段 |
| 汇编 | Assembly | 将汇编语言翻译成机器指令（.o 文件）的阶段 |
| 链接 | Linking | 将多个 .o 文件合并成一个可执行文件，解析符号引用，分配最终地址 |
| 目标文件 | Object File | 编译/汇编阶段产生的 .o 文件，包含机器码但地址尚未确定 |
| 可执行文件 | ELF | Executable and Linkable Format，包含完整代码和地址信息的可执行文件 |
| 链接脚本 | Linker Script | 定义 Flash/RAM 地址范围和段布局的配置文件（.lds/.ld） |
| 段 | Section | 按用途划分的代码/数据区域，如 text、data、bss |
| 符号 | Symbol | 函数名、变量名等在链接时的标识符 |
| 交叉编译 | Cross Compilation | 在一种架构（如 x86）上编译出另一种架构（如 RISC-V）可执行代码 |
| 启动代码 | Startup Code | 芯片上电后最先执行的汇编代码，初始化 C 运行环境 |
| 栈指针 | Stack Pointer | 指向当前栈顶的 CPU 寄存器，SP/RSP |
| 入口点 | Entry Point | 程序开始执行的第一条指令的地址，通常为 `_start` |
| 烧录 | Flashing | 将编译好的 .bin 文件写入芯片 Flash 的过程 |

## 第一层：费曼心智模型

### 快递包裹的全过程类比

把你写代码到芯片运行，想象成寄快递：

| 你做的事情 | 对应步骤 | 实际发生了什么 |
|-----------|---------|---------------|
| 你写 C 代码 | 源文件 | `main.c`、`uart.c` 等 |
| 快递员打包 | 编译 | 每个 `.c` 文件独立翻译成 `.o`（机器码） |
| 快递员贴快递单 | 链接 | 把所有 `.o` 拼成一个完整程序，给每个函数/变量分配地址 |
| 包裹送到目的地 | 烧录 | 把最终的 `.bin` 文件写入芯片的 Flash |
| 收件人拆包裹 | 启动 | 芯片上电，把 Flash 里的代码搬到 RAM 里跑起来 |

**关键理解**：你做了 1 和 5（写代码 + 看结果），编译器帮你做了 2-4。理解 2-4 是为了出问题时知道在哪一步出错了。

### 编译链接的完整流程

```
main.c ─┐                                ┌─→ main.o ─┐
uart.c ─┤─ ①预处理 → ②编译 → ③汇编 ─→ ├─→ uart.o ─┤─ ④链接 → app.elf
app.h  ─┘                                └─→ ...     ─┘
                                                        │
                                                    ⑤ 烧录到 Flash
                                                        │
                                                    ⑥ 上电启动
```

| 步骤 | 输入 | 输出 | 一句话 |
|------|------|------|--------|
| ① 预处理 | `.c` + `.h` | `.i` | 把头文件和宏展开，变成一份纯 C 代码 |
| ② 编译 | `.i`（纯 C） | `.s`（汇编） | 把 C 翻译成汇编语言 |
| ③ 汇编 | `.s`（汇编） | `.o`（机器码） | 把汇编翻译成 CPU 认识的二进制指令 |
| ④ 链接 | 多个 `.o` | `.elf`（可执行文件） | 把所有 .o 拼起来，给每个函数分配最终地址 |

### 链接做了什么？——最重要的一步

**编译把每个 `.c` 变成独立的 `.o`，但它们之间互相调用的函数还不知道彼此的地址。链接就是把它们拼在一起，告诉每个函数"你调用的那个函数在地址 0x00001234"。**

```c
// main.c 中调用了 uart_init()，但 uart_init 在 uart.c 中
// 编译 main.c 时，编译器不知道 uart_init 在哪
// 它只在 main.o 里留了一个"占位符"：这里需要填入 uart_init 的地址

// 链接时，链接器看到了 main.o 和 uart.o：
//   main.o 里有个占位符"需要 uart_init 的地址"
//   uart.o 里有个函数 uart_init，地址是 0x00001234
// → 链接器把占位符填成 0x00001234
```

### 芯片上电后的启动流程

```
按下电源键
    │
    ▼
CPU 从 Flash 地址 0 读第一条指令（这是硬件固化的行为）
    │
    ▼
启动代码（startup.S）执行：
  ① 设置栈指针 SP           ← 没有栈，C 函数无法调用（局部变量没地方放）
  ② 把 .data 从 Flash 拷到 RAM ← 全局变量需要初值
  ③ 把 .bss 清零              ← C 标准规定未初始化全局变量必须是 0
  ④ 调用 main()               ← 终于进入你的代码！
```

**场景推演**：你按下蓝牙耳机的电源键。芯片上电瞬间，CPU 的 PC 指针被硬件强制设为 Flash 的起始地址 0x00000000。那里存放的是启动代码的第一条指令。启动代码先设置栈指针，让 C 语言的函数调用成为可能；然后从 Flash 中拷贝 .data 段到 RAM 中（你的全局变量因此有了初值）；清零 .bss 段（未初始化的全局变量变成 0）；最后调用 main()，你的应用程序开始运行。

## 第二层：原理/时序/约束

### 程序的段布局

链接完成后，程序被分成几个段，每个段放在 Flash 或 RAM 的不同位置：

```
Flash（断电不丢）                    RAM（断电清零）
┌──────────────┐                   ┌──────────────┐
│  .text       │  ← 你的代码        │  .data       │  ← 有初值的全局变量
│  (机器指令)   │                   │  (从 Flash 搬来)│
├──────────────┤                   ├──────────────┤
│  .rodata     │  ← 常量字符串      │  .bss        │  ← 无初值的全局变量
│  ("hello")   │                   │  (启动时清零)  │
├──────────────┤                   ├──────────────┤
│  .data 的    │  ← 全局变量的初值   │  heap        │  ← malloc 从这分
│  初始值副本   │     存放在 Flash   │  ↓           │
└──────────────┘                   │  ↑           │
                                   │  stack       │  ← 局部变量在这
                                   └──────────────┘
```

**为什么 .data 要存两份？** 全局变量必须在 RAM 里才能读写（Flash 只能读不能随便写），但 RAM 断电就丢。所以初值存在 Flash 里，启动时拷贝到 RAM。

### 链接脚本的核心结构

链接脚本定义 Flash 和 RAM 的起始地址和大小，以及每个段放在哪里。这是 WQ7036AX ACORE 的链接脚本简化版：

```ld
// 来自 /home/ys/wq7036a/wq-audio/wq-adk/examples/tws/build/7036A/tws-pro/acore/link.lds
OUTPUT_ARCH( "riscv" )
ENTRY( _start )

MEMORY
{
    flash : ORIGIN = (0x04000000 + 0x240000 + 0x20), LENGTH = (0xC8000 - 0x20)
    ram   : ORIGIN = (0x02000000), LENGTH = 0x80000
}

SECTIONS
{
    .init :
    {
        KEEP (*(SORT_NONE(.init)))
        . = ALIGN(4);
    } >flash

    .text :
    {
        *(.text .text.*)
        *(.icache_text .icache_text.*)
    } >flash

    .rodata :
    {
        *(.rodata .rodata.*)
    } >flash

    .data :
    {
        *(.data .data.*)
    } >ram AT>flash      // 运行在 RAM，但初值存在 Flash

    .bss :
    {
        *(.bss .bss.*)
    } >ram
}
```

**关键语法**：
- `>flash` 表示该段运行在 Flash 中（直接从 Flash 取指令）
- `>ram AT>flash` 表示该段运行在 RAM 中，但初值存在 Flash 中，启动时拷贝
- `KEEP` 告诉链接器即使这个段没有被引用也要保留（如初始化段）

### 编译选项详解

| 选项 | 作用 | 什么时候用 |
|------|------|-----------|
| `-O0` | 不优化 | 调试时使用，代码行为与源码完全对应 |
| `-Os` | 优化体积 | 发布版本，嵌入式首选 |
| `-O2` | 优化速度 | 需要高性能时 |
| `-g` | 生成调试信息 | 调试时使用，会增大文件 |
| `-Wall -Wextra` | 开启所有警告 | 始终加上 |
| `-ffunction-sections` | 每个函数独立段 | 配合 `--gc-sections` 删除未用代码 |
| `-march=rv32imac` | 指定 RISC-V 指令集 | WQ7036AX 的 ACORE/BCORE |
| `-Wl,-Map,output.map` | 生成 .map 文件 | 需要查看内存占用时 |

## 第三层：真实 SDK 代码

### WQ7036AX 的启动代码（start.S）

以下是 WQ7036AX ACORE 的真实启动代码，位于 `/home/ys/wq7036a/wq-audio/wqcore/chipset/bbb/riscv/start.S`：

```asm
// 芯片上电后第一条指令从这里开始
.section .init
.globl _start
.type _start,@function

_start:
    /* ① 关中断——在初始化完成前不允许中断 */
    li t0, MSTATUS_MIE
    csrc mstatus, t0
    li t0, MIP_MTIP
    csrc mie, t0
    li t0, MIP_MEIP
    csrc mie, t0

    /* ② 设置全局指针（GP）寄存器 */
.option push
.option norelax
    la gp, __global_pointer$
.option pop

    /* ③ 设置栈指针——没有栈就不能调用 C 函数 */
    .weak __stack_top
    la sp, __stack_top

    /* ④ 调用 C 语言初始化函数 */
    call software_init

    /* ⑤ 启用浮点单元（如果硬件支持） */
#ifndef __riscv_float_abi_soft
    li t0, MSTATUS_FS
    csrs mstatus, t0
#endif

    /* ⑥ 设置参数并跳转到 main() */
    li a0, 0                    /* argc = 0 */
    la t0, __stack_size
    la a1, __stack_top
    sub a1, a1, t0              /* argv 指向栈顶下方 */
    call main

    /* ⑦ main 不应返回，如果返回则死循环 */
1:  j 1b
```

**关键细节**：
- `__stack_top` 和 `__stack_size` 在链接脚本中定义，链接器生成最终地址
- 启动代码必须用汇编，因为此时栈指针还未设置，无法调用 C 函数
- `software_init()` 是 C 函数，但此时栈已就绪，可以安全调用
- `.weak` 表示 `__stack_top` 可以被子链接脚本覆盖

### 链接脚本中的段分配

WQ7036AX 的链接脚本中，部分关键代码被放在 IRAM（内部 RAM）中以达到最快的执行速度，例如中断处理函数和低功耗管理代码：

```ld
// 来自 ACORE 链接脚本
.iram_text :
{
    *libpower_mgnt.a:dev_pm.o(.text .text.*)
    *libfreertos.a:*.o(.text.os_sys_restore)
    *lib*driver.a:flash_special.o(.text.flash_gd_set_quad_mode)
    *lib*driver.a:sfc.o(.text.sfc_init .text.sfc_set_io_map)
    // ... 更多需要快速执行或不能在 Flash 中运行的代码
    . = ALIGN(4);
} >ram AT>flash  // 运行在 RAM，初值从 Flash 拷贝
```

这意味着某些函数（如 Flash 控制器驱动、低功耗切换代码）不能放在 Flash 中执行（因为操作 Flash 控制器时 Flash 本身不可访问），必须放在 RAM 中运行。启动代码会将这些函数从 Flash 拷贝到 RAM。

### 使用 size 命令查看实际占用

```bash
# 在 WQ7036AX 项目中编译后查看
riscv64-unknown-elf-size build/acore/glass_acore.elf
#    text    data     bss     dec     hex
#   52340     256    2048   54644    d574

# 查看某个函数的大小
riscv64-unknown-elf-nm --size-sort build/acore/glass_acore.elf | tail -10

# 反汇编查看某个函数
riscv64-unknown-elf-objdump -d build/acore/glass_acore.elf | grep -A 50 "<main>:"
```

## 第四层：正常/异常路径

### 编译阶段

| 场景 | 正常路径 | 异常路径 |
|------|---------|---------|
| 预处理 | 头文件正确展开，宏正确替换 | 头文件找不到（`No such file or directory`）|
| 编译 | C 语法正确，生成汇编代码 | 语法错误（`syntax error`）、类型不匹配、未定义变量 |
| 汇编 | 汇编代码正确，生成 .o | 汇编指令错误（极少见，编译器生成的通常正确） |

### 链接阶段

| 场景 | 正常路径 | 异常路径 |
|------|---------|---------|
| 符号解析 | 所有符号都在某个 .o 或库中找到 | `undefined reference to 'xxx'`——调用了函数但没找到实现 |
| 地址分配 | 各段在 Flash/RAM 范围内分配 | 段溢出：Flash 或 RAM 空间不够，链接器报错或地址重叠 |
| 多段定义 | 每个符号只定义一次 | `multiple definition of 'xxx'`——同一个函数在多个 .c 中定义 |

### 启动阶段

| 场景 | 正常路径 | 异常路径 |
|------|---------|---------|
| 栈指针设置 | 指向 RAM 顶部，栈向下增长 | 栈指针未设置或指向非法地址，调用第一个 C 函数就崩溃 |
| .data 拷贝 | 从 Flash 正确拷贝到 RAM | 拷贝长度错误（少拷或多拷），全局变量初值错误 |
| .bss 清零 | 从起始地址到结束地址全部清零 | 清零范围错误，部分全局变量未初始化或踩了.data 区域 |
| 跳转 main | 正确跳转到 main 函数入口 | 跳转地址错误，执行了非法指令 |

### 常见错误速查

| 错误信息 | 阶段 | 含义 | 解决方法 |
|---------|------|------|---------|
| `file not found` | 预处理 | 头文件找不到 | 检查 `#include` 路径和文件名 |
| `undefined reference` | 链接 | 符号没找到实现 | 检查是否链接了对应的 .c 或库 |
| `multiple definition` | 链接 | 符号重复定义 | 检查 .h 中是否定义了变量（应该在 .c 中定义）|
| `relocation truncated` | 链接 | 地址超出范围 | 可能是 Flash/RAM 溢出或跳转距离太远 |
| `section .text exceeds` | 链接 | Flash 空间不够 | 优化代码体积或增大 Flash 分区 |
| HardFault 在启动时 | 运行 | 栈指针或中断向量表问题 | 检查启动代码和链接脚本 |

## 第五层：调试方法

### 1. 查看 .map 文件

编译后第一件事是看 .map 文件，确认 Flash 和 RAM 没超：

```bash
# 在 .map 文件中搜索关键信息
cat build/acore/glass_acore.map | grep -E "\.text|\.data|\.bss" | head -20

# 查看具体变量的地址
cat build/acore/glass_acore.map | grep "my_global_var"

# 查看某个函数是否被链接
cat build/acore/glass_acore.map | grep "uart_init"
```

### 2. 使用 objdump 反汇编

```bash
# 反汇编查看启动代码
riscv64-unknown-elf-objdump -d build/acore/glass_acore.elf | head -100

# 查看特定函数的反汇编
riscv64-unknown-elf-objdump -d build/acore/glass_acore.elf | grep -A 30 "<_start>:"

# 查看各段信息
riscv64-unknown-elf-objdump -h build/acore/glass_acore.elf
```

### 3. 使用 addr2line 定位故障地址

当发生 HardFault 时，异常寄存器 `mepc` 记录着出错时的指令地址：

```bash
# 将地址转换为源码行号
riscv64-unknown-elf-addr2line -e build/acore/glass_acore.elf 0x00001234
# 输出：/path/to/source.c:42
```

### 4. 链接阶段调试技巧

```bash
# 查看链接器详细过程（-v 或 --verbose 选项）
riscv64-unknown-elf-ld --verbose

# 查看所有符号及其地址
riscv64-unknown-elf-nm build/acore/glass_acore.elf | sort

# 只查看未定义符号（需要外部提供的符号）
riscv64-unknown-elf-nm --undefined-only build/acore/glass_acore.elf
```

### 5. 预处理阶段调试

```bash
# 查看预处理后的文件（确认宏展开是否正确）
gcc -E main.c -o main.i
# 或者用 C 编译器
riscv64-unknown-elf-gcc -E main.c -o main.i
```

## 第六层：实战练习

### 练习 1：手动编译链接一个多文件项目

创建三个文件：`main.c`、`uart.c`、`uart.h`，用命令行手动执行预处理、编译、汇编、链接各步骤：

```bash
# 1. 预处理
gcc -E main.c -o main.i
gcc -E uart.c -o uart.i

# 2. 编译（C → 汇编）
gcc -S main.i -o main.s
gcc -S uart.i -o uart.s

# 3. 汇编（汇编 → .o）
gcc -c main.s -o main.o
gcc -c uart.s -o uart.o

# 4. 链接
gcc main.o uart.o -o app.elf

# 5. 查看各段大小
gcc -Wl,-Map=app.map main.o uart.o -o app.elf
size app.elf
```

记录每个步骤的输入输出，并在每步后查看文件内容的变化。

### 练习 2：阅读 WQ7036AX 的链接脚本

阅读 `/home/ys/wq7036a/wq-audio/wq-adk/examples/tws/build/7036A/tws-pro/acore/link.lds`，回答以下问题：

1. Flash 的起始地址和大小是多少？RAM 的起始地址和大小是多少？
2. `.iram_text` 段为什么放在 RAM 中执行？哪些代码被放在这个段中？
3. `_iram_text_load_addr`、`_iram_text_start`、`_iram_text_end` 这三个符号是做什么用的？启动代码如何利用它们？
4. `.data` 段的运行地址和加载地址分别是什么？`>ram AT>flash` 语法是什么意思？

### 练习 3：分析 HardFault 地址

假设你的 WQ7036AX 项目运行时发生了 HardFault，异常寄存器 `mepc = 0x00001A3C`，`mtval = 0x00000000`。使用以下命令分析问题：

```bash
# 1. 将 mepc 地址转换为源码行号
riscv64-unknown-elf-addr2line -e build/acore/glass_acore.elf 0x00001A3C

# 2. 查看该地址附近的指令
riscv64-unknown-elf-objdump -d build/acore/glass_acore.elf | grep -A 10 "1a3c:"

# 3. 查看该地址属于哪个函数
riscv64-unknown-elf-nm build/acore/glass_acore.elf | sort | grep -B 1 "00001a3c"
```

请写出：你判断这是哪种类型的异常（非法指令？访存异常？），以及接下来如何定位具体代码行。

### 练习 4：自定义段

写一个程序，将某个变量放在自定义段 `.my_section` 中，并验证该变量是否出现在链接脚本指定的区域：

```c
// 使用 __attribute__((section(".my_section"))) 将变量放入自定义段
__attribute__((section(".my_section"))) int my_var = 0xDEADBEEF;

// 编译后，使用 objdump 或 nm 查看该变量地址
// 修改链接脚本，将 .my_section 放在特定地址
```

## 自测与验收

1. 编译链接分为哪四步？每步的输入和输出是什么？

2. 链接错误 `undefined reference to 'uart_init'` 是什么意思？可能的原因有哪些？

3. 芯片上电后，启动代码做了哪四件事？为什么这些事情必须用汇编做？

4. 什么是 .data 段的"运行地址"和"加载地址"？为什么需要两个地址？

5. `.map` 文件是做什么用的？如何查看某段代码占用了多少 Flash 空间？

6. `.bss` 段为什么不占用 Flash 空间？启动代码如何初始化 .bss 段？

7. 交叉编译和本地编译有什么区别？WQ7036AX 项目使用的是什么交叉编译器？

8. 链接脚本中的 `MEMORY` 块和 `SECTIONS` 块分别起什么作用？

## 延伸阅读

- [[c-core-C语言核心]] — 指针、volatile、内存布局
- [[computer-arch-mcu-计算机组成与MCU架构]] — Flash/RAM/总线的硬件基础
- [[build-system-构建系统]] — Makefile/SCons 怎么调这些编译选项
- [[boot-ota-启动流程与OTA升级]] — Bootloader 与 OTA 的完整链路
- [[c-fundamentals-C语言夯实基础]] — C 语言基础语法

#flashcard

编译链接与启动流程 / 编译链接四步是什么？
预处理（头文件展开、宏替换）→ 编译（C 到汇编）→ 汇编（汇编到 .o）→ 链接（合并 .o，分配地址）。

编译链接与启动流程 / 启动代码做了哪四件事？
设置栈指针 SP → 拷贝 .data 从 Flash 到 RAM → 清零 .bss → 调用 main()。

编译链接与启动流程 / 为什么启动代码必须用汇编？
因为 C 函数调用需要栈，而栈指针在启动代码的第一步才设置好。C 也无法直接操作 CPU 寄存器如 mtvec、mstatus。

编译链接与启动流程 / .bss 段为什么不占 Flash 空间？
因为 .bss 中所有变量都是 0，只需知道起始地址和长度，启动时统一清零，不需要存储初值。

编译链接与启动流程 / 交叉编译是什么意思？
在一种架构（如 x86 PC）上编译出另一种架构（如 RISC-V MCU）可执行代码的过程。编译器运行在 x86 上，但生成的目标代码是 RISC-V 指令。