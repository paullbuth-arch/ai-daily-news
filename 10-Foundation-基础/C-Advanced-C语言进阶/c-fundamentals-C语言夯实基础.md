---
type: concept
tags: [C语言, 嵌入式, 基础语法, 指针, 数据类型, 预处理器]
aliases: [C基础, C语言入门, C夯实基础]
---

# C 语言夯实基础（从零到嵌入式）

## 一句话结论

C 语言只有 32 个关键字，核心就三件事——数据怎么存（变量、类型、内存）、逻辑怎么走（判断、循环、函数）、内存怎么管（指针、数组、结构体）。掌握这三件事，你就掌握了 C 语言的 80%。

## 30 秒先看懂

C 语言是嵌入式开发的必修语言，原因在于它离硬件最近、没有运行时开销、编译出来的代码极小。你需要掌握三个核心维度：数据存储（变量类型决定大小和范围，固定宽度类型是嵌入式的铁律）、逻辑控制（if/for/while 组织流程，函数封装可复用逻辑）、内存管理（指针是所有高级操作的基石，数组和结构体是组织数据的两种基本方式）。预处理、类型转换、volatile 和位运算构成嵌入式特有的 C 语言技能。

## 学完以后应该能做什么

**第一遍：**
- 能够用 `stdint.h` 的固定宽度类型定义变量，避免平台相关的大小问题
- 能够写出正确的 if/for/while 逻辑，区分传值和传指针
- 能够定义结构体打包多个相关数据，区分普通对齐和 packed 对齐
- 能够使用指针访问数组元素和函数参数
- 能够理解并正确使用 `#define` 宏定义

**进阶：**
- 能够用函数指针实现回调机制，编写驱动层与应用层的解耦代码
- 能够使用 `volatile` 正确处理中断共享变量和硬件寄存器
- 能够用位运算操控寄存器的特定位，完成外设配置
- 能够分析编译错误和链接错误，快速定位问题根源

## 前置知识

- 熟悉基本的计算机操作（文件、目录、命令行）
- 了解二进制、十进制、十六进制的基本概念
- 不需要任何编程经验，本笔记从零开始

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 变量 | Variable | 内存中一个有名字的存储单元，存放可修改的数据 |
| 类型 | Type | 决定变量占用内存的大小和解释方式 |
| 函数 | Function | 可复用的代码块，接收输入参数，产生输出结果 |
| 指针 | Pointer | 值为内存地址的变量，用于间接访问数据 |
| 数组 | Array | 连续存放的相同类型元素的集合 |
| 结构体 | Struct | 将不同类型数据打包成一个复合类型的机制 |
| 联合体 | Union | 同一块内存区域按不同数据类型解释的机制 |
| 枚举 | Enum | 为整数常量赋予有意义的名称 |
| 预处理器 | Preprocessor | 编译前对源代码进行文本处理的阶段 |
| 宏 | Macro | 用 `#define` 定义的文本替换规则 |
| 作用域 | Scope | 变量在程序中可被访问的范围 |
| 生命周期 | Lifetime | 变量从创建到销毁所经历的时间段 |
| 条件编译 | Conditional Compilation | 根据宏定义决定哪些代码参与编译的机制 |
| 类型转换 | Type Casting | 将一种数据类型转换为另一种数据类型 |
| 符号扩展 | Sign Extension | 有符号整数从窄类型向宽类型转换时高位补符号位的行为 |

## 第一层：费曼心智模型

### 变量与内存的类比：储物柜

变量就像储物柜。每个柜子有编号（地址）、有大小（类型决定）、里面放东西（值）。

```c
int   age = 25;       // 一个叫 age 的柜子，大小 4 字节，里面放了 25
char  grade = 'A';    // 一个叫 grade 的柜子，大小 1 字节，里面放了 'A'
float temp = 36.5;    // 一个叫 temp 的柜子，大小 4 字节，里面放了 36.5
```

**这个类比的边界**：不同柜子大小不同（由类型决定），但相邻柜子之间不一定有间隙（结构体可能有 padding）。柜子编号（地址）是固定的，但里面的内容可以随意修改。有些柜子在你离开后会自动清空（局部变量），有些则一直存在（全局变量）。

### 指针的类比：门牌号

变量 = 房间里的人，指针 = 门牌号。

```c
int  a = 42;        // 一个叫 a 的房间，里面住着 42
int *p = &a;        // p 存的是 a 的门牌号（地址）

printf("%d\n", a);   // 42 —— 直接看房间里的人
printf("%p\n", p);   // 0x20001000 —— 看门牌号
printf("%d\n", *p);  // 42 —— 按门牌号找到房间，看里面的人

*p = 100;            // 按门牌号找到房间，把里面的人换成 100
// 现在 a 也变成了 100，因为 p 指向 a
```

