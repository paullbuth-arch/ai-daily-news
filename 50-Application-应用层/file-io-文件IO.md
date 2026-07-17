---
type: concept
tags: [Linux, 文件IO, 系统调用, 嵌入式, 存储]
aliases: [文件IO, File I/O, Linux文件操作]
---

# 文件 IO

## 一句话结论

Linux 一切皆文件——普通文件、设备、管道、Socket 都通过文件描述符操作。文件 IO 分两层：系统调用（`open/read/write/close`，无缓冲，直通内核）和标准库（`fopen/fread/fwrite/fclose`，用户态缓冲，性能好）。理解缓冲、同步和原子性是掌握文件 IO 的关键。

## 30秒先看懂

1. Linux 文件 IO 有两种方式：系统调用（直接进内核，无缓冲）和标准库（用户态缓冲，减少系统调用次数）。
2. 文件描述符（fd）是内核给进程的"号码牌"——0=stdin, 1=stdout, 2=stderr，新文件从 3 开始。
3. 写入数据不会立即到磁盘——先到用户缓冲区，再到内核页缓存，最后才刷到磁盘。`fsync` 强制刷盘防丢数据。
4. `O_APPEND` 保证多进程追加写入的原子性，但 `lseek + write` 组合不是原子的。
5. `mmap` 把文件映射到内存，像访问数组一样读写文件，适合大文件随机访问。

## 学完以后应该能做什么

### 第一遍
- 区分系统调用和标准库 IO 的适用场景，写出正确的文件读写代码
- 理解文件描述符的概念，知道如何排查 fd 泄漏
- 知道什么时候该调 `fsync` 保证数据不丢
- 会用 `O_APPEND` 实现多进程安全日志写入

### 进阶
- 使用 `mmap` 实现大文件的高效随机读写
- 正确使用 `pwrite/pread` 避免多线程中的 `lseek+write` 竞态
- 理解 `sendfile` 零拷贝机制，写出高性能文件传输代码
- 在嵌入式 Linux（V881）上设计可靠性文件存储方案

## 前置知识

- C 语言指针和数组操作
- 理解进程地址空间（用户态 vs 内核态）
- 基本的 Linux 命令行操作

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 文件描述符 | File Descriptor (fd) | 内核维护的打开文件索引，非负整数，用户态通过它操作文件 |
| 系统调用 | System Call | 用户态请求内核服务的接口，如 `open/read/write`，开销大 |
| 标准库 IO | Standard C Library IO | `fopen/fread/fwrite` 等 C 标准函数，在用户态加了缓冲层 |
| 页缓存 | Page Cache | 内核把磁盘数据缓存在内存中的机制，减少磁盘 IO |
| 文件偏移量 | File Offset | 文件当前读写位置，内核为每个 fd 维护 |
| 原子操作 | Atomic Operation | 不可被中断的操作，要么全部完成要么完全不执行 |
| 零拷贝 | Zero-Copy | 数据在设备间传输时不经过用户态，减少内存拷贝次数 |

## 第一层：费曼心智模型

### 类比：银行柜台 vs 钱包

- **系统调用 IO**（`read/write`）= 每次存取都去银行柜台排队。即时到账，但每次都要排队，人多时很慢。
- **标准库 IO**（`fread/fwrite`）= 先把钱存在钱包里，攒够一笔再去柜台。快，但钱包丢了（进程崩溃）数据就没了。
- **fsync/fdatasync** = 跟柜员说"现在就入账，别放缓冲区"——强制刷到磁盘，保证断电不丢。
- **mmap** = 银行给你一个保险箱钥匙，你自己开门存取，不用每次都排柜台。

### 边界

文件 IO 的"一切皆文件"不适用于所有场景：
- 网络 Socket 的 `read/write` 可能返回部分数据，需要循环调用
- 管道（pipe）和 FIFO 的读写行为与普通文件不同（阻塞/非阻塞）
- 某些特殊文件系统（如 procfs、sysfs）不支持所有操作

### 场景推演：嵌入式日志系统

