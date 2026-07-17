# U-Boot 引导程序

**一句话结论（20% 核心）**：U-Boot 是嵌入式 Linux 的"开机引导程序"——上电后它先跑，初始化硬件（内存/存储/串口），然后加载内核到内存并跳转。没有它，Linux 内核根本起不来。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：电影院的放映员

芯片上电 = 电影院开门。U-Boot = 放映员：
- ① 开灯、检查设备（初始化 DDR、串口、Flash）
- ② 从仓库拿出胶片（从 Flash/SD 卡加载内核镜像）
- ③ 装好胶片，按下播放键（把内核加载到内存，跳转执行）

**为什么需要 U-Boot？** 因为上电后只有 BootROM（固化在芯片里）能跑，它只能从固定位置加载很小的程序。U-Boot 作为"第二阶段引导程序"，有完整的驱动能力，能从各种设备加载内核。

### 1.2 启动流程

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

### 1.3 如果只记得一件事

> U-Boot = 嵌入式 Linux 的引导程序。BootROM → SPL（初始化 DDR）→ U-Boot（加载内核+DTB）→ 跳转内核。U-Boot 有命令行，可以在启动前修改环境变量。

---

## 第二层：实战理解

### 2.1 U-Boot 常用命令

```
# 查看环境变量
printenv

# 设置环境变量
setenv bootargs console=ttyS0,115200 root=/dev/mmcblk0p2 rootwait

# 从 SD 卡加载内核
fatload mmc 0:1 0x40080000 Image
fatload mmc 0:1 0x41000000 sunxi.dtb

# 启动内核
booti 0x40080000 - 0x41000000

# 保存环境变量
saveenv
```

### 2.2 关键环境变量

| 变量 | 作用 | 示例 |
|------|------|------|
| `bootcmd` | 自动启动时执行的命令序列 | `fatload mmc 0 ...; booti ...` |
| `bootargs` | 传给内核的命令行参数 | `console=ttyS0,115200 root=/dev/mmcblk0p2` |
| `bootdelay` | 自动启动前的等待秒数 | `2`（按任意键进入命令行） |

### 2.3 常见坑

| 问题 | 现象 | 根因 |
|------|------|------|
| DDR 初始化失败 | 系统直接死掉 | SPL 的 DDR 配置和实际硬件不匹配 |
| bootargs 拼错 | 内核 panic | root= 指向了不存在的分区 |
| DTB 不匹配 | 设备不工作 | 内核和 DTB 版本不对应 |

### 2.4 在 reGlasses 项目中怎么用

V881 使用 U-Boot 引导。U-Boot 配置在 `~/aiglass/tina-v861/` 的 `brandy/u-boot/` 下。日常开发很少需要改 U-Boot，除非换 DDR 型号、换 Flash 型号、或修改启动参数。

---

## 第三层：延伸阅读

- [[devicetree-DeviceTree设备树]] — U-Boot 加载 DTB 传给内核
- [[boot-ota-启动流程与OTA升级]] — 从 BootROM 到 A/B 升级的完整链路