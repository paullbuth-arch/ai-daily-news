# Buildroot 与 Yocto

**一句话结论（20% 核心）**：Buildroot 和 Yocto 都是"嵌入式 Linux 系统工厂"——自动帮你交叉编译内核、根文件系统、应用程序，打包成一个完整的固件镜像。Buildroot 简单快速，Yocto 灵活强大但复杂。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：宜家厨房 vs 定制厨房

- **Buildroot** = 宜家厨房套餐：选好型号，一键安装，快速搞定。不够灵活但够用。
- **Yocto** = 请设计师定制厨房：每个柜子、每个抽屉都可以定制。灵活但复杂，学习曲线陡。

### 1.2 两者对比

| | Buildroot | Yocto |
|---|---|---|
| 配置方式 | Kconfig (menuconfig) | 层+配方 (layer+recipe) |
| 学习曲线 | 平缓 | 陡峭 |
| 首次构建 | 20-40 分钟 | 1-2 小时 |
| 增量构建 | 一般 | 优秀（共享 sstate cache） |
| 包管理 | 无（静态系统） | 有（.deb/.rpm/.ipk） |
| 适用场景 | 小型固件、快速原型 | 产品级、多板卡、需要在线更新 |

### 1.3 如果只记得一件事

> Buildroot = 简单但静态，Yocto = 复杂但灵活。V881 用 Tina Linux（全志魔改的 Buildroot），WQ7036AX 不需要根文件系统（跑 RTOS）。

---

## 第二层：实战理解

### 2.1 Buildroot 基本操作

```bash
# 配置
make menuconfig
# → Target options: 选择架构 (ARM64)
# → Toolchain: 选择交叉编译工具链
# → System configuration: 设置 root 密码、登录终端
# → Target packages: 选择要安装的包

# 编译
make -j$(nproc)

# 输出在 output/images/:
#   rootfs.tar / rootfs.ext4  → 根文件系统
#   Image / zImage             → 内核镜像
#   sunxi.dtb                  → 设备树
```

### 2.2 在 reGlasses 项目中怎么用

V881 使用全志的 **Tina Linux**（基于 Buildroot 深度定制）。代码在 `~/aiglass/tina-v861/`。配置和编译命令：

```bash
cd ~/aiglass/tina-v861
source build/envsetup.sh
lunch  # 选择 v881 配置
make -j$(nproc)
```

WQ7036AX 侧不需要 Buildroot——它跑 FreeRTOS，固件是 WPK 包（ZIP 格式），由 SCons 构建。

---

## 第三层：延伸阅读

- [[kernel-build-Kernel编译与裁剪]] — 内核是 Buildroot/Yocto 编译的核心组件
- [[boot-ota-启动流程与OTA升级]] — 编译产物如何打包成 OTA 固件