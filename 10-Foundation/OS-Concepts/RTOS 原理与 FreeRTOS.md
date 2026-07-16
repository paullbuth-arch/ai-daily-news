# RTOS 原理与 FreeRTOS

**一句话结论（20% 核心）**：RTOS（Real-Time Operating System，实时操作系统）让单片机"同时"干多件事——通过任务快速切换和优先级调度，让每个任务看起来都在独立运行。FreeRTOS 是嵌入式领域最流行的开源 RTOS。

---

## 第一层：核心认知

### 1.1 为什么需要 RTOS？

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

### 1.2 费曼类比：餐厅服务员

RTOS 调度器就像餐厅里的服务员领班：

- **任务（Task）**：每桌客人。
- **优先级（Priority）**：VIP 桌优先服务。
- **调度器（Scheduler）**：领班决定先服务哪桌。
- **上下文切换（Context Switch）**：服务员放下 A 桌的单子，拿起 B 桌的单子。
- **阻塞（Blocked）**：客人说"我去下洗手间"——这桌暂时不需要服务，服务员可以去服务其他桌。

```
高优先级任务就绪 ──→ 立刻抢走 CPU（抢占式调度）
低优先级任务运行中 ──→ 被高优先级任务打断
所有任务都在等待 ──→ 运行空闲任务（Idle Task）
```

### 1.3 核心概念速查表

| 术语 | 中文 | 含义 |
|---|---|---|
| Task | 任务 | 一段独立的执行流程，有自己的栈 |
| Scheduler | 调度器 | 决定哪个任务获得 CPU 时间 |
| Context Switch | 上下文切换 | 保存当前任务的寄存器，恢复另一个任务的寄存器 |
| Priority | 优先级 | 数字越大优先级越高（FreeRTOS） |
| Stack | 栈 | 每个任务私有的运行空间 |
| TCB | 任务控制块 | 存储任务状态、栈指针、优先级的结构体 |
| Queue | 队列 | 任务间传数据的管道 |
| Semaphore | 信号量 | 资源计数器，用于同步 |
| Mutex | 互斥量 | 保护共享资源的锁 |
| Tick | 系统节拍 | RTOS 的心跳，通常 1ms |

### 1.4 最小代码示例

```c
#include "FreeRTOS.h"
#include "task.h"

// 任务函数：一个独立的执行线程
void vLedTask(void *pvParameters)
{
    for (;;) {
        gpio_toggle(LED_PIN);                  // 翻转 LED
        vTaskDelay(pdMS_TO_TICKS(500));         // 延时 500ms，让出 CPU
    }
}

void vPrintTask(void *pvParameters)
{
    for (;;) {
        printf("Hello from print task\n");
        vTaskDelay(pdMS_TO_TICKS(1000));        // 延时 1000ms
    }
}

int main(void)
{
    // 创建任务：(函数, 名称, 栈大小(word), 参数, 优先级, 句柄)
    xTaskCreate(vLedTask,   "LED",   128, NULL, 1, NULL);
    xTaskCreate(vPrintTask, "Print", 256, NULL, 1, NULL);

    vTaskStartScheduler();  // 启动调度器（不会返回）
    return 0;
}
```

### 1.5 如果只记得一件事

> RTOS = 多任务 + 优先级调度 + 上下文切换。每个任务有自己的栈，调度器根据优先级决定谁运行，高优先级任务就绪时会立刻抢占 CPU。

---

## 第二层：实战理解

### 2.1 任务的四种状态

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
|---|---|---|
| Ready | 就绪 | 可以运行，但 CPU 正在执行其他更高优先级的任务 |
| Running | 运行 | 正在占用 CPU |
| Blocked | 阻塞 | 在等待某件事（延时、信号量、队列数据） |
| Suspended | 挂起 | 被手动暂停（vTaskSuspend），不参与调度 |

**关键理解**：当一个任务调用 `vTaskDelay()` 或 `xQueueReceive()` 时，它进入 **Blocked** 状态，CPU 会立刻切换到下一个最高优先级的就绪任务。这就是 RTOS 高效的原因——阻塞的任务不浪费 CPU 时间。

### 2.2 任务切换发生在什么时候？

FreeRTOS 的任务切换（Context Switch）只在两个时机发生：

