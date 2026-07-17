---
type: moc
tags: [moc, hardware, protocol, UART, I2C, SPI, I2S, PDM, GPIO, PWM, ADC, MIPI]
---

# 20-HardwareProtocol：硬件协议

> 嵌入式工程师的"语言"——芯片通过引脚上的电平变化和时序与外设沟通。这个目录覆盖从最基础的 GPIO 到 Gbps 级高速接口的全部串行协议。

## 小白学习路线

**第一遍（建立认知）**：GPIO（理解引脚、输入输出）→ UART（理解异步通信）→ I2C（理解地址和应答）→ 串口总线对比

**第二遍（深入原理）**：SPI（理解全双工和时钟模式）→ PWM（理解定时器和占空比）→ ADC/DAC（理解采样和量化）

**第三遍（音频专项）**：I2S 协议 → I2S 时钟树 → PDM 麦克风 → 音频接口对比

**第四遍（高速接口）**：MIPI/USB/SDIO（理解差分信号和多 lane）

## 串口总线：UART / I2C / SPI / GPIO

| 文件 | 核心内容 | 建议顺序 |
|------|---------|---------|
| [[gpio-config-GPIO配置]] | 输入/输出/中断、推挽/开漏、上下拉、去抖、低功耗唤醒 | 1（最基础） |
| [[uart-basics-UART基础]] | 异步采样、起始/停止位、波特率误差、FIFO/DMA、流控、共享 I/O | 2 |
| [[i2c-basics-I2C基础]] | 开漏电气、上拉计算、地址格式、ACK/NACK、时钟拉伸、WQ HAL + Linux I2C | 3 |
| [[spi-basics-SPI基础]] | 推挽全双工、CPOL/CPHA、dummy 字节、WQ SPI DMA、信号完整性 | 4 |
| [[uart-i2c-spi-compare-串口总线对比]] | 电气结构、时钟模型、GPIO 成本、选型决策框架 | 5（学完前四篇后再看） |

## 音频接口：I2S / PDM

| 文件 | 核心内容 | 建议顺序 |
|------|---------|---------|
| [[i2s-protocol-I2S协议]] | BCLK/LRCK/DATA、数据格式、Master/Slave、DMA 乒乓缓冲、reGlasses I2S0 | 1 |
| [[i2s-clock-tree-I2S时钟树]] | PLL→分频器→BCLK/LRCK、44.1k vs 48k 家族、时钟源选择 | 2（配合 I2S 协议） |
| [[pdm-mic-PDM麦克风]] | 1-bit 密度调制、抽取滤波、L/R 边沿复用、reGlasses 4 麦阵列 | 3 |
| [[i2s-vs-pdm-音频接口对比]] | 物理层对比、选型决策、reGlasses 三条音频链路 | 4（学完前三篇后再看） |

## 模拟与定时器

| 文件 | 核心内容 |
|------|---------|
| [[pwm-basics-PWM基础]] | 定时器比较器、占空比/频率、分辨率权衡、WQ 定时器 HAL |
| [[adc-dac-ADC与DAC基础]] | SAR/Σ-Δ 架构、量化误差、奈奎斯特、过采样、WQ 音频 ADC |

## 高速接口

| 文件 | 核心内容 |
|------|---------|
| [[mipi-usb-sdio-MIPI-USB-SDIO高速接口]] | 差分信号、MIPI DSI/CSI、USB Host/Gadget/OTG、SDIO、当前 SDK 证据缺口 |

## 如果你只能学 3 篇

1. [[gpio-config-GPIO配置]] — 一切外设的起点，理解引脚的物理本质
2. [[uart-basics-UART基础]] — 芯片间通信的主干道，WQ↔V861 的核心链路
3. [[i2c-basics-I2C基础]] — 传感器的标准接口，理解开漏和地址寻址