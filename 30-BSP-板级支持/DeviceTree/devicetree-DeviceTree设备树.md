# DeviceTree 设备树

**一句话结论（20% 核心）**：DeviceTree 是给 Linux 内核的"硬件清单"——描述板子上有什么芯片、连在哪个引脚、用什么驱动。没有它，内核不知道板子上有什么硬件。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：新房的电路图

买了一套新房，你要告诉电工：哪个房间有灯、开关在哪、插座在哪。DeviceTree 就是这张"电路图"——它告诉 Linux 内核：
- 这个板子上有哪些设备（灯/插座）
- 它们连在哪个引脚上（开关位置）
- 用什么驱动（多少电压）

**x86 PC 不需要 DeviceTree**，因为硬件通过 ACPI/PCI 枚举自动发现。ARM/RISC-V 嵌入式板没有这种自动发现机制，必须手动告诉内核。

### 1.2 一个最小的 DTS 示例

```dts
/dts-v1/;

/ {
    model = "V881 Development Board";
    compatible = "allwinner,v881";

    memory {
        reg = <0x40000000 0x10000000>;  // 256MB DDR at 0x40000000
    };

    soc {
        uart0: serial@2500000 {
            compatible = "snps,dw-apb-uart";
            reg = <0x02500000 0x400>;
            interrupts = <0 32 4>;
            clocks = <&ccu 0>;
            status = "okay";
        };

        i2c0: i2c@2500400 {
            compatible = "allwinner,sun8i-i2c";
            reg = <0x02500400 0x400>;
            interrupts = <0 34 4>;
            clock-frequency = <400000>;
            status = "okay";

            light_sensor@39 {
                compatible = "elam,elm2713";
                reg = <0x39>;
                interrupt-parent = <&pio>;
                interrupts = <0 12 2>;
            };
        };
    };
};
```

### 1.3 核心概念

| 概念 | 含义 | 例子 |
|------|------|------|
| **compatible** | 匹配驱动 | `"snps,dw-apb-uart"` → 内核找到对应的 UART 驱动 |
| **reg** | 寄存器基地址 + 长度 | `<0x02500000 0x400>` → 地址 0x02500000，长度 0x400 |
| **interrupts** | 中断号 | `<0 32 4>` → 中断控制器 0，中断 32，触发方式 4 |
| **status** | 设备状态 | `"okay"`=启用，`"disabled"`=禁用 |
| **phandle (&label)** | 引用其他节点 | `&ccu` → 引用时钟控制器节点 |

### 1.4 如果只记得一件事

> DeviceTree = 硬件清单，用 DTS 文件描述。compatible 字段匹配驱动，reg 字段指定寄存器地址。改硬件连接时改 DTS 而不是改内核代码。

---

## 第二层：实战理解

### 2.1 DeviceTree 的工作流程

```
DTS (源码) ──→ DTC (编译器) ──→ DTB (二进制) ──→ U-Boot 加载 ──→ 内核解析
                                                                    │
                                           compatible 匹配 ←────────┘
                                                                    │
                                                            驱动 probe() 被调用
```

### 2.2 常见操作

```bash
# 反编译 DTB 查看当前设备树
dtc -I dtb -O dts /boot/sunxi.dtb > current.dts

# 检查 DTS 语法
dtc -I dts -O dtb -o /dev/null myboard.dts

# 查看内核匹配了哪些驱动
cat /sys/devices/platform/*/uevent
```

### 2.3 常见坑

| 问题 | 现象 | 根因 |
|------|------|------|
| compatible 不匹配 | 驱动 probe 不执行 | 内核里没有对应驱动，或字符串拼错 |
| reg 地址错误 | 设备不工作 | 地址和 datasheet 对不上 |
| pinmux 冲突 | 两个设备争一个引脚 | 同一个 GPIO 分配给了两个外设 |

### 2.4 在 reGlasses 项目中怎么用

V881 运行 Linux，设备树在 `~/aiglass/tina-v861/` 的 `device/config/chips/v881/` 下。WQ7036AX 和 V881 之间的 UART 连接、I2S 连接都在 V881 的设备树中描述。当你需要修改 V881 侧的引脚配置时，改的就是这里的 DTS 文件。

---

## 第三层：延伸阅读

- [[uboot-U-Boot引导程序]] — U-Boot 加载 DTB 并传给内核
- [[platform-driver-外设驱动框架]] — compatible 如何匹配到驱动的 probe 函数