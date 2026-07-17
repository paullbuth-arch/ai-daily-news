---
type: concept
tags: [embedded, build-system, scons, makefile, cmake, wq7036a]
aliases: [构建系统, SCons, Makefile, CMake]
---

# 构建系统：Makefile / SCons / CMake

## 一句话结论

构建系统是"自动化编译脚本"——你告诉它哪些文件编译成什么目标、依赖关系是什么，它帮你处理增量编译、链接顺序、工具链参数。每次只编译改过的文件，不用全量重编。WQ7036AX SDK 使用 SCons（Python 语法），不是 Makefile。

## 30秒先看懂

- 构建系统自动判断哪些源文件需要重新编译：比较 .c 和 .o 的时间戳，.c 更新则重新编译。头文件依赖也会追踪——如果 .h 改了，所有包含它的 .c 都会重编。WQ7036AX SDK 的构建入口是 `wq-audio/wqcore/tools/SCons/`，核心类是 `WQEnvironment`，每个组件目录自动扫描成 `WQModule`。链接脚本（.ld 文件）决定代码和数据在 Flash/RAM 中的地址布局。日常开发 90% 只需要 `./build.sh --chip=7036AX --config-file=defconfig.stereo.i2s` 这一个命令。

## 学完以后应该能做什么

**第一遍看完后可以：**
- 在 WQ7036AX SDK 中正确执行编译、配置、打包、清理操作
- 理解 `./build.sh` 和 `scons` 命令的区别和适用场景
- 看懂编译报错信息，定位到具体文件和行号
- 添加新文件时知道不需要修改构建脚本（SCons 自动扫描）

**进阶后可以：**
- 阅读和修改 `WQEnvironment` 的构建逻辑
- 添加新的 Kconfig 配置项，控制组件的条件编译
- 编写链接脚本，自定义内存布局
- 搭建 CI/CD 构建流水线，自动编译和打包固件

## 前置知识

- C 语言编译流程：预处理 → 编译 → 汇编 → 链接
- 环境变量概念（PATH、WQCOREROOT）
- 基本的命令行操作

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 构建系统 | Build System | 自动化编译、链接、打包的工具链 |
| 增量编译 | Incremental Build | 只重新编译修改过的源文件，未改的直接复用 |
| 目标文件 | Object File (.o) | 源文件编译后的中间产物，尚未链接 |
| 链接脚本 | Linker Script (.ld) | 描述代码段和数据段在内存中的地址布局 |
| 工具链 | Toolchain | 编译器、汇编器、链接器、调试器的集合 |
| 配置 | Kconfig / defconfig | 通过菜单或配置文件选择芯片、功能、参数 |
| 模块 | WQModule | SDK 中一个功能组件的构建单元，包含源文件、头文件路径、依赖 |
| 依赖追踪 | Dependency Tracking | 跟踪头文件包含关系，头文件变更自动触发相关源文件重编 |

## 第一层：费曼心智模型

### 类比：建筑工地的工头

没有构建系统 = 你自己一个个叫工人干活：
"张三，你把 brick.c 搬去烧"
"李四，等张三烧完，你把 brick.o 和 cement.o 拼起来"
"王五，等李四拼完，把成品搬到仓库"

有构建系统 = 你给工头一张图纸（Makefile/SConscript），工头自动安排：
- 哪些文件改了需要重新编译（增量编译）
- 哪些文件依赖哪些文件（编译顺序）
- 用什么工具、什么参数（工具链配置）

**边界：**
- 构建系统不保证代码正确——它只保证编译过程正确
- 增量编译依赖时间戳，如果系统时间错乱可能导致误判
- 并行编译（-jN）可能暴露未正确声明的依赖关系

### 场景演练：修改一个头文件

1. 你修改了 `gpio.h`，增加了新的 GPIO 控制函数声明
2. 执行 `scons -j4`
3. SCons 发现 `gpio.h` 的时间戳变了
4. SCons 检查所有包含 `gpio.h` 的 .c 文件（通过 .d 依赖文件）
5. 所有包含 `gpio.h` 的 .c 文件重新编译
6. 链接器合并新的 .o 文件，生成新的 .elf

