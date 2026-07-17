---
type: concept
tags: [BSP, U-Boot, Bootloader, 引导程序, 嵌入式Linux, uboot]
aliases: [U-Boot, uboot, 引导程序, 启动引导, SPL, bootloader]
---

# U-Boot 引导程序

## 一句话结论

U-Boot 是嵌入式 Linux 的"开机引导程序"——上电后它先跑，初始化硬件（内存/存储/串口），然后加载内核到内存并跳转。没有它，Linux 内核根本起不来。

## 30秒先看懂

- U-Boot 是嵌入式 Linux 世界最通用的引导程序，支持 ARM、RISC-V、x86 等几乎所有架构。
- 启动分为两个阶段：SPL（极小，初始化 DDR 和基本外设）和完整 U-Boot（有命令行，加载内核和 DTB）。
- U-Boot 提供命令行界面，可以在启动前修改环境变量（如 bootargs、bootcmd），调试硬件。
- 核心命令：`printenv` 查看环境变量，`fatload` 从存储加载文件，`booti` 启动内核。
- U-Boot 的职责就是三板斧：初始化硬件 → 加载内核+DTB 到内存 → 跳转到内核入口。

## 学完以后应该能做什么

**第一遍**
- 能说出 U-Boot 的完整启动流程（BootROM → SPL → U-Boot → 内核）
- 会用 U-Boot 命令行加载和启动内核
- 能设置和保存 U-Boot 环境变量（bootargs、bootcmd）

**进阶**
- 能为新板子移植 U-Boot（修改 DDR 配置、Flash 驱动、网络驱动）
- 能理解 U-Boot 的 SPL 和 FIT image 机制
- 能调试 U-Boot 启动问题（DDR 初始化失败、内核加载失败等）

## 前置知识

- 嵌入式系统启动流程（BootROM 概念）
- Linux 内核启动参数（bootargs 的含义）
- 内存地址概念（DDR、MMU 映射）

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|----------|
| 通用引导加载器 | U-Boot (Universal Bootloader) | 嵌入式 Linux 最常用的引导程序，支持多种架构和存储设备 |
| 第二阶段引导 | SPL (Secondary Program Loader) | U-Boot 的第一阶段，极小（通常 < 32KB），初始化 DDR 后加载完整 U-Boot |
| 引导参数 | bootargs | 传给 Linux 内核的命令行参数，如 console、root、init |
| 引导命令 | bootcmd | U-Boot 自动启动时执行的命令序列 |
| 设备树二进制 | DTB (Device Tree Blob) | 硬件描述，U-Boot 加载后传给内核 |
| 内核镜像 | kernel image | Linux 内核的二进制文件（Image/zImage） |
| 环境变量 | environment variables | U-Boot 的配置参数，存储在 Flash 或 EEPROM 中 |

## 第一层：费曼心智模型

### 类比：电影院的放映员

芯片上电 = 电影院开门。U-Boot = 放映员：
- ① 开灯、检查设备（初始化 DDR、串口、Flash）
- ② 从仓库拿出胶片（从 Flash/SD 卡加载内核镜像）
- ③ 装好胶片，按下播放键（把内核加载到内存，跳转执行）

**为什么需要 U-Boot？** 因为上电后只有 BootROM（固化在芯片里）能跑，它只能从固定位置加载很小的程序。U-Boot 作为"第二阶段引导程序"，有完整的驱动能力，能从各种设备（SD 卡、eMMC、NAND Flash、网络）加载内核。

### 边界在哪里

- U-Boot 不负责运行应用程序——加载内核后它的使命就结束了
- U-Boot 的 SPL 阶段非常小（通常 < 32KB），受限于芯片内部 SRAM 大小
- U-Boot 可以修改 DTB（如修改 bootargs、使能/禁用节点），内核收到的是 U-Boot 修改后的版本
- U-Boot 的驱动能力远弱于内核——它只初始化足够启动内核的硬件

### 场景演练：V881 开发板开机

1. 按下电源键，V881 芯片上电
2. BootROM（芯片内置，不可修改）从 SD 卡固定位置加载 SPL
3. SPL 初始化 DDR 控制器（最重要的一步——没有 DDR 什么都干不了）
4. SPL 加载完整 U-Boot 到 DDR
5. U-Boot 启动，初始化串口，打印启动信息
6. U-Boot 执行 bootcmd：从 SD 卡加载 Image 到 0x40080000，加载 DTB 到 0x41000000
7. U-Boot 执行 `booti 0x40080000 - 0x41000000`，跳转到内核入口
8. Linux 内核接管系统

