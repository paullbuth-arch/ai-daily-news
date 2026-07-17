# Buildroot 与 Yocto

**一句话结论（20% 核心）**：Buildroot 和 Yocto 都是"嵌入式 Linux 系统工厂"——自动交叉编译内核、根文件系统、应用程序，打包成完整固件镜像。Buildroot 简单快速（Kconfig 配置，20-40 分钟），Yocto 灵活强大（layer+recipe，1-2 小时但可增量编译）。V881 用 Tina Linux（全志基于 Buildroot 魔改）。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：宜家厨房 vs 定制厨房

- **Buildroot** = 宜家厨房套餐：选好型号，开箱即用，一上午搞定。够用但不够个性化。
- **Yocto** = 请设计师定制厨房：每个柜子、每个抽屉、每个把手都可以定制。灵活但需要专业知识和时间。

**为什么需要这些工具？** 因为手动构建嵌入式 Linux 系统需要：编译内核、编译几百个库和工具、配置启动脚本、打包文件系统——这是一个极其繁琐的过程。Buildroot/Yocto 自动化了这个过程。

### 1.2 两者深度对比

| | Buildroot | Yocto |
|---|---|---|
| 配置方式 | Kconfig (menuconfig) | 层+配方 (layer+recipe) |
| 学习曲线 | 平缓，1 天上手 | 陡峭，1-2 周入门 |
| 首次构建 | 20-40 分钟 | 1-2 小时 |
| 增量构建 | 一般（改一个包可能触发重编） | 优秀（共享 sstate-cache，改一个包只重编它） |
| 包管理 | **无**（静态系统，不能在线安装新包） | **有**（.deb/.rpm/.ipk，可以 apt-get） |
| 适用场景 | 小型固件、快速原型、单板 | 产品级、多板卡、需要在线更新和包管理 |
| 代表用户 | 树莓派 Buildroot、OpenWrt、**Tina Linux** | 车载 Linux、工业控制、Yocto Project |

**关键选择依据**：如果你的产品不需要在线安装新软件（嵌入式固件通常不需要），Buildroot 就够了。如果需要像 Linux 发行版一样在线安装包，选 Yocto。

### 1.3 Buildroot 的目录结构和输出

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

### 1.4 如果只记得一件事

> Buildroot = 简单快速的静态固件构建工具，Kconfig 配置，无包管理。Yocto = 灵活强大的产品级构建工具，layer+recipe 配置，有包管理。V881 用 Tina Linux（全志魔改的 Buildroot），WQ7036AX 不需要（跑 RTOS）。

---

## 第二层：实战理解

### 2.1 Buildroot 完整操作流程

```bash
# 1. 下载 Buildroot
git clone https://git.buildroot.net/buildroot
cd buildroot

# 2. 选择板级配置
make raspberrypi4_defconfig   # 或 make menuconfig 从头配置

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

### 2.2 添加自定义包

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

### 2.3 在 reGlasses 项目中怎么用

V881 使用全志的 **Tina Linux**（基于 Buildroot 深度定制，增加了全志芯片的支持和多媒体框架）。代码在 `~/aiglass/tina-v861/`。

```bash
cd ~/aiglass/tina-v861
source build/envsetup.sh
lunch v881_glasses-tina    # 选择 reGlasses 的配置
make -j$(nproc)            # 编译完整系统
pack                       # 打包固件镜像
```

WQ7036AX 不需要 Buildroot——它跑 FreeRTOS，固件是 WPK 包（ZIP 格式），由 SCons 构建，直接烧录到 Flash。

---

## 第三层：深入扩展

### 3.1 Yocto 的 layer 和 recipe 概念

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

### 3.2 常见问题

- **Buildroot 和 Yocto 怎么选？** 快速原型和简单产品 → Buildroot。多产品线、需要在线包管理、团队协作 → Yocto。V881 用 Buildroot（Tina）是合理的——固件相对固定，不需要在线安装包。
- **Buildroot 能增量编译吗？** 能，但比 Yocto 弱。改一个包 Buildroot 通常只重编那个包，但改系统配置可能触发全局重编。
- **Tina Linux 和 Buildroot 的关系？** Tina 是全志在 Buildroot 基础上增加芯片支持、多媒体框架、系统工具的发行版。你可以把它理解为"全志优化过的 Buildroot"。

### 3.3 延伸阅读

- [[kernel-build-Kernel编译与裁剪]] — 内核是 Buildroot/Yocto 编译的核心组件
- [[boot-ota-启动流程与OTA升级]] — 编译产物如何打包成 OTA 固件
- [[devicetree-DeviceTree设备树]] — 设备树在 Buildroot 中的位置