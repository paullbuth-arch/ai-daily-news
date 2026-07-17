---
type: concept
tags: [embedded, assembly, riscv, xtensa, startup, debugging]
aliases: [汇编基础, RISC-V汇编, 启动代码]
---

# 汇编基础（嵌入式视角）

## 一句话结论

汇编是 CPU 唯一能听懂的语言。嵌入式工程师不需要写汇编，但需要能**看懂**——启动代码、中断上下文切换、crash 时的栈回溯，全是汇编。

## 30秒先看懂

- 汇编指令是 CPU 原生指令，每条只做一件事：读寄存器、做运算、写内存。C 语言编译器把高级代码翻译成汇编指令，你不需要写汇编，但需要能看懂启动代码和崩溃栈帧。WQ7036AX 的 ACORE/BCORE 使用 RISC-V 汇编，DCORE 使用 Xtensa 汇编，两种架构的指令集不同。汇编调试最常见的场景是 HardFault 排查——从栈帧中提取 PC 寄存器值，用 objdump 反汇编定位到具体的 C 代码行。

## 学完以后应该能做什么

**第一遍看完后可以：**
- 看懂 RISC-V 启动代码（startup.S）的基本流程
- 在 HardFault 发生时，从栈帧中提取关键寄存器值
- 使用 objdump 反汇编查找崩溃地址对应的函数
- 理解栈指针（SP）、返回地址（RA）、程序计数器（PC）的作用

**进阶后可以：**
- 编写中断上下文切换代码（保存/恢复寄存器）
- 手写 DSP 算法中的关键循环（Xtensa 汇编）
- 修改启动代码适配新芯片
- 分析编译器生成的汇编代码，进行极致优化

## 前置知识

- C 语言函数调用约定（参数传递、返回值）
- 栈的概念（压栈、出栈、栈帧）
- 编译链接流程（.c → .o → .elf）

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 程序计数器 | PC / Program Counter | 存放下一条要执行指令的地址 |
| 栈指针 | SP / Stack Pointer | 指向当前栈顶的寄存器 |
| 返回地址 | RA / Return Address | 函数返回后继续执行的地址 |
| 通用寄存器 | General Purpose Register | CPU 内部的通用存储单元（RISC-V 有 32 个） |
| 栈帧 | Stack Frame | 函数调用时在栈上分配的空间，存局部变量和返回地址 |
| 指令集 | Instruction Set | CPU 认识的所有指令的集合 |
| 伪指令 | Pseudo-instruction | 汇编器提供的简化写法，实际会展开成多条真实指令 |
| 反汇编 | Disassembly | 把机器码翻译回汇编指令的过程 |

## 第一层：费曼心智模型

### 类比：C 是点菜，汇编是后厨操作

C 语言：「给我做一盘宫保鸡丁」（编译器翻译成几百条汇编指令）

汇编：「打开冰箱 → 拿出鸡胸肉 → 放在案板上 → 切成 2cm 块 → ...」

每条汇编指令只做一件事：读一个寄存器、做一个运算、写一个地址。

**边界：**
- 汇编是 CPU 相关的——RISC-V 的汇编不能用在 ARM 上，Xtensa 的汇编不能用在 RISC-V 上
- 不需要背指令集——只需要知道常用指令（ld/add/beq/jal）和怎么看懂
- 现代编译器优化后的汇编代码不易读，调试时用 `-O0` 编译

### 场景演练：HardFault 排查

1. 程序崩溃，停在 HardFault_Handler
2. 在 GDB 中执行 `backtrace` 查看调用链
3. 看到崩溃发生在 `memcpy` 函数中
4. 执行 `frame 3` 切换到调用 `memcpy` 的函数
5. 查看局部变量，发现 `buf` 是空指针（`buf = 0x0`）
6. 定位到调用者传入了空指针——这就是 bug 所在

## 第二层：原理/时序/约束

### RISC-V 汇编 5 分钟速览

