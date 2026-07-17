---
type: concept
tags: [BSP, Kernel, Linux, 编译, 裁剪, Kconfig, menuconfig, 嵌入式Linux]
aliases: [Kernel编译, 内核裁剪, 内核配置, kernel-build, menuconfig, defconfig]
---

# Kernel 编译与裁剪

## 一句话结论

Linux 内核几千万行代码，你的板子只需要几百个驱动。内核裁剪就是通过 `make menuconfig` 关掉不需要的驱动、文件系统、网络协议，编译出最小可用的内核镜像（嵌入式通常 3-8 MB）。V881 的内核通过 `make sunxi_defconfig` 配置，`make -j$(nproc) Image dtbs modules` 编译。

## 30秒先看懂

- 完整内核包含所有硬件驱动，镜像巨大（100MB+），嵌入式 Flash 通常只有 16-128MB，必须裁剪。
- 裁剪的核心工具是 `make menuconfig`，通过 ncurses 界面勾选/取消配置项，决定哪些功能编译进内核、哪些编译为模块、哪些不编译。
- 配置项有三种状态：`[*]` 编译进内核（built-in）、`[M]` 编译为模块（module）、`[ ]` 不编译。
- 嵌入式裁剪的必砍清单：x86 驱动、不用的文件系统（只留 ext4/squashfs）、不用的网络协议、调试选项。
- V881 用 `sunxi_defconfig` 作为起点，WQ7036AX 跑 FreeRTOS，配置通过 Kconfig 管理。

## 学完以后应该能做什么

**第一遍**
- 能用 `make menuconfig` 配置和裁剪内核
- 能说出 `[*]`、`[M]`、`[ ]` 三种状态的区别和使用场景
- 能完成一次完整的内核编译（从 defconfig 到 Image/dtb/modules）

**进阶**
- 能制作一个最小嵌入式内核镜像（3-5MB），只包含板子需要的驱动
- 能用 `make savedefconfig` 管理配置，用 `scripts/diffconfig` 对比配置差异
- 能理解内核配置的依赖关系，避免关了不该关的导致内核 panic

## 前置知识

- Linux 基本命令行操作
- 交叉编译概念（主机编译，目标板运行）
- 嵌入式系统的 Flash 和内存限制

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|----------|
| 内核配置 | defconfig | 板级默认配置，通常是内核源码中 `arch/*/configs/` 下的文件 |
| 配置文件 | .config | 当前内核编译使用的配置，由 defconfig 或 menuconfig 生成 |
| 编译进内核 | built-in | 用 `[*]` 标记，功能直接编译进内核镜像，始终占用内存但无需加载 |
| 编译为模块 | module | 用 `[M]` 标记，编译成 `.ko` 文件，需要时 `insmod` 加载 |
| 最小配置 | savedefconfig | 只包含和默认配置不同的选项，用于版本管理 |
| 内核镜像 | Image | 编译生成的内核文件，ARM64 通常用未压缩的 Image 格式 |
| 设备树 | dtbs | Device Tree Blobs，内核编译时同时生成 |
| 内核模块 | modules | 可动态加载的驱动，后缀为 .ko |

## 第一层：费曼心智模型

### 类比：自助餐厅

完整内核 = 自助餐厅把 500 道菜全部做出来，摆在桌上（几千万行代码，编译 2 小时，镜像 100MB+）

裁剪后 = 你只点 3 道你爱吃的菜（编译 5 分钟，镜像 3-8MB）

**嵌入式 Flash 通常只有 16-128MB**，内核镜像必须裁剪到 3-8MB。关掉 99% 不需要的驱动是裁剪的核心。

### 边界在哪里

- 裁剪不能关掉关键的依赖项——比如关了 GPIO 子系统，所有 GPIO 驱动都不能用
- 编译为模块（[M]）需要根文件系统支持，如果根文件系统还没加载，模块无法加载 → 启动阶段需要的功能必须编译进内核（[*]）
- menuconfig 不会阻止所有错误配置——有些配置有隐含依赖，关掉 A 可能导致 B 不工作，但 menuconfig 不报错

### 场景演练：为 V881 裁剪内核

1. 从全志的 `sunxi_defconfig` 开始：`make ARCH=arm64 sunxi_defconfig`
2. 运行 `make menuconfig`，进入 File Systems → 关掉 XFS、Btrfs、JFS、F2FS，只保留 ext4 和 squashfs
3. Device Drivers → 关掉 PCI support（V881 没有 PCI）
4. Networking support → 关掉 Amateur Radio、X.25 等不用的协议
5. Kernel hacking → 全部关掉（release 版本不需要调试信息）
6. 保存退出，运行 `make -j$(nproc) Image dtbs modules`
7. 检查生成的 Image 大小：`ls -lh arch/arm64/boot/Image` — 目标 3-5MB

