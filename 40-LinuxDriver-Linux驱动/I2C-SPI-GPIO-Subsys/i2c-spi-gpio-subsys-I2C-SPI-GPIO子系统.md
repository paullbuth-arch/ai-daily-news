---
type: concept
tags: [LinuxDriver, I2C, SPI, GPIO, 子系统, 驱动, Linux内核, 设备树]
aliases: [I2C子系统, SPI子系统, GPIO子系统, i2c, spi, gpio, 子系统, gpiod, 设备驱动]
---

# I2C / SPI / GPIO 子系统

## 一句话结论

Linux 把 I2C、SPI、GPIO 封装成了标准子系统——驱动的 probe 不再手动初始化总线，而是由内核根据设备树自动匹配。I2C 用 `i2c_driver` + `i2c_client`，SPI 用 `spi_driver` + `spi_device`，GPIO 用 `gpiod_*` API。三个子系统的模式完全一致：设备树声明 → compatible 匹配 → probe 执行。

## 30秒先看懂

- 三个子系统的核心模式完全一致：设备树（DTS）中声明设备 → compatible 字符串匹配驱动 → 内核自动调用 probe 函数。
- 裸机开发你需要自己初始化 I2C 控制器、配置时钟、设置 GPIO——Linux 子系统帮你做了这些，你只需要在设备树中声明硬件连接。
- I2C 驱动用 `i2c_smbus_read_byte_data()` 等 API 读写，SPI 驱动用 `spi_write_then_read()` 等 API，GPIO 用 `gpiod_set_value()` 等 API。
- 换芯片时，只要新芯片的控制器驱动实现了标准子系统接口，你的设备驱动代码不需要改，改设备树中的 compatible 字符串即可。
- GPIO 子系统的新 API 是 `gpiod_*`（descriptor-based），使用 `struct gpio_desc *` 描述符，更安全；旧的 `gpio_*` 整数编号 API 已废弃。

## 学完以后应该能做什么

**第一遍**
- 能写出一个完整的 I2C 设备驱动（probe/remove + 读写）
- 能写出一个完整的 SPI 设备驱动
- 能用 gpiod API 在驱动中读取和设置 GPIO

**进阶**
- 能理解 I2C 设备树中 reg、interrupts 等属性的含义
- 能调试 probe 不执行的问题（compatible 匹配、pinmux 冲突等）
- 能在 V881 上为新的 I2C/SPI 传感器编写驱动

## 前置知识

- 设备树基础：compatible、reg、interrupts 属性
- 字符设备驱动基础：file_operations、probe 机制
- I2C/SPI 协议基础：时序、地址、速率

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|----------|
| I2C 客户端 | i2c_client | 内核中代表一个 I2C 从设备的对象，包含地址、适配器等信息 |
| I2C 驱动 | i2c_driver | I2C 设备驱动的结构体，包含 probe/remove 和 of_match_table |
| SPI 设备 | spi_device | 内核中代表一个 SPI 从设备的对象，包含模式、速度等信息 |
| SPI 驱动 | spi_driver | SPI 设备驱动的结构体，类似 i2c_driver |
| GPIO 描述符 | gpio_desc | GPIO 的描述符对象，替代旧的整数编号方式 |
| 匹配表 | of_match_table | 驱动中声明的 compatible 字符串列表，用于和设备树匹配 |
| SMBus | System Management Bus | I2C 的子集协议，8 位寄存器地址，更简单常用 |

## 第一层：费曼心智模型

### 类比：酒店前台

**裸机/RTOS 开发**：你自己拿钥匙开每个房间的门，直接操作寄存器（`*(volatile *)0x40000000 = 0x01`）。你要知道每个房间的门牌号、锁的类型、钥匙在哪。

**Linux 子系统**：你告诉前台"帮我开 302 房间"，前台帮你开。你不需要知道钥匙在哪，不需要知道 302 房间的门锁是什么品牌。前台（内核子系统）帮你处理了所有底层细节。

**核心价值**：换一个芯片，只要它的 I2C 控制器驱动实现了标准接口，你的设备驱动代码不用改。设备树中改一个 `compatible` 字符串，内核自动匹配合适的控制器驱动。

### 边界在哪里

