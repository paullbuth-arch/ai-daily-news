# 系统可靠性与异常处理

**一句话结论（20% 核心）**：可靠性就是让系统在"出错的时候还能活下来"——核心手段是**看门狗**（程序跑飞就复位）、**异常处理**（崩溃时保留现场）、**降级运行**（主功能坏了保核心功能）、**日志记录**（事后能复盘）。

---

## 第一层：核心认知

### 1.1 费曼类比：汽车安全系统

可靠性就像汽车的安全系统：

| 汽车安全 | 嵌入式可靠性 |
|---|---|
| 安全带 | **看门狗（Watchdog）**——出事时把你拉住（复位） |
| 安全气囊 | **异常处理（Exception Handler）**——碰撞发生时保护人 |
| 备胎 | **降级运行（Graceful Degradation）**——主轮坏了还能慢慢开 |
| 行车记录仪 | **日志记录（Crash Log）**——出事后能复盘 |
| 仪表盘报警灯 | **断言和健康检查**——问题刚出现就提醒 |

### 1.2 核心机制速查表

| 机制 | 作用 | 关键设计 |
|---|---|---|
| **看门狗** | 程序跑飞时自动复位 | 定期"喂狗"，不喂就复位 |
| **断言（Assert）** | 提前发现不可接受的错误 | 开发阶段崩在原地 |
| **异常向量表** | 统一管理 HardFault、NMI 等 | 在 Handler 中保存现场 |
| **心跳检测** | 证明系统还活着 | 定时翻转 GPIO / 发日志 |
| **降级策略** | 主功能失败时保留核心功能 | 蓝牙断了还能本地控制 |
| **CRC/校验** | 数据完整性保护 | 通信/存储数据都要校验 |

### 1.3 如果只记得一件事

> 可靠的嵌入式系统 = 出错了能检测到 + 检测到能恢复 + 恢复不了能复位 + 复位后能记日志。

---

## 第二层：实战理解

### 2.1 看门狗（Watchdog）详解

看门狗是一个硬件定时器。软件必须定期"喂狗"（重置计时器），如果不喂，计时器到 0 就会触发系统复位。

```
正常运行：
软件每隔 500ms 喂一次狗 → 计时器重置 → 永远不会到 0

程序跑飞：
软件卡在死循环里，忘记喂狗 → 计时器到 0 → 系统复位
```

```c
// 看门狗配置示例（伪代码）

void system_init(void) {
    // 配置看门狗：超时时间 2 秒
    watchdog_init(2000);  // 2000ms
    watchdog_enable();
}

// 在主循环或定时任务中定期喂狗
void main_loop(void) {
    for (;;) {
        process_tasks();
        watchdog_feed();   // 喂狗（重置计时器）
        vTaskDelay(pdMS_TO_TICKS(100));
    }
}
```

**喂狗策略的关键问题**：

| 问题 | 错误做法 | 正确做法 |
|---|---|---|
| 喂狗位置 | 放在定时器中断里 | 放在主循环中（中断正常不代表主循环正常） |
| 喂狗频率 | 和看门狗超时时间一样长 | 至少是超时时间的 1/2~1/3 |
| 多任务喂狗 | 只在一个任务里喂 | 所有关键任务都完成后才喂 |
| 调试时 | 开着看门狗断点调试 | 开发阶段关闭看门狗 |

**多任务系统的喂狗模式**：

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
            task_health = 0;  // 重置
        }
        vTaskDelay(pdMS_TO_TICKS(500));
    }
}
```

### 2.2 HardFault 处理：保存崩溃现场

HardFault 发生时，最重要的是**保留现场**，让工程师事后能分析崩溃原因。

```c
void HardFault_Handler(void)
{
    // 1. 保存关键寄存器到 Flash 或固定 RAM 区域
    __asm volatile(
        "push {lr}           \n"
        "mrs r0, psp         \n"  // 取进程栈指针
        "bl  save_fault_info \n"
        "pop {lr}            \n"
    );

    // 2. 尝试记录崩溃信息（不能阻塞）
    // save_fault_info() 会把 PC、LR、SP、调用栈写入固定 RAM 地址

    // 3. 复位系统
    NVIC_SystemReset();
}

