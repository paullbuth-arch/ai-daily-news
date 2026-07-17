---
type: concept
tags: [debug, memory-leak, heap, malloc, free, embedded]
aliases: [内存泄漏检测, 内存泄漏, 堆泄漏]
---

# 内存泄漏检测

## 一句话结论

内存泄漏 = 只申请不释放，嵌入式设备长时间运行后内存耗尽，然后死机。检测方法：追踪每次 malloc/free，看谁只借不还。

## 30秒先看懂

- 内存泄漏在嵌入式系统中比在 PC 上更严重——PC 进程退出后 OS 自动回收内存，但嵌入式设备没有进程退出，只有一个大循环，泄漏的内存永远不会被回收。嵌入式 SRAM 只有几百 KB 到几 MB，泄漏一点点就能让系统崩溃。检测内存泄漏最直接的方法是包装 malloc/free，记录每次分配的文件名、行号、大小，定期检查未释放的分配。更好的方案是使用内存池（固定大小的预分配块，无碎片、无泄漏、O(1) 时间）。WQ7036AX 的 SDK 在音频管道中大量使用内存池和静态分配，几乎不用 malloc。如果必须动态分配，优先使用 SDK 提供的 wq_mem_alloc 系列 API（内部是内存池实现）。

## 学完以后应该能做什么

**第一遍看完后可以：**
- 理解内存泄漏的原因和危害
- 实现简单的 malloc/free 包装，追踪分配记录
- 使用内存池替代动态分配
- 知道为什么嵌入式里优先用静态分配

**进阶后可以：**
- 实现 hook 方式拦截 malloc/free（不修改应用代码）
- 分析堆碎片化问题
- 使用 FreeRTOS 的 heap 监控 API
- 设计无泄漏的内存管理方案

## 前置知识

- C 语言的 malloc/free 函数
- 堆和栈的区别
- 嵌入式的内存限制

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 内存泄漏 | Memory Leak | 已分配的内存没有被释放，导致可用内存逐渐减少 |
| 堆 | Heap | 运行时动态分配的内存区域 |
| 内存碎片 | Memory Fragmentation | 频繁分配释放导致内存中出现许多小空闲块 |
| 内存池 | Memory Pool | 预分配固定大小的内存块集合 |
| 静态分配 | Static Allocation | 编译时确定大小的内存分配 |
| 悬挂指针 | Dangling Pointer | 指向已释放内存的指针 |
| 双重释放 | Double Free | 同一块内存被释放两次 |
| 内存越界 | Buffer Overflow | 写入的数据超过了分配的缓冲区大小 |
| 包装函数 | Wrapper Function | 在原始函数外包裹一层，添加额外功能 |

## 第一层：费曼心智模型

### 类比：图书馆借书

内存泄漏就像你在图书馆借书：

- `malloc(100)` = 借了 100 页的一本书
- `free(ptr)` = 还书
- **内存泄漏** = 借了书没还，书架上永远少了这本书

借一本不还，看不出来。借 1000 本不还，图书馆空了，新用户借不到书 → 系统 OOM 崩溃。

**嵌入式和 PC 的区别：**

| PC 程序 | 嵌入式程序 |
|---------|-----------|
| 进程退出，OS 自动回收所有内存 | 没有进程退出，只有一个大循环 |
| 内存 GB 级，泄漏慢 | 内存 KB 级，泄漏快 |
| 可以重启进程 | 重启整个设备，体验差 |

**边界：**
- 内存泄漏不一定立刻崩溃——可能运行几小时甚至几天后才暴露
- 内存池不是万能的——固定大小块在某些场景浪费空间
- 不是所有 malloc 都需要 free——有些缓冲区是永久分配的，不需要释放

### 场景演练：蓝牙音频播放 2 小时后崩溃

1. 产品正常运行，蓝牙播放音乐
2. 每次播放一首歌，应用层 malloc 一个缓冲区存放歌名
3. 歌曲切换时，忘记 free 这个缓冲区
4. 每首歌泄漏 100 字节，1000 首歌后泄漏 100KB
5. 系统 SRAM 总共 256KB，剩余可用内存越来越少
6. 2 小时后，malloc 返回 NULL，程序崩溃
7. 使用包装 malloc 检测，发现 `song_title.c:42` 的分配从未释放
8. 修复：在歌曲切换时添加 free

## 第二层：原理/时序/约束

