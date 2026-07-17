# 文件 IO

**一句话结论（20% 核心）**：Linux 一切皆文件——普通文件、设备文件、管道、Socket 都是文件。文件 IO 的核心 API：`open/read/write/close`（基础）和 `fopen/fread/fwrite/fclose`（带缓冲）。理解缓冲和同步是掌握文件 IO 的关键。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：银行柜台

- **无缓冲 IO**（`read/write`）= 每次存取都去柜台排队，即时但慢
- **带缓冲 IO**（`fread/fwrite`）= 先把钱存在钱包里，攒够了再去柜台，快但延迟

### 1.2 核心 API

```c
// 系统调用（无缓冲，直接进内核）
int fd = open("/data/log.txt", O_WRONLY | O_CREAT, 0644);
write(fd, buf, len);
fsync(fd);    // 强制刷到磁盘
close(fd);

// 标准库（带缓冲，在用户空间缓冲）
FILE *fp = fopen("/data/log.txt", "w");
fprintf(fp, "Log: %s\n", msg);
fflush(fp);   // 强制刷缓冲区
fclose(fp);
```

### 1.3 如果只记得一件事

> 文件 IO = open/read/write/close（系统调用，慢但实时）+ fopen/fread/fwrite（标准库，快但缓冲）。关键数据写入后要 fsync/fflush，否则断电可能丢失。

---

## 第二层：实战理解

### 2.1 常见坑

| 问题 | 现象 | 根因 |
|------|------|------|
| 写入后断电数据丢失 | 文件内容为空或截断 | 数据在缓冲区里，没刷到磁盘 |
| 文件描述符泄漏 | 打开文件失败（too many open files） | open 后忘了 close |
| 多进程写同一文件 | 数据交错 | 没有用 O_APPEND 或文件锁 |

### 2.2 在 reGlasses 项目中怎么用

V881 侧有 eMMC 存储，日志、配置、OTA 固件都通过文件 IO 读写。WQ7036AX 没有文件系统（Flash 直接存固件），不需要文件 IO。

---

## 第三层：延伸阅读

- [[network-mqtt-http-网络编程]] — Socket 也是文件描述符
- [[boot-ota-启动流程与OTA升级]] — OTA 固件下载后的文件写入