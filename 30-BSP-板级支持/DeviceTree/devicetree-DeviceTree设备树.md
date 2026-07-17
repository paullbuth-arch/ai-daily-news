---
type: concept
tags: [BSP, DeviceTree, DTS, DTB, 设备树, 硬件描述, Linux内核]
aliases: [设备树, DeviceTree, DT, devicetree]
---

# DeviceTree 设备树

## 一句话结论

DeviceTree 是给 Linux 内核的"硬件清单"——用树形结构描述板子上有什么芯片、连在哪个引脚、用什么驱动。ARM/RISC-V 嵌入式板没有 PC 的硬件自发现能力，内核全靠这张清单找到硬件。改硬件连接时改 DTS 而不是改内核代码。

## 30秒先看懂

- DeviceTree 是一棵从根节点（/）开始的树，每个节点代表一个硬件设备或总线控制器。
- 每个节点通过 `compatible` 字符串告诉内核应该用哪个驱动来驱动它。
- 树形结构直接反映物理总线拓扑——I2C 设备是 I2C 控制器的子节点，SPI 设备是 SPI 控制器的子节点。
- DTS 是人类可读的文本，通过 dtc 编译器生成 DTB 二进制，U-Boot 加载 DTB 后传给内核解析。
- 改硬件连接（换引脚、改地址、换芯片）只需要改 DTS 文件，不需要碰内核代码。

## 学完以后应该能做什么

**第一遍**
- 能读懂一个 DTS 文件，说出每个节点的含义和对应硬件
- 知道 compatible 匹配驱动的机制，能排查"设备不工作"是否因为 compatible 字符串错误
- 会用 dtc 编译/反编译 DTB，会用 /sys 文件系统查看设备树节点

**进阶**
- 能自己写一个完整的 DTS 文件，包括 CPU、内存、外设控制器、I2C/SPI 从设备
- 能写 DeviceTree Overlay 实现运行时动态加载设备
- 能在内核驱动中通过 OF API 读取设备树自定义属性

## 前置知识

- 计算机组成基础：CPU、内存、外设控制器的概念
- 嵌入式基础：I2C/SPI/UART 等总线的基本概念
- Linux 驱动基础：了解驱动 probe 机制有助于理解 compatible 匹配

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|----------|
| 设备树源文件 | DTS (DeviceTree Source) | 人类可读的设备树文本文件，一个板子通常对应一个 .dts 文件 |
| 设备树头文件 | DTSI (DeviceTree Source Include) | .dtsi 是 SoC 级通用定义，被多个板级 .dts 包含引用 |
| 设备树二进制 | DTB (DeviceTree Blob) | DTS 编译后的二进制文件，U-Boot 加载到内存后传给内核 |
| 兼容字符串 | compatible | 驱动和设备匹配的关键字，格式为 "厂商,型号"，拼错则不匹配 |
| 寄存器地址 | reg | 描述设备寄存器的地址和范围，格式为 `<基地址 长度>` |
| 节点指针 | phandle | 用 &label 引用其他节点，相当于 C 语言的指针 |
| 引脚控制 | pinctrl | 配置引脚复用功能，告诉芯片这个引脚现在是 UART 还是 GPIO |
| 覆盖层 | Overlay | 运行时动态加载的设备树片段，用于热插拔扩展板 |

## 第一层：费曼心智模型

### 类比：新房的电路图

买了一套毛坯房，你要告诉电工每个房间的电路布局。你不能说"电工你自己猜吧"——电工不知道你哪个房间要装灯、哪个要装空调。

DeviceTree 就是这张电路图，它告诉 Linux 内核：
- 这个板子上有哪些设备（灯、空调、插座）
- 它们连在哪个引脚/总线上（客厅东墙、卧室北墙）
- 用什么参数配置（电压 220V、空调功率 2 匹）

**x86 PC 为什么不需要？** 因为 PCI/USB 设备可以自动枚举发现（插上 U 盘，系统自动识别）。ARM 嵌入式板上的 I2C/SPI/UART 设备没有这种自动发现协议，必须手动告诉内核。

### 边界在哪里

- DeviceTree 只描述硬件"有什么、连在哪"，不描述"怎么用"——那是驱动的职责
- 内核不会因为 compatible 不匹配而报错，设备只会静默被忽略——这是排查问题时的最大陷阱
- U-Boot 会在启动前修改 DTB（如修改 bootargs、使能/禁用节点），反编译 `/sys/firmware/fdt` 才是最终生效版本

### 场景演练：V881 开发板新增一个 I2C 光传感器

1. 产品经理说"要在 V881 上接一个光传感器 ELM2713，挂在 I2C0 上，地址 0x39"
2. 你打开 V881 的设备树文件 `uboot-board.dts`，在 `&i2c0` 节点下添加子节点
3. 设置 `compatible = "elam,elm2713"`，`reg = <0x39>`，以及自定义属性 `proximity-threshold = <100>`
4. 用 `make dtbs` 重新编译，生成新的 DTB
5. 重启系统，内核解析 DTB → 发现 I2C0 上有新设备 → 匹配 `elam,elm2713` 驱动 → 调用 probe
6. 驱动在 probe 中通过 `i2c_smbus_read_byte_data(client, 0x00)` 读取芯片 ID 确认设备存在

