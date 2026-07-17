# C 语言夯实基础（从零到嵌入式）

**一句话结论（20% 核心）**：C 语言只有 32 个关键字，核心就三件事——**数据怎么存**（变量、类型、内存）、**逻辑怎么走**（判断、循环、函数）、**内存怎么管**（指针、数组、结构体）。掌握这三件事，你就掌握了 C 语言的 80%。

---

## 第 0 章：为什么嵌入式必须用 C？

在学 C 之前，先回答一个根本问题：**为什么嵌入式开发不用 Python、Java，偏要用 C？**

| 原因 | 解释 |
|------|------|
| **C 离硬件最近** | C 的指针可以直接读写内存地址（= 操控硬件寄存器），其他语言做不到 |
| **C 没有运行时开销** | 没有垃圾回收、没有虚拟机、没有庞大的运行时库——芯片上电就能跑 |
| **C 编译出来的代码极小** | 一个 FreeRTOS 内核只有几 KB，Python 解释器就几十 MB |
| **所有芯片都有 C 编译器** | RISC-V、ARM、Xtensa、8051——不管什么架构，第一个可用的编译器永远是 C |

**一句话**：C 是硬件的"母语"，其他语言是翻译。嵌入式开发需要直接和硬件对话，所以必须用 C。

---

## 第 1 章：数据怎么存

### 1.1 变量 = 内存里的一个盒子

**费曼类比**：变量就像储物柜。每个柜子有编号（地址）、有大小（类型决定）、里面放东西（值）。

```c
int   age = 25;       // 一个叫 age 的柜子，大小 4 字节，里面放了 25
char  grade = 'A';    // 一个叫 grade 的柜子，大小 1 字节，里面放了 'A'
float temp = 36.5;    // 一个叫 temp 的柜子，大小 4 字节，里面放了 36.5
```

### 1.2 数据类型：决定柜子大小

| 类型 | 大小（32位 MCU） | 范围 | 什么时候用 |
|------|-----------------|------|-----------|
| `char` | 1 字节 | -128 ~ 127 或 0 ~ 255 | 字符、小数字、标志位 |
| `short` | 2 字节 | -32768 ~ 32767 | 省内存时替代 int |
| `int` | 4 字节 | -21 亿 ~ 21 亿 | 通用整数，默认选择 |
| `long` | 4 或 8 字节 | 取决于平台 | 需要更大范围时 |
| `long long` | 8 字节 | ±9×10^18 | 时间戳、大计数 |
| `float` | 4 字节 | ±3.4×10^38（6 位精度） | 小数，精度要求不高 |
| `double` | 8 字节 | ±1.7×10^308（15 位精度） | 小数，精度要求高 |

**嵌入式里最重要的规则**：永远用 `stdint.h` 的固定宽度类型，不要用 `int`。

```c
#include <stdint.h>

// 不要这样写（大小不确定）：
int count;           // 32 位 MCU 上是 4 字节，16 位 MCU 上是 2 字节！

// 要这样写（大小确定）：
uint8_t  flag;       // 一定是 1 字节，无符号
int16_t  small_num;  // 一定是 2 字节，有符号
uint32_t address;    // 一定是 4 字节，无符号（寄存器地址必须用这个）
uint64_t timestamp;  // 一定是 8 字节
```

### 1.3 有符号 vs 无符号：嵌入式里最容易出错的坑

```c
uint8_t a = 0;     // 0 ~ 255
a = a - 1;         // a = 255！（不是 -1，而是绕回到 255）
// 因为无符号数不会变成负数，而是从 0 绕回到最大值

int8_t b = 127;    // -128 ~ 127
b = b + 1;         // b = -128！（溢出，从最大正数绕到最小负数）
```

**费曼类比**：有符号数 = 温度计（有零上和零下），无符号数 = 里程表（只会往前，到顶了绕回 0）。

### 1.4 数组：一排连续的柜子

```c
// 数组 = 一排相同大小的柜子，连续排列
int scores[5] = {90, 85, 78, 92, 88};

// scores[0] = 90  (第 0 个柜子)
// scores[1] = 85  (第 1 个柜子)
// ...
// scores[4] = 88  (第 4 个柜子)

// 数组名是指向第一个元素的指针
int *p = scores;     // p 指向 scores[0]
// p[0] = scores[0], p[1] = scores[1], ...

// 字符串 = 字符数组 + '\0' 结尾
char name[] = "hello";   // 实际是 {'h','e','l','l','o','\0'}，6 个字节
```

### 1.5 结构体：把不同类型数据打包

