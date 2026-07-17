# 芯片手册阅读方法

**一句话结论（20% 核心）**：Datasheet 是芯片的"使用说明书"，几千页，但 90% 的时候你只需要看三个章节：引脚定义、寄存器描述、电气特性。剩下的查到再看。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：宜家家具说明书

Datasheet 就像宜家家具的说明书：

- 你不需要从头读到尾
- 先看**组装图**（功能框图）了解整体结构
- 再看**零件清单**（引脚定义）知道每根线接哪
- 组装时查**具体步骤**（寄存器描述）知道怎么配置
- 最后看**安全警告**（电气特性）知道电压不能超多少

### 1.2 一本典型 Datasheet 的结构

| 章节 | 标题 | 什么时候看 | 重要度 |
|------|------|-----------|--------|
| 1 | Overview/Features | 选型时 | ⭐⭐ |
| 2 | Block Diagram | 每次都要先看 | ⭐⭐⭐ |
| 3 | Pin Definitions | 画原理图时 | ⭐⭐⭐ |
| 4 | Electrical Characteristics | 出问题时才看 | ⭐⭐ |
| 5 | Register Map | 写驱动时 | ⭐⭐⭐ |
| 6 | Functional Description | 深入理解时 | ⭐⭐ |
| 7 | Application Circuits | 参考设计 | ⭐⭐ |

### 1.3 5 分钟定位法（最重要）

拿到一本新 datasheet，不要从头翻。按这个顺序：

1. **看功能框图**（第 1-2 页）：芯片内部长什么样，有几个模块
2. **看引脚表**（找 Pin Definitions）：找你要用的那几个引脚
3. **搜寄存器**（Ctrl+F 搜你要配置的功能）：找到寄存器名→看 bit 定义
4. **看典型电路**（Application Circuit）：参考别人的连接方式

### 1.4 如果只记得一件事

> Datasheet 不是用来通读的，是用来查的。先看框图→找引脚→搜寄存器，90% 的问题这三步就够了。

---

## 第二层：实战理解

### 2.1 读寄存器描述的模板

以 WQ7036AX 的 UART 控制寄存器为例，datasheet 里是这样写的：

```
UART_CTRL Register (Offset: 0x00)
Bits  | Name  | R/W | Reset | Description
[0]   | EN    | R/W | 0x0   | UART Enable: 0=disable, 1=enable
[1]   | TXE   | R/W | 0x0   | TX Enable
[2]   | RXE   | R/W | 0x0   | RX Enable
[5:3] | WLEN  | R/W | 0x3   | Word Length: 0=5bit, 1=6bit, 2=7bit, 3=8bit
[6]   | PEN   | R/W | 0x0   | Parity Enable
```

对应的 C 代码：
```c
#define UART_CTRL   (*(volatile uint32_t *)(UART_BASE + 0x00))
#define UART_EN     BIT(0)
#define UART_TXE    BIT(1)
#define UART_WLEN_8 (3 << 3)

UART_CTRL = UART_EN | UART_TXE | UART_WLEN_8;  // 使能 UART，8 位数据
```

### 2.2 常见坑

| 问题 | 现象 | 根因 |
|------|------|------|
| 寄存器地址写错 | 外设根本不工作 | 基地址或偏移量算错 |
| 忘了先使能时钟 | 寄存器写入无效 | 外设模块的时钟没开 |
| 不看复位值 | 配置后行为不对 | 某些 bit 默认是 1，需要主动清零 |
| 单位搞混 | 时序错误 | kbps vs Mbps, ms vs μs |

### 2.3 在 WQ7036AX 项目中怎么用

WQ7036AX 的寄存器定义在 `wqcore/chipset/bbb/include/chip_reg_base.h`。但 SDK 已经封装了驱动层，大多数时候你不需要直接读寄存器——用 `wq_uart_init()` 等 API 即可。读 datasheet 主要用于：调试时确认寄存器配置、理解硬件限制、写新驱动。

---

## 第三层：延伸阅读

- [[computer-arch-mcu-计算机组成与MCU架构]] — 理解寄存器与地址映射
- [[uart-basics-UART基础]] — 一个典型的 datasheet 对照实例