## 第二层：原理/时序/约束

### 树形结构：从根节点到叶子

```
/ (根节点 — 整块板子)
├── cpus { cpu0, cpu1 ... }          — 几个 CPU 核
├── memory { reg = <base size> }     — 内存多大、从哪开始
├── soc {                            — 片上外设控制器
│   ├── uart0: serial@2500000 { }    — UART 控制器
│   ├── i2c0: i2c@2500400 {          — I2C 控制器
│   │   └── light_sensor@39 { }      — 挂在上面的传感器
│   │   └── charger@6a { }           — 挂在上面的充电芯片
│   │   }
│   ├── spi0: spi@2501000 { }        — SPI 控制器
│   └── mmc0: mmc@4020000 { }        — SD/MMC 控制器
│   }
├── chosen { bootargs = "..." }       — 传给内核的启动参数
└── aliases { serial0 = &uart0; }     — 别名（方便引用）
```

### DTS → DTB → 内核的完整流程

```
① 编写 DTS（人类可读的文本）
    │
    ↓ dtc 编译器
② 生成 DTB（二进制，通常几十 KB）
    │
    ↓ U-Boot 加载到内存
③ 内核启动时解析 DTB
    │
    ├── 遍历每个节点
    ├── 对每个 compatible 字符串，查找匹配的驱动
    ├── 匹配成功 → 调用驱动的 probe() 函数
    └── 匹配失败 → 该设备被忽略（不报错！）
```

### 关键约束

- `#address-cells` 和 `#size-cells` 定义子节点 reg 的编码格式：`#address-cells=1` 表示地址用 1 个 u32，`#size-cells=1` 表示大小用 1 个 u32
- 一个节点不能同时有两个相同名称的子节点（除非用 `reg` 区分）
- `status` 属性控制设备开关：`"okay"` = 启用，`"disabled"` = 禁用，`"reserved"` = 保留
- 多个 DTS 文件可以包含同一个 .dtsi，通过 `#include` 实现复用

## 第三层：真实 SDK 代码

### V881 的 U-Boot 设备树（reGlasses 项目）

文件路径：`/home/ys/aiglass/tina-v861/device/config/chips/v861/configs/reglasses/uboot-board.dts`

```dts
// SPDX-License-Identifier: (GPL-2.0+ or MIT)
/dts-v1/;

#include "sun252iw1p1.dtsi"

/ {
    model = "sun252iw1";
    compatible = "allwinner,v861", "riscv,sun252iw1p1";

    aliases {
        serial0 = &uart0;
    };

    chosen {
        stdout-path = "serial0:115200n8";
    };
};

&uart0 {
    pinctrl-names = "default";
    pinctrl-0 = <&uart0_ph_pins>;
    status = "okay";
};

&pio {
    uart0_ph_pins: uart0-ph-pins {
        pins = "PH9", "PH10";
        function = "mux@5";
    };

    spi0_pins_default: spi0@0 {
        pins = "PC0", "PC2", "PC3"; /* clk, mosi, miso */
        function = "spi0";
        drive-strength = <20>;
    };
};
```

这个文件展示了实际项目中的设备树结构：`#include` 引入 SoC 级通用定义，板级只覆盖需要修改的节点（如 `&uart0` 和 `&pio`）。`pinctrl` 子节点定义了引脚复用配置。

### 内核驱动中读取设备树的标准写法

```c
// 在 probe 函数中读取设备树属性
static int my_probe(struct platform_device *pdev) {
    struct device_node *np = pdev->dev.of_node;
    u32 val;

    // 读取整数属性
    if (of_property_read_u32(np, "clock-frequency", &val)) {
        dev_err(&pdev->dev, "missing clock-frequency\n");
        return -EINVAL;
    }

    // 读取 GPIO
    struct gpio_desc *rst = devm_gpiod_get(&pdev->dev, "reset", GPIOD_OUT_HIGH);

    // 读取中断
    int irq = platform_get_irq(pdev, 0);

    return 0;
}

static const struct of_device_id my_of_match[] = {
    { .compatible = "vendor,my-device" },
    { }  // 空终止
};
MODULE_DEVICE_TABLE(of, my_of_match);
```

## 第四层：正常/异常路径

### 正常路径

1. 编写 DTS，语法正确，compatible 字符串与驱动完全匹配
2. dtc 编译成功，生成 DTB
3. U-Boot 加载 DTB 到内存，内核解析时成功匹配驱动
4. probe 函数执行，设备正常工作

### 异常路径

