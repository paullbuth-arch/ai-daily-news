# DeviceTree 设备树

**一句话结论（20% 核心）**：DeviceTree 是给 Linux 内核的"硬件清单"——用树形结构描述板子上有什么芯片、连在哪个引脚、用什么驱动。ARM/RISC-V 嵌入式板没有 PC 的硬件自发现能力，内核全靠这张清单找到硬件。改硬件连接时改 DTS 而不是改内核代码。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：新房的电路图

买了一套毛坯房，你要告诉电工每个房间的电路布局。你不能说"电工你自己猜吧"——电工不知道你哪个房间要装灯、哪个要装空调。

DeviceTree 就是这张电路图，它告诉 Linux 内核：
- 这个板子上有哪些设备（灯、空调、插座）
- 它们连在哪个引脚/总线上（客厅东墙、卧室北墙）
- 用什么参数配置（电压 220V、空调功率 2 匹）

**x86 PC 为什么不需要？** 因为 PCI/USB 设备可以自动枚举发现（插上 U 盘，系统自动识别）。ARM 嵌入式板上的 I2C/SPI/UART 设备没有这种自动发现协议，必须手动告诉内核。

### 1.2 树形结构：从根节点到叶子

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

**关键心智模型**：树的结构 = 物理总线拓扑。I2C 设备一定是 I2C 控制器的子节点，因为数据确实通过 I2C 总线走。SPI 设备同理。树的嵌套关系直接反映硬件连接关系。

### 1.3 一个完整的最小 DTS 示例

```dts
/dts-v1/;

/ {
    model = "V881 Development Board";
    compatible = "allwinner,v881";
    #address-cells = <1>;
    #size-cells = <1>;

    memory {
        reg = <0x40000000 0x10000000>;  // 256MB DDR at 0x40000000
    };

    soc {
        compatible = "simple-bus";
        #address-cells = <1>;
        #size-cells = <1>;
        ranges;

        // UART 控制器
        uart0: serial@2500000 {
            compatible = "snps,dw-apb-uart";
            reg = <0x02500000 0x400>;
            interrupts = <0 32 4>;
            clocks = <&ccu 0>;
            clock-names = "baudclk";
            pinctrl-names = "default";
            pinctrl-0 = <&uart0_pins>;
            status = "okay";
        };

        // I2C 控制器 + 上面的设备
        i2c0: i2c@2500400 {
            compatible = "allwinner,sun8i-i2c";
            reg = <0x02500400 0x400>;
            interrupts = <0 34 4>;
            clock-frequency = <400000>;
            status = "okay";

            // 光传感器（挂在 I2C0 上）
            light_sensor@39 {
                compatible = "elam,elm2713";
                reg = <0x39>;              // I2C 7-bit 地址
                interrupt-parent = <&pio>;
                interrupts = <0 12 2>;      // GPIO 中断
                proximity-threshold = <100>;
            };
        };
    };

    chosen {
        bootargs = "console=ttyS0,115200 root=/dev/mmcblk0p2 rootwait";
    };
};
```

### 1.4 核心概念速查表

| 概念 | 含义 | 示例 | 为什么重要 |
|------|------|------|-----------|
| **compatible** | 匹配驱动的字符串 | `"snps,dw-apb-uart"` | 内核据此找到驱动，拼错=驱动不工作 |
| **reg** | 寄存器/内存地址 | `<0x02500000 0x400>` | 地址错了设备直接不响应 |
| **interrupts** | 中断号（3 元组） | `<0 32 4>` → 控制器0, 中断32, 上升沿触发 | 中断配错=设备能访问但不会通知 CPU |
| **status** | 设备开关 | `"okay"` / `"disabled"` / `"reserved"` | 不想用的设备关掉即可 |
| **phandle** | 节点指针 | `&ccu` → 指向时钟控制器节点 | 复用节点，避免重复定义 |
| **pinctrl** | 引脚复用配置 | `pinctrl-0 = <&uart0_pins>` | 告诉芯片这个引脚现在是 UART 不是 GPIO |

### 1.5 如果只记得一件事

> DeviceTree = 硬件清单。compatible 匹配驱动，reg 指定地址，树形结构反映物理总线拓扑。改硬件连接时只改 DTS 文件，内核驱动代码不用动。

---

## 第二层：实战理解

### 2.1 DTS → DTB → 内核的完整流程

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

**关键理解**：内核不会报"找不到驱动"。如果 compatible 写错了，设备静默被忽略。排查"设备不工作"时，第一件事就是确认 compat 字符串是否匹配。

