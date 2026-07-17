---
type: concept
tags: [linux, driver, dma, interrupt, power-management, aiglass]
aliases: [DMA中断与电源管理, Linux驱动框架, Runtime PM]
---

# DMA、中断与电源管理（Linux 驱动）

## 一句话结论

Linux 驱动中 DMA 负责搬运数据，中断负责响应硬件事件，电源管理（Runtime PM/System PM）负责省电。三者是驱动开发中必打交道的基础设施。

## 30秒先看懂

- Linux 提供了统一的 DMA API（dma_alloc_coherent/dma_map_single）屏蔽了不同 SoC 的 DMA 控制器差异。中断注册使用 devm_request_irq，ISR 必须快速返回，复杂工作推迟到 tasklet 或 workqueue 中执行。电源管理分为三个层次：Runtime PM（单个设备粒度的运行时省电，微秒级响应）、System PM（系统休眠/唤醒，毫秒级响应）和 Clock Gating（硬件模块级别的时钟开关，纳秒级响应）。DMA Cache 一致性用 dma_alloc_coherent 自动保证，或者用 dma_alloc_noncoherent 配合手动 sync。中断共享时多个设备共用同一中断号，ISR 需要判断是否自己的设备触发。

## 学完以后应该能做什么

**第一遍看完后可以：**
- 使用 Linux DMA API 分配和管理缓冲区
- 注册中断处理函数，正确区分 ISR 和 tasklet/workqueue
- 使用 Runtime PM 开关设备电源
- 理解 DMA Cache 一致性问题及其解决方法

**进阶后可以：**
- 编写 DMA 引擎驱动，支持描述符链和 scatter-gather
- 实现设备树的 Runtime PM 回调
- 调试中断风暴和 DMA 传输错误
- 设计复杂的电源管理策略

## 前置知识

- Linux 平台驱动框架（probe/remove）
- DMA 和中断的基本概念
- 设备树基础知识

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 直接内存访问 | DMA | Direct Memory Access，硬件外设和内存之间直接搬运数据 |
| 中断服务程序 | ISR | Interrupt Service Routine，中断发生时执行的函数 |
| 运行时电源管理 | Runtime PM | 设备空闲时自动关闭，使用时自动唤醒 |
| 系统电源管理 | System PM | 系统休眠/唤醒时的电源管理 |
| 工作队列 | Workqueue | 可以睡眠的延迟执行机制，适合中断下半部 |
| 微型任务 | Tasklet | 不可睡眠的软中断上下文，适合快速处理 |
| 一致 DMA 缓冲区 | DMA Coherent | 保证 Cache 和 RAM 一致的 DMA 缓冲区 |
| 流式 DMA 映射 | DMA Streaming | 单次传输的 DMA 映射，需要手动 sync |
| 时钟门控 | Clock Gating | 硬件模块级别的时钟开关 |

## 第一层：费曼心智模型

### 类比：公司前台、快递员和电费

- **DMA** = 快递员：你告诉他从仓库 A 搬货到仓库 B，他自己搬，搬完通知你
- **中断** = 门铃：有人来找你，门铃响了，你去开门（ISR），如果事情复杂就先记下来（tasklet），回头再处理（workqueue）
- **电源管理** = 关灯关空调：下班了关灯（Runtime PM），放假了拉总闸（System PM）

**边界：**
- ISR 不能睡觉——不能调用可能睡眠的函数（如 mutex_lock、kmalloc(GFP_KERNEL)）
- 不是所有设备都适合 Runtime PM——频繁开关的设备可能因为开关开销反而更耗电
- DMA 不是万能的——小数据量（< 64 字节）CPU 搬更快

### 场景演练：UART 接收数据

1. UART 收到一个字节，触发中断
2. ISR 中读取 UART 数据寄存器，把数据放入环形缓冲区
3. ISR 调用 `schedule_work()` 把数据处理推迟到 workqueue
4. ISR 返回（快速，不阻塞）
5. workqueue 函数执行：从环形缓冲区取出数据，解析协议帧
6. 如果系统空闲，Runtime PM 自动关闭 UART 模块
7. 下一个数据到来时，硬件自动唤醒 UART

## 第二层：原理/时序/约束

