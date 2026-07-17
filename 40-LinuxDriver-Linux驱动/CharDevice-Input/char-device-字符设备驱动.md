# 字符设备驱动

**一句话结论（20% 核心）**：字符设备是 Linux 最基础的驱动类型——按键、串口、传感器、I2C 设备都是字符设备。应用层通过 `open/read/write/ioctl` 操作 `/dev/xxx` 设备文件，驱动层实现 `file_operations` 结构体中的对应函数。内核把一切设备都抽象成文件，字符设备是这个哲学的基本实现。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：银行柜台

字符设备驱动 = 银行柜台系统：
- 你走进银行，取号（`open("/dev/button")`）——得到一个排队号（fd）
- 到 3 号窗口，递给柜员一张纸条"我要读余额"（`read(fd, buf, 4)`）
- 柜员在电脑上操作，把结果写在纸条上还给你（驱动从硬件读取数据，copy_to_user）
- 办完事，离开柜台（`close(fd)`）

**关键理解**：你不需要知道柜员（驱动）在电脑上怎么操作的——你只需要知道"递纸条→拿结果"这个接口。这就是驱动的核心价值：**把硬件操作封装成标准文件操作**。

### 1.2 字符设备 vs 块设备 vs 网络设备

Linux 把设备分成三类，字符设备是最基础的那一类：

| 类型 | 访问方式 | 特点 | 例子 |
|------|---------|------|------|
| **字符设备** | open/read/write/ioctl | 字节流，顺序访问 | 按键、串口、I2C、GPIO |
| **块设备** | mount → 文件系统 → read/write | 块访问，随机读写，有缓存 | 硬盘、SSD、eMMC |
| **网络设备** | socket/send/recv | 包传输，无设备文件 | 网卡、WiFi、蓝牙 |

**判断标准**：如果你对设备说"读第 5 个字节"，字符设备做不到（因为它没有"第 5 个"的概念，数据是流式的）。块设备可以（因为它是随机访问的存储）。

### 1.3 驱动层的核心：file_operations 结构体

```c
// 这是字符设备驱动的心脏——每个函数对应一个系统调用
static const struct file_operations my_fops = {
    .owner          = THIS_MODULE,      // 模块引用计数
    .open           = my_open,          // 系统调用 open() → 这里
    .release        = my_release,       // 系统调用 close() → 这里
    .read           = my_read,          // 系统调用 read() → 这里
    .write          = my_write,         // 系统调用 write() → 这里
    .unlocked_ioctl = my_ioctl,         // 系统调用 ioctl() → 这里
    .llseek         = my_llseek,        // 系统调用 lseek() → 这里
    .mmap           = my_mmap,          // 系统调用 mmap() → 这里
};

// 注册：让内核知道这个驱动的存在
cdev_init(&my_cdev, &my_fops);
cdev_add(&my_cdev, dev_num, 1);     // 1 = 创建设备节点 /dev/mydevice
```

### 1.4 用户空间 ↔ 内核空间的数据拷贝

这是驱动开发最容易出错的地方。用户空间的指针不能在内核中直接解引用（因为用户空间可能被换出，或者指针是恶意的）。

```c
// 错误：直接访问用户空间指针（会导致内核 oops）
// *user_ptr = 42;  ← 绝对不能这样做！

// 正确：使用专用函数
int value = 42;
copy_to_user(user_ptr, &value, sizeof(value));    // 内核→用户
copy_from_user(&value, user_ptr, sizeof(value));  // 用户→内核
```

**为什么需要这两个函数？** 它们会检查用户空间指针是否有效、是否在可访问的地址范围内。如果指针无效，返回 `-EFAULT` 而不是让内核崩溃。

### 1.5 如果只记得一件事

> 字符设备 = 通过 open/read/write/ioctl 操作 `/dev/xxx` 文件。驱动实现 `file_operations` 结构体中的函数。内核和用户空间之间用 `copy_to_user`/`copy_from_user` 安全传数据。

---

## 第二层：实战理解

### 2.1 完整的最小字符设备驱动（可编译运行）

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

// 打开设备：用户调用 open("/dev/mychardev")
static int my_open(struct inode *inode, struct file *filp) {
    pr_info("mychardev: opened\n");
    return 0;
}

// 读设备：用户调用 read(fd, buf, count)
static ssize_t my_read(struct file *filp, char __user *buf,
                       size_t count, loff_t *pos) {
    const char *msg = "Hello from kernel driver!\n";
    size_t len = strlen(msg);

    if (*pos >= len) return 0;          // 已经读到文件末尾
    if (count < len) return -ENOSPC;    // 用户缓冲区太小

    if (copy_to_user(buf, msg, len))    // 安全拷贝到用户空间
        return -EFAULT;

    *pos += len;                        // 更新文件位置
    return len;                         // 返回实际读取的字节数
}

