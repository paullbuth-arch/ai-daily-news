# 文件 IO

**一句话结论（20% 核心）**：Linux 一切皆文件——普通文件、设备、管道、Socket 都通过文件描述符操作。文件 IO 分两层：系统调用（`open/read/write/close`，无缓冲，直通内核）和标准库（`fopen/fread/fwrite/fclose`，用户态缓冲，性能好）。理解缓冲、同步和原子性是掌握文件 IO 的关键。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：银行柜台 vs 钱包

- **系统调用 IO**（`read/write`）= 每次存取都去银行柜台排队。即时到账，但每次都要排队。
- **标准库 IO**（`fread/fwrite`）= 先把钱存在钱包里，攒够一笔再去柜台。快，但钱包丢了（进程崩溃）数据就没了。
- **fsync/fdatasync** = 跟柜员说"现在就入账，别放缓冲区"——强制刷到磁盘，保证断电不丢。

### 1.2 文件描述符：内核的"号码牌"

```c
// 每个进程有一个文件描述符表，fd 是这张表的索引
int fd = open("/data/log.txt", O_WRONLY | O_CREAT, 0644);
// 内核返回 fd=3（0=stdin, 1=stdout, 2=stderr 已被占用）

write(fd, "hello", 5);  // 内核通过 fd 找到文件对象，写入数据
close(fd);               // 释放 fd，内核引用计数 -1
```

**关键理解**：fd 只是一个整数索引。真正的文件对象（inode、偏移量、缓冲区）在内核中管理。多个 fd 可以指向同一个文件（dup），多个进程可以同时打开同一个文件。

### 1.3 文件打开的 flag 详解

```c
// 访问模式（三选一）
O_RDONLY    // 只读
O_WRONLY    // 只写
O_RDWR      // 读写

// 常用组合（| 连接）
O_CREAT     // 文件不存在则创建
O_TRUNC     // 打开时清空文件
O_APPEND    // 每次写入追加到文件末尾（原子操作）
O_EXCL      // 配合 O_CREAT，文件已存在则失败
O_NONBLOCK  // 非阻塞模式（用于管道/Socket）
O_SYNC      // 每次 write 都同步到磁盘
```

### 1.4 如果只记得一件事

> 文件 IO = 系统调用（`open/read/write/close`，无缓冲，实时）+ 标准库（`fopen/fread/fwrite`，用户态缓冲，快）。关键数据写入后必须 `fsync`/`fdatasync`，否则断电丢失。`O_APPEND` 保证多进程追加写入的原子性。

---

## 第二层：实战理解

### 2.1 缓冲机制：数据到底在哪？

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

**为什么要三层？** 因为磁盘太慢了。每层缓冲都是"攒够一批再往下传"，大幅减少磁盘 IO 次数。

### 2.2 fsync vs fdatasync vs O_SYNC

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

### 2.3 原子追加写入

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

### 2.4 常见坑

| 问题 | 现象 | 排查方法 | 根因 |
|------|------|---------|------|
| 写入后断电数据丢失 | 文件为空或截断 | 检查是否调了 fsync | 数据在页缓存中，没刷到磁盘 |
| 文件描述符泄漏 | `open()` 返回 -1 (EMFILE) | `lsof -p PID` 看打开的 fd | 忘了 close，或 close 在错误路径中没执行 |
| 多进程写交错 | 日志行互相穿插 | 检查是否用了 O_APPEND | 没有原子追加，两进程的 write 内容混在一起 |
| 大文件写入慢 | 持续写入后性能骤降 | `iostat -x 1` 看磁盘利用率 | 页缓存满了，触发 writeback 阻塞 |

### 2.5 在 reGlasses 项目中怎么用

V881 侧有 eMMC 存储，所有持久化数据都通过文件 IO：
- **日志**：`/var/log/` 下各服务的日志文件，用 `O_APPEND` 原子写入
- **配置**：`/etc/` 下的配置文件，修改后 `fsync` 保证不丢失
- **OTA 固件**：下载到 `/tmp/update.bin`，校验后 `rename` 到 `/boot/`（`rename` 是原子操作）

WQ7036AX 没有文件系统，数据直接存在 Flash 固定地址，不需要文件 IO。

---

## 第三层：深入扩展

### 3.1 mmap：把文件映射到内存

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

### 3.2 常见问题

- **`write` 返回值小于请求长度怎么办？** 这通常意味着磁盘满了或达到文件大小限制。正常情况（写普通文件）不会发生，但写管道/Socket 时可能发生。
- **`fsync` 和 `sync` 的区别？** `fsync` 只刷一个文件，`sync` 刷整个系统的所有脏页缓存。`sync` 影响全局性能，不要随便用。
- **为什么 `rename` 是原子操作？** 因为文件系统保证 `rename` 要么完全成功，要么完全不变（不会出现中间状态）。OTA 更新常用这个特性：下载新固件 → `rename` 替换旧固件。

### 3.3 延伸阅读

- [[network-mqtt-http-网络编程]] — Socket 也是文件描述符，用 read/write 操作
- [[boot-ota-启动流程与OTA升级]] — OTA 固件的文件写入和原子替换
- [[systemd-daemon-Systemd守护进程]] — 守护进程的日志文件管理