### DMA API 使用

```c
// 分配 DMA 缓冲区（保证 Cache 一致性）
dma_addr_t dma_handle;
void *cpu_addr = dma_alloc_coherent(dev, size, &dma_handle, GFP_KERNEL);
// cpu_addr → CPU 用这个指针访问
// dma_handle → DMA 控制器用这个地址

// 单次流式传输
dma_map_single(dev, cpu_addr, size, DMA_TO_DEVICE);
// 启动 DMA 传输...
dma_unmap_single(dev, dma_handle, size, DMA_TO_DEVICE);

// 释放
dma_free_coherent(dev, size, cpu_addr, dma_handle);
```

### 中断注册与处理

```c
// 注册中断处理函数
int irq = platform_get_irq(pdev, 0);
int ret = devm_request_irq(dev, irq, my_isr, IRQF_TRIGGER_RISING,
                           "my-device", dev);

// 中断处理函数（ISR）
static irqreturn_t my_isr(int irq, void *dev_id) {
    // 处理中断（必须快速返回，不能阻塞）
    uint32_t status = readl(reg_base + INT_STATUS);
    if (status & RX_READY) {
        // 快速处理：读取数据到环形缓冲区
        rbuf_put(&rx_buf, readl(reg_base + RX_DATA));
    }
    // 复杂工作推迟到 workqueue
    schedule_work(&my_work);
    return IRQ_HANDLED;
}
```

### Runtime PM

```c
// 驱动 probe 中初始化
pm_runtime_enable(dev);
pm_runtime_get_sync(dev);   // 唤醒设备
// ... 使用设备 ...
pm_runtime_put(dev);         // 允许设备休眠

// Runtime PM 回调
static int my_dev_runtime_suspend(struct device *dev) {
    // 保存寄存器状态，关闭时钟
    clk_disable(my_clk);
    return 0;
}

static int my_dev_runtime_resume(struct device *dev) {
    // 恢复时钟，重新配置寄存器
    clk_enable(my_clk);
    my_dev_restore_regs(dev);
    return 0;
}
```

## 第三层：真实 SDK 代码

### reGlasses 中的 DMA/中断/PM

在 reGlasses 项目中，V881 侧的 Linux 驱动框架使用标准 Linux DMA API。

参考路径 `/home/ys/aiglass/tina-v861/kernel/linux-6.6-xuantie/drivers/` 下的驱动代码：

```c
// 平台驱动标准结构
static struct platform_driver my_driver = {
    .probe  = my_probe,
    .remove = my_remove,
    .driver = {
        .name = "my-device",
        .of_match_table = my_of_match,
        .pm = &my_dev_pm_ops,  // Runtime PM + System PM
    },
};

// PM 操作集
static const struct dev_pm_ops my_dev_pm_ops = {
    .runtime_suspend = my_runtime_suspend,
    .runtime_resume  = my_runtime_resume,
    .suspend         = my_system_suspend,
    .resume          = my_system_resume,
};
```

### 蓝牙低功耗管理

参考 `/home/ys/aiglass/tina-v861/bsp/drivers/bluetooth/bcm_btlpm.c` 中的蓝牙低功耗管理：

```c
// 蓝牙设备的 Runtime PM
static int bcm_btlpm_runtime_suspend(struct device *dev) {
    // 通过 UART 发送休眠命令给蓝牙芯片
    // 关闭蓝牙芯片的供电
    gpio_set_value(bt_dev->shutdown, 0);
    return 0;
}

static int bcm_btlpm_runtime_resume(struct device *dev) {
    // 恢复蓝牙芯片供电
    gpio_set_value(bt_dev->shutdown, 1);
    // 等待芯片启动，重新初始化
    msleep(100);
    return 0;
}
```

## 第四层：正常/异常路径

### 正常路径

DMA：分配缓冲区 → 配置传输 → 启动 DMA → 完成中断
中断：硬件触发 → ISR 快速处理 → tasklet/workqueue 处理剩余工作
PM：设备使用中 → 空闲 → Runtime suspend → 使用请求 → Runtime resume

### 异常路径

