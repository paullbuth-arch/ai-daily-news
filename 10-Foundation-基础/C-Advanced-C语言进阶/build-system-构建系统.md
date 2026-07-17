# 构建系统：Makefile / SCons / CMake

**一句话结论（20% 核心）**：构建系统就是"自动化编译脚本"——你告诉它哪些文件编译成什么目标、依赖关系是什么，它帮你处理增量编译、链接顺序、工具链参数。每次只编译改过的文件，不用全量重编。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：建筑工地的工头

没有构建系统 = 你自己一个个叫工人干活：
```
"张三，你把 brick.c 搬去烧"
"李四，等张三烧完，你把 brick.o 和 cement.o 拼起来"
"王五，等李四拼完，把成品搬到仓库"
```

有构建系统 = 你给工头一张图纸（Makefile/SConscript），工头自动安排：
- 哪些文件改了需要重新编译（增量编译）
- 哪些文件依赖哪些文件（编译顺序）
- 用什么工具、什么参数（工具链配置）

**WQ7036AX SDK 用 SCons**（Python 语法的构建系统），不是 Makefile。这是理解 SDK 构建流程的前提。

### 1.2 三种构建系统对比

| 构建系统 | 语法 | 哪里用 | 特点 |
|----------|------|--------|------|
| **Make** | Makefile（自定义语法） | Linux 内核、U-Boot | 最古老，最通用，语法难读 |
| **SCons** | Python | WQ7036AX SDK | 用 Python 写构建规则，灵活但慢 |
| **CMake** | CMakeLists.txt | Android、大项目 | 生成 Makefile/Ninja，现代标准 |

### 1.3 构建的核心概念

```
源文件 (.c/.cpp/.S)
    │
    ├── 编译 (gcc -c) → 目标文件 (.o)
    │                        │
    └─────────────────────────┤
                            链接 (ld) → 可执行文件 (ELF/BIN)
```

**增量编译**：构建系统比较 .c 和 .o 的时间戳。如果 .c 比 .o 新（改过），就重新编译这个文件。其他没改的 .o 直接复用。

**依赖关系**：如果 `a.h` 被 `b.c` 包含，那么 `a.h` 改了，`b.c` 也要重新编译。构建系统自动追踪这些依赖。

### 1.4 如果只记得一件事

> 构建系统 = 自动化编译脚本。Makefile 用自定义语法，SCons 用 Python（WQ7036AX 用它），CMake 是现代标准。核心能力：增量编译（只编译改过的文件）+ 依赖管理（头文件改了自动重编）。

---

## 第二层：实战理解

### 2.1 WQ7036AX 的 SCons 构建流程

SDK 的构建入口在 `wq-audio/wqcore/tools/SCons/`，核心类是 `WQEnvironment`：

```python
# SConstruct（每个 example 的根构建脚本）
env = WQEnvironment(coreroot, project_path, extcomps=adk_components_path)
# WQEnvironment 会：
# 1. 解析命令行参数（--chip, --config-file 等）
# 2. 加载 Kconfig 配置
# 3. 安装工具链（RISC-V GCC / Xtensa GCC）
# 4. 扫描所有组件（components/）
# 5. 为每个 core（acore/bcore/dcore）构建

DoBuild(env)  # 执行构建
```

每个组件目录自动被扫描成 `WQModule`：
```python
# 自动扫描 *.c, *.cpp, *.S 文件
# 自动管理 public/private include 路径
# 根据 Kconfig 自动决定是否编译这个组件
```

### 2.2 常用构建命令

```bash
# 在 wq-adk/examples/glass/ 下：

# 配置 + 编译
./build.sh --chip=7036AX --config-file=defconfig.stereo.i2s

# 只编译（不重新配置）
scons -j4

# 清理
scons -c

# 生成 compile_commands.json（给 IDE/clangd 用）
scons --compile-database

# 打包固件
./build.sh --chip=7036AX --pack
```

### 2.3 Makefile 最小示例

```makefile
# 变量定义
CC = riscv64-unknown-elf-gcc
CFLAGS = -O2 -Wall -march=rv32imac

# 目标: 依赖
# ↓ Tab 缩进的命令
app.elf: main.o uart.o
	$(CC) $(CFLAGS) -o app.elf main.o uart.o

main.o: main.c app.h
	$(CC) $(CFLAGS) -c main.c

uart.o: uart.c uart.h
	$(CC) $(CFLAGS) -c uart.c

# 伪目标
clean:
	rm -f *.o *.elf
```

**关键规则**：`目标: 依赖` → 如果依赖比目标新，执行下面的命令。

### 2.4 常见坑

| 问题 | 现象 | 根因 |
|------|------|------|
| 改了头文件没重编 | 奇怪的行为 | 头文件没写在依赖里 |
| 并行编译出错 | 链接时找不到符号 | 依赖顺序不对，缺少依赖声明 |
| 环境变量没设 | scons 找不到工具链 | `WQCOREROOT` 或 `PATH` 为空 |
| 增量编译出错 | 改了代码没生效 | 时间戳混乱，先 `scons -c` 清理 |

### 2.5 在 WQ7036AX 项目中怎么用

日常开发 90% 的时候只需要 `./build.sh --chip=7036AX --config-file=defconfig.stereo.i2s`。但遇到以下情况需要理解构建系统：

1. **加新文件**：SCons 自动扫描 `*.c`，不需要改构建脚本
2. **加新组件**：在 `Kconfig.in` 里加配置项，SCons 根据 Kconfig 决定是否编译
3. **编译失败排查**：看 `build/acore/*.log` 里的编译命令
4. **切换芯片**：改 `--chip=` 参数，构建系统自动切换工具链

---

## 第三层：深入扩展

### 3.1 链接脚本的作用

链接脚本（`.ld` 文件）告诉链接器：代码放 Flash 哪个地址，数据放 RAM 哪个地址。WQ7036AX 每个 core 有独立的 `.ld` 文件。

```ld
MEMORY {
    FLASH (rx)  : ORIGIN = 0x00000000, LENGTH = 512K
    SRAM  (rwx) : ORIGIN = 0x20000000, LENGTH = 128K
}
```

### 3.2 常见问题

- **Makefile 和 CMake 的区别？** Make 是构建工具，CMake 是构建系统生成器（生成 Makefile 或 Ninja）。
- **为什么 WQ7036AX 用 SCons 而不是 Make？** SCons 用 Python 语法，更灵活；Kconfig 集成方便；自动依赖分析。
- **增量编译的原理？** 比较源文件和目标文件的时间戳，源文件更新则重新编译。

### 3.3 延伸阅读

- [[compile-link-startup-编译链接与启动流程]] — 编译链接的详细四步流程
- [[boot-ota-启动流程与OTA升级]] — 固件是怎么打包和升级的