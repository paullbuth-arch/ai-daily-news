# SPI 基础

**一句话结论（20% 核心）**：SPI 是嵌入式最快的通用总线——4 根线（SCK 时钟 + MOSI 数据出 + MISO 数据入 + CS 片选），全双工，几十 MHz，比 UART 快几百倍，比 I2C 快几十倍。Flash、显示屏、WiFi 模块的标准接口。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：双向传送带

SPI 就像一条**双向传送带**：
- **SCK（时钟）** = 传送带的节拍器，Master 控制节奏，每拍传一个 bit
- **MOSI（Master Out Slave In）** = Master 的嘴巴 → Slave 的耳朵
- **MISO（Master In Slave Out）** = Slave 的嘴巴 → Master 的耳朵
- **CS/SS（片选）** = 选中信号，拉低=选中这个设备，拉高=忽略

**关键特性**：全双工——Master 每发一个 bit，Slave 同时回一个 bit。但 MOSI 和 MISO 的内容完全独立：你发的是命令，Slave 回的是数据。这意味着即使你只想读数据，也必须发数据（通常是 dummy 字节）。

```
Master                          Slave
  SCK ─────────────────────────→ SCK    (节拍器)
  MOSI ──[0x9F][0x00][0x00]───→ MOSI   (主→从 命令)
  MISO ←──[0xFF][0xEF][0x17]─── MISO   (从→主 数据)
  CS  ─────────────────────────→ CS     (选中信号)
```

### 1.2 为什么 SPI 这么快？

| 原因 | 解释 |
|------|------|
| **独立时钟线** | 不像 UART 靠波特率对齐，SCK 可以跑到 50 MHz |
| **全双工** | 收发同时进行，不浪费带宽 |
| **无地址开销** | 用 CS 硬件选设备，不需要像 I2C 那样先发地址字节 |
| **推挽输出** | 不像 I2C 用开漏+上拉电阻，SPI 主动驱动，边沿陡峭，速度快 |

### 1.3 四种工作模式（CPOL + CPHA）

SPI 最让人困惑的地方：时钟极性和相位有 4 种组合。**90% 的设备用 Mode 0 或 Mode 3。**

```
CPOL=0（空闲低电平）:
SCK: ──╮     ┌──┐     ┌──
       │     │  │     │
       └─────┘  └─────┘
CPOL=1（空闲高电平）:
SCK: ──┐     ┌──┐     ┌──
       │     │  │     │
       └─────┘  └─────┘

CPHA=0（第一个边沿采样）:
       采样点→ ↑  ↑  ↑  ↑
CPHA=1（第二个边沿采样）:
       采样点→    ↑  ↑  ↑  ↑
```

| Mode | CPOL | CPHA | 采样时机 | 常见设备 |
|------|------|------|---------|----------|
| **0** | 0（空闲低） | 0 | 上升沿 | 大多数 SPI Flash（W25Q 系列） |
| 1 | 0（空闲低） | 1 | 下降沿 | 少见 |
| 2 | 1（空闲高） | 0 | 下降沿 | 少见 |
| **3** | 1（空闲高） | 1 | 上升沿 | SD 卡 SPI 模式、部分显示屏 |

### 1.4 多设备连接：独立 CS vs Daisy Chain

**方式一：独立 CS（最常用）**
```
Master ──SCK──┬──Slave A──┬──Slave B
      ──MOSI──┤           │
      ←──MISO──┤           │
      ──CS0───Slave A      │
      ──CS1──────────────Slave B
```
每个 Slave 一根 CS 线。同时只拉低一个 CS，其他 Slave 忽略总线。

**方式二：Daisy Chain（菊花链）**
```
Master ──MOSI──→ Slave A ──→ Slave B ──→ Slave C ──→ MISO → Master
```
数据依次穿过所有 Slave，适合大量相同设备（如 LED 驱动芯片）。

### 1.5 如果只记得一件事

> SPI = 4 线（SCK/MOSI/MISO/CS），全双工，Master 控时钟，CS 选设备。极快（~50 MHz），Mode 0 最常用。想读必须写（dummy 字节），因为 MISO 数据由 SCK 时钟驱动。

---

## 第二层：实战理解

### 2.1 SPI Flash 读写实战

