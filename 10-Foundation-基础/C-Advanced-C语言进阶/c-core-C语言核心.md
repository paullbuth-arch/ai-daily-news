# C 语言核心

**一句话结论（20% 核心）**：嵌入式 C 语言的核心是**对内存的精确控制**。指针让你找到内存里的任意位置，位运算让你操控寄存器的每一个 bit，volatile 告诉编译器不要自作主张，内存布局让你知道变量到底存在哪里。

---

## 第一层：核心认知

### 1.1 什么是指针？

**一句话解释**：指针就是**内存地址**。

#### 费曼类比

想象一栋大楼，每个房间都有一个门牌号。
- **普通变量** = 房间里住的人（数据）。
- **指针** = 门牌号（地址）。
- **解引用 `*p`** = 按门牌号找到房间，看看里面住的是谁。

```c
int  a = 10;      // a 是一个 int 变量，值是 10
int *p = &a;      // p 是一个指针，存的是 a 的地址

printf("%d\n", a);   // 输出 10，直接看房间里的人
printf("%p\n", p);   // 输出地址，看门牌号
printf("%d\n", *p);  // 输出 10，按门牌号找到房间里的人
```

#### 为什么指针在嵌入式里这么重要？

因为 MCU 的**寄存器**就是内存地址。你要控制硬件，就要通过指针去读写这些地址。

```c
// 假设 GPIO 输出寄存器的地址是 0x40000000
volatile uint32_t *gpio_out = (uint32_t *)0x40000000;
*gpio_out = 0x01;  // 向 GPIO 输出寄存器写入 0x01，点亮 LED
```

> **英文术语**：Pointer（指针）、Dereference（解引用）、Address（地址）。

---

### 1.2 位运算：操控硬件的基本功

**一句话解释**：位运算让你一次性只改一个 bit，不改其他 bit。

#### 费曼类比

想象一个 8 位寄存器是一排 8 个开关，每个开关控制一个功能：
- 开关 0：LED
- 开关 1：蜂鸣器
- 开关 2：某个中断使能
- ...

你只想打开开关 2，但不想碰开关 0 和 1。位运算就是干这个的。

#### 四种基本操作

```c
#define BIT(n) (1U << (n))

uint32_t reg = 0;

reg |= BIT(3);     // 把第 3 位置 1（Set bit），其他位不变
reg &= ~BIT(3);    // 把第 3 位清 0（Clear bit），其他位不变
reg ^= BIT(3);     // 把第 3 位翻转（Toggle bit）
if (reg & BIT(3))  // 判断第 3 位是否为 1（Test bit）
```

#### 一个真实的例子

```c
// 使能某个外设的第 5 位中断
volatile uint32_t *ier = (uint32_t *)0x40001004;
*ier |= (1U << 5);
```

> **英文术语**：Bitwise Operation（位运算）、Set（置位）、Clear（清零）、Toggle（翻转）、Test（测试）。

---

### 1.3 volatile：告诉编译器“别优化”

**一句话解释**：`volatile` 告诉编译器，这个变量的值**随时可能被外部改变**，你不要自作聪明地优化掉对它的访问。

#### 费曼类比

假设你有一个“电子温度计”（寄存器），你每秒钟看一次。编译器看到你连续两次读同一个变量，且中间你没改它，就认为“肯定没变，不用真去读”。结果你看到的一直是旧温度。

加了 `volatile`，编译器就会每次都老老实实地去读。

```c
volatile uint32_t *temperature = (uint32_t *)0x40002000;

while (*temperature < 30) {
    // 等待温度升到 30 度以上
}
```

#### 三个必须加 volatile 的典型场景

1. **硬件寄存器**：外设的寄存器值会被硬件改变。
2. **中断中修改的变量**：ISR（Interrupt Service Routine，中断服务程序）会改，主程序会读。
3. **多核共享的变量**：另一个 CPU 可能修改它。

#### 重要误区

`volatile` **不能保证原子性**。

```c
volatile uint32_t counter = 0;

counter++;  // 这不是一个原子操作！
```

`counter++` 实际上做了三步：
1. 读出 counter 的值
2. 加 1
3. 写回

如果中断在这三步中间发生，数据就会出错。正确做法是用**临界区**保护（见 [[interrupt-concurrency-中断并发同步）]]。

> **英文术语**：Volatile（易变的）、Atomicity（原子性）、Optimization（优化）。

---

### 1.4 const / static / extern 的区别

**一句话解释**：这三个关键字控制的是**变量/函数的作用范围和可修改性**。

| 关键字 | 含义 | 通俗解释 | 典型用法 |
|---|---|---|---|
| `const` | 只读 | 这个值不能改 | 常量表、配置数据 |
| `static` | 限制作用域 / 延长生命周期 | 只有这个文件能看到；或者这个函数退出后变量还在 | 文件内私有函数、函数内保持状态 |
| `extern` | 声明外部变量 | 告诉编译器“这个变量在别的地方定义了” | 跨文件引用全局变量 |