### 包装 malloc/free 检测泄漏

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_TRACK 128

typedef struct {
    void *ptr;
    size_t size;
    const char *file;
    int line;
} alloc_record_t;

static alloc_record_t records[MAX_TRACK];
static size_t total_allocated = 0;
static size_t peak_allocated = 0;

void *tracked_malloc(size_t size, const char *file, int line) {
    void *ptr = malloc(size);
    if (ptr) {
        for (int i = 0; i < MAX_TRACK; i++) {
            if (records[i].ptr == NULL) {
                records[i] = (alloc_record_t){ptr, size, file, line};
                total_allocated += size;
                if (total_allocated > peak_allocated) {
                    peak_allocated = total_allocated;
                }
                break;
            }
        }
    }
    return ptr;
}

void tracked_free(void *ptr) {
    if (ptr == NULL) return;
    for (int i = 0; i < MAX_TRACK; i++) {
        if (records[i].ptr == ptr) {
            total_allocated -= records[i].size;
            records[i].ptr = NULL;
            break;
        }
    }
    free(ptr);
}

#define malloc(s) tracked_malloc(s, __FILE__, __LINE__)
#define free(p)   tracked_free(p)

// 定期打印内存状态
void print_mem_stats(void) {
    printf("=== Memory Stats ===\n");
    printf("Current allocated: %zu bytes\n", total_allocated);
    printf("Peak allocated: %zu bytes\n", peak_allocated);
    printf("Unfreed allocations:\n");
    for (int i = 0; i < MAX_TRACK; i++) {
        if (records[i].ptr) {
            printf("  %s:%d: %zu bytes at %p\n",
                   records[i].file, records[i].line,
                   records[i].size, records[i].ptr);
        }
    }
}
```

### 内存池方案

```c
// 固定大小内存池
#define POOL_BLOCK_SIZE 256
#define POOL_BLOCK_COUNT 16

static uint8_t pool[POOL_BLOCK_COUNT][POOL_BLOCK_SIZE];
static uint32_t pool_used = 0;  // 位图

void *pool_alloc(void) {
    for (int i = 0; i < POOL_BLOCK_COUNT; i++) {
        if (!(pool_used & BIT(i))) {
            pool_used |= BIT(i);
            return pool[i];
        }
    }
    return NULL;  // 池空了
}

void pool_free(void *ptr) {
    int idx = ((uint8_t *)ptr - pool[0]) / POOL_BLOCK_SIZE;
    pool_used &= ~BIT(idx);
}
```

## 第三层：真实 SDK 代码

### WQ7036AX 的内存管理

WQ7036AX 的 SDK 在音频管道中大量使用内存池和静态分配，几乎不用 malloc。如果需要在应用层动态分配，优先使用 SDK 提供的 `wq_mem_alloc` 系列 API，内部是内存池实现。

参考相关的内存管理头文件：

```c
// 在 SDK 中查找内存管理 API
// 参考路径：wqcore/components/ 下的相关组件

// 典型的内存池分配接口
void *wq_mem_alloc(size_t size);
void wq_mem_free(void *ptr);
void *wq_mem_calloc(size_t nmemb, size_t size);

// 内存统计
size_t wq_mem_get_free_size(void);
size_t wq_mem_get_min_free_size(void);
```

### FreeRTOS 堆监控

```c
// FreeRTOS 堆使用量 API
uint32_t free_heap = xPortGetFreeHeapSize();
uint32_t min_free_heap = xPortGetMinimumEverFreeHeapSize();

printf("Free heap: %lu bytes\n", free_heap);
printf("Min free heap: %lu bytes\n", min_free_heap);
// 如果 min_free_heap 持续下降，说明有内存泄漏
```

## 第四层：正常/异常路径

### 正常路径

malloc → 使用 → free → 内存回收

### 异常路径

| 异常场景 | 现象 | 原因 | 处理方式 |
|---------|------|------|---------|
| 内存泄漏 | 可用内存持续减少 | 只 malloc 不 free | 用包装 malloc 追踪未释放的分配 |
| 双重释放 | 程序崩溃 | 同一指针被 free 两次 | free 后置 NULL |
| 悬挂指针 | 访问已释放的内存 | free 后继续使用指针 | free 后置 NULL，使用前检查 |
| 内存越界 | 相邻内存块被破坏 | 写入超过缓冲区大小 | 使用边界检查工具 |
| 堆碎片化 | malloc 返回 NULL 但总空闲够 | 空闲块不连续 | 改用内存池 |

## 第五层：调试方法

```c
// 定期检查内存状态
void memory_health_check(void) {
    static size_t last_free = 0;
    size_t current_free = xPortGetFreeHeapSize();

    if (last_free != 0 && current_free < last_free) {
        printf("WARNING: Heap decreased by %lu bytes\n",
               last_free - current_free);
    }
    last_free = current_free;

    // 检查是否接近耗尽
    if (current_free < MIN_HEAP_THRESHOLD) {
        printf("CRITICAL: Only %lu bytes free!\n", current_free);
    }
}