```c
// 结构体 = 把相关数据放在一起
struct Sensor {
    uint16_t id;          // 传感器 ID
    uint8_t  type;        // 类型
    float    value;       // 当前值
    uint32_t timestamp;   // 时间戳
};

struct Sensor temp_sensor = {0x01, 0x03, 36.5, 12345678};
// 访问成员
temp_sensor.value = 37.0;

// 嵌入式里常用 typedef 简化
typedef struct {
    uint32_t magic;
    uint16_t length;
    uint8_t  data[256];
} packet_t;                     // 以后直接用 packet_t，不用写 struct

// 字节对齐：嵌入式里经常要紧凑排列
typedef struct __attribute__((packed)) {
    uint8_t  header;     // 1 字节
    uint32_t payload;    // 4 字节（不加 packed 会有 3 字节填充）
    uint8_t  checksum;   // 1 字节
} tight_packet_t;        // 不加 packed = 12 字节，加了 = 6 字节
```

### 1.6 枚举和联合体

```c
// 枚举：给整数起名字，代码更可读
typedef enum {
    STATE_IDLE = 0,
    STATE_RUNNING = 1,
    STATE_ERROR  = 2,
} state_t;

state_t current = STATE_IDLE;
if (current == STATE_RUNNING) { ... }

// 联合体：同一块内存，多种解读方式
typedef union {
    uint32_t word;           // 4 字节整体
    uint8_t  bytes[4];       // 4 个独立字节
    struct {
        uint16_t low;        // 低 2 字节
        uint16_t high;       // 高 2 字节
    } half;
} data_union_t;

data_union_t u;
u.word = 0x12345678;
// u.bytes[0] = 0x78 (小端), u.half.low = 0x5678
```

---

## 第 2 章：逻辑怎么走

### 2.1 判断：if/else 和 switch

```c
// if/else：条件判断
if (voltage < 3.3) {
    led_on();           // 电压低，亮红灯
} else if (voltage < 3.6) {
    led_green();        // 正常范围
} else {
    led_off();          // 过压保护
}

// switch：多分支（比一连串 if/else 更清晰）
switch (cmd) {
case CMD_START:
    start_recording();
    break;              // 别忘了 break！否则会继续执行下一个 case
case CMD_STOP:
    stop_recording();
    break;
default:
    send_error("Unknown command");
    break;
}
```

### 2.2 循环：for、while、do-while

```c
// for：知道循环次数时用
for (int i = 0; i < 10; i++) {
    process(i);
}

// while：条件满足时一直循环
while (uart_has_data()) {
    uint8_t byte = uart_read();
    process(byte);
}

// do-while：至少执行一次（嵌入式里常用于宏定义）
do {
    // 至少执行一次
} while (condition);

// 无限循环：嵌入式 main 函数里最常见
while (1) {
    // 嵌入式程序永远不会退出
}
```

### 2.3 函数：把代码组织成可复用的模块

```c
// 函数 = 输入 → 处理 → 输出
//        返回值类型  函数名    参数列表
          uint32_t    add      (uint32_t a, uint32_t b) {
    return a + b;      // 返回结果
}

// void 函数：没有返回值，只做事
void led_toggle(void) {
    gpio_toggle(LED_PIN);
}

// 传值 vs 传指针
void bad_swap(int a, int b) {       // 传值：改的是副本，不影响原变量
    int tmp = a; a = b; b = tmp;    // 没用！
}

void good_swap(int *a, int *b) {    // 传指针：通过地址改原变量
    int tmp = *a; *a = *b; *b = tmp; // 有效！
}
```

### 2.4 作用域和生命周期

```c
int global = 10;            // 全局变量：整个程序都能访问，程序结束时才销毁

static int file_private;    // 文件内全局：只有当前 .c 文件能访问

void my_func(void) {
    int local = 5;          // 局部变量：只在这个函数内有效，函数返回就销毁
    static int persistent;  // 静态局部变量：函数返回后保留值，下次调用还在
    persistent++;           // 每次调用 my_func，persistent 都会 +1
}
```

**变量存在哪？**

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

---

## 第 3 章：指针——C 语言的灵魂

### 3.1 指针是什么？为什么需要它？

**费曼类比**：变量 = 房间里的人，指针 = 门牌号。

```c
int  a = 42;        // 一个叫 a 的房间，里面住着 42
int *p = &a;        // p 存的是 a 的门牌号（地址）

printf("%d\n", a);   // 42 —— 直接看房间里的人
printf("%p\n", p);   // 0x20001000 —— 看门牌号
printf("%d\n", *p);  // 42 —— 按门牌号找到房间，看里面的人

*p = 100;            // 按门牌号找到房间，把里面的人换成 100
// 现在 a 也变成了 100，因为 p 指向 a
```

