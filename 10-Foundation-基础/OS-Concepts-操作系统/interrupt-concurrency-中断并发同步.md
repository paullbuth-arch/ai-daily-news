---
type: concept
tags: [中断, 并发, 同步, FreeRTOS, ISR, 临界区, 信号量, 互斥量, 优先级反转]
aliases: [中断并发, 中断同步, 并发机制]
---

# 中断、并发与同步机制

## 一句话结论

中断是 CPU 干活时被紧急事件打断，处理完再回来；并发是多件事看起来同时发生；同步机制是防止这些同时发生的事互相踩脚的规则。嵌入式 90% 的 bug 和这三者有关。

## 30 秒先看懂

中断是硬件向 CPU 发信号，CPU 暂停当前任务去执行中断服务程序（ISR）。ISR 必须短小精悍，只做"收数据+发通知"，不做复杂处理。并发问题出现在多个执行流（主循环和 ISR、多个任务）同时访问共享数据时，需要用同步机制保护。关中断是最快的保护方式（适合极短代码段），信号量用于 ISR 通知任务，互斥量保护任务间共享资源，队列用于传递数据。优先级反转是 RTOS 中常见的陷阱，优先级继承可以解决。

## 学完以后应该能做什么

**第一遍：**
- 能够区分中断和轮询，知道什么时候该用中断
- 能够写出正确的 ISR：只做收数据+发通知，不做阻塞操作
- 能够使用临界区保护共享变量，知道临界区越短越好
- 能够使用信号量实现 ISR 到任务的同步
- 能够识别数据竞争（data race）场景

**进阶：**
- 能够使用互斥量保护多个任务共享的资源，理解优先级继承
- 能够使用环形缓冲区实现 ISR 和任务之间的无锁通信
- 能够分析优先级反转问题并设计解决方案
- 能够理解 FreeRTOS 中 `FromISR` 和非 `FromISR` API 的区别
- 能够使用原子操作替代简单的锁

## 前置知识

- 了解 C 语言中的 volatile 关键字，参见 [[c-core-C语言核心]]
- 了解 RTOS 的基本概念（任务、调度），参见 [[rtos-freertos-RTOS原理与FreeRTOS]]
- 了解 MCU 的基本结构（CPU、外设、中断控制器）

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 中断 | Interrupt | 硬件向 CPU 发送的电信号，让 CPU 暂停当前任务，执行预设的中断处理函数 |
| 中断服务程序 | ISR | Interrupt Service Routine，中断发生时执行的函数 |
| 中断请求 | IRQ | Interrupt ReQuest，外设发出的中断信号线 |
| 中断嵌套 | Interrupt Nesting | 一个 ISR 执行时又被更高优先级的中断打断 |
| 临界区 | Critical Section | 访问共享资源时不允许被中断打断的代码段 |
| 竞态条件 | Race Condition | 程序结果取决于多个执行流的执行时序 |
| 数据竞争 | Data Race | 两个执行流同时访问同一变量，至少一个是写操作，且没有同步保护 |
| 互斥量 | Mutex | 用于保护共享资源的锁，同一时刻只能有一个任务持有 |
| 信号量 | Semaphore | 计数器，用于资源管理和事件通知 |
| 优先级反转 | Priority Inversion | 高优先级任务被低优先级任务间接阻塞的现象 |
| 优先级继承 | Priority Inheritance | 持有锁的低优先级任务临时提升到高优先级，防止优先级反转 |
| 死锁 | Deadlock | 两个任务互相等待对方释放锁，永远无法继续执行 |
| 可重入 | Reentrant | 函数可以安全地被多个执行流同时调用 |
| 原子操作 | Atomic Operation | CPU 保证不可被中断的操作，要么全部完成，要么全部不完成 |
| 上下文切换 | Context Switch | 保存当前任务状态，恢复另一个任务状态的过程 |

## 第一层：费曼心智模型

### 中断的类比：你在家看电视

你正在看电视（主程序）。突然门铃响了（中断请求）。

- 你按下暂停键，记住看到第 23 分钟（保存现场）
- 去开门，处理门外的事——拿快递、签收（执行 ISR）
- 回来，从第 23 分钟继续看（恢复现场）

```
主程序 → [中断发生] → 保存现场 → ISR 处理 → 恢复现场 → 主程序继续
```

