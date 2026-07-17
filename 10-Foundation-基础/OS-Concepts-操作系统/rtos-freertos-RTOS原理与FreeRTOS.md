---
type: concept
tags: [RTOS, FreeRTOS, 任务调度, 上下文切换, 实时操作系统, 嵌入式]
aliases: [FreeRTOS, RTOS原理, 实时系统]
---

# RTOS 原理与 FreeRTOS

## 一句话结论

RTOS（实时操作系统）让单片机"同时"干多件事——通过任务快速切换和优先级调度，让每个任务看起来都在独立运行。FreeRTOS 是嵌入式领域最流行的开源 RTOS，核心是任务调度器、上下文切换和同步原语。

## 30 秒先看懂

RTOS 的核心价值在于解决裸机超级循环中不同实时要求的任务互相干扰的问题。通过将不同功能拆分为独立任务，每个任务有自己的栈和优先级，调度器根据优先级决定谁使用 CPU。高优先级任务就绪时抢占低优先级任务。任务通过阻塞等待（信号量、队列、延时）主动让出 CPU，调度器切换到下一个最高优先级的就绪任务。上下文切换在每个系统节拍（Tick）中断和系统调用时发生，保存当前任务的全部寄存器到栈，从下一个任务的栈中恢复寄存器。

## 学完以后应该能做什么

**第一遍：**
- 能够使用 `xTaskCreate` 创建任务，理解栈大小、优先级、任务句柄的含义
- 能够使用 `vTaskDelay` 让任务延时阻塞，让出 CPU
- 能够使用队列在任务间传递数据
- 能够使用信号量在 ISR 和任务之间同步
- 能够使用 `uxTaskGetStackHighWaterMark` 检查任务栈使用量

**进阶：**
- 能够理解 FreeRTOS 的抢占式调度和时间片轮转机制
- 能够分析任务的四种状态（Ready/Running/Blocked/Suspended）转换
- 能够使用互斥量保护共享资源，理解优先级继承
- 能够配置 FreeRTOS 的 Tickless 模式实现低功耗
- 能够阅读 FreeRTOS 源码中的任务切换路径（`vTaskSwitchContext`）

## 前置知识

- 理解中断的基本概念，参见 [[interrupt-concurrency-中断并发同步]]
- 了解 C 语言中的函数指针、结构体，参见 [[c-core-C语言核心]]
- 对 MCU 的栈和堆有基本认识

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 实时操作系统 | RTOS | Real-Time Operating System，能在确定时间内响应外部事件的系统 |
| 任务 | Task | 独立的执行线程，拥有自己的栈和优先级 |
| 调度器 | Scheduler | 决定哪个任务获取 CPU 使用权的内核组件 |
| 上下文切换 | Context Switch | 保存当前任务的全部寄存器，恢复下一个任务的寄存器 |
| 任务控制块 | TCB | Task Control Block，存储任务状态、栈指针、优先级的结构体 |
| 抢占 | Preemption | 高优先级任务就绪时，强制打断正在运行的低优先级任务 |
| 时间片 | Time Slice | 同优先级任务轮流执行的时间单位，通常为 1 个 Tick |
| 阻塞 | Blocked | 任务因等待事件（延时、信号量、队列）而暂停执行的状态 |
| 就绪 | Ready | 任务可以运行但 CPU 正被更高优先级任务占用的状态 |
| 挂起 | Suspended | 任务被手动暂停，不参与调度的状态 |
| 系统节拍 | Tick | RTOS 的定时心跳，通常 1ms，用于时间测量和调度触发 |
| 空闲任务 | Idle Task | 所有用户任务都阻塞时运行的默认任务，优先级为 0 |
| 临界区 | Critical Section | 禁止任务切换和中断的代码区域 |
| 互斥量 | Mutex | 带优先级继承的锁，用于保护共享资源 |
| 信号量 | Semaphore | 计数器，用于资源管理和事件通知 |
| 任务通知 | Task Notification | 轻量级的任务间通信方式，比信号量更高效 |
| 栈溢出 | Stack Overflow | 任务栈空间不够用，覆盖了相邻内存区域 |
| 饥饿 | Starvation | 低优先级任务因高优先级任务一直就绪而得不到 CPU 时间 |

## 第一层：费曼心智模型

### 为什么需要 RTOS？——裸机调度的困境

不用 RTOS（裸机 / 超级循环）：