## 第二层：原理/时序/约束

### 增量编译的时序

```
t0: 编译 main.c → main.o (时间戳: 10:00)
t1: 编译 uart.c → uart.o (时间戳: 10:01)
t2: 链接 main.o + uart.o → app.elf (时间戳: 10:02)
t3: 修改 main.c (时间戳: 10:05)
t4: 执行 scons
    → 比较 main.c (10:05) 和 main.o (10:00): main.c 更新 → 重新编译 main.c
    → 比较 uart.c (10:01) 和 uart.o (10:01): 没变 → 跳过
    → 重新链接 app.elf
```

### WQ7036AX 构建流程

```python
# SConstruct（每个 example 的根构建脚本）
env = WQEnvironment(coreroot, project_path, extcomps=adk_components_path)
# WQEnvironment 会：
# 1. 解析命令行参数（--chip, --config-file 等）
# 2. 加载 Kconfig 配置 → 生成 wqconfig.h
# 3. 安装工具链（RISC-V GCC / Xtensa GCC）
# 4. 扫描所有组件（components/）
# 5. 为每个 core（acore/bcore/dcore）构建

DoBuild(env)  # 执行构建
```

### 构建输出

```
build/
  acore/       # <name>_acore.elf, .bin, .asm, .map, .mem, .info, .log
  bcore/       # <name>_bcore.elf, .bin, ...
  dcore/       # <name>_dcore.elf, .bin, ...
  memory_config.json   # Flash 分区地址和大小
  dbglog_table.txt     # 调试日志 ID 符号表
  <name>-<version>.wpk # 最终固件包（ZIP 格式）
```

## 第三层：真实 SDK 代码

### WQEnvironment 核心类

构建系统的核心在 `/home/ys/wq7036a/wq-audio/wqcore/tools/SCons/wq_environment.py`：

```python
# WQEnvironment 初始化流程
class WQEnvironment:
    def __init__(self, coreroot, project_path, extcomps=None):
        self.coreroot = coreroot           # wqcore 根路径
        self.project_path = project_path    # example 路径
        self.extcomps = extcomps or []      # 追加组件（如 wq-adk/components）
        self._parse_options()              # 解析命令行参数
        self._load_config()                # 加载 Kconfig
        self._setup_toolchain()            # 配置工具链
        self._scan_components()            # 扫描所有组件
```

### WQModule 自动扫描

每个组件被自动扫描为 `WQModule`，参考 `/home/ys/wq7036a/wq-audio/wqcore/tools/SCons/wq_modules.py`：

```python
class WQModule:
    def __init__(self, path, config):
        self.path = path
        self.sources = self._scan_sources()  # 自动扫描 *.c, *.cpp, *.S
        self.public_includes = [os.path.join(path, 'inc')]
        self.private_includes = [path]
        self.config = config  # 根据 Kconfig 决定是否编译
```

### 构建命令示例

```bash
# 配置 + 编译（在 wq-adk/examples/glass/ 下执行）
./build.sh --chip=7036AX --config-file=defconfig.stereo.i2s

# 只编译（不重新配置）
scons -j4

# 生成 compile_commands.json（给 IDE/clangd 用）
scons --compile-database

# 打包固件
./build.sh --chip=7036AX --pack
```

## 第四层：正常/异常路径

### 正常路径

配置加载 → 工具链检测 → 源码扫描 → 增量编译 → 链接 → 打包 → 输出 .wpk

### 异常路径

| 异常场景 | 现象 | 原因 | 处理方式 |
|---------|------|------|---------|
| 工具链找不到 | `riscv64-unknown-elf-gcc: command not found` | PATH 或 WQCORE_TOOLCHAIN_PATH 未设置 | 检查环境变量 |
| 配置冲突 | Kconfig 报错 | 依赖的配置项未开启 | 检查 Kconfig 依赖链 |
| 链接失败 | undefined reference to `xxx` | 缺少源文件或库未链接 | 检查组件依赖 |
| 增量编译不生效 | 改了代码但编译结果没变 | 时间戳错乱或 .d 依赖文件过期 | 执行 `scons -c` 清理后重编 |
| Flash 空间不足 | 链接脚本 region overflow | 代码或数据超过分区大小 | 优化代码或调整分区 |