**这个类比的边界**：你可以在看电视时接电话（中断嵌套），但如果在接电话时又有人敲门，你就要决定先处理哪个（中断优先级）。如果你在开门时一直不回去（ISR 太长），电视节目就一直在暂停（主程序被耽搁）。而且你不能在开门时开始做饭（ISR 里不能做阻塞操作）。

**中断 vs 轮询——等快递的类比**：

| 方式 | 怎么做 | 优缺点 |
|-----|--------|-------|
| 轮询 | 每 5 分钟去门口看看快递到了没 | 简单，但浪费你的时间（CPU 一直在空转） |
| 中断 | 快递到了门铃响 | 高效省电，但你要能随时放下手头的事 |

### 并发 bug 的类比：共用一个冰箱

你和室友共用一个冰箱。早上你看冰箱里还有牛奶，决定下楼买面包回来喝。你出门后，室友把牛奶喝光了。你回来发现牛奶没了——你的计划崩了。

**这就是并发 bug 的本质**：你看到的状态，在你使用它之前，被别人改了。

**程序里的例子**：

```c
volatile uint32_t counter = 0;

// 主循环
void main_loop(void) {
    counter++;  // 步骤：①读 counter → ②加 1 → ③写回
}

// UART 中断
void uart_isr(void) {
    counter++;  // 也是读→加→写
}
```

假设 counter 初始是 0：
- 主循环读出 counter = 0，准备加 1
- **此时中断发生！** ISR 读出 counter = 0，加 1 得到 1，写回
- 中断返回，主循环继续：把刚才的 0 加 1 得到 1，写回

**结果 counter = 1，但实际加了两次，应该是 2。** 这就是数据竞争（Data Race）。

### 同步机制的类比：火车上的厕所门锁

- 有人进去 → 锁门（获取锁）
- 外面的人进不来 → 等着（阻塞）
- 里面的人出来 → 开锁（释放锁）
- 下一个人进去

**场景推演**：两个任务（I2C 读传感器任务和 OLED 显示任务）都需要使用 I2C 总线。如果不加互斥量，任务 A 正在发 I2C 起始信号，任务 B 抢占了 CPU，也发了起始信号，I2C 总线上就乱了。用互斥量保护：任务 A 先获取 I2C 互斥量，任务 B 尝试获取时发现被占用了，自动阻塞等待。任务 A 用完后释放互斥量，任务 B 被唤醒，获取互斥量，开始使用 I2C 总线。

## 第二层：原理/时序/约束

### 中断的完整时序

```
CPU 正在执行主循环
    │
    │  UART 收到数据，拉高 IRQ 引脚
    ▼
中断控制器收到 IRQ 信号，向 CPU 发送中断请求
    │
    ▼
CPU 完成当前指令（不再执行新指令）
    │
    ▼
硬件自动保存：PC（程序计数器）和部分寄存器到栈
    │
    ▼
CPU 从向量表中查找 ISR 入口地址 → 跳转执行 ISR
    │
    ▼
ISR 执行：
    ├─ 保存剩余寄存器（软件保存）
    ├─ 识别中断源
    ├─ 处理数据（读 UART 数据寄存器，写入缓冲区）
    ├─ 发信号量通知任务
    ├─ 清中断标志位
    └─ 恢复寄存器
    │
    ▼
中断返回指令（ERET/IRET）→ 恢复 PC → 回到主循环被中断的位置
```

**关键约束**：
- 从 IRQ 触发到 ISR 第一条指令执行的时间称为**中断延迟**，取决于 CPU 和中断控制器
- ISR 必须清中断标志位，否则会反复触发
- ISR 长度直接影响系统实时性——ISR 越长，主程序和其他中断被延迟得越久

### 临界区的正确使用

```c
// 临界区 = 关中断 → 访问共享数据 → 恢复中断
// 必须非常短！通常只有几行代码

uint32_t save = irq_disable_save();  // 关中断 + 保存旧状态
shared_counter++;                     // 安全地修改共享变量
irq_restore(save);                    // 恢复中断状态
```

**关键点**：
- 临界区里的代码越短越好（通常 < 10 行，不要有循环）
- 保存/恢复中断状态，而不是简单地"开中断"——因为调用这个函数前中断可能本来就是关的
- 临界区嵌套时要小心：不能在里面调用可能阻塞的函数