**场景推演**：你要写一个驱动函数，通过 UART 发送数据。UART 数据寄存器在地址 0x40001000。你用 `volatile uint32_t *uart_dr = (uint32_t *)0x40001000;` 获得门牌号后，每次 `*uart_dr = byte;` 就是把一个字节数据"送进"UART 的发送寄存器，硬件自动把它从 TX 引脚发出去。

### 有符号/无符号的类比：温度计 vs 里程表

- **有符号数** = 温度计：有零上（正数）和零下（负数），刻度均匀分布
- **无符号数** = 里程表：只会往前数，到最大值后绕回 0

```c
uint8_t a = 0;
a = a - 1;         // a = 255！无符号数从 0 绕回到最大值

int8_t b = 127;
b = b + 1;         // b = -128！有符号数从最大正数绕到最小负数
```

**这个类比的边界**：计算机中的溢出是"环绕"而不是"饱和"——不会停在最大值，而是回到最小值。如果你的计数值需要从 0 到 1000，但用了 `uint8_t`，到 255 时就会变成 0，你可能永远察觉不到这个 bug。

## 第二层：原理/时序/约束

### 固定宽度类型的铁律

嵌入式开发中永远用 `stdint.h` 的固定宽度类型，不要用 `int`。

```c
#include <stdint.h>

// 不要这样写（大小不确定）：
int count;           // 32 位 MCU 上是 4 字节，16 位 MCU 上是 2 字节！

// 要这样写（大小确定）：
uint8_t  flag;       // 一定是 1 字节，无符号
int16_t  small_num;  // 一定是 2 字节，有符号
uint32_t address;    // 一定是 4 字节，无符号
```

**原因**：`int` 在不同平台上大小不同（16 位 MCU 上是 2 字节，32/64 位上是 4 字节）。如果你的代码需要跨平台、或者需要精确控制协议格式，必须使用固定宽度类型。

### 传值 vs 传指针

```c
void bad_swap(int a, int b) {       // 传值：改的是副本，不影响原变量
    int tmp = a; a = b; b = tmp;    // 没用！a 和 b 是副本
}

void good_swap(int *a, int *b) {    // 传指针：通过地址改原变量
    int tmp = *a; *a = *b; *b = tmp; // 有效！
}
```

**选择原则**：
- 基本类型（int/char/float）且不需要修改原值 → 传值
- 大型结构体 → 传指针（避免拷贝开销）
- 需要修改原值 → 传指针

### 变量的存储位置与生命周期

| 变量类型 | 存在哪 | 生命周期 | 谁初始化 |
|---------|--------|---------|---------|
| 全局变量（有初值） | `.data` 段（RAM） | 程序运行全程 | 启动代码从 Flash 拷贝 |
| 全局变量（无初值） | `.bss` 段（RAM） | 程序运行全程 | 启动代码清零 |
| 局部变量 | 栈（stack） | 函数调用期间 | 不自动初始化！值不确定 |
| static 局部变量 | `.data`/`.bss` | 程序运行全程 | 同全局变量 |
| malloc 分配 | 堆（heap） | 直到 free() | 不自动初始化 |

**最常犯的错误**：局部变量不初始化就直接用。

```c
void buggy(void) {
    int count;          // 栈上的值是不确定的！
    count++;            // 结果不可预测——可能是任何值
}

void fixed(void) {
    int count = 0;      // 始终初始化
    count++;
}
```

### 宏定义的安全写法

```c
// 错误：参数不加括号
#define SQUARE(x)  x * x
SQUARE(1 + 2)  // 展开: 1 + 2 * 1 + 2 = 5（错了！）

// 正确：每个参数加括号，整体加括号
#define SQUARE(x)  ((x) * (x))

// 多语句宏必须用 do-while(0) 包裹
#define DO_STUFF()  do { foo(); bar(); } while(0)
```

## 第三层：真实 SDK 代码

### WQ7036AX 中的变量类型规范

在 WQ7036AX SDK 中，所有代码都严格使用固定宽度类型。以下来自 `/home/ys/wq7036a/wq-audio/wqcore/chipset/bbb/riscv/irq.h`：

```c
// 中断优先级枚举，使用固定宽度类型
typedef enum {
    WQ_INTR_PRI_0 = 0,
    WQ_INTR_PRI_1,
    WQ_INTR_PRI_2,
    WQ_INTR_PRI_3,
    WQ_INTR_PRI_4,
    WQ_INTR_PRI_5,
    WQ_INTR_PRI_6,
    WQ_INTR_PRI_7,
    WQ_INTR_PRI_MAX
} WQ_INTR_PRIORITY;
```

### 结构体在 IPC 通信中的应用

WQ7036AX 的核间通信使用结构体定义消息格式，位于 `/home/ys/wq7036a/wq-audio/wqcore/components/amp/ipc/ipc.h`：