```c
int main(void) {
    while (1) {
        check_button();    // 10ms 一次就够
        read_sensor();     // 100ms 一次就够
        update_display();  // 500ms 一次就够
        play_audio();      // 必须每 1ms 处理一次！
    }
}
```

问题：`play_audio()` 要求 1ms 执行一次，但其他函数拖慢了循环，音频卡顿。

用 RTOS：

```c
// 每个功能一个任务，独立设置优先级和周期
xTaskCreate(audio_task,    "Audio",    256, NULL, 5, NULL);  // 最高优先级
xTaskCreate(button_task,   "Button",   128, NULL, 2, NULL);
xTaskCreate(sensor_task,   "Sensor",   128, NULL, 1, NULL);
xTaskCreate(display_task,  "Display",  256, NULL, 1, NULL);

vTaskStartScheduler();  // 启动调度器，不再返回
```

每个任务独立运行、独立调度，音频任务优先级最高，保证每 1ms 都能执行。

### 类比：餐厅服务员

RTOS 调度器就像餐厅里的服务员领班：

- **任务（Task）**：每桌客人，各有各的需求
- **优先级（Priority）**：VIP 桌优先服务
- **调度器（Scheduler）**：领班决定先服务哪桌
- **上下文切换（Context Switch）**：服务员放下 A 桌的单子，拿起 B 桌的单子
- **阻塞（Blocked）**：客人说"我去下洗手间"——这桌暂时不需要服务，服务员可以去服务其他桌
- **空闲任务（Idle Task）**：所有客人都没需求了，服务员休息一下

```
高优先级任务就绪 ──→ 立刻抢走 CPU（抢占式调度）
低优先级任务运行中 ──→ 被高优先级任务打断
所有任务都在等待 ──→ 运行空闲任务（Idle Task）
```

### 场景推演：蓝牙耳机上的任务调度

你在用蓝牙耳机听音乐时，突然收到来电通知。耳机内部的任务调度是这样的：

1. **音频任务**（高优先级，5）正在运行——从蓝牙接收音频数据，送 DAC 播放
2. **来电通知**：手机通过蓝牙发送来电通知
3. **蓝牙任务**（中高优先级，4）就绪，抢占音频任务
4. 上下文切换：保存音频任务的所有寄存器到其栈，恢复蓝牙任务的寄存器
5. 蓝牙任务处理来电通知，放入队列，发送信号量给应用任务
6. 蓝牙任务开始等待下一个蓝牙事件，进入阻塞状态
7. 调度器切换回音频任务，继续播放音乐
8. **应用任务**（中优先级，3）收到信号量，进入就绪状态
9. 等音频任务主动让出 CPU（处理完一个音频帧）后，应用任务运行
10. 应用任务在 OLED 上显示来电号码，然后进入阻塞等待下一个事件

在这个过程中，你完全感觉不到音乐中断——因为上下文切换只需要几十微秒。

## 第二层：原理/时序/约束

### 任务的四种状态

```
         创建
          ↓
      ┌─ Ready（就绪）─→ Running（运行）─┐
      │       ↑                           │
      │       │                           │ 阻塞（等待信号量/队列/延时）
      │   被抢占                        ↓
      │       │                      Blocked（阻塞）
      └───────┘                           │
                                          │ 事件到达/延时结束
                                          ↓
                                        Ready
```

| 状态 | 中文 | 含义 |
|-----|------|------|
| Ready | 就绪 | 可以运行，但 CPU 正在执行其他更高优先级的任务 |
| Running | 运行 | 正在占用 CPU |
| Blocked | 阻塞 | 在等待某件事（延时、信号量、队列数据、事件组） |
| Suspended | 挂起 | 被手动暂停（vTaskSuspend），不参与调度 |

**关键理解**：当一个任务调用 `vTaskDelay()` 或 `xQueueReceive()` 时，它进入 **Blocked** 状态，CPU 会立刻切换到下一个最高优先级的就绪任务。这就是 RTOS 高效的原因——阻塞的任务不浪费 CPU 时间。

### 任务切换发生的时机

FreeRTOS 的任务切换只在两个时机发生：

1. **SysTick 中断（系统节拍）**：每个 Tick（通常 1ms）检查一次是否有更高优先级的任务就绪
2. **系统调用**：任务主动调用 `vTaskDelay()`、`xQueueSend()`、`xSemaphoreGive()` 等 API 时

```
Task A (running)
   ↓ vTaskDelay(100)  ← 系统调用触发切换
Task B (running)       ← B 是下一个最高优先级的就绪任务
   ↓ Tick 中断到达
Task C (running)       ← C 的优先级比 B 高，Tick 中断后抢占
```