假设你需要在 V881 上写一个日志系统，多进程同时写入 `/var/log/app.log`。

错误做法：每个进程调用 `lseek + write`——两个进程的日志行会交错，数据会互相覆盖。正确做法：打开文件时加 `O_APPEND` 标志，内核保证每次 `write` 前自动移到末尾，且移动+写入是原子操作。如果日志需要保证崩溃不丢，在每次 `write` 后调 `fdatasync`（只刷数据不刷元数据，比 `fsync` 快）。

## 第二层：原理/时序/约束

### 缓冲机制：数据到底在哪？

```
用户空间                内核空间              磁盘
  │                       │                    │
  │ fwrite() ──→ 用户缓冲区 │                    │
  │  (4096B)              │                    │
  │                       │                    │
  │ fflush() ──→ ──→ ──→ write() ──→ 内核页缓存 │
  │                       │  (Page Cache)      │
  │                       │                    │
  │                       │ fsync() ──→ ──→ ──→ 磁盘
  │                       │  (强制刷盘)         │
```

**三层缓冲**：
1. **用户态缓冲**（stdio buffer）：`fwrite` 写入，`fflush` 或缓冲区满时调用 `write()`
2. **内核页缓存**（Page Cache）：`write()` 写入，内核定期刷盘（writeback）
3. **磁盘缓存**：硬盘自带的缓冲区

### fsync vs fdatasync vs O_SYNC

```c
// fsync: 刷文件数据 + 元数据（文件大小、修改时间）
fsync(fd);

// fdatasync: 只刷文件数据，不刷元数据（更快）
fdatasync(fd);

// O_SYNC: 每次 write 都相当于 write + fsync（最安全但最慢）
int fd = open("/data/critical.bin", O_WRONLY | O_CREAT | O_SYNC, 0644);
write(fd, data, len);  // 这次 write 返回时，数据已到磁盘
```

**选择指南**：日志文件用 `fflush` 就够了（丢几行日志无所谓），配置文件保存用 `fsync`（必须保证写入），数据库用 `fdatasync`（只关心数据，不关心元数据）。

### 原子追加写入

```c
// 多进程写同一个日志文件的安全做法
int fd = open("/data/app.log", O_WRONLY | O_CREAT | O_APPEND, 0644);

// O_APPEND 保证：每次 write 前，文件偏移量自动移到文件末尾
// 且"移到末尾+写入"是原子操作，不会被其他进程打断
write(fd, log_line, len);  // 安全！不会和其他进程的数据交错

// 错误做法：先 lseek 再 write（不是原子的，中间可能被打断）
// lseek(fd, 0, SEEK_END);  ← 这之间另一个进程可能也写了
// write(fd, log_line, len); ← 数据可能交错覆盖
```

### 文件描述符在内核中的管理

```
进程 A 的 fd 表             内核文件表                     inode
┌───────┐                ┌──────────────┐           ┌──────────┐
│ fd 0  │────→ stdin     │ 文件对象 1    │────→     │ inode 1  │
│ fd 1  │────→ stdout    │ refcount=2   │           │ 磁盘块列表│
│ fd 2  │────→ stderr    │ offset=1024  │           └──────────┘
│ fd 3  │────→ ─────────→│ 文件对象 2    │────→     ┌──────────┐
│ fd 4  │────→ ─────────→│ refcount=1   │────→     │ inode 2  │
└───────┘                │ offset=2048  │           └──────────┘
                         └──────────────┘
```

多个 fd 可以指向同一个内核文件对象（`dup` 后），共享 offset。多个 fd 指向不同文件对象但同一个 inode（`open` 同一个文件两次），各自有独立 offset。

### mmap 原理

```c
// mmap 让文件像内存数组一样访问，适合大文件随机读写
int fd = open("/data/large.bin", O_RDWR);
struct stat st;
fstat(fd, &st);

void *addr = mmap(NULL, st.st_size, PROT_READ | PROT_WRITE,
                  MAP_SHARED, fd, 0);
// 现在 addr[100] = 42 相当于把文件第 100 字节写成 42
// MAP_SHARED: 修改会写回文件
// MAP_PRIVATE: 修改只在本进程可见 (Copy-on-Write)

munmap(addr, st.st_size);
```

