# DMA、中断与电源管理（Linux 驱动）

**一句话结论（20% 核心）**：Linux 驱动中 DMA 负责搬运数据，中断负责响应硬件事件，电源管理（Runtime PM/System PM）负责省电。三者是驱动开发中必打交道的基础设施。

---

## 第一层：核心认知（必须先看懂）

### 1.1 DMA：数据搬运工

Linux 提供了统一的 DMA API，屏蔽了不同 SoC 的 DMA 控制器差异：

```c
// 分配 DMA 缓冲区（保证 Cache 一致性）
dma_addr_t dma_handle;
void *cpu_addr = dma_alloc_coherent(dev, size, &dma_handle, GFP_KERNEL);
// cpu_addr → CPU 用这个指针访问
// dma_handle → DMA 控制器用这个地址

// 单次传输
dma_map_single(dev, cpu_addr, size, DMA_TO_DEVICE);
// 启动 DMA 传输...
dma_unmap_single(dev, dma_handle, size, DMA_TO_DEVICE);

// 释放
dma_free_coherent(dev, size, cpu_addr, dma_handle);
```

### 1.2 中断：硬件事件的响应

```c
// 注册中断处理函数
int irq = platform_get_irq(pdev, 0);
int ret = devm_request_irq(dev, irq, my_isr, IRQF_TRIGGER_RISING,
                           "my-device", dev);

// 中断处理函数（ISR）
static irqreturn_t my_isr(int irq, void *dev_id) {
    // 处理中断（必须快速返回，不能阻塞）
    // 复杂工作放到 tasklet 或 workqueue 中
    schedule_work(&my_work);  // 推迟到 workqueue
    return IRQ_HANDLED;
}
```

### 1.3 电源管理：分层省电

| 机制 | 粒度 | 触发时机 | 延迟 |
|------|------|---------|------|
| **Runtime PM** | 单个设备 | 设备空闲时 | 微秒级 |
| **System PM** (suspend/resume) | 整个系统 | 休眠/唤醒 | 毫秒级 |
| **Clock Gating** | 单个模块 | 模块不使用时 | 纳秒级 |

```c
// Runtime PM 的使用
pm_runtime_enable(dev);
pm_runtime_get_sync(dev);   // 唤醒设备
// ... 使用设备 ...
pm_runtime_put(dev);         // 允许设备休眠
```

### 1.4 如果只记得一件事

> DMA 用 `dma_alloc_coherent` 分配缓冲区并保证 Cache 一致性。中断用 `devm_request_irq` 注册，ISR 必须快速返回。电源管理用 Runtime PM 按需开关设备。

---

## 第二层：实战理解

### 2.1 常见坑

| 问题 | 现象 | 根因 |
|------|------|------|
| DMA Cache 不一致 | 数据偶尔出错 | 用了 `dma_alloc_noncoherent` 但没手动 sync |
| ISR 中阻塞 | 系统卡死 | ISR 中调了可能 sleep 的函数 |
| 中断共享 | 中断风暴 | 多个设备共享同一中断号，ISR 要判断是否自己的中断 |
| 电源管理忘 resume | 唤醒后设备不工作 | 寄存器在休眠时丢失，需要重新配置 |

### 2.2 在 reGlasses 项目中怎么用

WQ7036AX 侧（FreeRTOS）的 DMA 概念见 [[memory-dma-内存管理与DMA]]。V881 侧（Linux）的 DMA 驱动使用 Linux DMA API。两者的核心概念一样（DMA 搬运数据，中断通知完成），但 API 不同。

---

## 第三层：延伸阅读

- [[memory-dma-内存管理与DMA]] — FreeRTOS 侧的 DMA 详解
- [[interrupt-concurrency-中断并发同步]] — 中断的底层原理
- [[low-power-低功耗设计]] — 低功耗的通用设计方法