// 保存崩溃信息的函数
void save_fault_info(uint32_t *stack_ptr)
{
    fault_info_t info;
    info.pc = stack_ptr[6];     // PC（崩溃地址）
    info.lr = stack_ptr[5];     // LR（调用者）
    info.sp = (uint32_t)stack_ptr;
    info.timestamp = get_tick();

    // 写到固定 RAM 地址（复位后仍可读取）
    *(fault_info_t **)FAULT_INFO_ADDR = &info;
}
```

**复位后读取上次崩溃信息**：

```c
void main(void) {
    // 检查是否有上次的崩溃记录
    if (is_watchdog_reset() || is_hardfault_reset()) {
        fault_info_t *info = *(fault_info_t **)FAULT_INFO_ADDR;
        if (info && info->pc != 0xFFFFFFFF) {
            log_error("Previous crash: PC=0x%08X, LR=0x%08X",
                      info->pc, info->lr);
        }
    }
    // ... 正常启动 ...
}
```

### 2.3 降级运行策略

当某个模块出错时，不是直接崩溃，而是保留核心功能：

| 场景 | 正常模式 | 降级模式 |
|---|---|---|
| 蓝牙断开 | 手机 APP 控制 | 本地按键控制 |
| 音频 DSP 崩溃 | 高质量音频 | 直通音频（跳过 DSP） |
| 传感器故障 | 精确测量 | 使用上次有效值 / 默认值 |
| Flash 写入失败 | OTA 升级 | 继续使用旧版本 |

```c
void bt_connection_handler(bt_event_t evt) {
    if (evt == BT_DISCONNECTED) {
        // 蓝牙断了，不崩溃，切换到本地控制模式
        LOG_WARN("BT disconnected, switching to local mode");
        switch_to_local_control();
        // 同时尝试重连
        bt_reconnect_start();
    }
}

