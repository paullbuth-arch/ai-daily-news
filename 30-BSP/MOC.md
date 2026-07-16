---
type: moc
tags: [moc, bsp, devicetree, uboot, kernel, buildroot]
---

# 30-BSP: 板级支持包 (Linux)

> BSP（Board Support Package）的工作：让 Linux 在你的板子上跑起来。这包括 DeviceTree（描述硬件）、U-Boot（引导程序）、Kernel（内核）、Buildroot（根文件系统）。

---

## 学习路线

```
DeviceTree（描述硬件长什么样）
    │
    └──→ U-Boot（启动引导，把 Kernel 加载起来）
          │
          └──→ Kernel（Linux 内核，管理所有硬件资源）
                │
                └──→ Buildroot（制作根文件系统，提供用户空间）
```

---

## 已有笔记

| 文件 | 一句话 | 什么时候学 |
|------|--------|-----------|
| [[启动流程与 OTA 升级]] | BootROM → U-Boot → Kernel → rootfs，以及 A/B 分区升级 | 理解固件更新流程时 |

## 待创建（按需补充）

| 主题 | 一句话 |
|------|--------|
| DeviceTree | DTS 语法、常用节点（gpio/i2c/spi/pinmux）、调试方法 |
| U-Boot | 启动流程、环境变量、常用命令、SPL |
| Kernel 裁剪 | defconfig/menuconfig、模块编译 |
| Buildroot | 交叉编译工具链、根文件系统定制 |

## 面试高频问题

- DeviceTree 中 `compatible` 字段的作用？
- U-Boot 的 bootcmd 和 bootargs 怎么配？
- Buildroot 和 Yocto 的核心区别？
- pinctrl 和 gpio 子系统的关系？