---
type: concept
created: 2026-07-17
tags: [debug, logging, log, 日志, 嵌入式, wq7036ax]
aliases: [日志系统, Logging Design, 日志设计, 嵌入式日志]
---

# 日志系统设计

## 一句话结论

嵌入式日志系统不是简单的 printf——你需要考虑内存占用、日志等级（ERROR/WARNING/INFO/DEBUG）、输出通道（串口/Flash/蓝牙）、性能影响和崩溃恢复能力。好的日志系统让你在 crash 后还能看到 crash 前的最后几条日志。WQ7036AX SDK 提供了 dbglog 系统（位于 `wqcore/components/dbglog/`），支持分级日志、模块过滤、ID 索引和 Flash 持久化。

## 30秒先看懂

- 嵌入式日志至少分 ERROR/WARNING/INFO/DEBUG 四级，通过宏在编译时控制等级，Release 版本关闭 DEBUG 日志。
- 环形缓冲区日志是 crash 后可读的关键——日志写入 RAM 中的环形缓冲区，芯片复位后数据不丢失（放在 .noinit 段）。
- 中断处理函数中不能调用阻塞式日志输出（如 printf），否则可能导致系统卡死。
- 日志太多会改变程序时序，导致"加了日志 bug 消失"的 Heisenbug 问题。
- WQ7036AX 的 dbglog 系统使用 ID 索引机制，每个日志消息有唯一 ID 存储在 `dbglog_table.txt` 中，支持通过 ID 过滤。

## 学完以后应该能做什么

### 第一遍
- 实现一个基础的分级日志系统，支持 ERROR/WARNING/INFO/DEBUG 四级
- 配置日志等级，Release 版本关闭 DEBUG 日志
- 理解环形缓冲区日志的原理并实现

### 进阶
- 在 WQ7036AX 的 dbglog 系统中添加新的日志模块
- 配置 Flash 日志持久化，crash 后读取日志
- 设计远程日志系统（通过蓝牙或 WiFi 输出日志）

## 前置知识

- [[debug-methodology-嵌入式调试方法论]]：调试方法论，日志在调试中的作用
- [[debug-tools-常用调试工具链]]：串口打印工具的使用
- [[c-core-C语言核心]]：C 语言可变参数宏、volatile、段属性
- [[interrupt-concurrency-中断并发同步]]：中断中不能调用阻塞函数

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 日志等级 | Log Level | 日志的严重程度等级，从 EMERG（最严重）到 DEBUG（最不严重） |
| 环形缓冲区 | Ring Buffer / Circular Buffer | 固定大小的循环缓冲区，新数据覆盖旧数据，保证始终保留最新数据 |
| noinit 段 | .noinit Section | 芯片复位时不清零的内存段，用于跨复位保存数据 |
| 日志 ID | Log ID | 每个日志消息的唯一数字标识，用于过滤和查找 |
| 条件编译 | Conditional Compilation | 通过 #ifdef 在编译时决定是否包含日志代码 |
| 输出通道 | Log Output Channel | 日志输出的目的地（串口/UART、Flash、蓝牙、WiFi） |
| 持久化日志 | Persistent Log | 存储在非易失介质（Flash）上的日志，断电不丢失 |
| 远程日志 | Remote Logging | 通过通信接口（蓝牙/UART/WiFi）将日志发送到远程主机 |

## 第一层费曼心智模型

### 类比：飞机黑匣子

嵌入式日志系统 = 飞机的黑匣子 + 仪表盘：

- **仪表盘（实时日志）**：通过串口实时输出，调试时看——就像飞机驾驶舱的仪表盘，实时显示飞行状态。
- **黑匣子（持久日志）**：存到 Flash，crash 后还能读出来——就像飞机的黑匣子，记录飞行数据，事故后分析用。
- **分级**：就像飞机的警报等级——绿色正常（INFO）、黄色警告（WARNING）、红色紧急（ERROR/CRITICAL）。
- **环形缓冲区**：就像飞机黑匣子的循环磁带——不断录制，新数据覆盖最旧的数据，始终保留最近的关键信息。

### 边界

- 日志不是越多越好——太多日志会降低性能、改变时序、填满缓冲区。
- 中断里不能打日志——printf 可能阻塞，中断里应该只设置标志位。
- 日志系统本身也可能有 bug——不要在你的日志系统里加复杂逻辑。
- 日志 ID 是有限资源——WQ7036AX 的 dbglog 系统中每个日志消息有唯一 ID，ID 总数有限。

### 场景推演

**场景：设备运行 2 小时后突然死机，需要排查原因**