**嵌入式里为什么指针是核心？** 因为芯片的寄存器就是固定地址的内存。你要控制硬件，必须通过指针读写这些地址。

```c
// GPIO 输出寄存器的地址是 0x40000000
volatile uint32_t *gpio_out = (uint32_t *)0x40000000;
*gpio_out = 0x01;  // 向这个地址写 0x01 → GPIO 引脚输出高电平 → LED 亮
```

### 3.2 指针的三种常见错误

```c
// 错误 1：空指针解引用
int *p = NULL;
*p = 10;        // 崩溃！向地址 0 写入 → HardFault

// 错误 2：野指针（未初始化）
int *q;         // q 指向随机的地址
*q = 10;        // 危险！不知道写到哪去了

// 错误 3：越界访问
int arr[5] = {0};
int *r = arr + 10;  // 指向 arr 范围之外
*r = 10;            // 踩坏了别人的内存
```

### 3.3 指针和数组的关系

```c
int arr[5] = {10, 20, 30, 40, 50};

// 数组名就是指向第一个元素的指针
int *p = arr;        // p = &arr[0]

// 以下写法完全等价：
arr[2] = 99;
*(p + 2) = 99;       // 指针算术：p + 2 = 跳过 2 个 int = 跳过 8 字节
*(arr + 2) = 99;
2[arr] = 99;         // 你没看错，这也是合法的！但不推荐

// 指针遍历数组
for (int *p = arr; p < arr + 5; p++) {
    printf("%d\n", *p);
}
```

### 3.4 函数指针：嵌入式里到处是回调

```c
// 函数指针 = 指向函数的指针，可以动态决定调用哪个函数

// 定义函数指针类型
typedef void (*callback_t)(int result);

// 使用函数指针
void register_callback(callback_t cb) {
    // 保存 cb，等事件发生时调用
}

void my_handler(int result) {
    if (result == 0) led_green();
    else led_red();
}

// 注册回调
register_callback(my_handler);  // 函数名本身就是函数指针

// 实际应用：UART 收到数据时调用你注册的回调函数
wq_uart_register_rx_callback(port, buffer, size, my_rx_handler);
```

---

## 第 4 章：预处理器——编译前的文本替换

### 4.1 三种最常用的预处理指令

```c
// ① #include：把头文件内容原样插入
#include "my_header.h"   // 从当前目录找
#include <stdint.h>      // 从系统目录找

// ② #define：宏定义（文本替换，不是变量！）
#define LED_PIN   5
#define MAX(a,b)  ((a) > (b) ? (a) : (b))  // 参数必须加括号！

// ③ 条件编译：控制哪些代码参与编译
#define DEBUG  1

#if DEBUG
    printf("Debug: value = %d\n", val);   // 调试时编译
#endif

#ifdef CONFIG_USE_OPUS
    // 只有在 Kconfig 中启用了 Opus 才编译这段代码
    opus_encode(...);
#endif
```

### 4.2 宏的陷阱

```c
// 陷阱 1：参数不加括号
#define SQUARE(x)  x * x
SQUARE(1 + 2)  // 展开: 1 + 2 * 1 + 2 = 1 + 2 + 2 = 5（错了！应该是 9）
// 正确写法:
#define SQUARE(x)  ((x) * (x))

// 陷阱 2：带副作用的参数
#define MAX(a,b)  ((a) > (b) ? (a) : (b))
MAX(i++, j++)  // i++ 和 j++ 可能被执行两次！不要这样用

// 陷阱 3：多语句宏
#define DO_STUFF()  do { foo(); bar(); } while(0)
// 用 do-while(0) 包裹，确保在任何 if/else 上下文中安全
```

---

## 第 5 章：类型转换——隐式和显式

```c
// 隐式转换：编译器自动做
int a = 10;
float b = a;        // a 自动转为 float，b = 10.0
int c = 3.14;       // 3.14 截断为 3（丢失小数部分，不四舍五入）

// 整数提升：小类型运算时自动提升为 int
uint8_t x = 200;
uint8_t y = 100;
uint32_t z = x + y;  // x 和 y 先提升为 int，再相加，再赋值给 z

// 显式转换：程序员明确指定
int d = (int)3.14;   // d = 3
uint8_t *ptr = (uint8_t *)0x20000000;  // 把地址强制转为指针

// 嵌入式里最常见的转换：寄存器地址
volatile uint32_t *reg = (volatile uint32_t *)0x40000000;
```

---

## 第 6 章：嵌入式 C 的特殊规则

### 6.1 volatile：告诉编译器"别自作聪明"

