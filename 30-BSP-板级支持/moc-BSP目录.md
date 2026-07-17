---
type: moc
tags: [moc, bsp, devicetree, uboot, kernel, buildroot, ota]
---

# 30-BSP：板级支持包（Linux）

> BSP（Board Support Package，板级支持包）的工作：让 Linux 在你的板子上跑起来。包括 DeviceTree（描述硬件）、U-Boot（引导程序）、Kernel（内核）、Buildroot（根文件系统）和 OTA（固件升级）。

## 学习路线

DeviceTree（描述硬件）→ U-Boot（启动引导）→ Kernel 编译（内核配置）→ Buildroot/Yocto（根文件系统）→ OTA（固件升级）

## 已有文档

| 文件 | 核心内容 |
|------|---------|
| [[devicetree-DeviceTree设备树]] | DTS 语法、compatible 匹配、pinctrl、GPIO/I2C/SPI 节点 |
| [[uboot-U-Boot引导程序]] | 启动流程、环境变量、SPL、bootcmd |
| [[kernel-build-Kernel编译与裁剪]] | defconfig/menuconfig、模块编译、交叉编译 |
| [[buildroot-yocto-Buildroot与Yocto]] | 交叉编译工具链、根文件系统定制 |
| [[boot-ota-启动流程与OTA升级]] | BootROM→U-Boot→Kernel、A/B 分区升级、签名校验、回滚 |
| [[power-pinmux-电源与引脚复用]] | 电源域、pinmux 配置、驱动强度 |

## 核心问题

- DeviceTree 中 `compatible` 字段的作用？匹配驱动和设备的字符串标识。
- U-Boot 的 bootcmd 和 bootargs 怎么配？bootcmd 定义启动命令序列，bootargs 传给内核的命令行参数。
- Buildroot 和 Yocto 的区别？Buildroot 简单快速适合小系统，Yocto 灵活强大适合复杂产品。