### 2.2 日常操作命令

```bash
# 1. 反编译 DTB 看当前实际生效的设备树
dtc -I dtb -O dts /boot/sunxi.dtb > current.dts
# 这看到的是 U-Boot 可能修改后的最终版本

# 2. 检查 DTS 语法（编译但不输出）
dtc -I dts -O dtb -o /dev/null myboard.dts

# 3. 查看内核实际匹配了哪些驱动
ls /sys/devices/platform/          # platform 设备
ls /sys/bus/i2c/devices/           # I2C 设备
ls /sys/bus/spi/devices/           # SPI 设备

# 4. 查看某个设备的 OF 节点（设备树节点）
cat /sys/devices/platform/serial@2500000/of_node/compatible
# 输出: snps,dw-apb-uart

# 5. 在驱动代码中读取设备树属性
# 内核中: of_property_read_u32(np, "clock-frequency", &val);
# 这个函数从设备树中读取 clock-frequency 的值
```

### 2.3 常见坑（附排查方法）

| 问题 | 现象 | 排查方法 | 根因 |
|------|------|---------|------|
| compatible 不匹配 | 驱动 probe 不执行 | `cat /sys/bus/*/drivers/*/bind` 看驱动是否注册 | 内核缺驱动，或 compatible 字符串和驱动中 `of_match_table` 不一致 |
| reg 地址错误 | 设备无响应，寄存器读写全是 0xFF | 对照 datasheet 的 Memory Map 章节 | 基地址或偏移量写错 |
| pinmux 冲突 | 后初始化的设备抢占成功 | 检查 `pinctrl-0` 有没有重复的引脚 | 两个外设复用了同一个 GPIO |
| 中断号错误 | 设备能访问但中断不触发 | `cat /proc/interrupts` 看中断计数是否增加 | 中断号或触发方式配错 |
| 忘了 status="okay" | 设备完全没出现 | 默认可能是 disabled | 只有 okay 的设备才会被内核初始化 |

### 2.4 在 reGlasses 项目中怎么用

V881 的设备树在 `~/aiglass/tina-v861/device/config/chips/v881/` 下。WQ7036AX 和 V881 之间的通信接口都在 V881 的设备树中描述：

```dts
// V881 侧看到 WQ7036AX 的 UART 和 I2S 连接
// V881 设备树中（简化示意）
&uart1 {
    status = "okay";
    // WQ7036AX 的 UART 连在 V881 的 UART1 上
    // PD18=RX, PD19=TX
};

&i2s0 {
    status = "okay";
    // V881 是 I2S Master，WQ7036AX 是 Slave
    // V881 提供 BCLK 和 LRCK
};
```

日常开发中，当你需要修改 V881 侧的引脚分配、启用/禁用某个外设、或调整驱动参数时，改的就是这些 DTS 文件。

---

## 第三层：深入扩展

### 3.1 DeviceTree Overlay：运行时修改设备树

Overlay 允许在不重启的情况下动态加载设备树片段。常用于：
- 树莓派 HAT（扩展板）即插即用
- FPGA 动态加载 IP 核后注册设备

```dts
/dts-v1/;
/plugin/;
&i2c0 {
    my_new_device@50 {
        compatible = "vendor,new-device";
        reg = <0x50>;
    };
};
```

### 3.2 内核驱动中读取设备树的标准写法

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

### 3.3 常见问题

- **U-Boot 会不会修改 DTB？** 会。U-Boot 可以修改 bootargs、使能/禁用节点、修补内存信息。用 `dtc` 反编译 `/sys/firmware/fdt` 看最终版本。
- **`#address-cells` 和 `#size-cells` 是什么？** 定义子节点 reg 属性的编码格式。`#address-cells=1` 表示地址用 1 个 u32 表示，`#size-cells=1` 表示大小用 1 个 u32 表示。
- **DeviceTree 和 ACPI 的区别？** DT 是 ARM/RISC-V 嵌入式用的硬件描述方式，ACPI 是 x86 PC 用的。ACPI 更复杂，支持电源管理和设备枚举。DT 更简单，只描述硬件拓扑。

### 3.4 延伸阅读

- [[uboot-U-Boot引导程序]] — U-Boot 加载 DTB 并传给内核
- [[platform-driver-外设驱动框架]] — compatible 如何匹配驱动的 probe
- [[power-pinmux-电源与引脚复用]] — pinctrl 子系统详解