- 子系统只负责"匹配驱动 → 调用 probe"，probe 之后的业务逻辑完全由你决定
- 如果 compatible 不匹配，设备静默被忽略——内核不会报"找不到驱动"
- GPIO 的 `gpiod_*` API 依赖设备树声明——如果没有设备树，需要用 `gpio_request` 等旧 API
- 三个子系统的 probe 都在线程上下文中运行，可以睡眠（可以调用 msleep、mutex_lock）

### 场景演练：V881 新增 I2C 光传感器

1. 打开 V881 的设备树，在 `&i2c0` 节点下添加子节点：
   ```dts
   light_sensor@39 {
       compatible = "elam,elm2713";
       reg = <0x39>;
       interrupt-parent = <&pio>;
       interrupts = <0 12 2>;
   };
   ```
2. 编写驱动，实现 `i2c_driver` 结构体，`of_match_table` 中声明 `"elam,elm2713"`
3. 编译并安装驱动模块
4. 内核启动时解析 DTB → 发现 I2C0 上有设备 0x39 → 匹配 `elam,elm2713` → 调用 probe
5. probe 中通过 `i2c_smbus_read_byte_data(client, 0x00)` 读取芯片 ID 确认设备存在

## 第二层：原理/时序/约束

### 三个子系统的统一模式

```
设备树 (DTS)                  驱动 (Driver)
    │                              │
    │ compatible = "vendor,dev"    │  of_match_table 中声明同样的字符串
    │                              │
    └────────── 内核匹配 ──────────┘
                    │
                    ↓
              probe() 被调用
                    │
                    ↓
         用子系统 API 读写设备
```

### 完整的 I2C 驱动骨架

```c
#include <linux/i2c.h>
#include <linux/module.h>

// ① 设备树匹配表
static const struct of_device_id my_of_match[] = {
    { .compatible = "elam,elm2713" },
    { }
};
MODULE_DEVICE_TABLE(of, my_of_match);

// ② probe 函数：设备被发现时调用
static int my_probe(struct i2c_client *client) {
    // client->addr  = 设备树中的 reg = <0x39>
    // client->adapter = 所属的 I2C 控制器

    // 读一个寄存器
    int val = i2c_smbus_read_byte_data(client, 0x00);
    if (val < 0) {
        dev_err(&client->dev, "failed to read chip ID\n");
        return val;
    }

    dev_info(&client->dev, "probed at addr 0x%02x\n", client->addr);
    return 0;
}

// ③ 驱动结构体
static struct i2c_driver my_driver = {
    .probe  = my_probe,
    .driver = {
        .name = "my-i2c-device",
        .of_match_table = my_of_match,
    },
};
module_i2c_driver(my_driver);
```

### SPI 驱动骨架（和 I2C 几乎一样）

```c
#include <linux/spi/spi.h>

static const struct of_device_id my_spi_of_match[] = {
    { .compatible = "vendor,spi-device" },
    { }
};

static int my_spi_probe(struct spi_device *spi) {
    // spi->max_speed_hz = 设备树中的 spi-max-frequency
    // spi->mode         = 设备树中的 spi-cpol/spi-cpha

    uint8_t tx[4] = {0x9F, 0, 0, 0};
    uint8_t rx[4] = {0};
    spi_write_then_read(spi, tx, 1, rx, 3);
    return 0;
}

static struct spi_driver my_spi_driver = {
    .probe  = my_spi_probe,
    .driver = {
        .name = "my-spi-device",
        .of_match_table = my_spi_of_match,
    },
};
module_spi_driver(my_spi_driver);
```

### GPIO 子系统（gpiod API）

```c
#include <linux/gpio/consumer.h>

// 从设备树获取 GPIO
struct gpio_desc *reset_gpio = devm_gpiod_get(dev, "reset", GPIOD_OUT_HIGH);
// 对应设备树中的: reset-gpios = <&pio 0 12 0>;

// 操作 GPIO
gpiod_set_value(reset_gpio, 0);  // 拉低（复位设备）
msleep(10);
gpiod_set_value(reset_gpio, 1);  // 拉高（释放复位）

// 获取输入 GPIO 的值
int val = gpiod_get_value(reset_gpio);
```

## 第三层：真实 SDK 代码

### WQ7036AX 的 I2C 驱动（裸机风格，对比 Linux 子系统）

文件路径：`/home/ys/wq7036a/wq-audio/wqcore/driver/periph/bbb/hw/i2c.c`

