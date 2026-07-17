---
type: concept
tags: [embedded, reliability, watchdog, exception, fault-handling, crc]
aliases: [系统可靠性, 异常处理, 看门狗, 降级运行]
---

# 系统可靠性与异常处理

## 一句话结论

可靠性就是让系统在"出错的时候还能活下来"——核心手段是**看门狗**（程序跑飞就复位）、**异常处理**（崩溃时保留现场）、**降级运行**（主功能坏了保核心功能）、**日志记录**（事后能复盘）。

## 30秒先看懂

- 可靠的嵌入式系统需要四层保护：看门狗（检测到程序跑飞后自动复位）、异常处理（HardFault 发生时保存 PC/LR 等关键寄存器）、降级运行（主功能失效时保留核心功能，如蓝牙断开后切换本地控制）和日志记录（崩溃后能读取复位原因和最后状态）。看门狗不能放在定时器中断里喂——因为中断可能正常但主循环已经卡死。多任务系统中，所有关键任务都完成后才喂狗，不是单个任务喂。HardFault 发生后最重要的事是保存 PC 和 LR 寄存器，这样复位后可以通过 addr2line 定位到崩溃的代码行。

## 学完以后应该能做什么

**第一遍看完后可以：**
- 正确配置看门狗，避免在中断里喂狗
- 编写 HardFault_Handler 保存崩溃现场
- 实现简单的降级运行策略
- 使用复位原因寄存器诊断重启原因

**进阶后可以：**
- 设计多任务看门狗喂狗策略
- 实现 CRC 校验保护通信数据
- 搭建故障树分析（FTA）系统可靠性
- 设计 A/B 分区 OTA 回滚机制

## 前置知识

- 中断的基本概念（中断向量表、ISR）
- 栈的概念（栈帧、压栈、出栈）
- 定时器的基本原理

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 看门狗 | Watchdog / WDT | 硬件定时器，超时未喂狗则复位系统 |
| 硬件错误 | HardFault | CPU 执行非法操作（如访问非法地址、除零）时触发的异常 |
| 断言 | Assert | 运行时条件检查，条件不满足时触发错误处理 |
| 降级运行 | Graceful Degradation | 主功能失败时保留核心功能继续运行 |
| 心跳 | Heartbeat | 定期发出的信号，证明系统仍然存活 |
| 故障树分析 | FTA | Fault Tree Analysis，从上到下分析系统失效的原因 |
| 失效模式与影响分析 | FMEA | Failure Mode and Effects Analysis，逐个分析组件失效的影响 |
| 循环冗余校验 | CRC | Cyclic Redundancy Check，检测数据传输/存储错误 |
| 欠压复位 | Brown-Out Reset | 供电电压过低时自动复位 |
| 复位原因 | Reset Reason | 记录上次复位来源的寄存器 |

## 第一层：费曼心智模型

### 类比：汽车安全系统

可靠性就像汽车的安全系统：

| 汽车安全 | 嵌入式可靠性 |
|---------|-------------|
| 安全带 | 看门狗（Watchdog）——出事时把你拉住（复位） |
| 安全气囊 | 异常处理（Exception Handler）——碰撞发生时保护人 |
| 备胎 | 降级运行（Graceful Degradation）——主轮坏了还能慢慢开 |
| 行车记录仪 | 日志记录（Crash Log）——出事后能复盘 |
| 仪表盘报警灯 | 断言和健康检查——问题刚出现就提醒 |

**边界：**
- 看门狗不是万能药——它只能复位，不能修复硬件损坏
- 降级运行需要提前设计——临时想"出了问题怎么办"往往来不及
- 过多日志影响性能——日志系统和业务逻辑需要平衡

### 场景演练：程序跑飞

1. 某个指针意外变成空指针，`memcpy(buf, src, len)` 中 `buf` 为 NULL
2. CPU 访问地址 0，触发 HardFault 异常
3. HardFault_Handler 被执行：
   - 保存 PC 寄存器的值（崩溃地址）
   - 保存 LR 寄存器的值（调用者地址）
   - 保存栈指针 SP
   - 把崩溃信息写入 .noinit 段（复位后不会丢失）
4. 系统复位
5. 启动代码读取复位原因，发现是 HardFault 引起的复位
6. 输出崩溃信息到串口：PC=0x00001234
7. 用 `addr2line -e app.elf 0x00001234` 定位到具体的 C 代码行

## 第二层：原理/时序/约束