**注意**：任务切换不是"随时"发生的，只在 Tick 中断和系统调用时发生。如果一个任务在做纯计算不调用任何 API，低优先级任务就只能等到下一次 Tick。

### 上下文切换的具体过程

```
1. 把 CPU 所有寄存器压入当前任务的栈（R0-R31、PC、SP…）
2. 把当前栈顶地址保存到当前任务的 TCB（任务控制块）
3. 从下一个任务的 TCB 取出它的栈顶地址
4. 从那个栈里弹出寄存器值，恢复 CPU 状态
5. PC（程序计数器）恢复后，下一个任务从上次暂停的地方继续执行
```

在 RISC-V 上，上下文切换全部由软件在 `portYIELD()` 中完成。在 ARM Cortex-M 上，由 PendSV 异常处理，硬件自动保存一部分寄存器。

### 调度算法的三种模式

FreeRTOS 支持三种调度模式（通过 `FreeRTOSConfig.h` 配置）：

| 模式 | 配置宏 | 行为 |
|-----|--------|------|
| 抢占式 + 时间片 | `configUSE_PREEMPTION=1` + `configUSE_TIME_SLICING=1` | 高优先级抢占；同优先级轮流执行，每个任务一个时间片 |
| 抢占式无时间片 | `configUSE_PREEMPTION=1` + `configUSE_TIME_SLICING=0` | 高优先级抢占；同优先级任务不轮换，当前任务持续运行直到主动阻塞 |
| 协作式 | `configUSE_PREEMPTION=0` | 任务主动让出 CPU 才切换，Tick 中断不会触发调度 |

**推荐**：大多数场景用"抢占式 + 时间片"。

### 任务栈大小的估算

```c
// 栈空间存放：局部变量、函数参数、返回地址、中断嵌套时的上下文
// 估算方法：
// 栈大小 = 最深调用路径的栈帧总和 + 中断嵌套额外开销 + 安全余量（20-30%）

void task_a(void *p) {          // 栈帧: 32 bytes
    char buf[64];               // +64 bytes
    process_data(buf);          // process_data 栈帧: 48 bytes
}                               // 合计: 144 bytes

// 加上中断开销（假设 128 bytes）+ 30% 余量
// 推荐栈大小: (144 + 128) * 1.3 ≈ 354 bytes → 取 512 bytes (128 words)
```

**FreeRTOS 中栈大小的单位是 word（4 字节）**：
```c
xTaskCreate(task_a, "A", 128, NULL, 1, NULL);
//                     ^^^ 128 words = 512 bytes
```

## 第三层：真实 SDK 代码

### WQ7036AX 的 FreeRTOS 配置

WQ7036AX 的 ACORE 运行 FreeRTOS 10.2.1，其配置位于 `/home/ys/wq7036a/wq-audio/wqcore/os/freertos_10_2_1/portable/riscv/FreeRTOSConfig.h`：

```c
// 核心调度配置
#define configUSE_PREEMPTION                    1    // 抢占式调度
#define configCPU_CLOCK_HZ                      16000000  // 16MHz CPU 时钟
#define configTICK_RATE_HZ                      1000      // 1ms Tick
#define configMAX_PRIORITIES                    15        // 15 个优先级
#define configMINIMAL_STACK_SIZE                384       // 最小栈 384 words = 1536 bytes
#define configUSE_TIME_SLICING                  1         // 启用时间片轮转
#define configUSE_MUTEXES                       1         // 启用互斥量
#define configUSE_COUNTING_SEMAPHORES           1         // 启用计数信号量
#define configUSE_TASK_NOTIFICATIONS            1         // 启用任务通知
#define configUSE_IDLE_HOOK                     1         // 空闲任务钩子
#define configUSE_TICK_HOOK                     1         // Tick 钩子
#define configCHECK_FOR_STACK_OVERFLOW          1         // 栈溢出检测
#define configUSE_TICKLESS_IDLE                 1         // Tickless 低功耗模式
```

### WQ7036AX 上的典型任务划分

| 任务 | 优先级 | 栈大小 (words) | 职责 |
|-----|--------|---------------|------|
| audio_task | 高 (5) | 512 | 管理音频管道、与 DCORE 交互 |
| bt_task | 中高 (4) | 512 | 蓝牙事件处理 |
| app_task | 中 (3) | 512 | 应用逻辑、按键、LED |
| ipc_task | 中 (3) | 384 | 处理与 BCORE/DCORE 的 IPC 消息 |
| idle_task | 0 (最低) | 128 | 空闲时进入低功耗 |