### 四种同步机制的选择

| 机制 | 实现方式 | 适用场景 | 注意事项 |
|------|---------|---------|---------|
| 关中断 | 修改 CPU 中断使能位 | 保护极短的共享数据访问（< 10 条指令） | 关太久会让系统失去响应 |
| 互斥量 | 任务调度器 + 优先级继承 | 多个任务共享资源（I2C 总线、配置结构体） | 不能在 ISR 中使用 |
| 信号量 | 二进制/计数信号量 | ISR 通知任务、资源计数 | 只传信号，不传数据 |
| 队列 | 环形缓冲区 + 任务阻塞 | 任务间传数据、ISR 向任务传数据 | 数据量极大时考虑环形缓冲区 |

### 优先级反转的完整场景

**费曼类比**：三个打工人抢会议室。
- 小 A（低优先级）：正在用会议室
- 小 B（中优先级）：在普通工位不停干活
- 小 C（高优先级）：急需用会议室

小 C 等着小 A 出来。但小 B 一直在干活（CPU 优先给小 B），小 A 抢不到 CPU 出不来。结果：**最高优先级的小 C 被最低优先级的小 A 和中优先级的小 B 一起卡住了**。

**解决方案**：优先级继承——小 A 持有锁期间，临时提升到小 C 的优先级，CPU 就会优先调度小 A 尽快完成，释放锁。FreeRTOS 的互斥量默认支持优先级继承。

### 环形缓冲区：ISR 和任务之间的无锁通信

核心设计思想：**ISR 只写 head，任务只读 tail，双方各改各的指针，不需要锁**。

```c
// 关键设计：head 只由 ISR 写，tail 只由任务写
// 双方只读对方的指针，不修改
typedef struct {
    uint8_t  buf[256];           // 大小必须是 2 的幂
    volatile uint32_t head;      // ISR 写入位置
    volatile uint32_t tail;      // 任务读取位置
} rbuf_t;

// ISR 中调用：写入一个字节
bool rbuf_put(rbuf_t *rb, uint8_t data) {
    if (rb->head - rb->tail == 256) return false;  // 满了
    rb->buf[rb->head & 0xFF] = data;
    rb->head++;
    return true;
}

// 任务中调用：读取一个字节
bool rbuf_get(rbuf_t *rb, uint8_t *data) {
    if (rb->head == rb->tail) return false;  // 空了
    *data = rb->buf[rb->tail & 0xFF];
    rb->tail++;
    return true;
}
```

## 第三层：真实 SDK 代码

### WQ7036AX 的中断框架

WQ7036AX 的 IRQ 管理代码位于 `/home/ys/wq7036a/wq-audio/wqcore/chipset/bbb/riscv/irq.c`，展示了中断处理函数注册和调用的完整框架：

```c
// 中断处理函数表——函数指针数组
static isr_handler_t wq_isr_handlers[WQ_IRQ_MAX];
static void *wq_isr_params[WQ_IRQ_MAX];

// 中断注册函数：驱动层调用此函数注册中断处理回调
void wq_irq_register(uint32_t irq_num, isr_handler_t handler, void *param) {
    uint32_t key = cpu_disable_irq();  // 进入临界区
    wq_isr_handlers[irq_num] = handler;
    wq_isr_params[irq_num] = param;
    cpu_restore_irq(key);              // 退出临界区
}

// 中断使能
void wq_irq_enable(uint32_t irq_num) {
    // 通过位操作设置中断使能寄存器
    uint32_t mask = irq_num_to_mask(irq_num);
    uint32_t reg = irq_num_to_reg(irq_num);
    *(volatile uint32_t *)(INTC_BASE + reg) |= mask;
}

// 中断入口（汇编跳转过来后调用的 C 函数）
void wq_do_irq(uint32_t irq_num) {
    // 从函数指针表中找到对应的处理函数并调用
    if (wq_isr_handlers[irq_num] != NULL) {
        wq_isr_handlers[irq_num](wq_isr_params[irq_num]);
    }
}
```

