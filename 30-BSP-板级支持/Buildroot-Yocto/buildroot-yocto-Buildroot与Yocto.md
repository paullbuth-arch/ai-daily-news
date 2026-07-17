---
type: concept
tags: [BSP, Buildroot, Yocto, 嵌入式Linux, 构建系统, 根文件系统, Tina Linux]
aliases: [Buildroot, Yocto, 嵌入式构建, 根文件系统构建, Tina Linux, 全志Tina]
---

# Buildroot 与 Yocto

## 一句话结论

Buildroot 和 Yocto 都是"嵌入式 Linux 系统工厂"——自动交叉编译内核、根文件系统、应用程序，打包成完整固件镜像。Buildroot 简单快速（Kconfig 配置，20-40 分钟），Yocto 灵活强大（layer+recipe，1-2 小时但可增量编译）。V881 用 Tina Linux（全志基于 Buildroot 魔改）。

## 30秒先看懂

- Buildroot 和 Yocto 解决同一个问题：自动构建嵌入式 Linux 的完整固件（内核 + 根文件系统 + 应用），不需要手动交叉编译每个包。
- Buildroot 用 Kconfig（menuconfig）配置，简单直接，首次构建只需 20-40 分钟，适合快速原型和小型产品。
- Yocto 用 layer+recipe 配置，学习曲线陡峭但功能强大，支持增量编译和在线包管理，适合产品级多板卡项目。
- 核心区别在于包管理：Buildroot 构建的是静态固件，不能在线安装新包；Yocto 可以生成 .deb/.rpm/.ipk 包，支持 apt-get 在线安装。
- V881 使用全志的 Tina Linux（基于 Buildroot 深度定制），WQ7036AX 跑 FreeRTOS 不需要这些工具。

## 学完以后应该能做什么

**第一遍**
- 能说清楚 Buildroot 和 Yocto 的核心区别和各自适用场景
- 能用 Buildroot 完成一次完整的固件构建（从 defconfig 到 sdcard.img）
- 能在 Buildroot 中添加一个自定义应用程序包

**进阶**
- 能理解 Yocto 的 layer 和 recipe 概念，能写一个简单的 .bb 文件
- 能分析 Tina Linux 的构建流程，定位构建问题
- 能在 Buildroot 中配置内核、文件系统类型、应用包

## 前置知识

- Linux 交叉编译概念
- 根文件系统的基本概念（init、/etc、/usr/bin 等目录结构）
- Kconfig 配置系统（与内核裁剪章节相关）

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|----------|
| 根文件系统 | rootfs | 包含 Linux 启动所需的所有文件（init、库、工具、配置）的目录树 |
| 板级配置 | defconfig | 针对特定开发板的 Buildroot/Yocto 默认配置，定义芯片、包、文件系统等 |
| 配方 | recipe (bb) | Yocto 中描述如何下载、编译、安装一个软件包的脚本文件 |
| 层 | layer | Yocto 中一组 recipe 的集合，不同层可以叠加（BSP 层、应用层等） |
| 交叉编译工具链 | toolchain | 在主机上编译目标板代码的工具集（gcc、ld、libc 等） |
| 主机目录 | host | Buildroot 中编译宿主工具（如交叉编译器）的输出目录 |
| 目标目录 | target | Buildroot 中根文件系统内容的输出目录 |
| 镜像输出 | images | 最终固件镜像的输出目录（内核、rootfs、sdcard.img） |
| 共享状态缓存 | sstate-cache | Yocto 的增量编译缓存，命中后只需几秒而非几十分钟 |

## 第一层：费曼心智模型

### 类比：宜家厨房 vs 定制厨房

- **Buildroot** = 宜家厨房套餐：选好型号，开箱即用，一上午搞定。够用但不够个性化。
- **Yocto** = 请设计师定制厨房：每个柜子、每个抽屉、每个把手都可以定制。灵活但需要专业知识和时间。

**为什么需要这些工具？** 因为手动构建嵌入式 Linux 系统需要：编译内核、编译几百个库和工具、配置启动脚本、打包文件系统——这是一个极其繁琐的过程。Buildroot/Yocto 自动化了这个过程。

### 边界在哪里

- Buildroot 构建的系统是"静态"的——固件烧录后不能在线安装新软件。如果需要像树莓派那样 `apt-get install`，选 Yocto。
- Yocto 的首次构建时间很长（1-2 小时），但 sstate-cache 让后续增量编译非常快。Buildroot 首次快（20-40 分钟），但增量编译能力较弱。
- 如果你的芯片厂商已经提供了 Buildroot 支持（如全志的 Tina Linux），优先使用厂商方案，省去大量适配工作。

### 场景演练：为 V881 构建固件

1. 全志已经提供了 Tina Linux 作为 V881 的 SDK，基于 Buildroot 深度定制
2. 你不需要从头配置：`source build/envsetup.sh` → `lunch v881_glasses-tina`
3. 系统自动选择目标芯片（V881）、架构（RISC-V）、工具链、内核版本
4. `make -j$(nproc)` 编译整个系统，包括内核、驱动模块、根文件系统、应用
5. 如果新增一个应用，在 `package/` 下添加一个目录和 Config.in，不需要改构建系统的核心逻辑