## 第二层：原理/时序/约束

### 内核编译的完整流程

```bash
# ① 设置架构和交叉编译器
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-

# ② 载入板级默认配置
make sunxi_defconfig          # 全志芯片的默认配置

# ③ 定制配置
make menuconfig                # ncurses 图形界面

# ④ 编译
make -j$(nproc) Image         # 内核镜像
make -j$(nproc) dtbs          # 设备树
make -j$(nproc) modules       # 内核模块

# ⑤ 安装
make modules_install INSTALL_MOD_PATH=./rootfs
cp arch/arm64/boot/Image /boot/
cp arch/arm64/boot/dts/allwinner/sunxi-v881.dtb /boot/
```

### 配置项的三种状态

```
menuconfig 中的标记:
  [*]  编译进内核 (built-in)    → 始终占用内存，但不需要加载
  [ ]  不编译                    → 功能不可用
  <M>  编译为模块 (module)      → 需要时加载，节省内存但需要文件系统支持
  < >  不编译（模块）

选择原则:
  - 必须始终可用的功能（如 GPIO 子系统）→ [*]
  - 偶尔用到的功能（如 USB 摄像头驱动）→ <M>
  - 用不到的功能（如 XFS 文件系统）→ [ ]
```

### 嵌入式内核裁剪的必砍清单

```
make menuconfig 中依次关掉:

General setup:
  [ ] POSIX Message Queues             # 如果不用 mq
  [ ] System V IPC                     # 如果不用 sysv ipc

File systems:
  [ ] XFS, Btrfs, JFS, F2FS           # 只保留 ext4 和 squashfs
  [ ] NFS client/server                # 不连网络存储

Device Drivers:
  [ ] PCI support                      # 嵌入式没有 PCI
  [ ] Sound card → 关掉 x86 声卡       # 只保留 SoC 音频
  [ ] USB support → 关掉不需要的 USB 设备
  [ ] Network device → 关掉 x86 网卡   # 只保留 SoC WiFi/以太网

Networking support:
  [ ] Amateur Radio, X.25, ...         # 关掉不用的协议
  [ ] Bluetooth → 关掉不需要的 profile  # 如果只用 BLE 不用经典

Kernel hacking:
  [ ] 全部关掉                         # release 版本
```

## 第三层：真实 SDK 代码

### WQ7036A 的 Kconfig 配置系统

文件路径：`/home/ys/wq7036a/wq-audio/wqcore/tools/config/Kconfig.base`

```
source "$(WQCOREROOT)/chipset/Kconfig"
source "$(WQCOREROOT)/driver/Kconfig"
lsource "$(COMPONENT_DIRS)"
source "$(WQCOREROOT)/os/Kconfig"
orsource "$(APP_ROOT)/Kconfig"
orsource "$(WQCOREROOT)/pre-project/recover/Kconfig"
```

WQ7036AX 虽然不跑 Linux，但它的 FreeRTOS 固件配置也使用了 Kconfig 系统（kconfiglib Python 实现）。这个 Kconfig.base 是配置入口，通过 `source` 引入芯片、驱动、组件、OS 和应用层的配置选项。`orsource` 表示可选引入（如果目录不存在也不报错）。

### V881 内核配置位置

```bash
# V881 的内核配置在 Tina Linux 中
# 板级配置：
/home/ys/aiglass/tina-v861/kernel/linux-6.6-xuantie/arch/arm64/configs/sunxi_defconfig

# 编译命令（在 Tina 环境中）：
cd ~/aiglass/tina-v861
source build/envsetup.sh
lunch v881_glasses-tina
make -j$(nproc)            # 编译整个系统（包含内核）
```

### 内核配置依赖关系分析

```bash
# 查看某个配置选项的依赖
make menuconfig → 按 / 搜索 → 看 "Depends on"

# 保存最小配置（只包含修改过的选项）
make savedefconfig

# 对比两个配置
scripts/diffconfig .config.old .config.new
```

## 第四层：正常/异常路径

### 正常路径

1. 载入正确的 defconfig → 所有依赖满足
2. `make menuconfig` 微调 → 保存
3. `make -j$(nproc) Image dtbs modules` → 编译成功
4. 内核镜像 3-5MB，dtb 几十 KB，模块按需加载

### 异常路径

