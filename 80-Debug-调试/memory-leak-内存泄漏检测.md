# 内存泄漏检测

**一句话结论（20% 核心）**：内存泄漏 = 只申请不释放，嵌入式设备长时间运行后内存耗尽，然后死机。检测方法：追踪每次 malloc/free，看谁只借不还。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：图书馆借书

内存泄漏就像你在图书馆借书：

- `malloc(100)` = 借了 100 页的一本书
- `free(ptr)` = 还书
- **内存泄漏** = 借了书没还，书架上永远少了这本书

借一本不还，看不出来。借 1000 本不还，图书馆空了，新用户借不到书 → 系统 OOM（Out of Memory）崩溃。

### 1.2 嵌入式里为什么尤其严重？

| PC 程序 | 嵌入式程序 |
|---------|-----------|
| 进程退出，OS 自动回收所有内存 | 没有进程退出，只有一个大循环 |
| 内存 GB 级，泄漏慢 | 内存 KB 级，泄漏快 |
| 可以重启进程 | 重启整个设备，体验差 |

### 1.3 如果只记得一件事

> 嵌入式优先用静态分配，其次用内存池。如果必须用 malloc，一定要追踪配对。长时间运行后内存减少 → 泄漏了。

---

## 第二层：实战理解

### 2.1 最简单的泄漏检测：包装 malloc/free

```c
// 记录每次 malloc/free，统计当前未释放的分配
#define MAX_TRACK 128

typedef struct {
    void *ptr;
    size_t size;
    const char *file;
    int line;
} alloc_record_t;

static alloc_record_t records[MAX_TRACK];
static size_t total_allocated = 0;

void *tracked_malloc(size_t size, const char *file, int line) {
    void *ptr = malloc(size);
    if (ptr) {
        for (int i = 0; i < MAX_TRACK; i++) {
            if (records[i].ptr == NULL) {
                records[i] = (alloc_record_t){ptr, size, file, line};
                total_allocated += size;
                break;
            }
        }
    }
    return ptr;
}

void tracked_free(void *ptr) {
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

// 定期打印：当前还有多少内存未释放
void print_mem_stats(void) {
    printf("Total allocated: %zu bytes\n", total_allocated);
    for (int i = 0; i < MAX_TRACK; i++) {
        if (records[i].ptr) {
            printf("  LEAK? %s:%d: %zu bytes at %p\n",
                   records[i].file, records[i].line,
                   records[i].size, records[i].ptr);
        }
    }
}
```

### 2.2 更好的方案：内存池

```c
// 固定大小内存池 —— 无泄漏、无碎片、O(1) 时间
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

### 2.3 在 WQ7036AX 项目中怎么用

WQ7036AX 的 SDK 在音频管道中大量使用内存池和静态分配，几乎不用 malloc。如果你在应用层需要动态分配，优先用 SDK 提供的 `wq_mem_alloc` 系列 API（内部是内存池实现）。

---

## 第三层：延伸阅读

- [[memory-dma-内存管理与DMA]] — 栈/堆/DMA 的完整内存管理
- [[debug-methodology-嵌入式调试方法论]] — 系统化排查内存问题