```c
// I2C 基地址（直接映射到寄存器地址）
static i2c_master_reg_t *const i2c_bases[] = {
    (i2c_master_reg_t *)I2C0_BASEADDR,
    (i2c_master_reg_t *)I2C1_BASEADDR,
    (i2c_master_reg_t *)I2C2_BASEADDR,
    (i2c_master_reg_t *)I2C3_BASEADDR,
};

// 裸机 I2C 写操作：需要手动控制时钟、引脚、中断
// 对比 Linux 子系统中，这些都由内核管理
```

文件路径：`/home/ys/wq7036a/wq-audio/wqcore/driver/periph/bbb/hw/i2c.h`

```c
// WQ7036A 的 I2C 操作模式
typedef enum {
    I2C_MODE_WRITE,
    I2C_MODE_READ,
    I2C_MODE_BUSRT,
    I2C_MODE_WRITE_READ,
    I2C_MODE_STOP,
    I2C_MODE_MAX,
} I2C_MODE;

// 中断类型
typedef enum {
    I2C_INT_TYPE_DONE,
    I2C_INT_TYPE_RX_OVERFLOW,
    I2C_INT_TYPE_TX_UNDERFLOW,
    I2C_INT_TYPE_RX_FULL,
    I2C_INT_TYPE_TX_EMPTY,
    I2C_INT_TYPE_NACK,
    I2C_INT_TYPE_MAX,
} I2C_INT_TYPE;
```

### 子系统 vs 裸机开发对比

| 操作 | 裸机/RTOS (WQ7036AX) | Linux 子系统 (V881) |
|------|----------------------|---------------------|
| 初始化 I2C | `wq_i2c_init(port, addr)` | 设备树声明，内核自动初始化 |
| 写寄存器 | `wq_i2c_write(port, addr, reg, &data, 1)` | `i2c_smbus_write_byte_data(client, reg, data)` |
| 读 GPIO | `gpio_get_level(pin)` | `gpiod_get_value(desc)` |
| 设备匹配 | 手动写死地址 | 设备树 compatible 自动匹配 |
| 中断处理 | `gpio_register_interrupt(pin, cb)` | `devm_request_irq(dev, irq, handler, ...)` |

### V881 的 GPIO 子系统驱动

V881 的 GPIO 控制器驱动在 `/home/ys/aiglass/tina-v861/kernel/linux-6.6-xuantie/drivers/gpio/` 下，实现了标准的 GPIO 子系统接口，上层驱动可以通过 `gpiod_*` API 统一访问。

## 第四层：正常/异常路径

### 正常路径

1. 设备树中声明设备，compatible 字符串正确
2. 驱动注册，of_match_table 包含对应的字符串
3. 内核匹配成功，调用 probe
4. probe 中使用子系统 API 读写设备
5. 设备正常工作

### 异常路径

| 问题 | 现象 | 根因 | 排查方法 |
|------|------|------|----------|
| probe 不执行 | 设备不工作，dmesg 无相关日志 | compatible 不匹配，或 status="disabled" | `cat /sys/bus/i2c/devices/` 查看设备是否注册 |
| I2C 地址冲突 | 两个设备都不响应 | 同一总线上两个设备地址相同 | `i2cdetect -y 0` 扫描总线看地址是否冲突 |
| GPIO 方向设错 | 输出无效 | gpiod_get 的 flag 参数错误 | `cat /sys/kernel/debug/gpio` 查看 GPIO 状态 |
| SPI mode 配错 | 读到全 0xFF | CPOL/CPHA 和 Flash 不匹配 | 逻辑分析仪看 SCK 和 MOSI 时序 |
| 忘了中断配置 | 中断不触发 | 设备树中 interrupts 属性缺失 | `cat /proc/interrupts` 看中断计数 |

## 第五层：调试方法

### I2C 调试

```bash
# 扫描 I2C 总线上的设备
i2cdetect -y 0           # 扫描 I2C0 总线

# 读取 I2C 设备寄存器
i2cget -y 0 0x39 0x00    # 从 0x39 地址读取寄存器 0x00

# 写入 I2C 设备寄存器
i2cset -y 0 0x39 0x00 0xFF  # 写入 0xFF 到 0x39 的寄存器 0x00

# 查看 I2C 设备是否注册
ls /sys/bus/i2c/devices/
```