// 在关键任务中调用
void health_monitor_task(void *p) {
    for (;;) {
        memory_health_check();
        vTaskDelay(pdMS_TO_TICKS(60000));  // 每分钟检查
    }
}
```

```bash
# Linux 内存泄漏检测
# 使用 valgrind
valgrind --leak-check=full ./my_app

# 使用 AddressSanitizer（编译时启用）
# gcc -fsanitize=address -g my_app.c -o my_app
./my_app

# 查看进程内存使用
cat /proc/$(pidof my_app)/maps
cat /proc/$(pidof my_app)/status | grep VmSize
```

## 第六层：实战练习

### 练习 1：实现泄漏检测包装（基础）

用包装 malloc/free 的方法检测内存泄漏：
1. 编写 `tracked_malloc` 和 `tracked_free` 函数
2. 用宏替换 `malloc` 和 `free`
3. 编写一个故意泄漏的程序（循环 malloc 但不 free）
4. 运行程序，用 `print_mem_stats` 检测泄漏
5. 修复泄漏，验证 `print_mem_stats` 显示 0 泄漏

### 练习 2：实现内存池（进阶）

实现一个固定大小的内存池：
1. 定义 `POOL_BLOCK_SIZE` 和 `POOL_BLOCK_COUNT`
2. 实现 `pool_alloc` 和 `pool_free`
3. 对比使用内存池和 malloc 的性能（分配时间）
4. 测试内存池满时返回 NULL 的情况
5. 验证内存池无碎片问题

### 练习 3：使用 FreeRTOS 堆监控（深入）

在 FreeRTOS 项目中使用堆监控 API 检测内存泄漏：
1. 在任务循环中定期调用 `xPortGetFreeHeapSize()` 和 `xPortGetMinimumEverFreeHeapSize()`
2. 用 `xPortGetMinimumEverFreeHeapSize()` 判断是否有泄漏（如果持续下降，则有泄漏）
3. 故意造成泄漏，观察 `xPortGetMinimumEverFreeHeapSize()` 的变化
4. 用包装 malloc 定位泄漏的具体位置

## 自测与验收

1. 为什么嵌入式设备的内存泄漏比 PC 更严重？
2. 检测内存泄漏最直接的方法是什么？
3. 内存池比 malloc 好在哪里？（至少 3 点）
4. 什么是内存碎片？它是怎么产生的？
5. 什么是悬挂指针？如何避免？
6. 什么是双重释放？如何避免？
7. FreeRTOS 中 `xPortGetFreeHeapSize` 和 `xPortGetMinimumEverFreeHeapSize` 的区别是什么？

## 延伸阅读

- [[memory-dma-内存管理与DMA]] — 栈/堆/DMA 的完整内存管理
- [[debug-methodology-嵌入式调试方法论]] — 系统化排查内存问题
- [[c-core-C语言核心]] — 指针和内存操作

## #flashcard

**Q: 内存泄漏的本质是什么？**
A: 只申请不释放，可用内存逐渐减少直到耗尽。

**Q: 为什么嵌入式内存泄漏比 PC 严重？**
A: 嵌入式没有进程退出机制（OS 不会自动回收），内存小（KB 级），泄漏快。

**Q: 检测内存泄漏最简单的方法是什么？**
A: 包装 malloc/free，记录每次分配的文件名和行号，定期检查未释放的分配。

**Q: 内存池比 malloc 的优势？**
A: 无碎片、无泄漏（必须显式释放）、O(1) 分配时间、确定性执行时间。

**Q: 嵌入式优先用什么分配方式？**
A: 静态分配（编译时确定）> 内存池 > malloc（不推荐）。