1. **SysTick 中断（系统节拍）**：每个 Tick（通常 1ms）检查一次是否有更高优先级的任务就绪。
2. **系统调用**：任务主动调用 `vTaskDelay()`、`xQueueSend()`、`xSemaphoreGive()` 等 API 时。

```
Task A (running)
   ↓ vTaskDelay(100)  ← 系统调用触发切换
Task B (running)       ← B 是下一个最高优先级的就绪任务
   ↓ Tick 中断到达
Task C (running)       ← C 的优先级比 B 高，Tick 中断后抢占
```

**注意**：任务切换不是"随时"发生的，只在 Tick 中断和系统调用时发生。如果一个任务在做纯计算不调用任何 API，低优先级任务就只能等到下一次 Tick。

### 2.3 上下文切换的具体过程

上下文切换就是保存 A 的寄存器到 A 的栈，然后从 B 的栈恢复 B 的寄存器：

```
1. 把 CPU 所有寄存器（R0-R31、PC、SP…）压入当前任务的栈
2. 把当前栈顶地址保存到当前任务的 TCB（任务控制块）
3. 从下一个任务的 TCB 取出它的栈顶地址
4. 从那个栈里弹出寄存器值，恢复 CPU 状态
5. PC（程序计数器）恢复后，下一个任务从上次暂停的地方继续执行
```

在 ARM Cortex-M 上，这个过程由 **PendSV** 异常处理，硬件自动保存一部分寄存器（R0-R3、R12、LR、PC、xPSR），软件保存剩余部分。

在 RISC-V 上，全部由软件在 `portYIELD()` 中完成。

### 2.4 怎么选择任务栈大小？

栈空间存放的是：局部变量、函数参数、返回地址、中断嵌套时的上下文。

**估算方法**：

```
栈大小 = 最深调用路径的栈帧总和 + 中断嵌套额外开销 + 安全余量（20-30%）
```

**示例**：

```c
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

**栈溢出怎么检测？**

- `uxTaskGetStackHighWaterMark(task_handle)` — 返回任务运行以来栈的剩余最小值（word 数）。
- FreeRTOS 配置 `configCHECK_FOR_STACK_OVERFLOW` 可以在栈溢出时触发回调。

### 2.5 任务间通信方式

| 方式 | 适用场景 | 示例 |
|---|---|---|
| Queue（队列） | ISR → 任务 或 任务 → 任务 传数据 | UART 收到数据放入队列 |
| Semaphore（信号量） | 通知事件发生（不传数据） | ISR 通知任务"数据准备好了" |
| Mutex（互斥量） | 保护共享资源 | 多个任务共用 I2C 总线 |
| Task Notification | 轻量级，一对一通知 | 替代简单的信号量 |
| Event Group | 多事件组合等待 | 等 A 和 B 都完成再执行 |

```c
// 经典模式：ISR 发数据 → 队列 → 任务处理

QueueHandle_t xDataQueue;

void uart_isr(void) {
    uint8_t byte = UART_DR;
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;
    xQueueSendFromISR(xDataQueue, &byte, &xHigherPriorityTaskWoken);
    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}

void vProcessTask(void *p) {
    uint8_t data;
    for (;;) {
        if (xQueueReceive(xDataQueue, &data, portMAX_DELAY) == pdTRUE) {
            // 处理 data
        }
    }
}
```

### 2.6 项目中的应用

WQ7036A 的 ACORE 运行 FreeRTOS，典型任务划分：

| 任务 | 优先级 | 职责 |
|---|---|---|
| audio_task | 高 | 管理音频管道、与 DCORE 交互 |
| bt_task | 中高 | 蓝牙事件处理 |
| app_task | 中 | 应用逻辑、按键、LED |
| ipc_task | 中 | 处理与 BCORE/DCORE 的 IPC 消息 |
| idle_task | 0 | 空闲时进入低功耗 |

详见 [[中断 并发与同步机制]] 中关于 ISR 与任务同步的具体模式。

---

## 第三层：深入扩展

### 3.1 FreeRTOS 调度算法

FreeRTOS 支持三种调度模式（通过 `FreeRTOSConfig.h` 配置）：

| 模式 | 配置宏 | 行为 |
|---|---|---|
| 抢占式 + 时间片 | `configUSE_PREEMPTION=1` + `configUSE_TIME_SLICING=1` | 高优先级抢占；同优先级轮流执行 |
| 抢占式无时间片 | `configUSE_PREEMPTION=1` + `configUSE_TIME_SLICING=0` | 高优先级抢占；同优先级不轮换 |
| 协作式 | `configUSE_PREEMPTION=0` | 任务主动让出 CPU 才切换 |

**推荐**：大多数场景用"抢占式 + 时间片"。

### 3.2 FreeRTOS 源码：任务切换的关键路径

```
Tick 中断（SysTick Handler）
   ↓