```c
// file1.c
static int local_only = 0;  // 只在 file1.c 内部可见
int shared = 10;             // 全局变量，其他文件可用 extern 声明

// file2.c
extern int shared;  // 使用 file1.c 中定义的 shared
```

---

### 1.5 内存布局

**一句话解释**：程序运行起来后，不同的数据会放在内存的不同区域，每个区域用途不同。

```
低地址
├─ .text ── 代码段（程序指令）
├─ .rodata ─ 只读数据（常量字符串、const 变量）
├─ .data ── 已初始化的全局/静态变量
├─ .bss ─── 未初始化的全局/静态变量
├─ heap ─── 堆（malloc 从这里分配）
└─ stack ── 栈（局部变量、函数参数、返回地址）
```

#### 费曼类比

把内存想象成一个大办公室：
- **.text**：仓库里放的手册（程序代码，只读）。
- **.data**：已经贴好标签的抽屉（有初值的变量）。
- **.bss**：还没贴标签的抽屉，但知道有多少个（启动时清零）。
- **stack**：员工的工作台，临时放东西，下班就清空（函数调用时分配，返回时释放）。
- **heap**：公共储物柜，按需申请和释放。

#### 启动文件做了什么？

芯片上电后，启动文件会：
1. 初始化栈指针（SP，Stack Pointer）。
2. 把 .data 从 Flash 拷贝到 RAM。
3. 把 .bss 清零。
4. 跳转到 main()。

> **英文术语**：Text Section、Read-Only Data、Initialized Data、BSS（Block Started by Symbol）、Heap、Stack。

---

### 1.6 结构体与字节对齐

**一句话解释**：结构体是把多个数据打包成一个整体，字节对齐是编译器为了让 CPU 更快访问数据而在结构体中插入空隙。

```c
typedef struct {
    uint8_t  a;   // 1 字节
    uint32_t b;   // 4 字节
    uint16_t c;   // 2 字节
} __attribute__((packed)) my_pkt_t;  // packed 表示取消对齐
```

不加 `__attribute__((packed))` 时，编译器可能会插入填充字节（padding）。

#### 为什么对齐很重要？

1. **协议解析**：网络包、蓝牙包、WQ Protocol 帧都有严格的字节顺序，不能乱加 padding。
2. **DMA 传输**：DMA 通常要求数据按一定边界对齐。
3. **性能**：未对齐访问可能导致 CPU 多次读取内存。

> **英文术语**：Structure（结构体）、Alignment（对齐）、Padding（填充）、Packed（紧凑排列）。

---

## 第二层：实战理解

### 2.1 指针常见的三种错误

```c
int *p = NULL;
*p = 10;  // 错误！向地址 0 写入，会 HardFault
```

```c
int *p;   // 野指针，指向不确定的地址
*p = 10;  // 危险！
```

```c
int arr[5] = {0};
int *p = arr + 10;  // 越界访问
*p = 10;
```

### 2.2 位运算配置寄存器的模板

```c
#define REG_BASE 0x40000000
#define REG(offset) (*(volatile uint32_t *)(REG_BASE + (offset)))

#define SET_BIT(reg, bit)   ((reg) |= (1U << (bit)))
#define CLEAR_BIT(reg, bit) ((reg) &= ~(1U << (bit)))
#define READ_BIT(reg, bit)  ((reg) & (1U << (bit)))

// 使用示例
SET_BIT(REG(0x04), 5);
```

### 2.3 项目中 volatile 的典型应用

在 [[uart-basics-UART基础]]、 [[wq-protocol-frame-WQ-Protocol帧结构 中]]，UART 接收中断会修改接收缓冲区指针，主循环会读取。这些指针/计数器通常都要加 `volatile`。

```c
volatile uint32_t rx_count = 0;

void uart_isr(void)
{
    rx_buf[rx_count++] = UART_DATA_REG;
}

void task_process(void)
{
    uint32_t cnt;
    // 临界区保护，见中断并发笔记
    cnt = rx_count;
    // ...
}
```

---

## 第三层：深入扩展

### 3.1 函数指针与回调

```c
typedef void (*callback_t)(int);

void register_callback(callback_t cb);
```

- 驱动层常用回调把事件通知给应用层。
- WQ7036A 项目中，外设驱动大量使用回调函数。

### 3.2 宏定义的高级技巧

```c
#define MAX(a, b) (((a) > (b)) ? (a) : (b))
#define CONTAINER_OF(ptr, type, member) \
    ((type *)((char *)(ptr) - offsetof(type, member)))
```

### 3.3 常见问题

- `volatile` 能不能替代锁？不能。
- `const int *p` 和 `int *const p` 的区别？前者指向的内容不能改，后者指针本身不能改。
- `static` 局部变量和全局变量有什么区别？生命周期相同，作用域不同。
- 结构体对齐为什么会导致 sizeof 比想象的大？因为编译器插入 padding。

### 3.4 延伸阅读

- [[memory-dma-内存管理与DMA]]
- [[compile-link-startup-编译链接与启动流程]]
- [[interrupt-concurrency-中断并发同步]]
- [[i2c-basics-I2C基础]]
- [[uart-basics-UART基础]]