### FreeRTOS 任务切换的关键路径

FreeRTOS 源码中任务切换的调用链：

```
Tick 中断（SysTick Handler）
   ↓
xPortSysTickHandler()           // 在 port.c 中实现
   ↓
vTaskIncrementTickCount()       // Tick 计数 +1，检查是否有延时结束的任务
   ↓
vTaskSwitchContext()            // 核心函数：选择下一个运行的任务
   ↓
pxCurrentTCB = 最高优先级的就绪任务  // 更新当前任务指针
   ↓
portYIELD()                     // 触发实际的寄存器保存/恢复
```

`vTaskSwitchContext()` 的核心逻辑：
1. 遍历所有优先级队列（每个优先级一个就绪任务链表）
2. 从最高非空优先级取出下一个任务
3. 更新 `pxCurrentTCB` 指针

### RISC-V 上的 FreeRTOS 移植

WQ7036AX 的 FreeRTOS 移植代码在 `/home/ys/wq7036a/wq-audio/wqcore/os/freertos_10_2_1/portable/riscv/port.c` 中，关键实现：

```c
// 中断栈——如果 configISR_STACK_SIZE_WORDS 定义了，使用静态分配的 ISR 栈
#ifdef configISR_STACK_SIZE_WORDS
static StackType_t xISRStack[configISR_STACK_SIZE_WORDS] = {0};
StackType_t xISRStackTop = (StackType_t)
    &(xISRStack[(configISR_STACK_SIZE_WORDS & ~portBYTE_ALIGNMENT_MASK) - 1]);
#else
StackType_t xISRStackTop = 0;  // 使用 main 函数的栈作为 ISR 栈
#endif

// 启动调度器
void vPortStartFirstTask(void) {
    // 设置栈指针
    // 触发第一个上下文切换
    portYIELD();
}
```

### IPC 通信中的任务同步

WQ7036AX 的多核通信框架使用信号量和队列实现核间同步：

```c
// 来自 /home/ys/wq7036a/wq-audio/wqcore/components/amp/ipc/ipc.h
// IPC 消息通过共享内存邮箱传递，配合软中断实现核间通知
typedef struct ipc_ctrl {
    uint32_t magic;                                     /* 魔数 */
    volatile wq_ipc_mailbox_t
        *mailbox[WQ_CORES_EN_MAX][WQ_CORES_EN_MAX - 1]; /* 邮箱地址表 */
    volatile struct list_head ipc_named_port_list;
} wq_ipc_ctrl_t;

// 消息发送：发送方把数据写入共享内存，触发软中断通知接收方
// 接收方在 ISR 中收到软中断，从共享内存读取数据，发信号量唤醒处理任务
```

## 第四层：正常/异常路径

### 任务创建

| 场景 | 正常路径 | 异常路径 |
|------|---------|---------|
| 栈大小 | 足够大，任务正常运行 | 栈太小，导致栈溢出，覆盖相邻内存 |
| 优先级 | 合理分配，高优先级任务及时执行 | 优先级过高导致低优先级任务饥饿 |
| 任务数量 | 在 RAM 范围内 | 创建过多任务，耗尽堆内存 |

### 任务调度

| 场景 | 正常路径 | 异常路径 |
|------|---------|---------|
| 高优先级就绪 | 抢占低优先级，立即执行 | 高优先级任务一直就绪，低优先级任务永远无法运行（饥饿） |
| 同优先级轮转 | 时间片用完，切换到下一个 | 任务不主动阻塞，时间片轮转正常，但整体响应变慢 |
| 任务阻塞 | 等待事件到达，进入 Blocked | 永久阻塞（事件永远不会到达），任务永远不执行 |

### 同步原语

| 场景 | 正常路径 | 异常路径 |
|------|---------|---------|
| 互斥量 | 获取→使用→释放，保护共享资源 | 死锁：两个任务互相等待对方持有的锁 |
| 信号量 | 正确的 give/take 配对 | 信号量泄露：give 了但没 task 去 take，计数一直增加 |
| 队列 | 发送→接收，数据完整传递 | 队列满时发送失败，数据丢失（未检查返回值） |
| ISR 中同步 | 使用 FromISR 版本 API | 使用非 FromISR 版本，可能导致调度器在 ISR 中运行 |

### 栈溢出