```c
// 读 SPI Flash 的 JEDEC ID（验证 Flash 型号）
// 命令 0x9F：发送 1 字节命令 + 读 3 字节 ID
uint8_t tx[4] = {0x9F, 0xFF, 0xFF, 0xFF};  // 后 3 字节是 dummy
uint8_t rx[4] = {0};

gpio_set_level(CS_PIN, 0);                   // 选中设备
spi_transfer(SPI_PORT, tx, rx, 4);           // 同时收发 4 字节
gpio_set_level(CS_PIN, 1);                   // 释放设备

// rx[0] = 0xFF（收发同时，第一个收到的字节是 dummy）
// rx[1] = manufacturer_id
// rx[2] = memory_type
// rx[3] = capacity

// 读 Flash 数据（命令 0x03）
void flash_read(uint32_t addr, uint8_t *buf, uint32_t len) {
    uint8_t cmd[4] = {
        0x03,                          // Read Data 命令
        (addr >> 16) & 0xFF,           // 地址 [23:16]
        (addr >> 8)  & 0xFF,           // 地址 [15:8]
        addr & 0xFF,                   // 地址 [7:0]
    };

    gpio_set_level(CS_PIN, 0);
    spi_write(SPI_PORT, cmd, 4);       // 发命令+地址
    spi_read(SPI_PORT, buf, len);      // 读数据
    gpio_set_level(CS_PIN, 1);
}
```

### 2.2 WQ7036AX 的 SPI 驱动 API

WQ7036AX 的 SPI 驱动在 `wqcore/driver/spi/` 下，API 风格和 UART/I2C 一致：

```c
// 初始化 SPI
spi_config_t cfg = {
    .mode      = SPI_MODE_0,      // CPOL=0, CPHA=0
    .freq      = 10000000,        // 10 MHz
    .data_bits = 8,
    .cs_pin    = GPIO_CS0,
};
spi_init(SPI_PORT_0, &cfg);

// 传输数据
spi_transfer(SPI_PORT_0, tx_buf, rx_buf, len);
```

### 2.3 常见坑（附排查方法）

| 问题 | 现象 | 排查方法 | 根因 |
|------|------|---------|------|
| Mode 配错 | 读出全是 0xFF 或 0x00 | 逻辑分析仪看 SCK 和 MOSI 时序 | 采样边沿不对，换 Mode 试 |
| CS 忘拉低 | 设备完全不响应 | 示波器看 CS 引脚电平 | SPI 设备靠 CS 下降沿"唤醒" |
| 速率太高 | 数据偶尔出错 | 降低频率到 1MHz 看是否正常 | 超过设备支持的最高频率 |
| 多设备 CS 同时拉低 | 总线冲突，数据全乱 | 逻辑分析仪看所有 CS 同时触发 | 两个 CS 被同时选中 |
| 忘记 dummy 字节 | 读到的数据偏移 | 读 Flash ID 从 rx[0] 开始看 | 收发同时，第一个收到的字节是 Master 发命令时 Slave 回的 |

### 2.4 在 reGlasses 项目中怎么用

reGlasses 当前硬件 SPI 未使用，但以下场景在类似项目中常见：
- **SPI Flash**：外挂固件存储（WQ7036AX 内部 Flash 不够时，通过 SPI 外挂 W25Q 系列）
- **SPI 显示屏**：微型 OLED（如 SSD1306），通过 SPI 发命令+像素数据
- **SPI TOF 传感器**：某些 TOF 芯片通过 SPI 传输深度数据

---

## 第三层：深入扩展

### 3.1 SPI 传输模式

| 模式 | 说明 | 适用场景 |
|------|------|---------|
| 单线 (Standard) | 1×MOSI + 1×MISO | 最常用 |
| 双线 (Dual) | MOSI 和 MISO 都用于数据，方向可切换 | 高速 Flash 读取 |
| 四线 (Quad) | 4 根数据线 | 高速 Flash（QSPI），读取速度翻 4 倍 |

### 3.2 UART vs I2C vs SPI 最终对比

| | UART | I2C | SPI |
|---|---|---|---|
| 线数 | 2 | 2 | **4** |
| 速度 | 115k-4M bps | 100k-3.4M bps | **10-50M bps** |
| 全双工 | 是 | 否 | **是** |
| 多设备 | 否 | **是（地址）** | 是（CS，每设备一根线） |
| 典型用途 | 调试/命令 | 传感器 | Flash/显示屏/高速 |

### 3.3 常见问题

- **为什么 SPI 读数据也要发数据？** 因为 SCK 由 Master 发出，Slave 只在 SCK 边沿上输出数据。Master 不发数据就没有 SCK，Slave 就回不了数据。
- **SPI 最大传输距离？** 很短（PCB 板上几厘米到十几厘米）。SPI 没有差分信号，没有校验，长距离走线容易受干扰。远距离传输用 RS-485 或 CAN。
- **SPI 和 QSPI 的区别？** QSPI（Quad SPI）使用 4 根数据线同时传输，速度是标准 SPI 的 4 倍。Flash 芯片常用 QSPI 模式。

### 3.4 延伸阅读

- [[uart-basics-UART基础]] — 对比：异步串口
- [[i2c-basics-I2C基础]] — 对比：两线地址总线
- [[uart-i2c-spi-compare-串口总线对比]] — 四种总线全面对比