```c
// IPC 邮箱结构体——通过精心安排成员顺序避免 padding
typedef struct mailbox {
    uint32_t size;  /*!< size of the mailbox */
    uint16_t w;     /*!< write index */
    uint16_t r;     /*!< read index */
    uint8_t data[]; /*!< ring data buffer */
} wq_ipc_mailbox_t;
```

### 函数指针在驱动层中的应用

WQ7036AX 的中断处理框架使用函数指针数组实现灵活的中断分发：

```c
// 来自 /home/ys/wq7036a/wq-audio/wqcore/chipset/bbb/riscv/irq.c
// 函数指针，用于注册中断处理回调
typedef void (*isr_handler_t)(void *param);

// 中断处理函数表
static isr_handler_t wq_isr_handlers[WQ_IRQ_MAX];
static void *wq_isr_params[WQ_IRQ_MAX];

// 注册中断处理函数
void wq_irq_register(uint32_t irq_num, isr_handler_t handler, void *param) {
    wq_isr_handlers[irq_num] = handler;
    wq_isr_params[irq_num] = param;
}
```

这是典型的函数指针回调模式——驱动层注册中断处理函数，框架层在中断发生时调用注册的函数，实现了解耦。

### 宏定义在寄存器操作中的应用

```c
// 来自 WQ7036AX 驱动层（典型模式）
#define REG_BASE 0x40000000
#define REG(offset) (*(volatile uint32_t *)(REG_BASE + (offset)))

#define SET_BIT(reg, bit)   ((reg) |= (1U << (bit)))
#define CLEAR_BIT(reg, bit) ((reg) &= ~(1U << (bit)))
```

## 第四层：正常/异常路径

### 变量初始化

| 场景 | 正常路径 | 异常路径 |
|------|---------|---------|
| 局部变量 | 声明时初始化 `int x = 0;` | 不初始化，值不确定，表现为随机行为 |
| 全局变量 | 有初值放 .data，无初值放 .bss | 忘记全局变量默认初始化为 0，依赖未定义行为 |
| 指针变量 | 初始化为 NULL 或合法地址 | 野指针，解引用时写随机地址导致 HardFault |

### 类型转换

| 场景 | 正常路径 | 异常路径 |
|------|---------|---------|
| 小类型赋给大类型 | 隐式转换，值不变 | 有符号扩展：`int8_t -1` 转 `uint32_t` 得到 `0xFFFFFFFF` |
| 大类型赋给小类型 | 显式转换，明确截断意图 | 隐式截断，高字节丢失，值非预期 |
| 浮点转整数 | 明确知道截断而非四舍五入 | 认为是四舍五入，结果偏差 0.5 |

### 数组操作

| 场景 | 正常路径 | 异常路径 |
|------|---------|---------|
| 数组访问 | 索引在 0 ~ size-1 范围内 | 越界访问，覆盖相邻变量或栈上返回地址 |
| 字符串 | 以 '\0' 结尾 | 没有 '\0'，`strlen` 读到越界，`printf %s` 打印乱码 |
| 数组做函数参数 | 同时传数组和长度参数 | 只传指针不传长度，函数内无法判断边界 |

## 第五层：调试方法

### 1. 编译错误快速定位

```bash
# 编译错误示例
main.c:10:5: error: 'count' undeclared
# 格式：文件名:行号:列号: 错误类型: 错误信息
# 先看行号，找到具体代码行

# 预处理后查看宏展开，确认宏定义是否正确
gcc -E main.c -o main.i
```

### 2. GDB 调试基础

```bash
# 编译时加 -g 选项
riscv64-unknown-elf-gcc -g -o app.elf main.c

# 启动 GDB
riscv64-unknown-elf-gdb app.elf

# 常用命令
(gdb) break main         # 在 main 函数设断点
(gdb) run                # 运行
(gdb) print x            # 打印变量 x 的值
(gdb) print &x           # 打印 x 的地址
(gdb) next               # 单步跳过
(gdb) step               # 单步进入
(gdb) backtrace          # 查看函数调用栈
(gdb) info locals        # 查看所有局部变量
```

### 3. 内存查看

```bash
# 查看 .map 文件确认变量地址
cat build/acore/glass_acore.map | grep "my_variable"

# 查看各段大小
riscv64-unknown-elf-size build/acore/glass_acore.elf

# 查看符号表
riscv64-unknown-elf-nm build/acore/glass_acore.elf | sort

# 反汇编
riscv64-unknown-elf-objdump -d build/acore/glass_acore.elf
```

### 4. 常见运行时问题的排查方法

- **HardFault**：查看异常寄存器（mepc、mtval），确认是访问非法地址还是执行了非法指令
- **栈溢出**：在函数入口和出口检查栈指针的值，看是否超出预期范围
- **数组越界**：在数组前后加"哨兵"变量（magic number），检查是否被修改