### 看门狗原理

```
正常运行：
软件每隔 500ms 喂一次狗 → 计时器重置 → 永远不会到 0

程序跑飞：
软件卡在死循环里，忘记喂狗 → 计时器到 0 → 系统复位
```

### 多任务喂狗模式

```c
// 每个关键任务完成后设置标志
volatile uint32_t task_health = 0;

void audio_task(void *p) {
    for (;;) {
        process_audio();
        task_health |= BIT(0);  // 音频任务完成
        vTaskDelay(pdMS_TO_TICKS(10));
    }
}

void bt_task(void *p) {
    for (;;) {
        process_bluetooth();
        task_health |= BIT(1);  // 蓝牙任务完成
        vTaskDelay(pdMS_TO_TICKS(50));
    }
}

// 喂狗任务：所有关键任务都完成后才喂
void watchdog_task(void *p) {
    for (;;) {
        if (task_health == (BIT(0) | BIT(1))) {
            watchdog_feed();
            task_health = 0;
        }
        vTaskDelay(pdMS_TO_TICKS(500));
    }
}
```

### 复位原因

| 复位原因 | 说明 | 处理方式 |
|---------|------|---------|
| Power-On Reset | 上电复位 | 正常启动 |
| Watchdog Reset | 看门狗超时 | 输出日志，检查程序是否卡死 |
| Software Reset | 软件主动复位 | 正常重启流程 |
| External Reset | 外部引脚触发 | 检查外部复位电路 |
| Brown-Out Reset | 电压过低 | 检查电源供电 |

## 第三层：真实 SDK 代码

### WQ7036A 看门狗驱动

看门狗驱动在 `/home/ys/wq7036a/wq-audio/wqcore/driver/periph/common/hal/wdt/wq_wdt.h`：

```c
// 初始化看门狗
void wq_wdt_init(void);

// 喂狗（重置计时器）
void wq_wdt_do_feed(void);

// 设置喂狗周期（秒）
void wq_wdt_set_feed_period(uint32_t period);

// 检查是否需要喂狗
bool wq_wdt_need_feed(void);

// 复位系统
void wq_wdt_do_reset(void);

// 禁用所有看门狗
void wq_wdt_disable_all(void);

// 检查看门狗超时
uint32_t wq_wdt_check_timeout(void);
```

### 复位原因分析

参考 `/home/ys/wq7036a/wq-audio/wqcore/components/startup/boot/src/boot_reason.c`：

```c
void main(void) {
    uint32_t reason = read_reset_reason();

    if (reason & RESET_REASON_WDT) {
        LOG_WARN("Previous reset: Watchdog timeout");
    } else if (reason & RESET_REASON_BOR) {
        LOG_WARN("Previous reset: Brown-out (voltage drop)");
    } else if (reason & RESET_REASON_POR) {
        LOG_INFO("Normal power-on reset");
    }

    clear_reset_reason();
    // ... 正常启动 ...
}
```

### HardFault 处理

```c
void HardFault_Handler(void) {
    // 保存崩溃信息到固定的 RAM 地址（.noinit 段，复位后不丢失）
    crash_info_t *crash = (crash_info_t *)CRASH_INFO_ADDR;
    crash->pc = __get_PC();    // 崩溃时的程序计数器
    crash->lr = __get_LR();    // 返回地址
    crash->sp = __get_SP();    // 栈指针
    crash->timestamp = get_tick();

    NVIC_SystemReset();  // 复位
}
```

## 第四层：正常/异常路径

### 正常路径

系统启动 → 配置看门狗 → 主循环中定期喂狗 → 正常执行

### 异常路径

| 异常场景 | 现象 | 原因 | 处理方式 |
|---------|------|------|---------|
| 看门狗超时复位 | 系统反复重启 | 程序卡死或看门狗周期太短 | 检查喂狗位置，确保主循环中喂狗 |
| HardFault 崩溃 | 程序突然停止 | 空指针、除零、访问非法地址 | 保存崩溃现场，复位后分析 PC 值 |
| 数据 CRC 校验失败 | 通信数据错乱 | 线路干扰或 Flash 存储损坏 | 请求重发或使用备份数据 |
| 栈溢出 | 变量被意外覆盖 | 递归太深或局部变量太大 | 增大栈空间或检查递归 |
| 降级运行 | 功能受限但不崩溃 | 某个模块异常 | 切换到备用方案，记录日志 |