| 异常场景 | 现象 | 原因 | 处理方式 |
|---------|------|------|---------|
| DMA Cache 不一致 | 数据偶尔出错 | 用了 noncoherent 但没手动 sync | 用 coherent 分配或手动 sync |
| ISR 中阻塞 | 系统卡死 | ISR 中调了可能 sleep 的函数 | 检查 ISR 中不能调用的函数 |
| 中断风暴 | CPU 100% 处理中断 | 共享中断未正确判断设备 | ISR 中检查硬件状态寄存器 |
| 忘 resume | 唤醒后设备不工作 | 寄存器在休眠时丢失 | 在 resume 中重新配置寄存器 |
| DMA 超时 | 传输未完成 | 地址错误或硬件故障 | 检查 DMA 配置参数 |

## 第五层：调试方法

```c
// 打印 DMA 缓冲区信息
void dma_dump_buf(struct device *dev, dma_addr_t handle, size_t size) {
    printf("DMA buffer: handle=0x%08lx, size=%zu\n", handle, size);
}

// 中断计数
static atomic_t irq_count = ATOMIC_INIT(0);
static irqreturn_t my_isr(int irq, void *dev_id) {
    atomic_inc(&irq_count);
    // ... 处理中断 ...
    return IRQ_HANDLED;
}

// 查看中断统计
cat /proc/interrupts | grep my-device

// 查看 Runtime PM 状态
cat /sys/devices/.../power/runtime_status
cat /sys/devices/.../power/runtime_suspended_time
```

## 第六层：实战练习

### 练习 1：中断处理（基础）

编写一个简单的字符驱动，注册中断处理函数：
1. 在 probe 中申请中断
2. ISR 中简单处理（读取状态寄存器）
3. 把复杂处理通过 workqueue 推迟
4. 验证 `/proc/interrupts` 中可以看到中断计数

### 练习 2：Runtime PM 实现（进阶）

为设备驱动添加 Runtime PM 支持：
1. 实现 `runtime_suspend` 和 `runtime_resume` 回调
2. 在 probe 中调用 `pm_runtime_enable`
3. 在 open/close 中调用 `pm_runtime_get/put`
4. 用 GPIO 翻转验证 PM 状态切换

### 练习 3：阅读 DMA 驱动源码（深入）

阅读 `/home/ys/aiglass/tina-v861/kernel/linux-6.6-xuantie/drivers/dma/` 下的 DMA 控制器驱动，回答：
1. DMA 驱动如何注册 DMA 通道？
2. 描述符链是如何实现的？
3. 传输完成中断是如何处理的？
4. 驱动支持哪些传输模式？

## 自测与验收

1. Linux 中 `dma_alloc_coherent` 和 `dma_alloc_noncoherent` 的区别是什么？
2. 为什么 ISR 中不能调用可能睡眠的函数？
3. Runtime PM 和 System PM 的区别是什么？
4. 什么是中断共享？多个设备共享中断时 ISR 需要做什么？
5. tasklet 和 workqueue 的区别是什么？分别在什么场景使用？
6. 如何查看设备的 Runtime PM 状态？
7. DMA 传输中 Cache 一致性问题如何解决？

## 延伸阅读

- [[memory-dma-内存管理与DMA]] — FreeRTOS 侧的 DMA 详解
- [[interrupt-concurrency-中断并发同步]] — 中断的底层原理
- [[low-power-低功耗设计]] — 低功耗的通用设计方法

## #flashcard

**Q: Linux DMA API 中 coherent 和 streaming 的区别？**
A: Coherent 保证 Cache 始终一致（适合长期使用），Streaming 需要手动 sync（适合单次传输）。

**Q: 为什么 ISR 中不能调用可能睡眠的函数？**
A: ISR 在中断上下文中运行，不能睡眠（没有进程上下文，没有调度器支持）。

**Q: Runtime PM 和 System PM 的区别？**
A: Runtime PM 是单个设备空闲时自动省电，System PM 是整个系统休眠/唤醒。

**Q: tasklet 和 workqueue 的区别？**
A: tasklet 在软中断上下文运行，不能睡眠；workqueue 在进程上下文运行，可以睡眠。

**Q: 中断共享时 ISR 需要做什么？**
A: 检查硬件状态寄存器，确认中断是否属于自己的设备，如果不是则返回 IRQ_NONE。