## 第六层：实战练习

### 练习 1：实现一个简单的环形缓冲区

```c
// 用数组和指针实现一个环形缓冲区，支持 put 和 get 操作
// 要求：
// 1. 缓冲区大小固定为 256 字节
// 2. put 向缓冲区写入一个字节，如果满了返回 false
// 3. get 从缓冲区读取一个字节，如果空了返回 false
// 4. head 和 tail 使用 volatile 修饰（因为可能被 ISR 修改）
// 5. 头尾指针各自增长，不互相修改

// 提示：typedef struct { uint8_t buf[256]; volatile uint32_t head; volatile uint32_t tail; } rbuf_t;
```

### 练习 2：阅读 WQ7036AX 的启动代码

阅读 `/home/ys/wq7036a/wq-audio/wqcore/chipset/bbb/riscv/start.S`，回答以下问题：

1. 启动代码在设置栈指针之前做了什么？为什么要先做这个？
2. `la sp, __stack_top` 中的 `__stack_top` 是在哪里定义的？提示：查看链接脚本。
3. 启动代码最后调用了 `main()`，如果 main 返回了会发生什么？

### 练习 3：宏定义陷阱修复

以下代码中有三处宏定义错误，请找出并修复：

```c
#define MUL(a, b) a * b
#define INC_AND_SUM(x, y) x++; y++; x + y
#define SAFE_FREE(p) free(p); p = NULL;

int main(void) {
    int result = MUL(2 + 3, 4);     // 期望 20，实际是多少？
    int sum = INC_AND_SUM(1, 2);    // 期望 5，实际是多少？
    if (1) SAFE_FREE(ptr) else do_something();  // 编译能通过吗？
}
```

### 练习 4：类型转换陷阱

写一个程序，验证以下场景，并记录结果：

```c
uint8_t a = 200;
uint8_t b = 100;
uint32_t c = a + b;    // c 是多少？是 300 还是 44？

int8_t d = -1;
uint32_t e = d;        // e 是多少？是 0xFFFFFFFF 还是 0x00000001？

uint32_t f = 0x12345678;
uint8_t *p = (uint8_t *)&f;
// 在小端系统上，p[0]、p[1]、p[2]、p[3] 分别是多少？
```

## 自测与验收

1. 在 32 位 MCU 上，`int` 是几字节？在 16 位 MCU 上呢？为什么嵌入式开发推荐用 `stdint.h` 的固定宽度类型？

2. 以下代码输出什么？为什么？
   ```c
   uint8_t x = 255;
   x = x + 1;
   printf("%d\n", x);
   ```

3. 传值和传指针有什么区别？什么时候用哪种？

4. 结构体 `__attribute__((packed))` 的作用是什么？什么场景下必须使用？

5. 以下宏展开后的结果是什么？有什么问题？
   ```c
   #define DOUBLE(x) x + x
   int result = 3 * DOUBLE(4);
   ```

6. 全局变量、static 局部变量、普通局部变量的生命周期分别是什么？

7. 什么是野指针？如何避免野指针？

8. 联合体（union）和结构体（struct）的根本区别是什么？

## 延伸阅读

- [[c-core-C语言核心]] — 嵌入式 C 的进阶技巧：指针操作寄存器、volatile 深入、结构体对齐、内存布局
- [[compile-link-startup-编译链接与启动流程]] — 代码怎么变成固件、芯片怎么启动
- [[data-structure-state-machine-数据结构与状态机]] — 嵌入式最常用的数据结构：环形缓冲区、链表、状态机
- [[interrupt-concurrency-中断并发同步]] — 中断和并发——嵌入式 90% 的 bug 来源
- [[computer-arch-mcu-计算机组成与MCU架构]] — Flash/RAM/总线的硬件基础

#flashcard

C 语言夯实基础 / 为什么嵌入式必须用 C？
C 离硬件最近（指针直接操作寄存器）、没有运行时开销（无 GC/虚拟机）、编译代码极小、所有芯片都有 C 编译器。

C 语言夯实基础 / 为什么用 stdint.h 的固定宽度类型？
因为 `int` 在不同平台大小不同（16 位上是 2 字节，32 位上是 4 字节），固定宽度类型确保跨平台一致性。

C 语言夯实基础 / 传值和传指针的根本区别？
传值拷贝整个数据，函数内修改不影响原变量；传指针只传地址，函数内通过地址修改原变量。

C 语言夯实基础 / 局部变量不初始化会怎样？
栈上的值是不确定的（上次函数调用留下的残留数据），使用前必须初始化。

C 语言夯实基础 / 宏定义中参数必须加括号的原因是什么？
宏是文本替换，不加括号会改变运算优先级。例如 `SQUARE(1+2)` 展开为 `1+2*1+2=5` 而非期望的 9。