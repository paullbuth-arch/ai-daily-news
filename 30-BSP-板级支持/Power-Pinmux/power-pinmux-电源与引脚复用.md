# 电源管理与引脚复用

**一句话结论（20% 核心）**：电源管理决定芯片的功耗和续航，引脚复用让一个物理引脚在不同时间扮演不同角色（GPIO/UART/I2C）。两者都是 BSP 工程师的日常：配电源让板子稳定运行，配引脚避免功能冲突。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：家里的配电箱和多功能插座

- **电源管理** = 家里的配电箱：客厅、卧室、厨房各有独立的空气开关。不用的时候关掉（省电），用的时候打开。
- **引脚复用** = 多功能插座：同一个插孔，可以插台灯（GPIO），也可以插空调（UART），但不能同时插两个。

### 1.2 电源管理的三层次

| 层次 | 控制粒度 | 例子 | 唤醒时间 |
|------|---------|------|---------|
| **Clock Gating** | 单个外设模块 | 不用 UART 时关掉它的时钟 | ~1μs |
| **Power Gating** | 整个电源域 | 不用 DCORE 时关掉 HiFi5 的电源 | ~10μs |
| **Sleep/DeepSleep** | 整个芯片 | 整机休眠，只保留 32kHz 时钟 | ~1ms |

### 1.3 引脚复用的原理

```
一个物理引脚（如 GPIO50）可以配置为：
  ├── GPIO50（通用输入输出）
  ├── UART1_TX（串口发送）
  ├── I2C2_SCL（I2C 时钟）
  └── PWM0（脉宽调制输出）

但同一时刻只能选一个功能！
```

### 1.4 如果只记得一件事

> 电源管理 = 不用的模块关掉省电。引脚复用 = 一个引脚多个功能，同一时刻只能选一个。配置 pinctrl 子系统来指定引脚功能。

---

## 第二层：实战理解

### 2.1 WQ7036AX 的引脚复用配置

```c
// WQ7036AX 的引脚复用（SDK 中）
// 把 GPIO50 配置为 UART1 TX
gpio_set_mux(GPIO50, GPIO_MUX_UART1_TX);

// 把 A10/A9 配置为 I2C1
gpio_set_mux(A10, GPIO_MUX_I2C1_SCL);
gpio_set_mux(A9,  GPIO_MUX_I2C1_SDA);
```

### 2.2 Linux 侧的 pinctrl（DeviceTree 中）

```dts
// V881 的 DeviceTree 中配置引脚
uart1_pins: uart1-pins {
    pins = "PD18", "PD19";
    function = "uart1";
    drive-strength = <20>;
    bias-pull-up;
};
```

### 2.3 常见坑

| 问题 | 现象 | 根因 |
|------|------|------|
| 两个外设复用同一引脚 | 后初始化的抢占成功 | 引脚复用冲突，规划时没检查 |
| 电源域没开 | 外设寄存器写入无效 | 忘了使能外设的电源域 |
| 休眠后引脚状态丢失 | 唤醒后引脚电平恢复默认 | 唤醒时没重新配置引脚 |

### 2.4 在 reGlasses 项目中怎么用

WQ7036AX 的引脚配置在 `wqcore/driver/gpio/` 和 `wqcore/chipset/bbb/` 下。reGlasses 的 GPIO 映射表见 [[gpio-config-GPIO配置]]。V881 侧的引脚在 DTS 中配置。两台芯片之间的 UART 和 I2S 连接需要两端的引脚都配置正确。

---

## 第三层：延伸阅读

- [[gpio-config-GPIO配置]] — WQ7036AX 的 GPIO 引脚映射
- [[low-power-低功耗设计]] — 时钟门控、休眠模式详解
- [[devicetree-DeviceTree设备树]] — Linux 侧的 pinctrl 配置