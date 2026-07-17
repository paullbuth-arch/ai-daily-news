# I2C / SPI / GPIO 子系统

**一句话结论（20% 核心）**：Linux 把 I2C、SPI、GPIO 都封装成了标准子系统——I2C 用 `i2c_client` 和 `i2c_driver`，SPI 用 `spi_device` 和 `spi_driver`，GPIO 用 `gpiod_*` API。驱动开发时不需要直接操作寄存器，调用子系统 API 即可。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：酒店前台 vs 自己开门

- **不用子系统**（裸机/RTOS）：你自己拿钥匙开每个房间门，直接操作寄存器
- **用子系统**（Linux）：你告诉前台（子系统 API）"帮我开 302 房间"，前台帮你开，你不用管钥匙在哪

子系统的核心价值：**屏蔽硬件差异**。换一个芯片，只要它的 I2C 控制器驱动实现了标准接口，你的设备驱动代码不用改。

### 1.2 三个子系统的核心 API 速查

```c
// === I2C 子系统 ===
// 设备树中声明设备
&i2c0 {
    my_sensor@39 {
        compatible = "vendor,my-sensor";
        reg = <0x39>;
    };
};

// 驱动中匹配
static const struct of_device_id my_of_match[] = {
    { .compatible = "vendor,my-sensor" },
    { }
};

static int my_probe(struct i2c_client *client) {
    // 读写寄存器
    i2c_smbus_read_byte_data(client, REG_ADDR);
    i2c_smbus_write_byte_data(client, REG_ADDR, value);
    return 0;
}

static struct i2c_driver my_driver = {
    .probe  = my_probe,
    .driver = { .name = "my-sensor", .of_match_table = my_of_match },
};

// === SPI 子系统 ===
// 类似结构，用 spi_device, spi_driver, spi_write/spi_read

// === GPIO 子系统 ===
// 获取 GPIO（从设备树中）
struct gpio_desc *reset_gpio = devm_gpiod_get(dev, "reset", GPIOD_OUT_HIGH);
gpiod_set_value(reset_gpio, 0);  // 拉低
gpiod_set_value(reset_gpio, 1);  // 拉高
```

### 1.3 如果只记得一件事

> Linux 子系统的模式都一样：设备树声明设备 → compatible 匹配驱动 → probe 函数初始化 → 用子系统 API 读写设备。I2C/SPI/GPIO 三个子系统的 API 风格统一。

---

## 第二层：实战理解

### 2.1 子系统 vs 裸机开发的对比

| 操作 | 裸机/RTOS | Linux 子系统 |
|------|-----------|-------------|
| 初始化 I2C | `i2c_init(port, addr)` | `i2c_add_driver(&my_driver)` |
| 写寄存器 | `*(volatile uint32_t *)REG = val` | `i2c_smbus_write_byte_data(client, reg, val)` |
| 读 GPIO | `gpio_get_level(pin)` | `gpiod_get_value(desc)` |
| 设备匹配 | 手动写死地址 | 设备树 compatible 自动匹配 |

### 2.2 常见坑

| 问题 | 现象 | 根因 |
|------|------|------|
| compatible 不匹配 | probe 不执行 | 设备树和驱动的 compatible 字符串不一致 |
| GPIO 方向忘设 | GPIO 输出无效 | gpiod_get 的 flag 参数设错 |
| I2C 地址冲突 | 设备不响应 | 同一总线上两个设备地址相同 |

### 2.3 在 reGlasses 项目中怎么用

WQ7036AX 侧跑 FreeRTOS，用的是裸机风格的 API（`wq_i2c_write` 等）。V881 侧跑 Linux，用的是子系统 API。两种风格都要会，因为你要在两颗芯片上写代码。

---

## 第三层：延伸阅读

- [[i2c-basics-I2C基础]] — I2C 协议基础
- [[spi-basics-SPI基础]] — SPI 协议基础
- [[devicetree-DeviceTree设备树]] — 设备树中如何声明 I2C/SPI/GPIO 设备