| 场景 | 正常路径 | 异常路径 |
|------|---------|---------|
| 栈空间 | 栈使用量在安全范围内 | 栈使用量超过分配值，覆盖相邻内存 |
| 检测 | 配置 `configCHECK_FOR_STACK_OVERFLOW` | 未配置，栈溢出后悄无声息地破坏内存 |
| 恢复 | 栈溢出钩子触发，记录错误 | 栈溢出破坏 TCB 或其他关键数据，系统崩溃 |

## 第五层：调试方法

### 1. 检查栈使用量

```c
// 在任务中定期检查
UBaseType_t high_water = uxTaskGetStackHighWaterMark(NULL);
// NULL 表示当前任务，返回任务运行以来栈剩余的最小值（word 数）
// 如果这个值接近 0，说明栈快溢出了

// 示例：检查并打印栈使用情况
void check_stack(void) {
    UBaseType_t free = uxTaskGetStackHighWaterMark(NULL);
    TaskHandle_t handle = xTaskGetCurrentTaskHandle();
    const char *name = pcTaskGetName(handle);
    printf("Task %s: stack free = %u words\n", name, free);
}
```

### 2. 查看所有任务状态

```c
// 获取系统任务状态
TaskStatus_t *task_array;
UBaseType_t task_count = uxTaskGetNumberOfTasks();
UBaseType_t total_runtime;

task_array = malloc(task_count * sizeof(TaskStatus_t));
uxTaskGetSystemState(task_array, task_count, &total_runtime);

for (int i = 0; i < task_count; i++) {
    printf("Task: %s, state: %d, priority: %u, stack: %u\n",
           task_array[i].pcTaskName,
           task_array[i].eCurrentState,  // 0=Ready, 1=Running, 2=Blocked, 3=Suspended
           task_array[i].uxCurrentPriority,
           task_array[i].usStackHighWaterMark);
}
```

### 3. 使用 FreeRTOS 的 Trace 功能

```c
// 在 FreeRTOSConfig.h 中启用：
#define configUSE_TRACE_FACILITY 1
#define configGENERATE_RUN_TIME_STATS 1

// 然后可以调用：
// vTaskGetRunTimeStats() - 打印每个任务的 CPU 使用率
// vTaskList() - 打印所有任务的详细信息
```

### 4. 栈溢出检测配置

```c
// 在 FreeRTOSConfig.h 中配置：
#define configCHECK_FOR_STACK_OVERFLOW 2
// 1 = 只检查栈指针是否溢出
// 2 = 检查栈指针 + 栈内容是否被破坏（更彻底，但更慢）

// 实现栈溢出钩子函数：
void vApplicationStackOverflowHook(TaskHandle_t xTask, char *pcTaskName) {
    printf("FATAL: Stack overflow in task %s!\n", pcTaskName);
    // 记录错误信息，然后重启或进入安全模式
    while (1);
}
```

### 5. 使用 GDB 调试任务

```bash
# 在 GDB 中查看所有 TCB
(gdb) print pxCurrentTCB           # 当前任务
(gdb) print pxReadyTasksLists      # 就绪任务列表
(gdb) print xDelayedTaskList1      # 延时任务列表

# 查看特定任务的栈内容
(gdb) print (char *)task_handle->pcTaskName  # 任务名
(gdb) print *task_handle->pxTopOfStack       # 栈顶内容
(gdb) print *task_handle->pxStack            # 栈底内容
```

## 第六层：实战练习

### 练习 1：创建多任务 LED 闪烁程序

使用 FreeRTOS API 创建三个任务，实现以下功能：

```c
// 任务 1：LED1 以 500ms 间隔闪烁（优先级 1）
// 任务 2：LED2 以 1000ms 间隔闪烁（优先级 1）
// 任务 3：打印任务状态信息，每 3 秒打印一次（优先级 2）

// 要求：
// 1. 使用 xTaskCreate 创建任务
// 2. 使用 vTaskDelay 实现定时
// 3. 在任务 3 中使用 uxTaskGetSystemState 获取所有任务状态
// 4. 观察：当任务 3（高优先级）运行时，是否会抢占任务 1 和 2？
// 5. 尝试修改优先级，观察行为变化
```

### 练习 2：阅读 WQ7036AX 的 FreeRTOS 配置

阅读 `/home/ys/wq7036a/wq-audio/wqcore/os/freertos_10_2_1/portable/riscv/FreeRTOSConfig.h`，回答以下问题：