| 异常 | 现象 | 原因 | 排查方法 |
|------|------|------|----------|
| 关了不该关的 | 内核 panic 或功能缺失 | 依赖关系不清楚，连锁关掉了关键功能 | `make savedefconfig` 对比 defconfig |
| 模块没自动加载 | 设备不工作但内核已编译 | 编译为模块但没在 /etc/modules 中配置 | `modprobe xxx` 手动加载 |
| defconfig 不匹配 | 关键硬件无响应 | 用了通用 defconfig 而不是板级 defconfig | 对比芯片厂商的 defconfig |
| 编译不通过 | 编译错误，Kconfig 语法问题 | 配置选项有依赖冲突 | 检查 menuconfig 中选项的 Depends on |
| 镜像太大 | Flash 放不下 | 没关够功能 | 检查 `size vmlinux` 看哪些部分最占空间 |

## 第五层：调试方法

### 查看内核大小

```bash
# 查看内核镜像大小
ls -lh arch/arm64/boot/Image

# 查看各子系统的代码大小
size vmlinux
# text    data     bss     dec     hex
# 6234567  345678  123456 6703701 664b55

# 查看哪些符号最占空间
nm --size-sort vmlinux | tail -20
```

### 编译调试

```bash
# 编译单个模块（快速迭代）
make M=drivers/net/wireless/realtek

# 只编译设备树
make dtbs

# 并行编译时查看详细错误
make -j$(nproc) 2>&1 | grep -E "error:|warning:"

# 清理后重新编译
make clean && make -j$(nproc) Image
```

## 第六层：实战练习

### 练习 1：完成一次完整的内核编译

使用 V881 的 Tina Linux 环境，完成以下步骤：
1. 进入 `/home/ys/aiglass/tina-v861/kernel/linux-6.6-xuantie/`
2. 执行 `make ARCH=arm64 sunxi_defconfig`
3. 执行 `make ARCH=arm64 menuconfig`，浏览各个子系统的配置选项
4. 关掉 PCI support、XFS 文件系统、Amateur Radio 协议
5. 保存退出，执行 `make ARCH=arm64 -j$(nproc) Image`
6. 记录编译前后的 Image 大小变化

### 练习 2：分析配置依赖

在 `make menuconfig` 中，按 `/` 搜索 `CONFIG_EXT4_FS`，查看：
- 它依赖哪些配置（Depends on）？
- 它被哪些配置选择（Selects）？
- 如果关了它依赖的某个配置，会发生什么？

### 练习 3：制作最小 defconfig

从 `sunxi_defconfig` 开始，通过 `make menuconfig` 逐步关掉功能，每次关掉后运行 `make savedefconfig`，对比生成的 defconfig 文件大小变化。目标：生成一个 3-5MB 内核的 defconfig。

### 练习 4：对比 WQ7036A 的 Kconfig 和 Linux 的 Kconfig

阅读 `/home/ys/wq7036a/wq-audio/wqcore/tools/config/Kconfig.base`，对比 Linux 内核的 `Kconfig` 语法，找出 WQ7036A 的 Kconfig 使用了哪些不同特性（如 `lsource`、`orsource`）。

## 自测与验收

1. `[*]`、`[M]`、`[ ]` 三种配置状态分别代表什么？什么场景下应该用 `[M]` 而不是 `[*]`？
2. 嵌入式裁剪的必砍清单包括哪些大类？为什么 PCI support 通常可以关掉？
3. `make savedefconfig` 和 `make defconfig` 的区别是什么？
4. 为什么启动阶段必需的功能不能编译为模块？
5. 内核镜像 Image 和 zImage 有什么区别？ARM64 通常用哪个？

## 延伸阅读

- [[devicetree-DeviceTree设备树]] — 内核通过 DTB 知道硬件连接
- [[buildroot-yocto-Buildroot与Yocto]] — 内核和根文件系统一起打包
- [[uboot-U-Boot引导程序]] — U-Boot 加载内核镜像

## #flashcard

Q: 内核配置中 `[*]`、`[M]`、`[ ]` 分别代表什么？
A: `[*]` = 编译进内核（built-in），始终占用内存；`[M]` = 编译为模块（.ko 文件），需要时加载；`[ ]` = 不编译，功能不可用。

Q: 嵌入式裁剪内核时，哪些东西通常可以关掉？
A: x86 驱动、PCIE 支持、不用的文件系统（XFS/Btrfs 等）、不用的网络协议（X.25/Amateur Radio）、Kernel hacking 调试选项。

Q: `make savedefconfig` 有什么用？
A: 从当前 `.config` 生成一个最小 defconfig 文件，只包含与默认配置不同的选项，方便版本管理和代码审查。

Q: Image 和 zImage 的区别是什么？
A: Image 是未压缩的内核镜像，zImage 是压缩的内核镜像（带自解压头）。ARM64 通常用 Image（U-Boot 支持直接加载），ARM32 通常用 zImage。

Q: 为什么启动必需的功能要编译进内核而不能编译为模块？
A: 因为根文件系统可能还没加载，模块存放在根文件系统中，如果根文件系统不可用，模块无法加载，系统就启动不了。