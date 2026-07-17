# I2C / SPI / GPIO 子系统

**一句话结论（20% 核心）**：Linux 把 I2C、SPI、GPIO 封装成了标准子系统——驱动的 probe 不再手动初始化总线，而是由内核根据设备树自动匹配。I2C 用 `i2c_driver` + `i2c_client`，SPI 用 `spi_driver` + `spi_device`，GPIO 用 `gpiod_*` API。三个子系统的模式完全一致：设备树声明 → compatible 匹配 → probe 执行。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：酒店前台

- **裸机/RTOS 开发**：你自己拿钥匙开每个房间的门，直接操作寄存器（`*(volatile *)0x40000000 = 0x01`）
- **Linux 子系统**：你告诉前台"帮我开 302 房间"，前台帮你开。你不需要知道钥匙在哪，不需要知道 302 房间的门锁是什么品牌

**核心价值**：换一个芯片，只要它的 I2C 控制器驱动实现了标准接口，你的设备驱动代码不用改。设备树中改一个 `compatible` 字符串，内核自动匹配合适的控制器驱动。

### 1.2 三个子系统的统一模式

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

### 1.3 完整的 I2C 驱动骨架

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

// ③ remove 函数：设备被移除时调用
static void my_remove(struct i2c_client *client) {
    // 清理资源
}

// ④ 驱动结构体
static struct i2c_driver my_driver = {
    .probe  = my_probe,
    .remove = my_remove,
    .driver = {
        .name = "my-i2c-device",
        .of_match_table = my_of_match,
    },
};
module_i2c_driver(my_driver);  // 注册 I2C 驱动
```

### 1.4 SPI 驱动骨架（和 I2C 几乎一样）

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
    spi_write_then_read(spi, tx, 1, rx, 3);  // 发命令+读数据
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

### 1.5 GPIO 子系统（gpiod API）

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

// 设备树中声明
// my_device {
//     compatible = "vendor,my-device";
//     reset-gpios = <&pio 0 12 GPIO_ACTIVE_LOW>;
//     irq-gpios   = <&pio 0 13 0>;
// };
```

### 1.6 如果只记得一件事

> Linux 三个子系统的模式完全一致：设备树声明 → compatible 匹配 → probe 执行 → 子系统 API 读写。换芯片只改设备树，驱动代码不变。

---

## 第二层：实战理解

### 2.1 子系统 vs 裸机开发对比

| 操作 | 裸机/RTOS (WQ7036AX) | Linux 子系统 (V881) |
|------|----------------------|---------------------|
| 初始化 I2C | `wq_i2c_init(port, addr)` | 设备树声明，内核自动初始化 |
| 写寄存器 | `wq_i2c_write(port, addr, reg, &data, 1)` | `i2c_smbus_write_byte_data(client, reg, data)` |
| 读 GPIO | `gpio_get_level(pin)` | `gpiod_get_value(desc)` |
| 设备匹配 | 手动写死地址 | 设备树 compatible 自动匹配 |
| 中断处理 | `gpio_register_interrupt(pin, cb)` | `devm_request_irq(dev, irq, handler, ...)` |

### 2.2 设备树中声明 I2C/SPI/GPIO 设备

```dts
// I2C 设备
&i2c0 {
    light_sensor@39 {
        compatible = "elam,elm2713";
        reg = <0x39>;                     // I2C 地址
        interrupt-parent = <&pio>;
        interrupts = <0 12 2>;            // GPIO 中断
        proximity-threshold = <100>;      // 自定义属性
    };
};

// SPI 设备
&spi0 {
    flash@0 {
        compatible = "winbond,w25q32";
        reg = <0>;                        // CS 编号
        spi-max-frequency = <50000000>;   // 最大 50MHz
        spi-cpol;                         // CPOL=1
        spi-cpha;                         // CPHA=1 → Mode 3
    };
};

// GPIO 设备
my_device {
    compatible = "vendor,my-device";
    reset-gpios = <&pio 0 12 GPIO_ACTIVE_LOW>;
    power-gpios = <&pio 0 13 0>;
};
```

### 2.3 常见坑（附排查方法）

| 问题 | 现象 | 排查方法 | 根因 |
|------|------|---------|------|
| probe 不执行 | 设备不工作，dmesg 无相关日志 | `cat /sys/bus/i2c/devices/` 看设备是否注册 | compatible 不匹配，或设备树中 status="disabled" |
| I2C 地址冲突 | 两个设备都不响应 | `i2cdetect -y 0` 扫描总线 | 同一 I2C 总线上两个设备地址相同 |
| GPIO 方向设错 | GPIO 输出无效 | `cat /sys/kernel/debug/gpio` 看 GPIO 状态 | `gpiod_get` 的 flag 参数和实际需求不符 |
| SPI mode 配错 | 读到全 0xFF | 逻辑分析仪看 SCK 和 MOSI 时序 | 设备树中 spi-cpol/spi-cpha 和 Flash 不匹配 |

### 2.4 在 reGlasses 项目中怎么用

WQ7036AX 侧（FreeRTOS）用裸机 API：`wq_i2c_write`、`wq_uart_write` 等。V881 侧（Linux）用子系统 API。**两颗芯片你都要写代码，所以两种风格都要会。**

---

## 第三层：深入扩展

### 3.1 常见问题

- **I2C 的 `i2c_smbus_*` 和 `i2c_master_*` 有什么区别？** SMBus 是 I2C 的子集（8-bit 寄存器地址），更简单也更常用。`i2c_master_*` 更底层，支持任意长度的读写。
- **GPIO 的 `gpiod_*` 和旧的 `gpio_*` 有什么区别？** `gpiod_*` 是新 API（descriptor-based），使用 `struct gpio_desc *` 描述符，更安全。旧的 `gpio_*` 用整数编号，容易出错，已废弃。
- **为什么 SPI 设备树中 reg 是 CS 编号而不是地址？** 因为 SPI 没有地址概念，靠 CS 硬件选设备。设备树用 `reg` 表示使用第几个 CS 线。

### 3.2 延伸阅读

- [[devicetree-DeviceTree设备树]] — 设备树语法和 compatible 匹配机制
- [[i2c-basics-I2C基础]] — I2C 协议基础（从裸机角度）
- [[spi-basics-SPI基础]] — SPI 协议基础（从裸机角度）
- [[platform-driver-外设驱动框架]] — I2C/SPI 驱动本质上是 platform driver 的封装