**关键点**：
- `wq_irq_register` 在注册时用 `cpu_disable_irq` 保护——因为中断处理函数表是多执行流共享的数据
- 中断使能通过位操作 `|=` 实现，只修改目标中断位，不影响其他中断
- 中断处理采用函数指针回调模式，驱动层注册自己的处理函数，框架层按需调用

### 中断嵌套深度跟踪

```c
// 来自 irq.c——跟踪中断嵌套深度
uint32_t irq_nest = 0;

// 这个变量用于检测中断风暴（interrupt storm）
// 如果短时间内中断触发次数超过阈值，可能是硬件故障
#define WQ_IRQ_INTERRUPT_STORM_MAX 1000
```

### FreeRTOS 临界区 API

在 WQ7036AX 的 FreeRTOS 移植中，临界区通过宏定义实现：

```c
// 来自 /home/ys/wq7036a/wq-audio/wqcore/os/freertos_10_2_1/portable/riscv/FreeRTOSConfig.h
// 任务中进入临界区
taskENTER_CRITICAL();
// 访问共享资源
taskEXIT_CRITICAL();

// ISR 中进入临界区
UBaseType_t uxSavedInterruptStatus;
uxSavedInterruptStatus = taskENTER_CRITICAL_FROM_ISR();
taskEXIT_CRITICAL_FROM_ISR(uxSavedInterruptStatus);
```

### WQ7036AX 项目中的同步机制应用

| 场景 | 同步机制 | 代码位置 |
|------|---------|---------|
| UART 接收数据 | 环形缓冲区（ISR→任务） | `wqcore/driver/periph/common/hal/uart/wq_uart.c` |
| 音频数据传输 | DMA 双缓冲 + 信号量 | `wq-adk/components/audio_service/` |
| 多核通信 | 共享内存 + 软中断 | `wqcore/components/amp/ipc/ipc.c` |
| IPC 消息传递 | 队列 + 信号量 | `wqcore/components/amp/ipc/ipc.h` |
| 中断处理函数表 | 临界区（关中断） | `wqcore/chipset/bbb/riscv/irq.c` |

### IPC 核心数据结构中的并发设计

```c
// 来自 /home/ys/wq7036a/wq-audio/wqcore/components/amp/ipc/ipc.h
typedef struct mailbox {
    uint32_t size;  /*!< size of the mailbox */
    uint16_t w;     /*!< write index */
    uint16_t r;     /*!< read index */
    uint8_t data[]; /*!< ring data buffer */
} wq_ipc_mailbox_t;

typedef struct ipc_ctrl {
    uint32_t magic;  /* 魔数，用于有效性检查 */
    volatile wq_ipc_mailbox_t
        *mailbox[WQ_CORES_EN_MAX][WQ_CORES_EN_MAX - 1];  /* 邮箱地址表 */
    volatile struct list_head ipc_named_port_list;
} wq_ipc_ctrl_t;
```

注意 `volatile` 关键字的使用——因为邮箱结构体被多个核通过共享内存访问，编译器不能优化掉对这些变量的访问。

## 第四层：正常/异常路径

### 中断处理

| 场景 | 正常路径 | 异常路径 |
|------|---------|---------|
| 中断触发 | ISR 执行，处理数据，清标志位，返回 | 中断风暴：硬件故障导致连续触发，系统卡死在 ISR 中 |
| 中断嵌套 | 高优先级中断打断低优先级 ISR，处理完返回 | 嵌套过深导致栈溢出 |
| 中断标志位 | ISR 最后清标志位 | 忘记清标志位，中断返回后立即再次触发，死循环 |
| 中断延迟 | 短延迟后进入 ISR | 关中断过久导致中断丢失，紧急事件未处理 |

### 临界区

| 场景 | 正常路径 | 异常路径 |
|------|---------|---------|
| 关中断保护 | 极短代码段，开关中断配对 | 忘记恢复中断，系统永久失去响应 |
| 临界区嵌套 | 保存/恢复中断状态，嵌套安全 | 直接开中断，破坏了外层临界区的保护 |
| 临界区长度 | 几行代码，几十个指令周期 | 临界区里有循环或阻塞调用，中断延迟严重 |

### 互斥量与优先级反转