1. 串口日志实时输出，但死机时来不及看最后几条
2. 幸好日志系统使用了环形缓冲区，日志放在 .noinit 段
3. 重置设备后，通过 GDB 读取环形缓冲区内容
4. 看到最后几条日志：
   ```
   [ERROR] audio_task: DMA buffer underflow!
   [WARN]  audio_task: retry DMA restart...
   [ERROR] audio_task: DMA restart failed!
   ```
5. 结论：DMA 缓冲区 underflow，重启失败，导致音频任务卡死

## 第二层原理/时序/约束

### 日志等级的黄金标准

| 等级 | 宏 | 含义 | 什么时候用 | 示例 |
|------|------|------|-----------|------|
| 0 | `LOG_EMERG` | 系统崩溃 | 不可恢复的错误 | 内存耗尽、断言失败 |
| 1 | `LOG_ALERT` | 立即处理 | 需要立即关注 | 电池电量临界、过热 |
| 2 | `LOG_CRIT` | 严重错误 | 关键操作失败 | 关键外设初始化失败 |
| 3 | `LOG_ERR` | 一般错误 | 操作失败但可恢复 | 通信超时、重试 |
| 4 | `LOG_WARNING` | 警告 | 异常但能继续 | 电量低、性能下降 |
| 5 | `LOG_NOTICE` | 注意 | 重要但正常的条件 | 连接建立、配置变更 |
| 6 | `LOG_INFO` | 信息 | 正常运行信息 | 初始化完成、任务启动 |
| 7 | `LOG_DEBUG` | 调试 | 开发调试用 | 函数调用、变量值 |

实际项目中通常简化为 4 级：ERROR、WARNING、INFO、DEBUG。

### 环形缓冲区原理

```
┌────┬────┬────┬────┬────┬────┬────┬────┐
|  1 |  2 |  3 |  4 |  5 |  6 |  7 |  8 |  ← 缓冲区（8 条）
└────┴────┴────┴────┴────┴────┴────┴────┘
  ↑                                       ↑
  head (写入位置)                          tail (最旧数据)

写入第 9 条时：
┌────┬────┬────┬────┬────┬────┬────┬────┐
|  9 |  2 |  3 |  4 |  5 |  6 |  7 |  8 |  ← 覆盖了第 1 条
└────┴────┴────┴────┴────┴────┴────┴────┘
  ↑
  head

始终保留最新的 N 条日志。crash 后环形缓冲区中的数据就是 crash 前的最新记录。
```

### 日志输出通道对比

| 通道 | 实时性 | 持久性 | 影响性能 | 适用场景 |
|------|-------|--------|---------|---------|
| 串口/UART | 实时 | 否 | 有（阻塞） | 日常开发调试 |
| 环形缓冲区 (RAM) | 延迟写入 | 否（掉电丢） | 极低 | Crash 分析 |
| Flash | 延迟写入 | 是 | 高（擦写慢） | 长期运行记录 |
| 蓝牙 | 近实时 | 否 | 有（占用带宽） | 远程调试 |
| WiFi | 近实时 | 否 | 有（占用带宽） | 远程调试 |

### 日志性能影响分析

```c
// 日志对性能的影响取决于：
// 1. 日志数量：每秒打多少条日志
// 2. 每条日志的处理时间：字符串格式化 + 输出
// 3. 输出通道的速率：UART 115200 baud ≈ 11.5 KB/s

// 估算：UART 115200 baud 的日志输出能力
// 115200 bps / 10 bits(1 start + 8 data + 1 stop) = 11520 字符/秒
// 如果每条日志平均 50 字符，则最大约 230 条/秒
// 超过这个速率，日志会堆积或丢失
```

## 第三层真实SDK代码

### WQ7036AX 的 dbglog 系统

位于 `/home/ys/wq7036a/wq-audio/wqcore/components/dbglog/inc/dbglog.h` 和 `/home/ys/wq7036a/wq-audio/wqcore/components/dbglog/src/dbglog.c`：