## 第二层：原理/时序/约束

### Buildroot 的目录结构和输出

```
buildroot/
├── package/          # 所有可编译的软件包
├── configs/          # 板级默认配置
├── output/
│   ├── build/        # 编译中间文件
│   ├── host/         # 交叉编译工具链
│   ├── images/       # 最终输出 ← 你关心这个
│   │   ├── rootfs.ext4    # 根文件系统镜像
│   │   ├── Image          # 内核镜像
│   │   ├── sunxi.dtb      # 设备树
│   │   └── sdcard.img     # 完整 SD 卡镜像
│   └── target/       # 根文件系统目录结构（用于调试）
└── .config           # 当前配置
```

### Buildroot 完整操作流程

```bash
# 1. 下载 Buildroot
git clone https://git.buildroot.net/buildroot
cd buildroot

# 2. 选择板级配置
make raspberrypi4_defconfig

# 3. 自定义配置
make menuconfig
# Target options → ARM64, Cortex-A53
# Toolchain → External toolchain (Linaro ARM64)
# System configuration → root password, getty port
# Target packages → 勾选需要的包（如 openssh, iperf3, python3）
# Filesystem images → ext4 + squashfs

# 4. 编译
make -j$(nproc)

# 5. 输出在 output/images/
ls output/images/
# Image, sunxi.dtb, rootfs.ext4, sdcard.img
```

### Yocto 的 layer 和 recipe 概念

```
yocto/
├── poky/                    # 参考发行版
├── meta-openembedded/       # 社区提供的包
├── meta-sunxi/              # 全志芯片层
├── meta-reglasses/          # 你自己的层
│   ├── conf/layer.conf
│   ├── recipes-app/myapp/
│   │   └── myapp_1.0.bb     # 配方文件
│   └── recipes-kernel/linux/
│       └── linux-sunxi_5.4.bbappend  # 修改内核配置
```

### 两者深度对比

| 特性 | Buildroot | Yocto |
|------|-----------|-------|
| 配置方式 | Kconfig (menuconfig) | 层+配方 (layer+recipe) |
| 学习曲线 | 平缓，1 天上手 | 陡峭，1-2 周入门 |
| 首次构建 | 20-40 分钟 | 1-2 小时 |
| 增量构建 | 一般（改一个包可能触发重编） | 优秀（共享 sstate-cache，改一个包只重编它） |
| 包管理 | **无**（静态系统，不能在线安装) | **有**（.deb/.rpm/.ipk，可以 apt-get） |
| 适用场景 | 小型固件、快速原型、单板 | 产品级、多板卡、需要在线更新和包管理 |
| 代表用户 | 树莓派 Buildroot、OpenWrt、**Tina Linux** | 车载 Linux、工业控制、Yocto Project |

## 第三层：真实 SDK 代码

### Tina Linux 构建 V881 固件

文件路径：`/home/ys/aiglass/tina-v861/`

```bash
# 进入 Tina Linux 构建环境
cd ~/aiglass/tina-v861
source build/envsetup.sh
lunch v881_glasses-tina    # 选择 reGlasses 的配置
make -j$(nproc)            # 编译完整系统
pack                       # 打包固件镜像
```

Tina Linux 的 `package/` 目录包含了全志支持的所有软件包定义，V881 相关的配置在 `target/allwinner/v861/` 下。

### 添加自定义包到 Buildroot

```makefile
# package/myapp/myapp.mk
MYAPP_VERSION = 1.0
MYAPP_SITE = /path/to/myapp/source
MYAPP_SITE_METHOD = local

define MYAPP_BUILD_CMDS
    $(MAKE) CC=$(TARGET_CC) -C $(@D)
endef

define MYAPP_INSTALL_TARGET_CMDS
    $(INSTALL) -D -m 0755 $(@D)/myapp $(TARGET_DIR)/usr/bin/myapp
endef

$(eval $(generic-package))
```

```ini
# package/myapp/Config.in
config BR2_PACKAGE_MYAPP
    bool "myapp"
    help
      My custom application for reGlasses
```

### WQ7036AX 的构建系统对比

WQ7036AX 跑 FreeRTOS，固件是 WPK 包（ZIP 格式），由 SCons 构建系统管理。配置通过 Kconfig（kconfiglib Python 实现）管理，入口文件在 `/home/ys/wq7036a/wq-audio/wqcore/tools/config/Kconfig.base`。这与 Buildroot/Yocto 解决的是同一类问题——自动化构建和配置管理，但针对的是 RTOS 环境而非 Linux 环境。

## 第四层：正常/异常路径

### 正常路径

1. 选择正确的 defconfig → 所有依赖自动解析
2. menuconfig 定制 → 保存
3. `make -j$(nproc)` → 自动下载源码、交叉编译、打包
4. 输出 images/ 目录下的固件镜像可以直接烧录

### 异常路径

