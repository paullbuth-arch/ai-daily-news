---
type: snippet
created: 2026-07-16
tags: [snippet, i2c, register, read, write]
aliases: [I2C 模板, I2C 代码]
---

# Snippet - I2C 读写寄存器

> 通用的 I2C 寄存器操作模板，适用于 [[elm2713-ELM2713光传感器 和充电 IC]]。

## 写寄存器

```c
#include "wq_i2c.h"

#define ELM2713_ADDR  0x39  // 7-bit 地址 (elm2713_sensor.c 确认)

// 写单个寄存器
WQ_RET elm2713_write_reg(uint8_t reg, uint8_t value)
{
    return wq_i2c_write(WQ_I2C_PORT_0, ELM2713_ADDR, reg, &value, 1);
}

// 写多个寄存器 (连续)
WQ_RET elm2713_write_regs(uint8_t start_reg, const uint8_t *data, uint8_t len)
{
    return wq_i2c_write(WQ_I2C_PORT_0, ELM2713_ADDR, start_reg, data, len);
}
```

## 读寄存器

```c
// 读单个寄存器
WQ_RET elm2713_read_reg(uint8_t reg, uint8_t *value)
{
    return wq_i2c_read(WQ_I2C_PORT_0, ELM2713_ADDR, reg, value, 1);
}

// 读多个寄存器 (连续)
WQ_RET elm2713_read_regs(uint8_t start_reg, uint8_t *buf, uint8_t len)
{
    return wq_i2c_read(WQ_I2C_PORT_0, ELM2713_ADDR, start_reg, buf, len);
}
```

## 完整初始化示例

```c
void elm2713_init(void)
{
    uint8_t chip_id = 0;

    // 1. 读 Chip ID 验证通信
    elm2713_read_reg(0x00, &chip_id);  // 假设 0x00 是 ID 寄存器
    LOGI("ELM2713 chip_id: 0x%02X\n", chip_id);

    // 2. 配置 ALS (环境光传感器)
    elm2713_write_reg(ALS_CONFIG_REG, 0x03);   // 使能 ALS, 连续模式
    elm2713_write_reg(ALS_GAIN_REG, 0x01);     // 增益 ×1
    elm2713_write_reg(ALS_INTEGRATION_REG, 0x0A); // 积分时间

    // 3. 配置 PS (近程传感器)
    elm2713_write_reg(PS_CONFIG_REG, 0x03);    // 使能 PS
    elm2713_write_reg(PS_THRESHOLD_HIGH, 0xFF);// 高阈值
    elm2713_write_reg(PS_THRESHOLD_LOW, 0x00); // 低阈值

    // 4. 使能中断
    elm2713_write_reg(INT_CONFIG_REG, 0x03);   // ALS + PS 中断使能

    // 5. 注册中断回调
    gpio_register_interrupt(GPIO_M12, GPIO_INT_FALLING,
                            elm2713_isr, NULL);
}
```

## 中断处理

```c
static void elm2713_isr(void *arg)
{
    // 注意: 中断上下文中不能做 I2C 操作
    // 发送消息给任务处理
    os_send_message(elm2713_task, MSG_ELM2713_INT, 0, NULL);
}

// 任务中处理
static void elm2713_task_handler(uint16_t msg_id, void *param)
{
    if (msg_id == MSG_ELM2713_INT) {
        uint8_t status;
        elm2713_read_reg(INT_STATUS_REG, &status);

        if (status & ALS_INT_FLAG) {
            uint8_t als_data[2];
            elm2713_read_regs(ALS_DATA_REG, als_data, 2);
            uint16_t lux = (als_data[0] << 8) | als_data[1];
            LOGI("ALS: %d lux\n", lux);
        }

        if (status & PS_INT_FLAG) {
            uint8_t ps_data[2];
            elm2713_read_regs(PS_DATA_REG, ps_data, 2);
            uint16_t proximity = (ps_data[0] << 8) | ps_data[1];
            LOGI("PS: %d\n", proximity);
        }
    }
}
```

## I2C 总线波形 (逻辑分析仪抓包)

```
写寄存器 0x10 = 0x03:
  [S] [0x52] [A] [0x10] [A] [0x03] [A] [P]
   │   │      │   │      │   │      │   │
   │   │      │   │      │   │      │   └─ Stop
   │   │      │   │      │   │      └───── ACK
   │   │      │   │      │   └──────────── 数据 0x03
   │   │      │   │      └──────────────── ACK
   │   │      │   └─────────────────────── 寄存器地址 0x10
   │   │      └─────────────────────────── ACK
   │   └────────────────────────────────── 地址+W (0x29<<1|0 = 0x52)
   └────────────────────────────────────── Start

读寄存器 0x10:
  [S] [0x52] [A] [0x10] [A] [Sr] [0x53] [A] [0x03] [N] [P]
   │                              │      │   │      │   │
   │                              │      │   │      │   └─ Stop
   │                              │      │   │      └───── NACK (结束)
   │                              │      │   └──────────── 读到的数据
   │                              │      └──────────────── 地址+R (0x53)
   │                              └─────────────────────── Repeated Start
   └────────────────────────────────────────────────────── 先写寄存器地址
```

## 关联概念

- [[i2c-basics-I2C基础]] — I2C 协议基础
- [[elm2713-ELM2713光传感器]] — 实际使用的 I2C 设备
- [[wq7036ax-chip-WQ7036AX芯片]] — I2C 控制器
- [[gpio-config-GPIO配置]] — 中断引脚配置