```asm
# RISC-V 汇编（WQ7036AX 的 ACORE/BCORE 用这个）

# 寄存器：x0-x31，常用别名：
# x0(zero)=0, x1(ra)=返回地址, x2(sp)=栈指针, x10-x17(a0-a7)=函数参数

lw   a0, 0(sp)       # 从栈上加载 4 字节到 a0（Load Word）
sw   a1, 4(sp)       # 把 a1 存到栈上（Store Word）
addi a0, a0, 1       # a0 = a0 + 1（立即数加法）
beq  a0, a1, label   # 如果 a0 == a1，跳转到 label
jal  ra, function    # 调用函数，返回地址存到 ra
ret                   # 返回（伪指令，实际是 jalr zero, ra, 0）
```

### 启动代码的核心汇编

```asm
# WQ7036AX 启动代码的核心部分（简化）
.section .text.init
.global _start
_start:
    la   sp, _stack_top      # ① 初始化栈指针（没有栈，C 函数无法调用）
    la   a0, _data_lma       # ② 拷贝 .data 段
    la   a1, _sdata
    la   a2, _edata
copy_loop:
    bge  a1, a2, copy_done
    lw   a3, 0(a0)
    sw   a3, 0(a1)
    addi a0, a0, 4
    addi a1, a1, 4
    j    copy_loop
copy_done:
    la   a0, _sbss           # ③ 清零 .bss 段
    la   a1, _ebss
clear_loop:
    bge  a0, a1, clear_done
    sw   zero, 0(a0)
    addi a0, a0, 4
    j    clear_loop
clear_done:
    call main                # ④ 终于进入 C 语言世界
```

### 中断上下文切换

```asm
# 中断发生时保存上下文
interrupt_handler:
    # 保存所有寄存器到当前任务的栈上
    sw   ra,  -1*4(sp)
    sw   gp,  -2*4(sp)
    sw   tp,  -3*4(sp)
    sw   t0,  -4*4(sp)
    # ... 保存所有被调用者保存的寄存器 ...
    addi sp, sp, -CONTEXT_SIZE

    # 调用 C 语言的中断处理函数
    call c_interrupt_handler

    # 恢复上下文
    # ... 反向加载寄存器 ...
    addi sp, sp, CONTEXT_SIZE
    lw   ra,  -1*4(sp)
    mret  # 返回中断前的程序
```

## 第三层：真实 SDK 代码

### 启动代码位置

WQ7036AX 的启动代码在 `/home/ys/wq7036a/wq-audio/wqcore/components/startup/` 下，每个 core 有独立的 `startup_*.S` 文件：

```
startup/
  boot/          # 通用启动代码
    src/         # 启动源码
    inc/         # 启动头文件
  bbb/           # 7036A/X 系列
    acore/       # ACORE 启动代码
    bcore/       # BCORE 启动代码
    dcore/       # DCORE 启动代码（Xtensa 汇编）
```

### 栈回溯分析

```bash
# 从 crashdump 分析崩溃位置
riscv64-unknown-elf-objdump -d build/acore/app_acore.elf | grep -A5 "崩溃地址"

# 查看符号表，找到地址对应的函数名
riscv64-unknown-elf-nm build/acore/app_acore.elf | grep "崩溃地址"

# 查看栈帧布局
riscv64-unknown-elf-objdump -d build/acore/app_acore.elf | grep -A20 "<my_function>:"
```

### 复位原因分析

参考 `/home/ys/wq7036a/wq-audio/wqcore/components/startup/boot/src/boot_reason.c`，启动时读取复位原因寄存器：

```c
// 复位原因寄存器
uint32_t reason = read_reset_reason();
if (reason & RESET_REASON_WDT) {
    printf("Previous reset: Watchdog timeout\n");
} else if (reason & RESET_REASON_BOR) {
    printf("Previous reset: Brown-out (voltage drop)\n");
}
```

## 第四层：正常/异常路径

### 正常路径

_start → 初始化 SP → 拷贝 .data → 清零 .bss → 配置中断向量表 → call main

### 异常路径

| 异常场景 | 现象 | 原因 | 处理方式 |
|---------|------|------|---------|
| SP 未初始化 | 函数调用崩溃 | 启动代码中 `la sp` 指令未执行或地址错误 | 检查链接脚本中 _stack_top 定义 |
| .data 拷贝地址错误 | 全局变量初值不对 | 拷贝源地址（LMA）或目标地址（VMA）错误 | 检查链接脚本的段地址 |
| 中断向量表未对齐 | 中断不触发或跳错 | 向量表地址未按对齐要求放置 | 检查链接脚本的对齐属性 |
| 栈溢出 | 变量被意外覆盖 | 栈向下增长覆盖了堆或全局变量 | 增大栈空间或检查递归深度 |

