# 日志系统设计

**一句话结论（20% 核心）**：嵌入式日志不是 printf——你要考虑内存占用、日志等级、输出通道（串口/Flash/蓝牙）、性能影响。好的日志系统让你在 crash 后还能看到 crash 前的最后几条日志。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：飞机黑匣子

嵌入式日志系统 = 飞机的黑匣子 + 仪表盘：

- **仪表盘**（实时日志）：通过串口实时输出，调试时看
- **黑匣子**（持久日志）：存到 Flash，crash 后还能读出来
- **分级**：就像飞机的警报等级——绿色正常、黄色警告、红色紧急

### 1.2 日志等级的黄金标准

| 等级 | 宏 | 含义 | 什么时候用 |
|------|------|------|-----------|
| 0 | `LOG_EMERG` | 系统崩溃 | 不可恢复的错误 |
| 1 | `LOG_ALERT` | 立即处理 | 电池快没电了 |
| 2 | `LOG_CRIT` | 严重错误 | 关键操作失败 |
| 3 | `LOG_ERR` | 一般错误 | 操作失败但可恢复 |
| 4 | `LOG_WARNING` | 警告 | 异常但能继续 |
| 5 | `LOG_NOTICE` | 注意 | 重要但正常的条件 |
| 6 | `LOG_INFO` | 信息 | 正常运行信息 |
| 7 | `LOG_DEBUG` | 调试 | 开发调试用 |

### 1.3 如果只记得一件事

> 日志系统 = 分级 + 多通道 + 低开销。至少分 ERROR/WARNING/INFO/DEBUG 四级，通过宏控制在 release 版本中关闭 DEBUG 日志。

---

## 第二层：实战理解

### 2.1 嵌入式最小日志实现

```c
// 简洁但够用的日志系统
typedef enum {
    LOG_ERROR = 0,
    LOG_WARN  = 1,
    LOG_INFO  = 2,
    LOG_DEBUG = 3,
} log_level_t;

#define CURRENT_LOG_LEVEL LOG_DEBUG  // 编译时设置

#define LOG(level, fmt, ...) \
    do { \
        if (level <= CURRENT_LOG_LEVEL) { \
            printf("[%s] " fmt "\r\n", #level, ##__VA_ARGS__); \
        } \
    } while(0)

// 使用
LOG(LOG_ERROR, "I2C read failed at addr 0x%02X", addr);
LOG(LOG_DEBUG, "UART RX: %02X", byte);
```

### 2.2 环形缓冲区日志（crash 后可读）

```c
// 日志写入环形缓冲区，crash 后通过 JTAG 或下次启动时读出
typedef struct {
    char buf[4096];
    volatile uint32_t head;
} log_ring_t;

static log_ring_t log_ring __attribute__((section(".noinit")));
// .noinit 段在复位时不清零，crash 后数据还在

void log_to_ring(const char *msg) {
    for (const char *p = msg; *p; p++) {
        log_ring.buf[log_ring.head & 0xFFF] = *p;
        log_ring.head++;
    }
}
```

### 2.3 常见坑

| 问题 | 现象 | 根因 |
|------|------|------|
| 日志太多影响性能 | 加了日志后 bug 消失了 | 日志改变了时序，实时性问题 |
| 中断里打日志 | 系统卡死 | printf 可能阻塞，中断里不能调用 |
| 日志缓冲溢出 | 日志截断 | 串口输出速度 < 日志产生速度 |
| Release 忘了关 DEBUG | 性能下降 | 编译时没切换日志等级 |

### 2.4 在 WQ7036AX 项目中怎么用

SDK 提供了 debug log 系统，在 `wqcore/components/dbglog/` 下。每个日志消息有唯一的 ID（`dbglog_table.txt`），支持通过 ID 过滤。日常开发建议用串口输出 INFO 级别，发布版本只保留 ERROR 级别。

---

## 第三层：延伸阅读

- [[debug-methodology-嵌入式调试方法论]] — 系统化的调试思路
- [[debug-tools-常用调试工具链]] — 串口/GDB 等调试工具