mmap 的底层原理：通过缺页中断（page fault）按需加载文件块到内存，修改后内核通过 writeback 机制写回磁盘。

## 第三层：真实SDK代码

### V881 上的日志系统

在 `/home/ys/aiglass/reglasses/` 中，各系统服务的日志写入使用标准的文件 IO 模式：

```c
// 伪代码——V881 服务日志写入模式
// 文件路径: reglasses/services/common/log_writer.c
int log_writer_init(const char *path) {
    // 使用 O_APPEND 保证多服务写入不交错
    int fd = open(path, O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (fd < 0) return -1;
    return fd;
}

void log_write(int fd, const char *msg, int len) {
    write(fd, msg, len);
    // 日志可以容忍少量丢失，不调 fsync 以获得更好性能
    // 但关键事件（如 OTA 开始/结束）会调 fsync
}
```

### OTA 固件的原子替换

```c
// 伪代码——V881 OTA 固件更新
// 文件路径: reglasses/services/ota/ota_update.c
int ota_apply_update(const char *download_path, const char *boot_path) {
    // 1. 先下载到临时文件
    int ret = download_firmware(download_path, "/tmp/update.bin");
    if (ret < 0) return -1;

    // 2. 校验完整性
    ret = verify_firmware("/tmp/update.bin");
    if (ret < 0) return -1;

    // 3. 原子替换——rename 是文件系统级的原子操作
    // 要么完全成功，要么完全不变，不会出现部分写入的中间状态
    ret = rename("/tmp/update.bin", boot_path);
    if (ret < 0) return -1;

    // 4. 同步确保元数据落盘
    fsync(open(boot_path, O_RDONLY));
    return 0;
}
```

### WQ7036AX 的 Flash 存储

WQ7036AX 没有文件系统，数据直接存储在 Flash 固定地址。代码在 `/home/ys/wq7036a/wq-audio/wqcore/components/startup/boot/` 中，使用 Flash 读写驱动而非文件 IO：

```c
// 伪代码——WQ7036AX Flash 读写
// 文件路径: wqcore/components/startup/boot/inc/boot.h
// 在嵌入式 MCU 上，没有文件系统，直接操作 Flash 地址
int flash_read(uint32_t offset, void *buf, uint32_t len);
int flash_write(uint32_t offset, const void *buf, uint32_t len);
int flash_erase(uint32_t offset, uint32_t len);
```

## 第四层：正常/异常路径

### 正常路径

```
open("/data/config.json", O_RDWR | O_CREAT, 0644)
  → 内核分配 fd (3) → 创建文件对象 → 返回 fd
read(fd, buf, 1024)
  → 检查 fd 有效性 → 从页缓存/磁盘读取 → 复制到用户态 → 返回实际读取字节数
write(fd, data, len)
  → 检查权限 → 写入页缓存 → 更新 offset → 返回写入字节数
close(fd)
  → 刷出缓冲区 → 释放文件对象 → 释放 fd
```

### 异常路径

| 异常 | 现象 | 触发条件 | 恢复方式 |
|------|------|---------|---------|
| fd 耗尽 | `open` 返回 -1，errno=EMFILE | 进程打开文件数超 `ulimit -n` 限制 | 调大 ulimit，或修复 fd 泄漏 |
| 磁盘满 | `write` 返回 -1，errno=ENOSPC | 存储设备无剩余空间 | 清理磁盘 |
| 文件被删 | `read`/`write` 正常但文件已无目录项 | 其他进程 `unlink` 了文件 | 无法恢复，但已打开 fd 仍可用 |
| 写入中断电 | 文件内容不完整或为空 | 未调 `fsync`，数据只在页缓存中 | 确保调用 `fsync` |
| 权限不足 | `open` 返回 -1，errno=EACCES | 对文件没有对应权限 | 修改权限或切换用户 |
| 文件不存在 | `open` 返回 -1，errno=ENOENT | 未加 `O_CREAT` 时打开不存在的文件 | 加 `O_CREAT` 标志 |

