---
type: moc
tags: [moc, foundation, C, OS, 计算机组成]
---

# 10-Foundation：C 语言 / OS / 计算机组成

> 嵌入式开发的地基。计算机组成告诉你"芯片里面有什么"，C 语言告诉你"怎么指挥芯片干活"，OS 概念告诉你"怎么让芯片同时干多件事"。

## 小白学习路线

**第一遍**：计算机组成 → C 语言夯实基础 → C 语言核心 → 编译链接启动

**第二遍**：中断与并发 → RTOS → 内存与 DMA

**第三遍**：多核 IPC → 低功耗 → 系统可靠性

## C 语言与数据结构

| 文件 | 核心内容 |
|------|---------|
| [[c-fundamentals-C语言夯实基础]] | 从零开始的 C 语言完整教程：类型、指针、数组、结构体、函数、预处理器 |
| [[c-core-C语言核心]] | 指针 = 内存地址，位运算 = 操控寄存器 |
| [[data-structure-state-machine-数据结构与状态机]] | 链表/状态机是嵌入式代码的骨架 |
| [[ring-buffer-环形缓冲区]] | ISR 和任务之间传数据的经典模式 |
| [[compile-link-startup-编译链接与启动流程]] | 源码→编译→链接→烧录→上电启动 |
| [[build-system-构建系统]] | Makefile/SCons/Kconfig 构建工具链 |

## OS 概念

| 文件 | 核心内容 |
|------|---------|
| [[interrupt-concurrency-中断并发同步]] | 中断 = 门铃，信号量/互斥量/队列 |
| [[rtos-freertos-RTOS原理与FreeRTOS]] | 调度器、任务、FreeRTOS API |
| [[memory-dma-内存管理与DMA]] | 栈/堆、DMA 传输、cache 一致性 |

## 计算机组成

| 文件 | 核心内容 |
|------|---------|
| [[computer-arch-mcu-计算机组成与MCU架构]] | CPU+Flash+RAM+总线 = 芯片骨架 |
| [[assembly-basics-汇编基础]] | 汇编指令、寄存器、调用约定 |
| [[ipc-multicore-多核通信与IPC]] | 共享内存 + 中断通知 = 多核协作 |
| [[low-power-低功耗设计]] | Sleep/DeepSleep/ClockGating 省电三板斧 |
| [[reliability-exception-系统可靠性与异常处理]] | 看门狗、异常处理、FMEA |

## 如果你只能学 3 篇

1. [[computer-arch-mcu-计算机组成与MCU架构]] — 芯片里面有什么
2. [[c-core-C语言核心]] — 怎么操控它
3. [[interrupt-concurrency-中断并发同步]] — 为什么 bug 总是和中断有关