# Kernel 编译与裁剪

**一句话结论（20% 核心）**：Linux 内核几千万行代码，你的板子只需要几百个驱动。内核裁剪就是通过 `make menuconfig` 选择需要的功能，编译出最小可用的内核镜像。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：自助餐 vs 点菜

完整内核 = 把所有菜都做一遍（几千万行，编译几小时，镜像几百 MB）

裁剪后 = 只点你需要的菜（编译几分钟，镜像几 MB）

嵌入式设备 Flash 空间有限，必须裁剪。V881 的内核镜像通常只有 3-8 MB。

### 1.2 内核配置的核心操作

```bash
# 使用默认配置
make ARCH=arm64 defconfig           # 通用默认配置
make ARCH=arm64 sunxi_defconfig     # 全志芯片的默认配置

# 图形化配置
make ARCH=arm64 menuconfig          # ncurses 菜单界面

# 修改后编译
make ARCH=arm64 -j$(nproc) Image dtbs modules
```

### 1.3 配置项的类型（menuconfig 里看到的）

| 标记 | 含义 | 怎么选 |
|------|------|--------|
| `[*]` | 编译进内核 | 必须的功能（如 GPIO 子系统） |
| `[ ]` | 不编译 | 用不到的功能 |
| `<M>` | 编译为模块 | 偶尔用到（如 USB 驱动），按需加载 |
| `< >` | 不编译（模块） | 同上，但不编译 |

### 1.4 如果只记得一件事

> 内核裁剪 = 用 menuconfig 关掉不需要的驱动和功能。嵌入式板子要瘦身：关掉不需要的文件系统、网络协议、驱动框架，编译出几 MB 的内核镜像。

---

## 第二层：实战理解

### 2.1 嵌入式内核裁剪的必砍项

```bash
# 通常在 menuconfig 中关掉这些：
# General setup → 关掉不需要的 init 系统
# File systems → 只保留 ext4 和 squashfs（关掉 xfs/btrfs 等）
# Device Drivers → 关掉 x86 平台驱动、不需要的 USB/PCI/网络设备
# Networking support → 关掉不需要的协议（如 amateur radio、X.25）
# Kernel hacking → 关掉调试选项（release 版本）
```

### 2.2 常见坑

| 问题 | 现象 | 根因 |
|------|------|------|
| 关了不该关的 | 内核 panic 或功能缺失 | 依赖关系不清楚，连锁关掉了关键功能 |
| 编译为模块但没加载 | 设备不工作 | 需要 `modprobe` 或加入自动加载列表 |
| defconfig 不匹配 | 关键硬件不工作 | 用了通用 defconfig 而不是板级 defconfig |

### 2.3 在 reGlasses 项目中怎么用

V881 的内核配置在 `~/aiglass/tina-v861/kernel/linux/arch/arm64/configs/` 下。编译时 `make sunxi_defconfig` 生成 `.config`。日常开发中，遇到"内核缺少某个功能"时，需要在这里开启对应配置。

---

## 第三层：延伸阅读

- [[devicetree-DeviceTree设备树]] — 内核通过 DTB 知道硬件连接
- [[buildroot-yocto-Buildroot与Yocto]] — 内核和根文件系统一起打包