## 第五层：调试方法

### 排查 fd 泄漏

```bash
# 查看进程打开了哪些文件
lsof -p <PID>

# 查看进程的 fd 目录
ls -la /proc/<PID>/fd/

# 统计打开的文件数
lsof -p <PID> | wc -l

# 查看系统级 fd 限制
ulimit -n
cat /proc/sys/fs/file-max
```

### 追踪文件 IO

```bash
# 使用 strace 追踪系统调用
strace -e open,read,write,close -p <PID>

# 追踪特定文件操作
strace -e trace=file -p <PID>

# 统计文件 IO 耗时
strace -T -e read,write -p <PID>
```

### 性能分析

```bash
# 查看磁盘 IO 统计
iostat -x 1

# 查看页缓存命中率
cat /proc/meminfo | grep -E "(Dirty|Writeback)"

# 查看文件系统缓存
free -h
```

## 第六层：实战练习

### 练习1：实现一个安全的日志写入函数

编写一个 `safe_log_write` 函数，支持多进程同时写入同一个日志文件，保证日志行不交错，且关键日志能立即刷盘。

```c
// 提示：
// 1. 使用 O_APPEND 保证原子追加
// 2. 对需要立即落盘的关键日志调用 fsync
// 3. 返回写入的字节数
int safe_log_write(int fd, const char *line, int len, bool critical);
```

### 练习2：分析 mmap 和 read 的性能差异

写一个测试程序，用 `mmap` 和 `read` 两种方式读取一个 100MB 的文件，分别统计耗时。分析为什么 `mmap` 在随机访问场景下比 `read` 快。

### 练习3：阅读真实源码——V881 OTA 更新流程

阅读 `/home/ys/aiglass/reglasses/services/ota/` 目录下的源码，找出 OTA 固件更新中使用了哪些文件 IO 技术（原子替换、fsync、临时文件），画出 OTA 更新的完整 IO 流程。

## 自测与验收

1. 系统调用（`read/write`）和标准库（`fread/fwrite`）的核心区别是什么？分别适用于什么场景？
2. 为什么 `write` 返回后数据不一定在磁盘上？要保证数据落盘需要调用什么函数？
3. 多进程同时写入同一个日志文件，如何保证日志行不交错？为什么 `lseek + write` 不安全？
4. 什么是文件描述符泄漏？如何排查和预防？
5. `mmap` 读文件和 `read` 读文件在底层机制上有什么不同？为什么 `mmap` 适合大文件随机访问？
6. `rename` 为什么是原子操作？在 OTA 升级中怎么利用这个特性？

## 延伸阅读

- [[network-mqtt-http-网络编程]] — Socket 也是文件描述符，用 read/write 操作
- [[boot-ota-启动流程与OTA升级]] — OTA 固件的文件写入和原子替换
- [[systemd-daemon-Systemd守护进程]] — 守护进程的日志文件管理
- [[memory-dma-内存管理与DMA]] — DMA 和内存缓冲机制

## #flashcard

Q: 文件描述符（fd）是什么？0/1/2 分别代表什么？
A: fd 是内核维护的打开文件索引，非负整数。0=stdin（标准输入），1=stdout（标准输出），2=stderr（标准错误）。

Q: write 返回后数据是否一定在磁盘上？
A: 不一定。write 只是在用户态缓冲区或内核页缓存中写入，要确保数据落盘需要调用 fsync 或 fdatasync。

Q: O_APPEND 解决了什么问题？
A: 多进程同时追加写同一个文件时的数据交错问题。O_APPEND 保证"移到末尾+写入"是原子操作。

Q: fopen 和 open 的区别？
A: fopen 是标准库函数（带用户态缓冲），open 是系统调用（无缓冲）。fopen 基于 open 实现，减少系统调用次数。

Q: mmap 读取文件的原理？
A: mmap 把文件映射到进程地址空间，通过缺页中断按需加载文件块，修改后由内核 writeback 写回磁盘。适合大文件随机访问。