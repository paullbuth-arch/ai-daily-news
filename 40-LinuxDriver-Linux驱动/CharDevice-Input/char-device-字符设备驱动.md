---
type: concept
tags: [LinuxDriver, 字符设备, 驱动, file_operations, cdev, 设备文件, Linux内核]
aliases: [字符设备, char device, cdev, 设备驱动, 驱动开发, file_operations]
---

# 字符设备驱动

## 一句话结论

字符设备是 Linux 最基础的驱动类型——按键、串口、传感器、I2C 设备都是字符设备。应用层通过 `open/read/write/ioctl` 操作 `/dev/xxx` 设备文件，驱动层实现 `file_operations` 结构体中的对应函数。内核把一切设备都抽象成文件，字符设备是这个哲学的基本实现。

## 30秒先看懂

- 字符设备以字节流方式访问，没有随机访问能力（不能"读第 5 个字节"），典型例子是按键和串口。
- 驱动的核心是 `file_operations` 结构体，它定义了 `open`、`read`、`write`、`ioctl`、`release` 等函数的实现。
- 用户空间和内核空间不能直接传递指针——必须用 `copy_to_user` 和 `copy_from_user` 安全拷贝数据。
- 设备号（major/minor）是内核识别设备的 ID，主设备号对应驱动，次设备号对应具体设备实例。
- 驱动注册流程：分配设备号 → 初始化 cdev → 注册 cdev → 创建设备类 → 创建设备节点 `/dev/xxx`。

## 学完以后应该能做什么

**第一遍**
- 能写出一个完整的字符设备驱动（包括 open/read/write/ioctl 实现）
- 能理解 `copy_to_user`/`copy_from_user` 的重要性和用法
- 能手动或自动创建设备节点，并验证驱动工作

**进阶**
- 能理解 udev 自动创建设备节点的机制
- 能实现阻塞和非阻塞读写
- 能实现多进程并发访问的互斥保护

## 前置知识

- Linux 系统调用基础：open/read/write/ioctl/close
- C 语言：指针、结构体、函数指针
- Linux 内核模块基础：module_init/module_exit

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|----------|
| 字符设备 | Character Device | 以字节流方式访问的设备，顺序读写，不支持随机访问 |
| 块设备 | Block Device | 以块（512B/4KB）为单位随机访问，有缓存，如硬盘、eMMC |
| 网络设备 | Network Device | 通过网络协议栈收发数据包，没有设备文件，如网卡 |
| 文件操作结构体 | file_operations | 驱动实现的函数指针表，每个函数对应一个系统调用 |
| 设备号 | Device Number | 主设备号（major）标识驱动，次设备号（minor）标识设备实例 |
| 设备节点 | Device Node | `/dev/xxx` 文件，应用层通过它访问设备 |
| 内核空间 | Kernel Space | 驱动代码运行的空间，有最高权限，不能直接访问用户空间指针 |
| 用户空间 | User Space | 应用程序运行的空间，受限，不能直接操作硬件 |

## 第一层：费曼心智模型

### 类比：银行柜台

字符设备驱动 = 银行柜台系统：
- 你走进银行，取号（`open("/dev/button")`）——得到一个排队号（fd）
- 到 3 号窗口，递给柜员一张纸条"我要读余额"（`read(fd, buf, 4)`）
- 柜员在电脑上操作，把结果写在纸条上还给你（驱动从硬件读取数据，copy_to_user）
- 或者你递进去一张存款单（`write(fd, buf, len)`），柜员帮你存钱
- 或者你问"帮我查一下这个账户的流水"（`ioctl(fd, CMD, arg)`）
- 办完事，离开柜台（`close(fd)`）

**关键理解**：你不需要知道柜员（驱动）在电脑上怎么操作的——你只需要知道"递纸条→拿结果"这个接口。这就是驱动的核心价值：**把硬件操作封装成标准文件操作**。

### 边界在哪里