## 第五层：调试方法

### 看门狗调试

```c
// 开发阶段：关闭看门狗，方便断点调试
void debug_init(void) {
    wq_wdt_disable_all();  // 开发阶段关闭看门狗
}

// 查看喂狗次数
uint32_t feed_cnt = wq_wdt_get_feed_cnt();
printf("Watchdog feed count: %lu\n", feed_cnt);
```

### 崩溃分析

```bash
# 从 crashdump 地址定位代码
riscv64-unknown-elf-addr2line -e build/acore/app_acore.elf -f 崩溃PC地址

# 反汇编查看崩溃附近的代码
riscv64-unknown-elf-objdump -d build/acore/app_acore.elf | grep -A20 "崩溃PC地址:"

# 查看栈回溯
(gdb) target remote :3333
(gdb) backtrace full
(gdb) info registers
```

### 健康监控

```c
void health_monitor_task(void *p) {
    for (;;) {
        uint32_t free_heap = xPortGetFreeHeapSize();
        uint32_t watermark = uxTaskGetStackHighWaterMark(NULL);

        if (free_heap < MIN_HEAP_THRESHOLD) {
            LOG_ERROR("Low heap: %lu bytes", free_heap);
        }
        if (watermark < MIN_STACK_THRESHOLD) {
            LOG_ERROR("Stack low: %lu words remaining", watermark);
        }

        vTaskDelay(pdMS_TO_TICKS(60000));  // 每分钟检查一次
    }
}
```

## 第六层：实战练习

### 练习 1：看门狗实验（基础）

实现一个看门狗驱动的闪烁 LED 程序：
1. 初始化看门狗，超时时间设为 3 秒
2. 主循环中每 500ms 喂狗一次
3. LED 每 500ms 翻转一次
4. 故意取消喂狗，观察 LED 熄灭（系统复位）
5. 复位后读取复位原因，确认是看门狗复位

### 练习 2：实现多任务喂狗（进阶）

在多任务系统中实现健壮的喂狗策略：
1. 创建 3 个任务（音频、蓝牙、显示）
2. 每个任务完成后设置对应的健康标志位
3. 创建喂狗任务，检查所有标志位都置位后才喂狗
4. 模拟其中一个任务卡死，观察看门狗是否触发
5. 记录哪个任务没有及时完成

### 练习 3：阅读看门狗源码（深入）

阅读 `/home/ys/wq7036a/wq-audio/wqcore/driver/periph/common/hal/wdt/wq_wdt.h` 和相关实现，回答：
1. WQ7036A 有几个看门狗？分别属于哪个核？
2. 全局看门狗和系统看门狗的区别是什么？
3. `wq_wdt_auto_feed()` 的作用是什么？
4. 看门狗超时后的处理方式是什么？

## 自测与验收

1. 看门狗为什么不能放在定时器中断里喂？
2. HardFault 发生后最重要的事是什么？
3. 什么是降级运行？请举一个具体的例子。
4. CRC 和 MD5/SHA 的区别是什么？CRC 用在什么场景？
5. 多任务系统中如何设计正确的喂狗策略？
6. 复位原因寄存器有什么用？常见的复位原因有哪些？
7. 什么是 FTA（故障树分析）？如何用它对系统做可靠性分析？

## 延伸阅读

- [[debug-methodology-嵌入式调试方法论]] — HardFault 定位的详细方法
- [[boot-ota-启动流程与OTA升级]] — OTA 失败回滚
- [[interrupt-concurrency-中断并发同步]] — 数据竞争和死锁
- [[low-power-低功耗设计]] — 低功耗下看门狗的处理

## #flashcard

**Q: 看门狗为什么不能放在定时器中断里喂？**
A: 因为定时器中断可能正常运行但主循环已经卡死，这时看门狗不会超时，起不到保护作用。

**Q: HardFault 发生后最重要的事是什么？**
A: 保存 PC 和 LR 寄存器，定位崩溃的代码行。

**Q: 什么是降级运行？**
A: 主功能失效时保留核心功能，而不是整个系统崩溃。例如蓝牙断开后切换本地控制。

**Q: 可靠的嵌入式系统四层保护是什么？**
A: 看门狗（复位）+ 异常处理（保存现场）+ 降级运行（保核心）+ 日志记录（事后复盘）。

**Q: CRC 的作用是什么？**
A: 检测数据传输或存储中的错误，快速、简单，适合嵌入式通信场景。