## 第二层：原理/时序/约束

### 启动流程

```
芯片上电
  │
  └─→ BootROM（芯片内置，不可改）
        │
        └─→ SPL（U-Boot 的第一阶段，极小，初始化 DDR）
              │
              └─→ U-Boot（完整版，有命令行）
                    │
                    ├─ 加载 DeviceTree (DTB)
                    ├─ 加载 Kernel Image (zImage/Image)
                    │
                    └─→ 跳转到内核入口
```

### U-Boot 常用命令

```
# 查看环境变量
printenv

# 设置环境变量
setenv bootargs console=ttyS0,115200 root=/dev/mmcblk0p2 rootwait

# 从 SD 卡加载内核和设备树
fatload mmc 0:1 0x40080000 Image
fatload mmc 0:1 0x41000000 sunxi.dtb

# 启动内核
booti 0x40080000 - 0x41000000

# 保存环境变量
saveenv
```

### 关键环境变量

| 变量 | 作用 | 示例 |
|------|------|------|
| `bootcmd` | 自动启动时执行的命令序列 | `fatload mmc 0:1 0x40080000 Image; fatload mmc 0:1 0x41000000 sunxi.dtb; booti 0x40080000 - 0x41000000` |
| `bootargs` | 传给内核的命令行参数 | `console=ttyS0,115200 root=/dev/mmcblk0p2 rootwait` |
| `bootdelay` | 自动启动前的等待秒数 | `2`（按任意键进入命令行） |
| `ipaddr` | 开发板 IP 地址 | `192.168.1.100` |
| `serverip` | TFTP 服务器 IP 地址 | `192.168.1.1` |

## 第三层：真实 SDK 代码

### V881 的 U-Boot 设备树

文件路径：`/home/ys/aiglass/tina-v861/device/config/chips/v861/configs/reglasses/uboot-board.dts`

```dts
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
```

这个文件是 U-Boot 使用的设备树，与内核用的设备树类似但更精简。U-Boot 只需要足够初始化硬件和加载内核的设备信息。

### V881 的 U-Boot 源码位置

```bash
# V881 的 U-Boot 源码
/home/ys/aiglass/tina-v861/brandy/brandy-2.0/u-boot-bsp/

# 编译生成的反编译 DTS 文件
/home/ys/aiglass/tina-v861/brandy/brandy-2.0/u-boot-2023/u-boot-dtb.dts
```

## 第四层：正常/异常路径

### 正常路径

1. BootROM 从启动介质加载 SPL → 成功
2. SPL 初始化 DDR → 成功
3. SPL 加载完整 U-Boot 到 DDR → 成功
4. U-Boot 初始化串口，打印启动信息
5. U-Boot 执行 bootcmd，加载内核和 DTB
6. 跳转到内核，内核启动成功

### 异常路径

| 问题 | 现象 | 根因 | 排查方法 |
|------|------|------|----------|
| DDR 初始化失败 | 系统直接死掉，无任何输出 | SPL 的 DDR 配置和实际硬件不匹配（频率、时序、型号） | 检查 DDR 芯片型号和 datasheet，确认 SPL 配置正确 |
| bootargs 拼错 | 内核 panic，无法挂载根文件系统 | root= 指向了不存在的分区 | 检查 bootargs 中的 root= 参数 |
| DTB 不匹配 | 内核启动但设备不工作 | 内核和 DTB 版本不对应 | 确保内核和 DTB 来自同一版本编译 |
| bootcmd 错误 | 内核不自动启动，停在 U-Boot 命令行 | bootcmd 中的命令序列有误 | 手动执行 bootcmd 中的命令逐步排查 |
| 存储介质损坏 | 加载内核失败 | SD 卡坏道或 Flash 损坏 | 更换存储介质 |

## 第五层：调试方法

### 串口调试

```bash
# 通过串口连接 U-Boot（通常 115200 8N1）
screen /dev/ttyUSB0 115200

# 上电后按任意键进入 U-Boot 命令行
# 看到 "Hit any key to stop autoboot:" 提示时快速按键
```