### SPI 调试

```bash
# 查看 SPI 设备
ls /sys/bus/spi/devices/

# 通过 spidev 直接读写 SPI 设备
# 需要设备树中配置 compatible = "spidev"
```

### GPIO 调试

```bash
# 查看 GPIO 使用情况
cat /sys/kernel/debug/gpio

# 导出 GPIO 到用户空间操作
echo 12 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio12/direction
echo 1 > /sys/class/gpio/gpio12/value
```

## 第六层：实战练习

### 练习 1：写一个 I2C 温度传感器驱动

为 TMP117 温度传感器（I2C 地址 0x48，温度寄存器 0x00，16 位数据）写一个 Linux I2C 驱动：
- 实现 `of_match_table`，compatible = "ti,tmp117"
- 在 probe 中读取芯片 ID（寄存器 0x0F，值应为 0x0117）
- 实现 `read` 函数读取温度（寄存器 0x00，转换为摄氏度）
- 注册为字符设备或使用非标准接口

### 练习 2：阅读 WQ7036A 的 I2C 驱动代码

阅读 `/home/ys/wq7036a/wq-audio/wqcore/driver/periph/bbb/hw/i2c.c` 和 `i2c.h`，回答：
- WQ7036A 的 I2C 驱动支持哪些传输模式？
- 中断处理如何区分多个 I2C 端口共用同一个中断向量？
- 对比 Linux 的 I2C 子系统，裸机驱动多了哪些手动操作？

### 练习 3：设备树添加 SPI Flash

为 V881 添加一个 SPI Flash 芯片（Winbond W25Q32，SPI 模式 3，最大 50MHz，CS 使用 CS0），写出完整的设备树节点代码。

### 练习 4：GPIO 控制 LED 驱动

写一个 Linux 平台驱动，使用 gpiod API 控制一个 LED：
- 从设备树获取 `led-gpios` 属性
- 在 probe 中初始化为输出高电平（点亮）
- 在 remove 中设置为低电平（熄灭）
- 提供 sysfs 接口或 ioctl 控制闪烁

## 自测与验收

1. I2C、SPI、GPIO 三个子系统的统一模式是什么？
2. `i2c_smbus_*` 和 `i2c_master_*` 的区别是什么？分别适用于什么场景？
3. GPIO 的 `gpiod_*` 新 API 和旧的 `gpio_*` API 有什么区别？
4. 为什么 SPI 设备树中 `reg` 表示 CS 编号而不是地址？
5. 如何排查 I2C 驱动 probe 不执行的问题？列出至少 4 个步骤。

## 延伸阅读

- [[devicetree-DeviceTree设备树]] — 设备树语法和 compatible 匹配机制
- [[platform-driver-外设驱动框架]] — I2C/SPI 驱动本质上是 platform driver 的封装
- [[char-device-字符设备驱动]] — 字符设备是子系统驱动的上层接口

## #flashcard

Q: I2C、SPI、GPIO 三个子系统的统一模式是什么？
A: 设备树声明 → compatible 匹配 → probe 执行 → 子系统 API 读写。换芯片只改设备树，驱动代码不变。

Q: `i2c_smbus_*` 和 `i2c_master_*` 的区别是什么？
A: SMBus 是 I2C 的子集（8-bit 寄存器地址），更简单也更常用。`i2c_master_*` 更底层，支持任意长度的读写。

Q: GPIO 的 `gpiod_*` 新 API 和旧 `gpio_*` API 有什么区别？
A: `gpiod_*` 使用 `struct gpio_desc *` 描述符，更安全，支持设备树自动映射。旧的 `gpio_*` 用整数编号，容易出错，已废弃。

Q: 为什么 SPI 设备树中 reg 是 CS 编号而不是地址？
A: 因为 SPI 没有像 I2C 那样的地址概念，通过 CS（片选）线硬选设备。设备树用 reg 表示使用第几个 CS 线。

Q: 如何排查 I2C 驱动 probe 不执行？
A: 1. `cat /sys/bus/i2c/devices/` 看设备是否注册；2. 检查设备树中 compatible 是否和驱动一致；3. 检查 status 是否为 "okay"；4. 检查驱动是否已加载（lsmod）；5. 检查 dmesg 有无错误信息。