1. `configUSE_PREEMPTION` 设置为 1 表示什么？如果设置为 0 会怎样？
2. `configTICK_RATE_HZ` 设置为 1000 意味着什么？Tick 周期是多少毫秒？
3. `configMINIMAL_STACK_SIZE` 的值是多少？这个值是怎么确定的（Kconfig 中可配置）？
4. `configUSE_TICKLESS_IDLE` 的作用是什么？什么场景下需要开启？
5. `configCHECK_FOR_STACK_OVERFLOW` 如何配置？栈溢出钩子函数的名字是什么？

### 练习 3：实现任务间通信

使用队列实现两个任务之间的数据传递：

```c
// 任务 A（发送者，优先级 1）：
// - 每 500ms 生成一个随机数（模拟传感器读数）
// - 通过队列发送给任务 B
// - 打印发送的值

// 任务 B（接收者，优先级 2）：
// - 阻塞等待队列数据
// - 收到数据后，打印收到值
// - 如果数据超过阈值，点亮 LED 报警

// 附加要求：
// 1. 使用 xQueueCreate 创建队列，队列长度为 10
// 2. 使用 xQueueSend 和 xQueueReceive 传递数据
// 3. 使用 xQueueReset 处理队列满的情况
// 4. 观察：如果发送速度超过接收速度，队列满了会发生什么？
```

### 练习 4：栈溢出检测实验

```c
// 创建一个栈很小的任务，故意让栈溢出，验证栈溢出检测机制

// 1. 在 FreeRTOSConfig.h 中配置：
//    #define configCHECK_FOR_STACK_OVERFLOW 2
// 2. 实现 vApplicationStackOverflowHook
// 3. 创建一个任务，栈大小设为 64 words（256 bytes）
// 4. 在任务中定义一个很大的局部变量（如 char buf[512]）
// 5. 运行并观察栈溢出钩子是否被触发
// 6. 使用 uxTaskGetStackHighWaterMark 观察栈使用量
```

## 自测与验收

1. 裸机超级循环有什么问题？RTOS 如何解决这个问题？

2. 任务的四种状态是什么？每个状态之间如何转换？

3. 上下文切换发生在哪两个时机？为什么不是在"任意时刻"？

4. FreeRTOS 的栈大小单位是什么？如何估算一个任务需要的栈大小？

5. 抢占式调度和时间片轮转有什么区别？在 FreeRTOS 中如何配置？

6. 什么是任务饥饿？如何避免？

7. `xSemaphoreGiveFromISR` 和 `xSemaphoreGive` 有什么区别？为什么 ISR 中必须用 `FromISR` 版本？

8. 互斥量和二进制信号量有什么区别？为什么 FreeRTOS 推荐用互斥量保护共享资源？

9. 空闲任务的作用是什么？如何利用空闲任务实现低功耗？

10. 如何检测和调试 FreeRTOS 的栈溢出问题？

## 延伸阅读

- [[interrupt-concurrency-中断并发同步]] —— ISR 与任务的同步机制详解
- [[memory-dma-内存管理与DMA]] —— 任务栈与堆的关系
- [[low-power-低功耗设计]] —— 空闲任务与 Tickless 休眠
- [[debug-methodology-嵌入式调试方法论]] —— 任务死锁和栈溢出的排查
- [[ipc-multicore-多核通信与IPC]] —— 多核 FreeRTOS 通信
- [[c-core-C语言核心]] —— 指针与内存布局

#flashcard

RTOS 与 FreeRTOS / RTOS 相比裸机的核心优势是什么？
RTOS 通过任务拆分和优先级调度，让不同实时性要求的功能独立运行，高优先级任务确保及时响应，阻塞的任务不浪费 CPU 时间。

RTOS 与 FreeRTOS / 任务四种状态及转换？
Ready（就绪）→ Running（运行）→ Blocked（阻塞）→ Ready。Running 被抢占回到 Ready，Running 等待事件进入 Blocked，事件到达从 Blocked 到 Ready。

RTOS 与 FreeRTOS / 上下文切换发生在哪两个时机？
SysTick 中断（每个 Tick 检查是否有更高优先级任务就绪）和系统调用（任务主动调用 API 如 vTaskDelay、xQueueSend 时）。

RTOS 与 FreeRTOS / FreeRTOS 栈大小的单位是什么？
单位是 word（4 字节）。xTaskCreate 中传入的栈大小是 word 数，不是字节数。

RTOS 与 FreeRTOS / 抢占式调度和时间片轮转的区别？
抢占式：高优先级任务就绪时立即打断低优先级任务。时间片轮转：同优先级任务之间轮流执行，每个任务一个 Tick 时间。