```c
// 没有 volatile：
uint32_t *flag = (uint32_t *)0x20000000;
while (*flag == 0) {
    // 编译器可能优化成：把 *flag 读到寄存器，然后一直检查寄存器
    // 如果 flag 被中断改变了，编译器看不到！
}

// 有 volatile：
volatile uint32_t *flag = (volatile uint32_t *)0x20000000;
while (*flag == 0) {
    // 编译器每次都真的从 0x20000000 读值
    // 中断改了 flag 能立即看到
}
```

**三个必须加 volatile 的场景**：
1. 硬件寄存器（`volatile uint32_t *reg = (uint32_t *)0x40000000`）
2. 中断中修改的变量（ISR 和主循环共享的变量）
3. 多核共享的变量（另一个核可能修改它）

### 6.2 位运算：操控寄存器的基本技能

```c
#define BIT(n)  (1U << (n))

uint32_t reg = 0;

reg |= BIT(3);      // 第 3 位置 1：  reg = reg | 0x00000008
reg &= ~BIT(3);     // 第 3 位清零：  reg = reg & 0xFFFFFFF7
reg ^= BIT(3);      // 第 3 位翻转：  reg = reg ^ 0x00000008
if (reg & BIT(3))   // 测试第 3 位：  如果第 3 位是 1，条件成立

// 给一个寄存器字段赋值（如 bit[5:3]）
reg &= ~(0x7 << 3);      // 先清零 bit[5:3]
reg |= (new_value << 3);  // 再写入新值
```

### 6.3 const 和 static 的嵌入式用法

```c
// const：放在 Flash 里（不占 RAM）
const uint16_t sine_table[256] = { ... };  // 查找表，放 Flash
const char *error_msg = "Error!";          // 字符串放 Flash

// static：限制作用域
static int local_counter;    // 只在本文件可见，其他文件看不到
static void helper(void) {}  // 只在本文件可见的私有函数

// extern：声明外部变量（在别的 .c 文件中定义）
extern int global_config;    // 告诉编译器"这个变量在别的文件里"
```

---

## 第 7 章：常见错误速查表

| 错误 | 代码 | 后果 | 修复 |
|------|------|------|------|
| `=` 和 `==` 混淆 | `if (a = 5)` | 条件永远为真，a 被改成 5 | `if (a == 5)` |
| 数组越界 | `arr[10] = 0`（arr 只有 10 个元素） | 踩坏栈上的其他变量 | 检查边界 |
| 忘 break | switch 中漏了 break | 执行了不该执行的 case | 每个 case 加 break |
| 整数溢出 | `uint8_t x = 255; x++;` | x = 0 | 用更大的类型 |
| 除零 | `a / 0` | 硬件异常（HardFault） | 除法前检查除数 |
| 忘初始化 | `int x; x++;` | 结果不确定 | 始终初始化 |
| 宏展开错误 | `SQUARE(1+2)` 展开为 `1+2*1+2` | 结果错误 | 宏参数加括号 |
| 符号扩展 | `uint8_t → int` 时意外带符号 | 结果错误 | 显式转换 |

---

## 第 8 章：下一步学什么

学完本篇，你已经掌握了 C 语言的 80%。接下来按这个顺序进阶：

1. **[[c-core-C语言核心]]** — 嵌入式 C 的进阶技巧：指针操作寄存器、volatile 深入、结构体对齐、内存布局
2. **[[data-structure-state-machine-数据结构与状态机]]** — 嵌入式最常用的数据结构：环形缓冲区、链表、状态机
3. **[[compile-link-startup-编译链接与启动流程]]** — 代码怎么变成固件、芯片怎么启动
4. **[[interrupt-concurrency-中断并发同步]]** — 中断和并发——嵌入式 90% 的 bug 来源

---

## 核心术语表

| 英文 | 中文 | 一句话 |
|------|------|--------|
| Variable | 变量 | 内存里的一个命名盒子 |
| Type | 类型 | 决定盒子的大小和里面放什么 |
| Pointer | 指针 | 存地址的变量，门牌号 |
| Array | 数组 | 一排连续的相同类型盒子 |
| Struct | 结构体 | 把不同类型的数据打包在一起 |
| Function | 函数 | 可复用的代码块，输入→处理→输出 |
| Preprocessor | 预处理器 | 编译前做文本替换的工具 |
| Stack | 栈 | 局部变量的存放处，函数返回自动释放 |
| Heap | 堆 | 动态分配的内存，手动管理 |
| Volatile | 易变的 | 告诉编译器每次都要真的从内存读 |
| Bitwise | 位运算 | 操控单个 bit 的运算 |
| Scope | 作用域 | 变量在哪些地方可见 |
| Lifetime | 生命周期 | 变量从创建到销毁的时间 |