```c
// 日志等级定义
typedef enum {
    DBGLOG_LEVEL_ALL = 0,            // 所有等级
    DBGLOG_LEVEL_VERBOSE = 1,        // 详细
    DBGLOG_LEVEL_DEBUG = 2,          // 调试
    DBGLOG_LEVEL_INFO = 3,           // 信息
    DBGLOG_LEVEL_WARNING = 4,        // 警告
    DBGLOG_LEVEL_ERROR = 5,          // 错误
    DBGLOG_LEVEL_CRITICAL = 6,       // 严重
    DBGLOG_LEVEL_NONE = 7,           // 无输出
    DBGLOG_LEVEL_MAX = 8,
} DBGLOG_LEVEL;

// 日志宏
#define DBGLOG_LOG(module, lvl, fmt, ...) \
    do { \
        if (wq_dbglog_level_check(module, lvl)) { \
            wq_dbglog_raw_log_write(module, fmt, ##__VA_ARGS__); \
        } \
    } while (0)

// 分等级日志宏
#define DBGLOG_INFO(module, fmt, ...)
#define DBGLOG_WARNING(module, fmt, ...)
#define DBGLOG_ERROR(module, fmt, ...)

// 日志 ID 机制：每个日志消息通过 __attribute__((section)) 分配唯一 ID
#define LOG_STREAM_SEC      __attribute__((__section__(".stream_log.str"))) static const char
#define LOG_STREAM_ADDR_SEC __attribute__((__section__(".stream_log.addr"))) static const char *

// 日志输出通道配置
#define DBGLOG_DUMP_UART  0x00    // UART 输出
#define DBGLOG_DUMP_FLASH 0x01    // Flash 输出

// Flash 日志使能（通过 Kconfig 配置）
#ifdef CONFIG_FLASH_LOG_ENABLE
#define CONFIG_DBGLOG_DEFAULT_IO GENERIC_TRANSMISSION_IO_FLASH
#else
#define CONFIG_DBGLOG_DEFAULT_IO GENERIC_TRANSMISSION_IO_UART0
#endif
```

### 使用示例

```c
// 在 WQ7036AX 项目中使用 dbglog
#include "dbglog.h"

#define LOG_TAG "[app_ota_trans_ble] "
#include "app_log.h"

// 使用方式
LOGI("BLE init start");           // 信息日志
LOGW("Buffer near full");         // 警告日志
LOGE("I2C read failed");          // 错误日志
```

### 基础日志实现参考

```c
// 一个简洁但完整的嵌入式日志系统实现
typedef enum {
    LOG_ERROR = 0,
    LOG_WARN  = 1,
    LOG_INFO  = 2,
    LOG_DEBUG = 3,
} log_level_t;

// 编译时设置日志等级（通过 -D 或 Kconfig 控制）
#ifndef CURRENT_LOG_LEVEL
#define CURRENT_LOG_LEVEL LOG_DEBUG
#endif

// 基础日志宏
#define LOG(level, fmt, ...) \
    do { \
        if (level <= CURRENT_LOG_LEVEL) { \
            log_output(level, __FILE__, __LINE__, fmt, ##__VA_ARGS__); \
        } \
    } while(0)

// 分等级宏
#define LOGE(fmt, ...) LOG(LOG_ERROR, fmt, ##__VA_ARGS__)
#define LOGW(fmt, ...) LOG(LOG_WARN,  fmt, ##__VA_ARGS__)
#define LOGI(fmt, ...) LOG(LOG_INFO,  fmt, ##__VA_ARGS__)
#define LOGD(fmt, ...) LOG(LOG_DEBUG, fmt, ##__VA_ARGS__)

// 日志输出函数
void log_output(log_level_t level, const char *file, int line,
                const char *fmt, ...) {
    const char *level_str[] = {"E", "W", "I", "D"};
    char buf[LOG_MAX_LEN];

    va_list args;
    va_start(args, fmt);
    vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);

    // 格式: [等级][时间戳][文件名:行号] 消息
    printf("[%s][%lu][%s:%d] %s\n",
           level_str[level],
           xTaskGetTickCount(),
           file, line, buf);
}
```

## 第四层正常/异常路径

### 正常路径

```
日志产生 → 等级检查（low > current_level? 丢弃）
  → 字符串格式化（vsnprintf）
  → 写入环形缓冲区（RAM，快速）
  → 写入输出通道（串口/Flash，较慢）
  ↓
日志输出到终端或持久化存储
```

### 异常路径

| 问题 | 现象 | 原因 | 解决方案 |
|------|------|------|---------|
| 日志太多影响性能 | 加了日志后 bug 消失了 | 日志改变了时序，实时性问题 | 减少日志量，或使用无侵入日志 |
| 中断里打日志 | 系统卡死 | printf 可能阻塞，中断里不能调用 | 中断中只设置标志位，任务中输出日志 |
| 日志缓冲溢出 | 日志截断 | 串口输出速度 < 日志产生速度 | 增大缓冲区，或降低日志等级 |
| Release 忘了关 DEBUG | 性能下降 | 编译时没切换日志等级 | 在 Makefile/Kconfig 中预置日志等级 |
| 环形缓冲区溢出 | 重要日志被覆盖 | 缓冲区太小 | 增大缓冲区，或降低日志频率 |
| Flash 日志写入慢 | 系统卡顿 | Flash 擦写时间长（ms 级） | 使用异步写入，或减少 Flash 日志频率 |

## 第五层调试方法

### 读取环形缓冲区日志

```bash
# 崩溃后，通过 GDB 读取环形缓冲区内容
(gdb) p log_ring
(gdb) x/256xb log_ring.buf

# 或者用 addr2line 分析日志中的地址信息
```