- 字符设备不能随机访问——如果你对设备说"读第 5 个字节"，字符设备做不到（数据是流式的）
- 驱动运行在内核空间，有最高权限——一个 bug 驱动的崩溃会导致整个系统 panic，不只是那个进程挂掉
- `copy_to_user` 会检查用户空间指针的有效性——如果指针无效，返回 `-EFAULT` 而不是让内核崩溃
- 字符设备不适合大数据块传输——高吞吐场景（如显示、存储）用块设备或其他机制

### 场景演练：V881 读取光传感器

1. 应用层：`fd = open("/dev/light_sensor", O_RDWR)` → 内核调用驱动的 `my_open`
2. 应用层：`ioctl(fd, CMD_START_MEASURE, NULL)` → 内核调用 `my_ioctl`，启动 ADC 采集
3. 应用层：`read(fd, &lux, 4)` → 内核调用 `my_read`，从硬件寄存器读取光强度值，`copy_to_user` 返回
4. 应用层：`close(fd)` → 内核调用 `my_release`，释放资源

## 第二层：原理/时序/约束

### 字符设备 vs 块设备 vs 网络设备

| 类型 | 访问方式 | 特点 | 例子 |
|------|---------|------|------|
| **字符设备** | open/read/write/ioctl | 字节流，顺序访问 | 按键、串口、I2C、GPIO |
| **块设备** | mount → 文件系统 → read/write | 块访问，随机读写，有缓存 | 硬盘、SSD、eMMC |
| **网络设备** | socket/send/recv | 包传输，无设备文件 | 网卡、WiFi、蓝牙 |

### 驱动注册流程

```
模块加载（module_init）
    │
    ├── ① alloc_chrdev_region()     ← 动态分配设备号
    ├── ② cdev_init()               ← 初始化 cdev，绑定 file_operations
    ├── ③ cdev_add()                ← 注册 cdev 到内核
    ├── ④ class_create()            ← 创建设备类（用于 udev 自动创建节点）
    └── ⑤ device_create()           ← 创建设备节点 /dev/xxx
    │
    ↓ 模块卸载（module_exit）
    ├── device_destroy()
    ├── class_destroy()
    ├── cdev_del()
    └── unregister_chrdev_region()
```

### 完整的最小字符设备驱动

```c
#include <linux/module.h>
#include <linux/fs.h>
#include <linux/cdev.h>
#include <linux/device.h>
#include <linux/uaccess.h>

#define DEVICE_NAME "mychardev"

static dev_t dev_num;
static struct cdev my_cdev;
static struct class *my_class;

// 打开设备
static int my_open(struct inode *inode, struct file *filp) {
    pr_info("mychardev: opened\n");
    return 0;
}

// 读设备
static ssize_t my_read(struct file *filp, char __user *buf,
                       size_t count, loff_t *pos) {
    const char *msg = "Hello from kernel driver!\n";
    size_t len = strlen(msg);

    if (*pos >= len) return 0;
    if (count < len) return -ENOSPC;

    if (copy_to_user(buf, msg, len))
        return -EFAULT;

    *pos += len;
    return len;
}

// 写设备
static ssize_t my_write(struct file *filp, const char __user *buf,
                        size_t count, loff_t *pos) {
    char kbuf[128];
    size_t len = min(count, sizeof(kbuf) - 1);

    if (copy_from_user(kbuf, buf, len))
        return -EFAULT;

    kbuf[len] = '\0';
    pr_info("mychardev: wrote '%s'\n", kbuf);
    return len;
}

// ioctl 控制
static long my_ioctl(struct file *filp, unsigned int cmd, unsigned long arg) {
    switch (cmd) {
    case 0x01:
        pr_info("mychardev: reset\n");
        break;
    default:
        return -ENOTTY;
    }
    return 0;
}

static int my_release(struct inode *inode, struct file *filp) {
    pr_info("mychardev: closed\n");
    return 0;
}

static const struct file_operations my_fops = {
    .owner          = THIS_MODULE,
    .open           = my_open,
    .release        = my_release,
    .read           = my_read,
    .write          = my_write,
    .unlocked_ioctl = my_ioctl,
};

static int __init my_init(void) {
    alloc_chrdev_region(&dev_num, 0, 1, DEVICE_NAME);
    cdev_init(&my_cdev, &my_fops);
    cdev_add(&my_cdev, dev_num, 1);
    my_class = class_create(THIS_MODULE, DEVICE_NAME);
    device_create(my_class, NULL, dev_num, NULL, DEVICE_NAME);
    pr_info("mychardev: loaded, major=%d\n", MAJOR(dev_num));
    return 0;
}

static void __exit my_exit(void) {
    device_destroy(my_class, dev_num);
    class_destroy(my_class);
    cdev_del(&my_cdev);
    unregister_chrdev_region(dev_num, 1);
    pr_info("mychardev: unloaded\n");
}

module_init(my_init);
module_exit(my_exit);
MODULE_LICENSE("GPL");
```