## 第五层：调试方法

### 从 crash 地址定位代码

```bash
# 方法 1：用 objdump 反汇编查找
riscv64-unknown-elf-objdump -d build/acore/app_acore.elf | grep -A5 "异常地址"

# 方法 2：用 addr2line 直接定位到源代码行
riscv64-unknown-elf-addr2line -e build/acore/app_acore.elf -f 异常地址

# 方法 3：用 GDB 查看崩溃位置
(gdb) target remote :3333
(gdb) monitor reset halt
(gdb) load
(gdb) continue
# 等待崩溃后：
(gdb) backtrace
(gdb) info registers
(gdb) x/10x $sp  # 查看栈内容
```

### 汇编级别调试

```gdb
# 单步执行汇编指令
(gdb) stepi          # 执行一条汇编指令
(gdb) display/5i $pc  # 每次暂停时显示 PC 附近的 5 条指令
(gdb) info registers  # 查看所有寄存器

# 查看栈回溯
(gdb) backtrace full  # 带局部变量的栈回溯
(gdb) frame 3         # 切换到第 3 帧
```

## 第六层：实战练习

### 练习 1：分析崩溃栈帧（基础）

用 GDB 模拟一个空指针解引用的崩溃，然后：
1. 执行 `backtrace` 查看调用链
2. 执行 `info registers` 查看 PC 寄存器的值
3. 用 `objdump` 反汇编找到 PC 地址对应的代码
4. 确定崩溃发生在哪个函数、哪一行

### 练习 2：阅读启动代码（进阶）

阅读 `/home/ys/wq7036a/wq-audio/wqcore/components/startup/` 下的启动汇编代码，回答：
1. 启动代码中有多少个汇编写成的循环？
2. 每个循环的作用是什么？
3. 中断向量表是如何初始化的？
4. 在进入 main() 之前，CPU 处于什么特权级？

### 练习 3：反汇编分析（深入）

编译一个简单的 C 函数，然后反汇编分析：
```c
int add(int a, int b) {
    return a + b;
}
```
1. 用 `riscv64-unknown-elf-gcc -O2 -c add.c -S` 生成汇编
2. 分析生成的汇编代码，找到参数传递的寄存器
3. 找到返回值的存放位置
4. 对比 `-O0` 和 `-O2` 生成的汇编差异

## 自测与验收

1. RISC-V 中 `ra` 寄存器的作用是什么？在函数调用时谁负责保存它？
2. 启动代码中为什么要先初始化栈指针（SP）再调用 C 函数？
3. .data 段为什么要从 Flash 拷贝到 SRAM？.bss 段为什么要清零？
4. HardFault 发生后，如何从栈帧中提取崩溃时的 PC 值？
5. `objdump -d` 和 `addr2line` 分别用来做什么？
6. RISC-V 的函数参数传递规则是什么？前几个参数放在哪个寄存器？
7. 编译优化（`-O2`）对调试有什么影响？如何解决"优化后变量不可见"的问题？

## 延伸阅读

- [[compile-link-startup-编译链接与启动流程]] — 上电到 main() 的完整链路
- [[debug-methodology-嵌入式调试方法论]] — HardFault 排查流程
- [[gdb-ftrace-GDB与ftrace]] — GDB 远程调试详细用法

## #flashcard

**Q: 嵌入式工程师什么时候必须看汇编？**
A: 启动代码（startup.S）、中断上下文切换、HardFault 排查、极致优化。

**Q: RISC-V 中 x1 寄存器的别名是什么？作用是什么？**
A: ra（Return Address），保存函数调用的返回地址。

**Q: 启动代码中初始化 SP 的作用？**
A: 没有 SP，C 函数无法调用（函数调用需要在栈上分配局部变量和保存返回地址）。

**Q: 如何从 crash 地址定位到 C 代码行？**
A: 用 `riscv64-unknown-elf-addr2line -e app.elf -f 崩溃地址`。

**Q: WQ7036AX 各核的汇编架构是什么？**
A: ACORE/BCORE 用 RISC-V 汇编，DCORE 用 Xtensa 汇编。