// 写设备：用户调用 write(fd, buf, count)
static ssize_t my_write(struct file *filp, const char __user *buf,
                        size_t count, loff_t *pos) {
    char kbuf[128];
    size_t len = min(count, sizeof(kbuf) - 1);

    if (copy_from_user(kbuf, buf, len))  // 安全拷贝到内核空间
        return -EFAULT;

    kbuf[len] = '\0';
    pr_info("mychardev: wrote '%s'\n", kbuf);
    return len;
}

// ioctl：用户调用 ioctl(fd, CMD, arg)
static long my_ioctl(struct file *filp, unsigned int cmd, unsigned long arg) {
    switch (cmd) {
    case 0x01:  // 自定义命令：重置设备
        pr_info("mychardev: reset\n");
        break;
    default:
        return -ENOTTY;  // 不支持的 ioctl 命令
    }
    return 0;
}

// 释放设备：用户调用 close(fd)
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

// 模块加载时：注册设备
static int __init my_init(void) {
    // ① 动态分配设备号
    alloc_chrdev_region(&dev_num, 0, 1, DEVICE_NAME);

    // ② 初始化 cdev
    cdev_init(&my_cdev, &my_fops);
    cdev_add(&my_cdev, dev_num, 1);

    // ③ 创建设备节点 /dev/mychardev（自动创建，不需要手动 mknod）
    my_class = class_create(THIS_MODULE, DEVICE_NAME);
    device_create(my_class, NULL, dev_num, NULL, DEVICE_NAME);

    pr_info("mychardev: loaded, major=%d\n", MAJOR(dev_num));
    return 0;
}

// 模块卸载时：注销设备
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
MODULE_DESCRIPTION("A minimal character device driver");
```

### 2.2 设备号的分配：静态 vs 动态

```c
// 方式一：静态分配（指定主设备号，容易冲突）
#define MY_MAJOR 240
register_chrdev_region(MKDEV(MY_MAJOR, 0), 1, "mychardev");

// 方式二：动态分配（推荐，内核自动分配空闲的主设备号）
alloc_chrdev_region(&dev_num, 0, 1, "mychardev");
// dev_num 被内核填入分配的设备号
```

### 2.3 常见坑（附排查方法）

| 问题 | 现象 | 排查方法 | 根因 |
|------|------|---------|------|
| copy_to_user 返回非零 | 应用层 read 返回 -EFAULT | dmesg 看有无 oops | 用户空间指针无效（NULL、已释放、越界） |
| 设备号冲突 | insmod 失败 | `cat /proc/devices` 看哪些设备号已占用 | 静态分配的设备号已被其他驱动占用 |
| 设备节点未创建 | 应用层 open 返回 -ENOENT | `ls -l /dev/` 看节点是否存在 | 忘了调用 device_create 或 udev 规则不对 |
| read 返回 0 后不再调用 | 应用层只读到一次数据 | 检查 `*pos` 是否正确更新 | 内核 VFS 层认为已到文件末尾，不再调用 read |
| open 时设备被占用 | open 返回 -EBUSY | 检查是否有其他进程已打开 | 驱动在 open 中设了独占标志 |

### 2.4 在 reGlasses 项目中怎么用

WQ7036AX 跑 FreeRTOS，没有 Linux 字符设备概念——它的驱动模型是裸机/RTOS 风格（直接调用 `wq_uart_init` 等 API）。

V881 侧所有外设驱动都是字符设备：
- `/dev/video0` — 广角摄像头（V4L2 设备，底层也是字符设备）
- `/dev/video1` — TOF 摄像头
- `/dev/i2c-0` — I2C 总线，应用层可以直接读写 I2C 设备
- `/dev/ttyS0` — 调试串口

在 V881 上写驱动时，你写的就是这种 `file_operations` 结构体。

---

## 第三层：深入扩展

### 3.1 驱动的模块参数

```c
// 加载模块时传递参数
static int debug = 0;
module_param(debug, int, 0644);
MODULE_PARM_DESC(debug, "Enable debug output");

// insmod mydriver.ko debug=1
```

### 3.2 常见问题

- **字符设备和 platform driver 的关系？** Platform driver 是字符设备的一种组织方式，它把硬件资源（寄存器地址、中断号）从设备树中获取，然后注册字符设备接口。大多数嵌入式驱动都是 platform driver + 字符设备的组合。
- **为什么需要 ioctl？** 因为 read/write 只适合流式数据，不适合控制操作（如"设置波特率"、"开始采集"）。ioctl 是通用控制接口。
- **设备节点的主次设备号是什么意思？** 主设备号（major）对应驱动，次设备号（minor）对应具体设备实例。例如 `/dev/ttyS0` 和 `/dev/ttyS1` 共享同一个驱动（主设备号相同），次设备号不同区分两个串口。

### 3.3 延伸阅读

- [[platform-driver-外设驱动框架]] — Platform Driver 是字符设备的标准封装
- [[i2c-spi-gpio-subsys-I2C-SPI-GPIO子系统]] — I2C/SPI 设备的字符设备实现
- [[devicetree-DeviceTree设备树]] — 设备树中如何声明字符设备资源