## 第三层：真实 SDK 代码

### WQ7036AX 侧没有字符设备概念

WQ7036AX 跑 FreeRTOS，没有 Linux 字符设备概念。它的驱动模型是裸机/RTOS 风格——直接调用 `wq_uart_init()`、`wq_i2c_write()` 等 API。但 FreeRTOS 也提供了类似字符设备的抽象，例如通过队列（Queue）实现类似 read/write 的机制。

### V881 侧的外设都是字符设备

V881 跑 Linux，所有外设驱动都是字符设备：
- `/dev/video0` — 广角摄像头（V4L2 设备，底层也是字符设备）
- `/dev/video1` — TOF 摄像头
- `/dev/i2c-0` — I2C 总线，应用层可以直接读写 I2C 设备
- `/dev/ttyS0` — 调试串口
- `/dev/input/event0` — 输入设备（按键、触摸）

### Linux 内核中的字符设备驱动示例

V881 的 GPIO 驱动在 `/home/ys/aiglass/tina-v861/kernel/linux-6.6-xuantie/drivers/gpio/` 下，这些驱动最终都通过字符设备接口暴露给用户空间（通过 gpiolib 的 cdev 接口）。

## 第四层：正常/异常路径

### 正常路径

1. 应用层 `open("/dev/mychardev")` → 驱动 `my_open` 执行，返回 fd
2. 应用层 `read(fd, buf, count)` → 驱动 `my_read` 执行，数据正确返回
3. 应用层 `write(fd, buf, count)` → 驱动 `my_write` 执行，数据写入硬件
4. 应用层 `close(fd)` → 驱动 `my_release` 执行，资源释放

### 异常路径

| 问题 | 现象 | 根因 | 排查方法 |
|------|------|------|----------|
| copy_to_user 返回非零 | 应用层 read 返回 -EFAULT | 用户空间指针无效（NULL、已释放、越界） | dmesg 看有无 oops |
| 设备号冲突 | insmod 失败 | 静态分配的设备号已被其他驱动占用 | `cat /proc/devices` 查看已占用的设备号 |
| 设备节点未创建 | 应用层 open 返回 -ENOENT | 忘了调 device_create 或 udev 规则不对 | `ls -l /dev/` 查看节点是否存在 |
| read 返回 0 后不再调用 | 应用层只读到一次数据 | 内核 VFS 层认为已到文件末尾，不再调用 read | 检查 `*pos` 是否正确更新 |
| open 时设备被占用 | open 返回 -EBUSY | 驱动在 open 中设了独占标志 | 检查是否有其他进程已打开同一个设备 |

## 第五层：调试方法

### 查看设备信息

```bash
# 查看设备号分配
cat /proc/devices

# 查看设备节点
ls -l /dev/mychardev

# 查看内核日志
dmesg | tail -20

# 查看哪些进程打开了设备
lsof | grep /dev/mychardev
```

### 测试驱动