| 场景 | 正常路径 | 异常路径 |
|------|---------|---------|
| 互斥量获取 | 获取成功，使用资源，释放 | 死锁：两个任务互相等待对方持有的锁 |
| 优先级继承 | 低优先级任务临时提升优先级，尽快释放锁 | 没有优先级继承，高优先级任务被无限阻塞 |
| ISR 中使用 | 使用 FromISR 版本的 API | 直接在 ISR 中调用 `xSemaphoreTake`，阻塞导致系统崩溃 |

### 信号量与队列

| 场景 | 正常路径 | 异常路径 |
|------|---------|---------|
| 信号量给予 | ISR 调用 `xSemaphoreGiveFromISR` | 在 ISR 中调用 `xSemaphoreGive`（非 FromISR 版本），可能触发调度 |
| 队列发送 | ISR 用 `xQueueSendFromISR`，任务用 `xQueueSend` | ISR 中发送队列时未检查返回值，队列满导致数据丢失 |
| 队列接收 | 任务阻塞等待，数据到达后唤醒 | 接收超时设置不合理，任务频繁超时导致 CPU 浪费 |

## 第五层：调试方法

### 1. 确认中断是否触发

```c
// 添加调试计数器
volatile uint32_t irq_count = 0;

void my_isr(void) {
    irq_count++;
    // 实际处理...
}

// 在主循环中打印 irq_count，看是否在增长
// 如果 irq_count 一直为 0，说明中断根本没触发，检查硬件配置

// 检查中断风暴
#define IRQ_STORM_THRESHOLD 1000
if (irq_count > IRQ_STORM_THRESHOLD) {
    printf("WARNING: interrupt storm detected! IRQ=%d count=%lu\n", irq_num, irq_count);
}
```

### 2. 检查栈使用情况

```c
// 检查任务的栈用量（FreeRTOS）
UBaseType_t stack_high_water = uxTaskGetStackHighWaterMark(task_handle);
printf("Task stack remaining: %u words\n", stack_high_water);
// 如果这个值接近 0，说明栈溢出风险很高

// 检查 ISR 栈（如果使用独立 ISR 栈）
// 在 FreeRTOSConfig.h 中配置 configISR_STACK_SIZE_WORDS
```

### 3. 数据竞争检测

```c
// 方法1：在临界区访问前后加调试打印
uint32_t save = cpu_disable_irq();
printf("DEBUG: entering critical section, shared_var=%lu\n", shared_var);
shared_var++;
printf("DEBUG: leaving critical section, shared_var=%lu\n", shared_var);
cpu_restore_irq(save);

// 方法2：如果不确定变量是否被多个执行流访问
// 在所有可能访问该变量的地方加断点或打印
// 运行后分析访问顺序是否正确
```

### 4. 死锁分析

```c
// 使用 FreeRTOS 的跟踪功能
// 在 FreeRTOSConfig.h 中配置：
#define configUSE_TRACE_FACILITY 1

// 运行时查看任务状态
TaskStatus_t *task_status_array;
UBaseType_t task_count = uxTaskGetNumberOfTasks();
task_status_array = malloc(task_count * sizeof(TaskStatus_t));
uxTaskGetSystemState(task_status_array, task_count, NULL);
// 检查每个任务的状态：如果是 Blocked 且等待时间异常长，可能死锁
```

### 5. 常用调试命令

```bash
# 查看反汇编，确认中断向量表是否正确
riscv64-unknown-elf-objdump -d build/acore/glass_acore.elf | grep -A 5 "vector"

# 查看中断处理函数的地址
riscv64-unknown-elf-nm build/acore/glass_acore.elf | grep "isr"

# 检查栈使用量
riscv64-unknown-elf-nm --size-sort build/acore/glass_acore.elf | grep "stack"
```

## 第六层：实战练习

### 练习 1：实现一个信号量同步的 ISR-任务通信

使用 FreeRTOS API 实现以下场景：

```c
// 1. 创建一个二进制信号量
// 2. 在 ISR 中：读 GPIO 引脚电平 → 放入缓冲区 → 发信号量
// 3. 在任务中：等待信号量 → 读取缓冲区数据 → 处理
// 4. 确保使用 FromISR 版本的 API
// 5. 验证 ISR 中不能调用 vTaskDelay 或 printf

// 提示：需要用的 API
// xSemaphoreCreateBinary()
// xSemaphoreGiveFromISR()
// xSemaphoreTake()
// portYIELD_FROM_ISR()
```