| 异常 | 现象 | 原因 | 排查方法 |
|------|------|------|----------|
| compatible 不匹配 | 驱动 probe 不执行，设备不可用，dmesg 无报错 | 设备树中 compatible 写错，或驱动中 of_match_table 不包含该字符串 | `cat /sys/bus/*/drivers/*/bind` 查看已注册驱动 |
| reg 地址错误 | 设备无响应，寄存器读写全是 0xFF | 基地址或偏移量写错，或 size 范围不够 | 对照 datasheet 的 Memory Map 章节 |
| 忘了 status="okay" | 设备完全没出现，内核不解析 | 默认为 disabled，只有 okay 才会被初始化 | 检查 DTS 中 status 属性 |
| pinctrl 冲突 | 后初始化的设备抢占成功 | 两个外设复用了同一个 GPIO | 检查 pinctrl-0 中引脚是否重复 |
| 中断号错误 | 设备能访问但中断不触发 | 中断号或触发方式配错 | `cat /proc/interrupts` 看中断计数是否增加 |
| DTB 版本不匹配 | 内核 panic 启动失败 | 内核和 DTB 版本不一致 | 重新编译内核和 DTB 确保版本同步 |

## 第五层：调试方法

### 查看当前生效的设备树

```bash
# 反编译 /sys/firmware/fdt 查看内核实际收到的 DTB
dtc -I dtb -O dts /sys/firmware/fdt > current.dts

# 查看设备树节点中的 compatible 属性
cat /sys/devices/platform/serial@2500000/of_node/compatible

# 查看注册了哪些 platform 设备
ls /sys/devices/platform/

# 查看 I2C 总线上有哪些设备
ls /sys/bus/i2c/devices/

# 查看 SPI 总线上有哪些设备
ls /sys/bus/spi/devices/
```

### 编译检查

```bash
# 检查 DTS 语法（编译但不输出）
dtc -I dts -O dtb -o /dev/null myboard.dts

# 查看编译错误位置
dtc -I dts -O dtb -o myboard.dtb myboard.dts 2>&1
```

## 第六层：实战练习

### 练习 1：读懂一个 DTS 文件

找 `/home/ys/aiglass/tina-v861/device/config/chips/v861/configs/reglasses/uboot-board.dts`，回答以下问题：
- 这个板子用的什么 SoC？compatible 是什么？
- 开了哪些外设（status = "okay"）？
- UART0 的引脚配置是什么？用了哪两个引脚？

### 练习 2：写一个简单的 DTS

为一个假想的开发板写一个最小 DTS：
- CPU：1 核 RISC-V
- 内存：512MB 从 0x40000000 开始
- UART0：地址 0x2500000，中断 32
- I2C0：地址 0x2500400，上面挂一个温度传感器 `tmp117@48`

### 练习 3：添加自定义属性

在练习 2 的 I2C 温度传感器节点中，添加自定义属性 `alert-temperature = <85>`，并编写对应的内核驱动代码片段，在 probe 中使用 `of_property_read_u32` 读取该属性。

### 练习 4：排查 compatible 不匹配

假设你添加了一个新设备，但 `ls /sys/bus/i2c/devices/` 中看不到它。写出你的排查步骤（至少 4 步）。

## 自测与验收

1. DeviceTree 和 ACPI 有什么本质区别？为什么 ARM 嵌入式用 DeviceTree 而 x86 用 ACPI？
2. `compatible = "snps,dw-apb-uart"` 中的 `"snps,dw-apb-uart"` 是在哪里定义的？内核如何通过这个字符串找到驱动？
3. DTS 中的 `reg = <0x02500000 0x400>` 中的两个数字分别代表什么？
4. 什么是 DeviceTree Overlay？它和普通 DTS 有什么不同？
5. 如果一个设备在 DTS 中声明了但 probe 不执行，可能的原因有哪些？请列出至少 4 个排查步骤。

## 延伸阅读

- [[uboot-U-Boot引导程序]] — U-Boot 加载 DTB 并传给内核
- [[platform-driver-外设驱动框架]] — compatible 如何匹配驱动的 probe
- [[power-pinmux-电源与引脚复用]] — pinctrl 子系统详解
- [[i2c-spi-gpio-subsys-I2C-SPI-GPIO子系统]] — 设备树中声明 I2C/SPI 设备

## #flashcard

Q: DeviceTree 中 compatible 属性的作用是什么？
A: 驱动匹配的关键字，格式为"厂商,型号"。内核通过 compatible 字符串在已注册的驱动中查找匹配的 of_match_table，找到后调用驱动的 probe 函数。

Q: DTS、DTSI、DTB 三者的关系是什么？
A: DTSI 是 SoC 级通用定义（头文件），DTS 是板级具体定义（包含 DTSI），DTB 是 DTS 经 dtc 编译后的二进制。U-Boot 加载 DTB 并传给内核解析。

Q: 为什么 x86 PC 不需要 DeviceTree 而 ARM 需要？
A: x86 的 PCI/USB 设备支持自动枚举发现（即插即用），ARM 嵌入式板上的 I2C/SPI/UART 设备没有这种协议，需要 DeviceTree 手动告诉内核硬件连接。

Q: pinctrl 在设备树中的作用是什么？
A: 配置引脚复用功能，告诉芯片某个物理引脚当前应该作为什么功能使用（如 UART TX、I2C SCL、GPIO 等），避免多个外设冲突。

Q: DeviceTree 中 status 属性有哪些可选值？分别代表什么？
A: "okay"=启用，该设备会被内核初始化；"disabled"=禁用，内核忽略该设备；"reserved"=保留，通常用于固件保留的内存区域。