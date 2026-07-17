# 汇编基础（嵌入式视角）

**一句话结论（20% 核心）**：汇编是 CPU 唯一能听懂的语言。嵌入式工程师不需要写汇编，但需要能**看懂**——启动代码、中断上下文切换、crash 时的栈回溯，全是汇编。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：C 是点菜，汇编是后厨操作

C 语言：「给我做一盘宫保鸡丁」（编译器翻译成几百条汇编指令）

汇编：「打开冰箱 → 拿出鸡胸肉 → 放在案板上 → 切成 2cm 块 → ...」

每条汇编指令只做一件事：读一个寄存器、做一个运算、写一个地址。

### 1.2 嵌入式里什么时候必须看汇编？

| 场景 | 为什么 |
|------|--------|
| **启动代码**（startup.S） | 芯片上电后第一条指令就是汇编，初始化栈、搬数据段 |
| **上下文切换** | 保存/恢复所有寄存器，C 语言做不到 |
| **HardFault 排查** | 异常发生后，栈帧里存的是寄存器的值，需要用汇编解读 |
| **极致优化** | DSP 算法中，汇编手写的关键循环比 C 快 5-10 倍 |

### 1.3 RISC-V 汇编 5 分钟速览

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

### 1.4 如果只记得一件事

> 汇编 = CPU 的原生语言。嵌入式工程师不需要写，但需要能看懂启动代码和 crash 栈帧。WQ7036AX 的 ACORE/BCORE 用 RISC-V 汇编，DCORE 用 Xtensa 汇编。

---

## 第二层：实战理解

### 2.1 启动代码里最关键的汇编

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

### 2.2 怎么从 crash 地址定位代码

```bash
# 当 HardFault 发生时，从栈帧读出异常 PC（程序计数器）
# 然后用 objdump 反汇编查找对应地址

riscv64-unknown-elf-objdump -d app.elf | grep -A5 "异常地址"
# 输出：异常地址对应的汇编指令和所在函数
```

### 2.3 在 WQ7036AX 项目中怎么用

启动代码在 `wqcore/components/startup/boot/` 下，每个 core 有独立的 `startup_*.S`。遇到"程序一启动就 crash"或"全局变量初值不对"时，回来看启动汇编。

---

## 第三层：延伸阅读

- [[compile-link-startup-编译链接与启动流程]] — 上电到 main() 的完整链路
- [[debug-methodology-嵌入式调试方法论]] — HardFault 排查流程