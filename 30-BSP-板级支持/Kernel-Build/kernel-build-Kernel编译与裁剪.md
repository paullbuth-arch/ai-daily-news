# Kernel 编译与裁剪

**一句话结论（20% 核心）**：Linux 内核几千万行代码，你的板子只需要几百个驱动。内核裁剪就是通过 `make menuconfig` 关掉不需要的驱动、文件系统、网络协议，编译出最小可用的内核镜像（嵌入式通常 3-8 MB）。V881 的内核通过 `make sunxi_defconfig` 配置，`make -j$(nproc) Image dtbs modules` 编译。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：自助餐厅

完整内核 = 自助餐厅把 500 道菜全部做出来，摆在桌上（几千万行代码，编译 2 小时，镜像 100MB+）

裁剪后 = 你只点 3 道你爱吃的菜（编译 5 分钟，镜像 3-8MB）

**嵌入式 Flash 通常只有 16-128MB**，内核镜像必须裁剪到 3-8MB。关掉 99% 不需要的驱动是裁剪的核心。

### 1.2 内核编译的完整流程

```bash
# ① 设置架构和交叉编译器
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-

# ② 载入板级默认配置
make sunxi_defconfig          # 全志芯片的默认配置
# 或从现有配置开始
# cp /boot/config-$(uname -r) .config

# ③ 定制配置
make menuconfig                # ncurses 图形界面

# ④ 编译
make -j$(nproc) Image         # 内核镜像
make -j$(nproc) dtbs          # 设备树
make -j$(nproc) modules       # 内核模块
# 或一条命令全编译
make -j$(nproc) Image dtbs modules

# ⑤ 安装
make modules_install INSTALL_MOD_PATH=./rootfs
cp arch/arm64/boot/Image /boot/
cp arch/arm64/boot/dts/allwinner/sunxi-v881.dtb /boot/
```

### 1.3 配置项的三种状态

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

### 1.4 如果只记得一件事

> 内核裁剪 = `make menuconfig` 关掉不需要的驱动/文件系统/协议。嵌入式必砍：关掉 x86 驱动、关掉不需要的文件系统（只留 ext4/squashfs）、关掉不需要的网络协议。V881 用 `sunxi_defconfig` 作为起点。

---

## 第二层：实战理解

### 2.1 嵌入式内核裁剪的必砍清单

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

### 2.2 查看内核大小

```bash
# 查看内核镜像大小
ls -lh arch/arm64/boot/Image
# -rw-r--r-- 1 root root 6.8M  Image

# 查看各子系统的代码大小
size vmlinux
# text    data     bss     dec     hex
# 6234567  345678  123456 6703701 664b55

# 查看哪些符号最占空间
nm --size-sort vmlinux | tail -20
```

### 2.3 编译内核模块

```bash
# 编译单个模块
make M=drivers/net/wireless/realtek

# 安装模块
make modules_install INSTALL_MOD_PATH=./rootfs

# 查看模块依赖
depmod -b ./rootfs 5.4.0

# 加载模块
insmod mydriver.ko        # 加载单个模块
modprobe mydriver         # 加载模块+自动加载依赖
rmmod mydriver            # 卸载

# 查看已加载模块
lsmod
```

### 2.4 常见坑

| 问题 | 现象 | 排查方法 | 根因 |
|------|------|---------|------|
| 关了不该关的 | 内核 panic 或功能缺失 | `make savedefconfig` 对比 defconfig | 依赖关系不清楚，连锁关掉了关键功能 |
| 模块没加载 | 设备不工作但内核已编译 | `modprobe xxx` 或加入 /etc/modules | 编译为模块但没自动加载 |
| defconfig 不工作 | 关键硬件无响应 | 对比芯片厂商的 defconfig | 用了通用 defconfig 而不是板级 defconfig |
| 编译不通过 | 编译错误 | 逐个检查 menuconfig 改动 | 有些配置选项有依赖，menuconfig 不会阻止错误配置 |

### 2.5 在 reGlasses 项目中怎么用

V881 的内核配置在 `~/aiglass/tina-v861/kernel/linux/arch/arm64/configs/` 下。Tina Linux 提供了 `sunxi_defconfig` 作为起点，然后通过 `make menuconfig` 定制。

```bash
cd ~/aiglass/tina-v861/kernel/linux
make ARCH=arm64 sunxi_defconfig
make ARCH=arm64 menuconfig   # 添加/删除需要的功能
make ARCH=arm64 -j$(nproc) Image dtbs modules
```

WQ7036AX 不跑 Linux，不需要内核裁剪。ACORE 跑 FreeRTOS，配置通过 Kconfig 管理（`wqcore/tools/config/Kconfig.base`）。

---

## 第三层：深入扩展

### 3.1 内核配置的依赖关系

```bash
# 查看某个配置选项的依赖
make menuconfig → 按 / 搜索 → 看 "Depends on"

# 保存最小配置（只包含修改过的选项）
make savedefconfig
# 生成 defconfig 文件，只包含你改过的选项

# 对比两个配置
scripts/diffconfig .config.old .config.new
```

### 3.2 常见问题

- **内核镜像和 zImage 的区别？** `Image` 是未压缩的内核镜像，`zImage` 是压缩的内核镜像（带自解压头）。ARM64 通常用 `Image`（U-Boot 支持直接加载），ARM32 通常用 `zImage`。
- **为什么有的驱动要编译成模块？** 节省内存（不用的模块不加载）、热插拔支持（USB 设备插入时加载驱动）、方便调试（不用重启内核）。
- **menuconfig 和 defconfig 的关系？** `defconfig` 是初始配置，`menuconfig` 修改后生成 `.config`。`make savedefconfig` 可以把 `.config` 的反向生成最小 `defconfig`。

### 3.3 延伸阅读

- [[devicetree-DeviceTree设备树]] — 内核通过 DTB 知道硬件连接
- [[buildroot-yocto-Buildroot与Yocto]] — 内核和根文件系统一起打包
- [[uboot-U-Boot引导程序]] — U-Boot 加载内核镜像