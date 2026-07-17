---
type: moc
tags: [moc, debug, gdb, ftrace, jtag, 调试, 逻辑分析仪]
---

# 80-Debug：调试方法论

> "能调试"比"能写代码"更重要。嵌入式调试和 PC 调试最大的区别：你不能 printf 到屏幕上，出问题后芯片可能直接死掉，没有任何错误信息。

## 学习路线

调试方法论（先建立思维框架）→ 调试工具链（GDB/OpenOCD/逻辑分析仪）→ 日志系统设计 → 内存泄漏检测 → 性能分析

## 已有文档

| 文件 | 核心内容 |
|------|---------|
| [[debug-methodology-嵌入式调试方法论]] | 复现→分类→假设→验证→归档，HardFault/死锁/通信故障排查 |
| [[debug-tools-常用调试工具链]] | GDB/OpenOCD/逻辑分析仪/示波器——全套工具 |
| [[serial-jtag-swd-串口与JTAG调试]] | 串口控制台、JTAG 连接、OpenOCD 配置 |
| [[gdb-ftrace-GDB与ftrace]] | GDB 远程调试：断点/单步/栈回溯、ftrace 内核追踪 |
| [[logic-analyzer-逻辑分析仪与示波器]] | SPI/I2C/UART 协议解码、时序分析 |
| [[logging-design-日志系统设计]] | 日志分级、缓冲、异步输出 |
| [[memory-leak-内存泄漏检测]] | 内存泄漏检测工具和方法 |
| [[crashdump-perf-Crashdump与性能分析]] | kernel panic、core dump、perf 性能分析 |

## 调试心法

1. **先复现**：不能稳定复现的 bug 几乎没法修
2. **二分法**：注释掉一半代码，确定 bug 在哪一半
3. **一次只改一个变量**：改多个东西就不知道哪个是真正的原因
4. **记录**：把排查过程写进 [[95-Bugs-踩坑日志/moc-踩坑日志目录]]，下次遇到类似的不用重来