### 练习 2：阅读 WQ7036AX 的 IRQ 框架代码

阅读 `/home/ys/wq7036a/wq-audio/wqcore/chipset/bbb/riscv/irq.c`，回答以下问题：

1. `wq_irq_register` 函数在注册处理函数时，为什么用 `cpu_disable_irq` 和 `cpu_restore_irq` 保护？
2. 中断处理函数表 `wq_isr_handlers` 是什么类型的数组？参数表 `wq_isr_params` 是什么？
3. 代码中使用了 `irq_nest` 变量，它的作用是什么？
4. 如果 `wq_isr_handlers[irq_num]` 为 NULL（未注册处理函数），中断触发时会发生什么？

### 练习 3：模拟优先级反转

写一个 FreeRTOS 程序，创建三个任务：

```c
// 任务 A：低优先级（1），持有互斥量 2 秒后释放
// 任务 B：中优先级（2），纯计算，不释放 CPU
// 任务 C：高优先级（3），等待互斥量

// 1. 观察：任务 C 被任务 B 间接阻塞的时间
// 2. 解释：为什么任务 C 比任务 A 优先级高，却被阻塞了？
// 3. 修改：使用互斥量（带优先级继承）替代二进制信号量，观察差异
```

### 练习 4：实现一个无锁环形缓冲区

参考本文第二层的环形缓冲区代码，实现一个支持多个写入者和单个读取者的版本：

```c
// 要求：
// 1. 缓冲区大小可以在初始化时指定（必须是 2 的幂）
// 2. put 操作：如果缓冲区满，返回错误码
// 3. get 操作：如果缓冲区空，返回错误码
// 4. 使用 volatile 保护 head 和 tail
// 5. 测试在 ISR 写入 + 任务读取的场景下的正确性

// 边界情况考虑：
// - head 绕回到 0 时，tail 还在后面，计算已用空间需要用 head - tail
// - 缓冲区满的条件是 head - tail == size
// - 缓冲区空的条件是 head == tail
```

## 自测与验收

1. 中断和轮询有什么区别？什么场景下必须用中断？

2. 什么是数据竞争（Data Race）？请举一个具体的例子。

3. 为什么 ISR 里不能调用 `vTaskDelay()`、`printf()`、`malloc()`？

4. 临界区（关中断）和互斥量有什么区别？什么时候用哪种？

5. 什么是优先级反转？FreeRTOS 的互斥量如何解决这个问题？

6. `xSemaphoreGiveFromISR` 和 `xSemaphoreGive` 有什么区别？为什么需要 `FromISR` 版本？

7. 环形缓冲区如何实现 ISR 和任务之间的无锁通信？head 和 tail 分别由谁修改？

8. 什么是死锁？写出一个死锁的代码示例，并说明如何避免。

## 延伸阅读

- [[rtos-freertos-RTOS原理与FreeRTOS]] — 任务调度与同步原语的实现
- [[ring-buffer-环形缓冲区]] — ISR 安全缓冲区的完整代码
- [[memory-dma-内存管理与DMA]] — DMA 中断与任务同步
- [[ipc-multicore-多核通信与IPC]] — 多核场景下的同步问题
- [[c-core-C语言核心]] — volatile 的深入理解
- [[debug-methodology-嵌入式调试方法论]] — 死锁和栈溢出的排查

#flashcard

中断并发同步 / 中断和轮询的区别？
中断是事件驱动（门铃来了去开门），轮询是主动查询（不停看门口）。事件发生时间不确定、频率低时用中断。

中断并发同步 / 为什么 ISR 里不能阻塞？
ISR 不是任务，没有自己的上下文可以保存/恢复。阻塞会让整个系统失去响应。

中断并发同步 / 什么是优先级反转？
高优先级任务等待低优先级任务持有的锁，但中优先级任务抢占了 CPU，低优先级任务无法释放锁，导致高优先级任务被间接阻塞。

中断并发同步 / 环形缓冲区如何实现无锁？
ISR 只写 head，任务只读 tail，双方都只读对方的指针，不修改。不需要锁，靠 volatile 保证可见性。

中断并发同步 / 临界区的核心原则是什么？
尽可能短（< 10 条指令），保存/恢复中断状态（而不是简单开/关），嵌套时注意不要破坏外层保护。