```bash
# 编译驱动
make -C /lib/modules/$(uname -r)/build M=$(pwd) modules

# 加载驱动
insmod mychardev.ko

# 测试读写
echo "hello" > /dev/mychardev
cat /dev/mychardev

# 卸载驱动
rmmod mychardev

# 查看内核日志中的驱动消息
dmesg | grep mychardev
```

## 第六层：实战练习

### 练习 1：写一个字符设备驱动

写一个简单的字符设备驱动，实现以下功能：
- `open` 时打印 "device opened"
- `read` 返回当前的内核启动时间（jiffies 值）
- `write` 接收一个字符串，打印到内核日志
- `ioctl` 支持两个命令：CMD_RESET（重置设备状态）和 CMD_GET_STATUS（获取设备状态）
- `close` 时打印 "device closed"

### 练习 2：应用层测试程序

写一个 C 语言测试程序，测试练习 1 中的驱动：
- 调用 `open()` 打开设备
- 调用 `read()` 读取并打印 jiffies 值
- 调用 `write()` 写入 "test message"
- 调用 `ioctl()` 执行 CMD_GET_STATUS
- 调用 `close()` 关闭设备

### 练习 3：分析 V881 的 I2C 字符设备接口

在 V881 的 Linux 系统中，I2C 设备通过 `/dev/i2c-N` 字符设备暴露给用户空间。阅读对应的内核源码（位置自寻），回答：
- I2C 字符设备的 `file_operations` 中实现了哪些函数？
- 应用层如何通过 ioctl 读写 I2C 从设备？
- I2C 字符设备的主设备号是多少？

### 练习 4：阻塞 vs 非阻塞

修改练习 1 的驱动，使 `read` 在设备没有数据时阻塞等待，直到有数据才返回。要求：
- 使用等待队列（wait_queue_head_t）
- 应用层可以用 `O_NONBLOCK` 标志选择非阻塞模式
- 非阻塞模式下没有数据时立即返回 -EAGAIN

## 自测与验收

1. 字符设备、块设备、网络设备有什么区别？判断一个设备属于哪种类型的关键标准是什么？
2. 为什么内核和用户空间之间不能直接传递指针？`copy_to_user` 和 `copy_from_user` 的作用是什么？
3. 设备号中的主设备号和次设备号分别代表什么？
4. 驱动注册的完整流程是什么？从模块加载到 `/dev/xxx` 出现。
5. `file_operations` 结构体中的 `unlocked_ioctl` 和 `compat_ioctl` 有什么区别？

## 延伸阅读

- [[platform-driver-外设驱动框架]] — Platform Driver 是字符设备的标准封装
- [[i2c-spi-gpio-subsys-I2C-SPI-GPIO子系统]] — I2C/SPI 设备的字符设备实现
- [[devicetree-DeviceTree设备树]] — 设备树中如何声明字符设备资源

## #flashcard

Q: 字符设备的核心特征是什么？
A: 以字节流方式顺序访问，不支持随机访问（不能"读第 5 个字节"）。通过 `/dev/xxx` 设备文件暴露给用户空间。

Q: 为什么需要 `copy_to_user` 和 `copy_from_user`？
A: 内核空间不能直接解引用用户空间指针（指针可能无效、恶意、被换出）。这两个函数会检查指针有效性，失败时返回 -EFAULT 而不是让内核崩溃。

Q: 字符设备驱动注册的完整流程是什么？
A: alloc_chrdev_region() 分配设备号 → cdev_init() 初始化 cdev → cdev_add() 注册 cdev → class_create() 创建设备类 → device_create() 创建设备节点。

Q: 主设备号和次设备号分别代表什么？
A: 主设备号（major）对应驱动，次设备号（minor）对应具体设备实例。例如 /dev/ttyS0 和 /dev/ttyS1 主设备号相同（同驱动），次设备号不同（不同串口）。

Q: 为什么 WQ7036AX 没有字符设备概念？
A: WQ7036AX 跑 FreeRTOS 而非 Linux，没有 VFS 层和 file_operations 机制。它的驱动模型是直接调用 API 的裸机/RTOS 风格。