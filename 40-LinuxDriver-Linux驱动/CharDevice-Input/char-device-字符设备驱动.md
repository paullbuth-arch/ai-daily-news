# 字符设备驱动

**一句话结论（20% 核心）**：字符设备是 Linux 下最基础的驱动类型——按键、传感器、串口都是字符设备。应用层通过 `open/read/write/ioctl` 操作设备文件，驱动层实现这些操作对应的函数。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：前台接待

字符设备驱动 = 前台接待：
- 应用层说 `open("/dev/button", O_RDONLY)` → "你好，我要用按键服务"
- 驱动层返回一个 fd（文件描述符）→ "给你个号，3 号窗口"
- 应用层说 `read(fd, buf, size)` → "读一下按键状态"
- 驱动层返回按键值 → "当前按下了 KEY_1"

### 1.2 核心结构体

```c
// 每个字符设备驱动都要实现这个结构体
static const struct file_operations my_fops = {
    .owner   = THIS_MODULE,
    .open    = my_open,
    .read    = my_read,
    .write   = my_write,
    .unlocked_ioctl = my_ioctl,
    .release = my_release,
};

// 注册字符设备
cdev_init(&my_cdev, &my_fops);
cdev_add(&my_cdev, dev_num, 1);  // 创建设备节点 /dev/mydevice
```

### 1.3 如果只记得一件事

> 字符设备 = 通过 open/read/write/ioctl 操作的设备（按键、串口、传感器）。驱动实现 `file_operations` 结构体中的函数，应用层通过 `/dev/xxx` 访问。

---

## 第二层：实战理解

### 2.1 最小字符设备驱动

```c
#include <linux/module.h>
#include <linux/fs.h>
#include <linux/cdev.h>
#include <linux/uaccess.h>

static int my_open(struct inode *inode, struct file *filp) {
    pr_info("Device opened\n");
    return 0;
}

static ssize_t my_read(struct file *filp, char __user *buf,
                       size_t count, loff_t *pos) {
    const char *msg = "Hello from kernel!\n";
    size_t len = strlen(msg);
    if (*pos >= len) return 0;
    if (copy_to_user(buf, msg, len)) return -EFAULT;
    *pos += len;
    return len;
}

static const struct file_operations my_fops = {
    .owner = THIS_MODULE,
    .open  = my_open,
    .read  = my_read,
};

static int __init my_init(void) { /* 注册设备 */ return 0; }
static void __exit my_exit(void) { /* 注销设备 */ }

module_init(my_init);
module_exit(my_exit);
MODULE_LICENSE("GPL");
```

### 2.2 常见坑

| 问题 | 现象 | 根因 |
|------|------|------|
| copy_to_user 失败 | 应用层读不到数据 | 用户空间指针无效，返回 -EFAULT |
| 设备号冲突 | 创建设备节点失败 | 主设备号已被占用 |
| 忘注册设备节点 | 应用层 open 失败 | 需要在 /dev 下创建设备节点 |

### 2.3 在 reGlasses 项目中怎么用

WQ7036AX 跑 FreeRTOS，没有 Linux 字符设备概念。V881 侧的所有外设驱动（摄像头、TOF、WiFi）都是字符设备或 V4L2 设备，通过 `/dev/video0`、`/dev/i2c-0` 等节点访问。

---

## 第三层：延伸阅读

- [[platform-driver-外设驱动框架]] — Platform Driver 是字符设备驱动的常用封装
- [[i2c-spi-gpio-subsys-I2C-SPI-GPIO子系统]] — I2C/SPI 字符设备的具体实现