### 日志等级动态切换

```c
// 在运行时动态切换日志等级（不需要重新编译）
log_level_t g_current_log_level = LOG_DEBUG;

void set_log_level(log_level_t level) {
    g_current_log_level = level;
    LOGI("Log level changed to %d", level);
}

// 通过串口命令或蓝牙命令切换
// 终端输入: log_level 3  → 设置为 INFO 等级
// 终端输入: log_level 7  → 关闭所有日志
```

### 日志 ID 查询

```bash
# WQ7036AX 的 dbglog 系统生成日志 ID 表
# 在 build 目录下查找
cat build/dbglog_table.txt

# 格式：模块名 日志ID 日志字符串
# 示例：
# APP_OTA 0x0001 "BLE init start"
# APP_OTA 0x0002 "BLE connected"
# BT_HFP  0x0100 "SCO link established"
```

## 第六层实战练习

### 练习1：实现环形缓冲区日志

编写代码实现一个环形缓冲区日志模块，日志存放在 .noinit 段，crash 后可读：

```c
// 要求：
// 1. 缓冲区大小 4096 字节
// 2. 放在 .noinit 段（复位不清零）
// 3. 支持写入字符串
// 4. 支持通过 GDB 读取
// 5. 缓冲区满时覆盖最旧的数据

#define LOG_RING_SIZE 4096
// 请补全
typedef struct {
    char buf[LOG_RING_SIZE];
    volatile uint32_t head;
    // 可能需要添加其他字段...
} log_ring_t;

// 声明 noinit 段变量
// 写入函数
// 读取函数
```

### 练习2：阅读 SDK 源码分析 dbglog 实现

在 `/home/ys/wq7036a/wq-audio/wqcore/components/dbglog/src/dbglog.c` 中分析：
- 日志 ID 的生成机制（如何为每个日志消息分配唯一 ID）
- Flash 日志的写入流程（如何将日志写入 Flash）
- 多核日志如何处理（ACORE 和 BCORE 的日志如何汇总）
- 日志模块的过滤机制

### 练习3：实现远程日志输出

编写代码，通过 BLE 将日志输出到手机 APP：

```c
// 要求：
// 1. 在 GATT Service 中注册一个日志输出 Characteristic（Notify）
// 2. 将所有日志同时输出到串口和 BLE
// 3. 支持通过手机 APP 远程切换日志等级
// 4. 考虑 BLE 带宽限制，高等级日志可以降频

// 提示：log_output 函数中增加一个 BLE 输出通道
// 在 BLE 连接建立后，通过 wq_gatts_send_notify 发送日志
// 请补全设计
```

## 自测与验收

1. 嵌入式日志系统至少应该分哪几个等级？Release 版本应该保留哪些等级？
2. 环形缓冲区日志为什么能帮助分析 crash 原因？关键内存段属性是什么？
3. 为什么不能在中断处理函数中直接调用 printf 输出日志？
4. WQ7036AX 的 dbglog 系统使用什么机制来唯一标识每条日志消息？
5. 日志太多导致 Heisenbug 的原因是什么？如何避免？

## 延伸阅读

- [[debug-methodology-嵌入式调试方法论]] — 系统化的调试思路
- [[debug-tools-常用调试工具链]] — 串口/GDB 等调试工具
- [[c-core-C语言核心]] — 可变参数宏、volatile、段属性
- [[interrupt-concurrency-中断并发同步]] — 中断安全的日志输出
- `/home/ys/wq7036a/wq-audio/wqcore/components/dbglog/inc/dbglog.h` — dbglog 头文件
- `/home/ys/wq7036a/wq-audio/wqcore/components/dbglog/src/dbglog.c` — dbglog 实现

#flashcard
问：嵌入式日志系统至少应该分哪几个等级？
答：至少分 ERROR/WARNING/INFO/DEBUG 四级。Release 版本保留 ERROR/WARNING，关闭 INFO/DEBUG。

问：环形缓冲区为什么能帮助分析 crash 原因？
答：日志写入 RAM 中的环形缓冲区，放在 .noinit 段（复位不清零），crash 后可通过 GDB 读取 crash 前的最后几条日志。

问：为什么不能在中断里打日志？
答：printf 可能阻塞（如等待 UART 发送完成），中断里应该只设置标志位，在任务上下文中输出日志。

问：WQ7036AX 的 dbglog 系统如何标识日志消息？
答：通过编译器属性将日志字符串放入特定段（.stream_log.str），为每条日志生成唯一 ID，存储在 dbglog_table.txt 中。

问：Heisenbug 是什么？如何避免？
答：加日志后 bug 消失的现象，因为日志改变了程序时序。避免方法：减少日志量、使用无侵入日志（ITM）、只在关键路径加少量日志。