xPortSysTickHandler()
   ↓
vTaskIncrementTickCount()     // Tick 计数 +1
   ↓
vTaskSwitchContext()           // 核心：选择下一个运行的任务
   ↓
pxCurrentTCB = 最高优先级的就绪任务
   ↓
portYIELD() / PendSV           // 触发实际的寄存器保存/恢复
```

`vTaskSwitchContext()` 的核心逻辑：
1. 遍历所有优先级队列（每个优先级一个就绪链表）。
2. 从最高非空优先级取出下一个任务。
3. 更新 `pxCurrentTCB` 指针。

### 3.3 实时性：硬实时 vs 软实时

| 类型 | 含义 | 后果 | 例子 |
|---|---|---|---|
| 硬实时（Hard Real-Time） | 必须在截止时间前完成 | 超时就出事故 | 安全气囊、刹车控制 |
| 软实时（Soft Real-Time） | 尽量快，偶尔超时可以 | 体验下降但不致命 | 音频播放、蓝牙 |

FreeRTOS 是**软实时**系统。WQ7036A 的音频管道接近硬实时要求（I2S 数据不能断），所以需要高优先级任务和 DMA 配合。

### 3.4 空闲任务与低功耗

当所有用户任务都阻塞时，FreeRTOS 运行**空闲任务（Idle Task）**。可以在空闲任务的回调中进入低功耗模式：

```c
// FreeRTOSConfig.h
#define configUSE_IDLE_HOOK 1

void vApplicationIdleHook(void) {
    // 所有任务都在等待，进入低功耗
    __WFI();  // Wait For Interrupt，CPU 休眠直到中断唤醒
}
```

详见 [[低功耗设计]]。

### 3.5 常见面试题

- **任务和线程有什么区别？** 在 RTOS 中通常没有本质区别，都是独立的执行流。在 Linux 中线程共享地址空间，任务（进程）不共享。
- **为什么 ISR 里不能调用 `vTaskDelay()`？** 延时会让出 CPU，但 ISR 不是任务，没有上下文可以保存/恢复。
- **FreeRTOS 的 `xSemaphoreGiveFromISR` 和 `xSemaphoreGive` 有什么区别？** `FromISR` 版本不阻塞、不会触发任务切换，由调用者决定是否需要 `portYIELD_FROM_ISR`。
- **什么是 configMINIMAL_STACK_SIZE？** FreeRTOS 内部使用的最小栈大小（word），低于这个值任务可能无法正常运行。
- **优先级最高的任务一直就绪会怎样？** 其他任务永远得不到 CPU 时间（饥饿），除非高优先级任务主动阻塞或延时。

### 3.6 核心术语表

| 英文 | 中文 | 说明 |
|---|---|---|
| RTOS | 实时操作系统 | Real-Time Operating System |
| Task | 任务 | 独立执行流 |
| Scheduler | 调度器 | 决定任务执行顺序 |
| Context Switch | 上下文切换 | 保存/恢复寄存器 |
| TCB | 任务控制块 | Task Control Block |
| Preemption | 抢占 | 高优先级任务打断低优先级 |
| Time Slice | 时间片 | 同优先级任务轮转的时间单位 |
| Semaphore | 信号量 | 资源计数 / 事件通知 |
| Mutex | 互斥量 | 共享资源保护锁 |
| Queue | 队列 | 任务间数据传递 |
| Idle Task | 空闲任务 | 所有任务阻塞时运行 |
| Tick | 系统节拍 | RTOS 的定时心跳 |

### 3.7 延伸阅读

- [[中断 并发与同步机制]] —— ISR 与任务的同步
- [[内存管理与 DMA]] —— 任务栈与堆的关系
- [[低功耗设计]] —— 空闲任务与休眠
- [[嵌入式调试方法论]] —— 任务死锁和栈溢出的排查