### U-Boot 命令行调试

```
# 查看内存内容
md 0x40080000 0x10     # 显示内存地址 0x40080000 开始的 16 个 word

# 测试内存
mtest 0x40000000 0x50000000

# 查看设备树
fdt addr 0x41000000    # 指定 DTB 地址
fdt list               # 列出设备树节点

# 网络启动（通过 TFTP 加载内核，调试时非常有用）
setenv autoload no
dhcp                   # 获取 IP 地址
tftp 0x40080000 Image  # 从 TFTP 服务器加载内核
```

## 第六层：实战练习

### 练习 1：阅读 V881 的 U-Boot 设备树

阅读 `/home/ys/aiglass/tina-v861/device/config/chips/v861/configs/reglasses/uboot-board.dts`，回答：
- 这个板子在 U-Boot 阶段启用了哪些外设？
- UART0 的引脚配置是什么？
- aliases 节点的作用是什么？为什么需要它？

### 练习 2：写一个 U-Boot 启动脚本

假设你的开发板有以下配置：
- 内核在 SD 卡第一个分区，文件名 `Image`
- DTB 在 SD 卡第一个分区，文件名 `board.dtb`
- 加载地址：内核到 0x40080000，DTB 到 0x41000000
- 根文件系统在 eMMC 的第二个分区

写一个完整的 bootcmd 命令序列，并写出对应的 bootargs。提示：用 `fatload mmc 0:1` 加载。

### 练习 3：模拟 U-Boot DDR 初始化失败排查

假设你的新板子上电后串口无任何输出，已知 SPL 已经加载但 DDR 初始化失败，列出你的排查步骤（至少 5 步）。

### 练习 4：分析 U-Boot 和内核设备树的区别

对比 `/home/ys/aiglass/tina-v861/device/config/chips/v861/configs/reglasses/uboot-board.dts` 和内核的 DTS 文件（位置自寻），回答：
- U-Boot 的 DTS 和内核的 DTS 有什么不同？
- 为什么 U-Boot 的 DTS 更精简？
- 哪些设备只在内核 DTS 中出现而不在 U-Boot DTS 中出现？

## 自测与验收

1. U-Boot 的 SPL 和完整 U-Boot 有什么区别？为什么需要两个阶段？
2. U-Boot 环境变量 `bootcmd` 和 `bootargs` 分别有什么用？
3. 如何在 U-Boot 启动时阻止自动启动，进入命令行？
4. 如果 U-Boot 启动后串口无任何输出，可能的原因是什么？
5. U-Boot 如何把 DTB 传给内核？U-Boot 会不会修改 DTB？

## 延伸阅读

- [[devicetree-DeviceTree设备树]] — U-Boot 加载 DTB 传给内核
- [[boot-ota-启动流程与OTA升级]] — 从 BootROM 到 A/B 升级的完整链路
- [[kernel-build-Kernel编译与裁剪]] — 内核编译产出 Image 和 dtbs

## #flashcard

Q: U-Boot 的 SPL 是什么？为什么需要它？
A: SPL (Secondary Program Loader) 是 U-Boot 的第一阶段，极小（通常 < 32KB），在芯片内部 SRAM 中运行，初始化 DDR 后加载完整 U-Boot 到 DDR。因为 BootROM 受限于 SRAM 大小，无法直接加载完整 U-Boot。

Q: U-Boot 的 bootcmd 和 bootargs 环境变量分别有什么作用？
A: bootcmd 是 U-Boot 自动启动时执行的命令序列（如加载内核和 DTB、跳转执行）。bootargs 是传给 Linux 内核的命令行参数（如 console、root、init）。

Q: 如何在 U-Boot 启动时进入命令行？
A: 在串口看到 "Hit any key to stop autoboot" 提示时，按任意键。可以通过设置 bootdelay 环境变量控制等待时间。

Q: U-Boot 会不会修改 DTB？
A: 会。U-Boot 可以在启动前修改 bootargs、使能/禁用节点、修补内存信息。用 `dtc` 反编译 `/sys/firmware/fdt` 查看最终版本。

Q: U-Boot DDR 初始化失败的现象是什么？
A: 系统直接死掉，串口无任何输出。因为 DDR 初始化失败后，SPL 无法加载完整 U-Boot 到内存，也没有串口输出。