int read_sensor(uint16_t *value) {
    int ret = i2c_read(sensor_addr, value);
    if (ret != 0) {
        // I2C 读取失败，不崩溃，返回上次有效值
        LOG_WARN("Sensor read failed, using cached value");
        *value = last_valid_value;
        return -1;  // 返回错误码但不崩溃
    }
    last_valid_value = *value;
    return 0;
}
```

### 2.4 心跳检测与健康监控

```c
// 心跳 LED：每秒翻转一次，肉眼可观察系统是否活着
void heartbeat_task(void *p) {
    for (;;) {
        gpio_toggle(HEARTBEAT_LED);
        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

// 系统健康监控
typedef struct {
    uint32_t free_heap;
    uint32_t min_stack[8];  // 每个任务的栈水位线
    uint32_t error_count;
    uint32_t uptime_seconds;
} health_info_t;

void health_monitor_task(void *p) {
    for (;;) {
        health_info_t info;
        info.free_heap = xPortGetFreeHeapSize();
        // ... 收集各任务栈水位线 ...
        
        // 定期检查
        if (info.free_heap < MIN_HEAP_THRESHOLD) {
            LOG_ERROR("Low heap: %lu", info.free_heap);
        }

        vTaskDelay(pdMS_TO_TICKS(60000));  // 每分钟检查一次
    }
}
```

### 2.5 项目中的应用

WQ7036A 项目中的可靠性设计：

- **看门狗**：ACORE 主循环中喂狗，如果应用卡死则复位。
- **蓝牙断线重连**：BT 断开不崩溃，自动重连。
- **音频管道降级**：DSP 出错时切换到直通模式。
- **IPC 超时重试**：核间通信超时不崩溃，重试或降级。
- **OTA 回滚**：新固件启动失败自动回退旧版本（见 [[boot-ota-启动流程与OTA升级）]]。

---

## 第三层：深入扩展

### 3.1 故障树分析（FTA, Fault Tree Analysis）

从上到下分析"系统失效"的所有可能原因：

```
系统崩溃
├── 硬件故障
│   ├── 电源异常
│   ├── 时钟故障
│   └── Flash 损坏
├── 软件故障
│   ├── 栈溢出
│   ├── 空指针
│   ├── 死锁
│   └── 数据竞争
└── 外部异常
    ├── 通信中断
    ├── 电磁干扰
    └── 温度过高
```

### 3.2 FMEA（失效模式与影响分析）

| 组件 | 失效模式 | 影响 | 严重度 | 检测方法 | 缓解措施 |
|---|---|---|---|---|---|
| UART | 数据丢失 | 命令未执行 | 高 | CRC 校验 | 超时重发 |
| Flash | 写入失败 | OTA 中断 | 高 | 回读验证 | A/B 分区 |
| 蓝牙 | 断连 | 控制失效 | 中 | 心跳检测 | 自动重连 |
| I2S | 时钟漂移 | 音频杂音 | 中 | 采样率检测 | 重新初始化 |

### 3.3 复位原因寄存器

大多数 MCU 都有复位原因寄存器，复位后可以读取"上次是因为什么复位的"：

| 复位原因 | 说明 |
|---|---|
| Power-On Reset | 上电复位 |
| Watchdog Reset | 看门狗超时 |
| Software Reset | 软件主动复位 |
| External Reset | 外部引脚触发 |
| Brown-Out Reset | 电压过低自动复位 |

```c
void main(void) {
    uint32_t reason = read_reset_reason();
    
    if (reason & RESET_REASON_WDT) {
        LOG_WARN("Previous reset: Watchdog timeout");
    } else if (reason & RESET_REASON_BOR) {
        LOG_WARN("Previous reset: Brown-out (voltage drop)");
    }
    
    // 清除复位原因，避免下次误读
    clear_reset_reason();
    
    // ... 正常启动 ...
}
```

### 3.4 CRC 校验与数据完整性

```c
// CRC-32 校验（通信和存储中最常用）
uint32_t crc32(const uint8_t *data, size_t len)
{
    uint32_t crc = 0xFFFFFFFF;
    for (size_t i = 0; i < len; i++) {
        crc ^= data[i];
        for (int j = 0; j < 8; j++) {
            if (crc & 1)
                crc = (crc >> 1) ^ 0xEDB88320;
            else
                crc >>= 1;
        }
    }
    return ~crc;
}

// 使用：发送端附加 CRC，接收端验证
void send_packet(uint8_t *data, size_t len) {
    uint32_t crc = crc32(data, len);
    memcpy(data + len, &crc, 4);  // CRC 附加在数据末尾
    uart_send(data, len + 4);
}

bool receive_packet(uint8_t *data, size_t len) {
    uint32_t received_crc;
    memcpy(&received_crc, data + len, 4);
    uint32_t calc_crc = crc32(data, len);
    return (received_crc == calc_crc);  // 不匹配说明数据损坏
}
```

### 3.5 常见问题

- **看门狗为什么不能放在定时器中断里喂？** 因为定时器中断可能正常运行但主循环已经卡死，这时看门狗不会超时，起不到保护作用。
- **HardFault 发生后最重要的事是什么？** 保存 PC 和 LR 寄存器，定位崩溃的代码行。
- **什么是降级运行？** 主功能失效时保留核心功能，而不是整个系统崩溃。
- **CRC 和 MD5/SHA 的区别？** CRC 用于检测传输错误（快速、简单），MD5/SHA 用于检测数据篡改（安全、防碰撞）。

### 3.6 核心术语表

| 英文 | 中文 | 说明 |
|---|---|---|
| Watchdog | 看门狗 | 超时自动复位 |
| HardFault | 硬件错误 | CPU 执行非法操作 |
| Assert | 断言 | 运行时条件检查 |
| Graceful Degradation | 降级运行 | 主功能失败保留核心功能 |
| Heartbeat | 心跳 | 定期信号证明系统存活 |
| FTA | 故障树分析 | Fault Tree Analysis |
| FMEA | 失效模式与影响分析 | Failure Mode and Effects Analysis |
| CRC | 循环冗余校验 | Cyclic Redundancy Check |
| Brown-Out Reset | 欠压复位 | 电压过低时自动复位 |
| Reset Reason | 复位原因 | 上次复位的来源 |

### 3.7 延伸阅读

- [[debug-methodology-嵌入式调试方法论]] —— HardFault 定位的详细方法
- [[boot-ota-启动流程与OTA升级]] —— OTA 失败回滚
- [[interrupt-concurrency-中断并发同步]] —— 数据竞争和死锁
- [[low-power-低功耗设计]] —— 低功耗下看门狗的处理