| 异常 | 现象 | 原因 | 排查方法 |
|------|------|------|----------|
| 下载失败 | 编译卡在 "Downloading" | 源码包在境外服务器，网络不通 | 配置本地镜像源或提前下载好源码包 |
| 包依赖冲突 | 编译报错，版本不兼容 | 选的包版本之间不兼容 | 查看包文档或选兼容版本 |
| 根文件系统太大 | 超出 Flash 分区大小 | 选了太多包 | 检查 output/images/rootfs.ext4 大小，关掉不需要的包 |
| 内核配置不匹配 | 内核编译失败 | defconfig 和目标架构不匹配 | 确认 ARCH 和 CROSS_COMPILE 设置正确 |
| 工具链版本不兼容 | 编译报错，语法错误 | 工具链太新或太旧 | 使用芯片厂商推荐的工具链版本 |

## 第五层：调试方法

### Buildroot 调试

```bash
# 查看编译日志
make -j$(nproc) 2>&1 | tee build.log

# 重新编译单个包
make <package>-rebuild    # 如 make openssh-rebuild

# 查看包的实际配置
make show-targets

# 进入编译目录手动调试
cd output/build/<package>-<version>/
# 手工执行 make 看具体错误
```

### Yocto 调试

```bash
# 查看 recipe 的完整环境
bitbake -e myapp | grep ^S=

# 运行 devshell 进入编译环境
bitbake -c devshell myapp

# 查看依赖树
bitbake -g myapp && cat recipe-depends.dot
```

## 第六层：实战练习

### 练习 1：探索 Tina Linux 的构建系统

进入 `/home/ys/aiglass/tina-v861/`，执行以下操作：
1. 运行 `source build/envsetup.sh`，查看支持哪些板级配置
2. 运行 `lunch` 看有哪些选项（不需要实际选择）
3. 查看 `package/` 目录下有哪些包分类
4. 找到与 V881 相关的配置目录（`target/allwinner/v861/`）

### 练习 2：在 Buildroot 中添加一个包

假设你需要在 Buildroot 中添加一个 `hello` 程序，它只有一个 C 源文件 `hello.c`，输出 "Hello from Buildroot!"。写一个完整的 `hello.mk` 和 `Config.in`，以及 `hello.c` 中需要的内容。

### 练习 3：对比分析

比较 Buildroot 的 `package/` 目录结构和 Yocto 的 `meta-*/recipes-*/` 目录结构，回答：
- 两者的软件包描述文件有什么不同？
- Buildroot 的 `.mk` 文件和 Yocto 的 `.bb` 文件在语法上有什么异同？
- 从维护者的角度看，哪个更容易添加新包？

### 练习 4：分析 WQ7036A 的构建系统和 Buildroot 的异同

阅读 `/home/ys/wq7036a/wq-audio/wqcore/tools/config/Kconfig.base`，对比 Buildroot 的 Kconfig 配置，回答：
- WQ7036A 的构建系统是否也支持类似 menuconfig 的图形界面？
- WQ7036A 的 "包" 概念和 Buildroot 的 "package" 有什么异同？
- 两者都使用 Kconfig，但目标有什么不同？

## 自测与验收

1. Buildroot 和 Yocto 的核心区别是什么？什么场景下选 Buildroot，什么场景下选 Yocto？
2. Buildroot 的 `output/images/` 目录下通常有哪些文件？
3. 什么是 Yocto 的 layer？layer 解决了什么问题？
4. Tina Linux 和 Buildroot 的关系是什么？Tina 在 Buildroot 基础上增加了什么？
5. 为什么 WQ7036AX 不需要 Buildroot/Yocto？

## 延伸阅读

- [[kernel-build-Kernel编译与裁剪]] — 内核是 Buildroot/Yocto 编译的核心组件
- [[boot-ota-启动流程与OTA升级]] — 编译产物如何打包成 OTA 固件
- [[devicetree-DeviceTree设备树]] — 设备树在 Buildroot 中的位置

## #flashcard

Q: Buildroot 和 Yocto 的核心区别是什么？
A: Buildroot 简单快速（Kconfig 配置，无包管理，静态固件），Yocto 灵活强大（layer+recipe，有包管理，支持增量编译）。Buildroot 适合快速原型，Yocto 适合产品级项目。

Q: 什么是 Tina Linux？它和 Buildroot 的关系？
A: Tina Linux 是全志基于 Buildroot 深度定制的嵌入式 Linux 发行版，增加了全志芯片支持、多媒体框架、系统工具。

Q: Buildroot 的 output/images/ 目录下通常有哪些文件？
A: rootfs.ext4（根文件系统）、Image（内核镜像）、sunxi.dtb（设备树）、sdcard.img（完整 SD 卡镜像）。

Q: Yocto 的 layer 概念解决了什么问题？
A: Layer 让不同团队的代码解耦——BSP 层（芯片厂商维护）、应用层（产品团队维护）、社区层（开源社区维护），可以独立更新和组合。

Q: 为什么 WQ7036AX 不需要 Buildroot？
A: WQ7036AX 跑 FreeRTOS，不是 Linux。它的固件是 WPK 包（ZIP 格式），由 SCons 构建系统管理，配置通过 Kconfig（kconfiglib）管理。