## 第五层：调试方法

### 编译问题定位

```bash
# 查看详细编译日志
cat build/acore/*.log

# 查看链接脚本
cat build/acore/*.map  # 内存映射

# 查看各段大小
riscv64-unknown-elf-size build/acore/app_acore.elf

# 查看符号表
riscv64-unknown-elf-nm build/acore/app_acore.elf | grep my_function

# 反汇编特定函数
riscv64-unknown-elf-objdump -d build/acore/app_acore.elf | grep -A50 '<my_function>:'
```

### 配置问题定位

```bash
# 查看最终生效的配置
cat build/sdkconfig

# 查看生成的配置头文件
cat build/wqconfig.h | grep CONFIG_MY_FEATURE

# 查看 Kconfig 依赖树
./build.sh --chip=7036AX --config
# 在 menuconfig 界面中按 '/' 搜索配置项
```

## 第六层：实战练习

### 练习 1：完整构建流程（基础）

从零开始完成 WQ7036AX 的 TWS 示例项目构建：
1. 设置环境变量（WQCOREROOT、PATH）
2. 进入 `wq-adk/examples/tws/` 目录
3. 执行 `./build.sh --chip=7036AX --config-file=defconfig.pro`
4. 查看 `build/` 目录下的输出文件
5. 执行 `scons -c` 清理，然后重新编译

### 练习 2：自定义构建配置（进阶）

新建一个自定义配置，只开启最小编译选项：
1. 复制 `defconfig.basic` 为 `defconfig.custom`
2. 修改 `defconfig.custom`，关闭不需要的功能
3. 用 `./build.sh --chip=7036AX --config-file=defconfig.custom` 编译
4. 对比 `defconfig.pro` 和 `defconfig.custom` 生成的固件大小

### 练习 3：阅读真实源码（深入）

阅读 `/home/ys/wq7036a/wq-audio/wqcore/tools/SCons/wq_environment.py`，回答：
1. `_parse_options()` 解析了哪些命令行参数？
2. `_load_config()` 如何加载 Kconfig 并生成 `wqconfig.h`？
3. 多核构建（acore/bcore/dcore）是如何并行执行的？
4. 组件扫描（`_scan_components`）的路径规则是什么？

## 自测与验收

1. 增量编译的原理是什么？如何判断一个源文件是否需要重新编译？
2. WQ7036AX SDK 使用的是什么构建系统？为什么选择它而不是 Makefile？
3. `./build.sh` 和直接 `scons` 有什么区别？
4. 链接脚本（.ld 文件）的作用是什么？
5. 如果修改了一个头文件，但编译时没有重编包含它的 .c 文件，可能是什么原因？
6. 什么是 Kconfig？它是如何控制组件的条件编译的？
7. 如何查看编译后的固件中各个段（.text/.data/.bss）的大小？

## 延伸阅读

- [[compile-link-startup-编译链接与启动流程]] — 编译链接的详细四步流程
- [[boot-ota-启动流程与OTA升级]] — 固件是怎么打包和升级的
- [[c-core-C语言核心]] — 编译期和运行时的内存布局

## #flashcard

**Q: 增量编译的核心判断依据是什么？**
A: 比较源文件（.c）和目标文件（.o）的时间戳，源文件更新则重新编译。

**Q: WQ7036AX 使用的构建系统是什么？**
A: SCons（Python 语法），不是 Makefile。

**Q: WQModule 是什么？**
A: SDK 中一个功能组件的构建单元，自动扫描 *.c/*.cpp/*.S 文件，管理 include 路径。

**Q: 头文件改了为什么相关 .c 文件也要重编？**
A: 因为头文件中可能包含宏定义、函数声明、结构体定义，这些变化会影响 .c 文件的编译结果。