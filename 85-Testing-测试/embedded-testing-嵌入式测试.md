---
type: concept
created: 2026-07-17
tags: [testing, embedded, unit-test, integration-test, hil, 测试]
aliases: [嵌入式测试, Embedded Testing, 单元测试, 测试金字塔]
---

# 嵌入式测试

## 一句话结论

嵌入式测试比 PC 软件测试难——没有屏幕、资源有限、硬件依赖，解决方案是分层测试：单元测试（PC 上测纯逻辑，用 Unity 框架）、集成测试（开发板上测模块交互）、硬件在环测试（真实硬件+模拟环境）。核心思路是**把纯逻辑和硬件操作分离**，纯逻辑在 PC 上编译运行测试，硬件操作通过 mock 替换。WQ7036AX SDK 目前没有正式单元测试框架，建议从协议解析、环形缓冲区、CRC 校验等纯逻辑模块开始补充测试。

## 30秒先看懂

- 嵌入式测试金字塔：底层单元测试要最多（PC 上跑，便宜且快），顶层硬件在环最少（真实硬件，贵且慢）。
- 测试的关键设计模式：将硬件操作抽象成接口（函数指针或 HAL 层），测试时用 mock 实现替换真实硬件操作。
- Unity 是嵌入式 C 项目最常用的单元测试框架，仅 3 个源文件，极轻量，可在 PC 上编译运行。
- 值得测试的模块：协议解析状态机、数据校验算法、编解码逻辑、业务逻辑判断、环形缓冲区。不值得测试的：硬件寄存器操作、简单 getter/setter、初始化代码、延时函数。
- 嵌入式项目 60-70% 行覆盖率就很好了，不需要追求 90%+，因为 30% 的代码是硬件寄存器操作，在 PC 上无法测试。

## 学完以后应该能做什么

### 第一遍
- 使用 Unity 框架在 PC 上为 C 语言模块编写和运行单元测试
- 将硬件操作抽象成接口，使代码可测试
- 判断哪些模块值得写测试、哪些不值得

### 进阶
- 使用 CMock 自动生成 mock 函数，提高测试编写效率
- 设计双目标编译（Dual Targeting），同一份代码可编译为 PC 版本和嵌入式版本
- 在 CI（GitHub Actions/Jenkins）中集成测试运行

## 前置知识

- [[debug-methodology-嵌入式调试方法论]]：测试和调试的互补关系
- [[c-core-C语言核心]]：函数指针、条件编译、头文件管理
- [[data-structure-state-machine-数据结构与状态机]]：状态机是最值得测试的模式

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 单元测试 | Unit Test | 测试单个函数或模块的行为，不依赖外部硬件 |
| 集成测试 | Integration Test | 测试多个模块组合后的交互，通常需要真实硬件 |
| 硬件在环测试 | HIL (Hardware-In-the-Loop) | 真实硬件 + 模拟外部环境的测试方式 |
| 测试桩 | Mock / Stub | 模拟真实模块行为的替代实现，用于隔离被测试代码 |
| 测试覆盖率 | Test Coverage | 被测试代码覆盖的代码行数的百分比 |
| 双目标编译 | Dual Targeting | 同一份代码可编译为两个目标平台（PC 和嵌入式） |
| 测试驱动开发 | TDD (Test-Driven Development) | 先写测试再写代码的开发方式 |
| 回归测试 | Regression Test | 修改代码后运行已有测试，确保没破坏旧功能 |
| 持续集成 | CI (Continuous Integration) | 代码变更后自动构建和测试的流程 |

## 第一层费曼心智模型

### 类比：造汽车的质量检测

嵌入式测试就像造汽车的质量检测，分不同层次：

- **单元测试** = 检测每个零件：发动机单独测试马力、刹车单独测试制动力、轮胎单独测试耐磨性。在零件生产线上就测，不需要整车。
- **集成测试** = 检测零件组装后是否配合：发动机+变速箱装在一起，看能否正常换挡。在台架上测，不需要上路。
- **硬件在环（HIL）** = 上路测试，但用电脑模拟危险场景：在实验室里用电脑发送"前方有障碍物"信号，看自动刹车是否响应。不需要真的开到路上。

### 边界

- 单元测试不能替代硬件测试——单元测试保证逻辑正确，但不能保证时序正确、中断正确、DMA 正确。
- 测试覆盖率不是越高越好——嵌入式项目中 30% 的代码是硬件寄存器操作，在 PC 上无法测试。
- 并不是所有代码都需要测试——简单 getter/setter 的测试 ROI 很低。
- 写测试本身也有成本——需要评估测试的维护成本和 bug 发现收益。

### 场景推演

**场景：WQ Protocol 协议解析模块**

1. 协议解析函数 `wq_protocol_unpack()` 接收原始字节流，解析出帧头、长度、负载、校验和
2. 这是一个纯逻辑函数——输入是字节数组，输出是结构体，不依赖任何硬件
3. 在 PC 上写单元测试：
   - 输入正常帧 → 验证解析出正确的字段值
   - 输入长度错误的帧 → 验证返回 -1（错误码）
   - 输入校验和错误的帧 → 验证返回 -2（校验失败）
   - 输入空指针 → 验证返回 -3（参数错误）
4. 测试覆盖了所有边界情况，可以通过 CI 自动运行
5. 以后修改协议解析逻辑时，运行测试确保没有破坏已有功能

## 第二层原理/时序/约束

### 测试金字塔

```
         ┌──────────────────────┐
         │  硬件在环 (HIL)       │  ← 最贵，最真实，最难自动化
         │  需要真实硬件+模拟环境 │
         ├──────────────────────┤
         │  集成测试              │  ← 需要真实硬件或模拟器
         │  测模块间交互          │
         ├──────────────────────┤
         │  单元测试              │  ← 最便宜，最快，最容易自动化
         │  测单个函数/模块       │  ← 应该最多（80%）
         └──────────────────────┘
```

**测试金字塔原则**：底层（单元测试）应该最多，顶层（HIL）应该最少。但实际上很多嵌入式项目正好反过来——几乎没有单元测试，全靠在板子上手动测。

### 嵌入式测试框架对比

| 框架 | 语言 | 运行位置 | 特点 | 适合场景 |
|------|------|---------|------|---------|
| **Unity** | C | PC | 3 个文件，极轻量 | MCU 固件纯逻辑 |
| **CppUTest** | C/C++ | PC | 支持 mock，内存泄漏检测 | 有 C++ 的嵌入式项目 |
| **CMock** | C | PC | 自动生成 mock 函数 | 需要 mock 硬件接口 |
| **Google Test** | C++ | PC | 功能全面，社区大 | Linux 应用层 |
| **Ceedling** | C | PC | Unity+CMock 的打包工具 | 快速搭建测试环境 |

### 代码可测试性改造

**改造前（不可测试）**：
```c
// 协议解析直接依赖硬件 UART 读取
int parse_packet(void) {
    uint8_t byte = UART_DR;  // 直接读硬件寄存器！
    // 状态机处理...
}
```

**改造后（可测试）**：
```c
// 把硬件操作抽象成接口
typedef struct {
    int (*read_byte)(uint8_t *byte);   // 函数指针
    int (*write_byte)(uint8_t byte);
} hal_uart_t;

// 协议解析不再依赖硬件
int parse_packet(hal_uart_t *uart) {
    uint8_t byte;
    if (uart->read_byte(&byte) != 0) return -1;
    // 状态机处理...
}

// 测试时：提供 mock 实现
int mock_read_byte(uint8_t *byte) {
    static uint8_t test_data[] = {0xAA, 0x03, 0x01, 0x02, 0x03, 0x55};
    static int idx = 0;
    *byte = test_data[idx++];
    return 0;
}

void test_parse_packet(void) {
    hal_uart_t mock_uart = { .read_byte = mock_read_byte };
    int result = parse_packet(&mock_uart);
    TEST_ASSERT_EQUAL(0, result);
}
```

### 什么值得测

| 值得测（高 ROI） | 不值得测（低 ROI） |
|-----------------|-------------------|
| 协议解析状态机 | 硬件寄存器操作（`*(volatile *)0x40000000 = val`） |
| 数据校验算法（CRC、checksum） | 简单 getter/setter |
| 编解码逻辑（Opus 帧封装） | 平台相关的初始化代码 |
| 业务逻辑判断（命令路由） | 临界区保护和中断处理（时序依赖） |
| 环形缓冲区操作 | 延时函数（`vTaskDelay`） |
| 状态机转换 | 配置项读取 |

## 第三层真实SDK代码

### Unity 测试框架示例

```c
// test_wq_protocol.c
#include "unity.h"
#include "wq_protocol.h"

// 在每个测试前执行
void setUp(void) {
    // 初始化被测试模块
}

// 在每个测试后执行
void tearDown(void) {
    // 清理
}

// 测试正常帧解析
void test_parse_normal_packet(void) {
    uint8_t input[] = {0xAA, 0x05, 0x01, 0x02, 0x03, 0x04, 0x05, 0x55};
    packet_t pkt;

    int result = wq_protocol_unpack(input, sizeof(input), &pkt);

    TEST_ASSERT_EQUAL(0, result);          // 解析成功
    TEST_ASSERT_EQUAL(0xAA, pkt.header);   // 帧头正确
    TEST_ASSERT_EQUAL(5, pkt.length);      // 长度正确
    TEST_ASSERT_EQUAL(0x55, pkt.checksum); // 校验和正确
}

// 测试空指针输入
void test_parse_null_input(void) {
    int result = wq_protocol_unpack(NULL, 10, NULL);
    TEST_ASSERT_EQUAL(-1, result);  // 返回错误
}

// 测试长度错误
void test_parse_wrong_length(void) {
    uint8_t input[] = {0xAA, 0x00, 0x55};  // 长度字段为 0
    packet_t pkt;

    int result = wq_protocol_unpack(input, sizeof(input), &pkt);
    TEST_ASSERT_EQUAL(-2, result);  // 长度错误
}

// 主函数：运行所有测试
int main(void) {
    UNITY_BEGIN();
    RUN_TEST(test_parse_normal_packet);
    RUN_TEST(test_parse_null_input);
    RUN_TEST(test_parse_wrong_length);
    return UNITY_END();
}
```

### Makefile 集成测试

```makefile
# Makefile 中集成测试目标
CC = gcc
CFLAGS = -Wall -g -DTEST_BUILD
SRC = wq_protocol.c
TEST_SRC = test_wq_protocol.c
UNITY_SRC = unity.c

test: $(SRC) $(TEST_SRC) $(UNITY_SRC)
	$(CC) $(CFLAGS) -o test_runner $^
	./test_runner

# 在 CI 中运行
ci-test: test
	@echo "All tests passed!"
```

### 双目标编译

```makefile
# 同一份代码编译两次
# 1. 目标平台（WQ7036AX）：用 RISC-V GCC
# 2. 测试平台（PC）：用 x86 GCC

# 条件编译隔离硬件相关代码
#ifdef TEST_BUILD
    #include "mock_gpio.h"
#else
    #include "wq_gpio.h"
#endif
```

## 第四层正常/异常路径

### 测试流程

```
正常路径：
  编写测试（先写或后写）→ 编译测试（PC GCC）→ 运行测试 → 全部通过 → 提交代码
异常路径：
  编写测试 → 编译失败 → 修改测试代码
  运行测试 → 测试失败 → 调试被测试代码 → 修复 → 重新运行
  测试通过 → 提交代码
```

### 测试失败原因

| 失败类型 | 原因 | 排查方法 |
|---------|------|---------|
| 编译错误 | 测试代码语法错误或头文件缺失 | 检查 include 路径和语法 |
| 断言失败 | 被测试函数输出与预期不符 | 调试被测试函数，查看中间值 |
| mock 调用不匹配 | 实际调用参数与预期不同 | 检查 mock 的 Expected 设置 |
| 段错误 | 测试代码访问了非法内存 | 检查指针和数组边界 |
| 测试环境不一致 | PC 和嵌入式环境的行为不同 | 检查条件编译和字节序 |

## 第五层调试方法

### 测试覆盖率的计算

```bash
# 使用 gcov 计算测试覆盖率
gcc -fprofile-arcs -ftest-coverage -o test_runner test.c wq_protocol.c
./test_runner
gcov wq_protocol.c

# 查看覆盖率报告
cat wq_protocol.c.gcov
# 每行前面显示执行次数，"#####" 表示从未执行
```

### 测试日志

```c
// 在测试中添加日志，帮助调试失败原因
#include "unity.h"

void test_complex_state_machine(void) {
    // 设置初始状态
    fsm_init(&fsm);

    // 发送事件
    fsm_handle_event(&fsm, EVENT_START);
    printf("After EVENT_START: state=%d\n", fsm.current_state);
    TEST_ASSERT_EQUAL(STATE_RUNNING, fsm.current_state);

    fsm_handle_event(&fsm, EVENT_STOP);
    printf("After EVENT_STOP: state=%d\n", fsm.current_state);
    TEST_ASSERT_EQUAL(STATE_IDLE, fsm.current_state);
}
```

## 第六层实战练习

### 练习1：为环形缓冲区写单元测试

使用 Unity 框架为环形缓冲区模块编写完整的单元测试：

```c
// 环形缓冲区接口
typedef struct {
    uint8_t *buffer;
    uint32_t size;
    uint32_t head;
    uint32_t tail;
    bool full;
} ring_buffer_t;

void ring_buffer_init(ring_buffer_t *rb, uint8_t *buf, uint32_t size);
bool ring_buffer_put(ring_buffer_t *rb, uint8_t data);
bool ring_buffer_get(ring_buffer_t *rb, uint8_t *data);
bool ring_buffer_is_empty(ring_buffer_t *rb);
bool ring_buffer_is_full(ring_buffer_t *rb);
uint32_t ring_buffer_available(ring_buffer_t *rb);

// 请补全以下测试
void test_ring_buffer_init(void) {
    // 验证初始化后 buffer 为空
}

void test_ring_buffer_put_get(void) {
    // 写入一个字节，然后读出，验证值一致
}

void test_ring_buffer_full(void) {
    // 填满 buffer，验证 is_full 返回 true
}

void test_ring_buffer_overflow(void) {
    // 写入超过 size 的数据，验证最旧的数据被覆盖
}
```

### 练习2：阅读 SDK 源码分析可测试性

在 `/home/ys/wq7036a/wq-audio/` 目录下选择一个纯逻辑模块（如 CRC 校验、协议解析、数据结构操作），分析：
- 是否有硬件依赖？如果有，能否通过接口抽象分离？
- 输入输出是否明确？能否在 PC 上编译测试？
- 如果可以，设计一个测试方案；如果不可以，提出代码改造建议。

### 练习3：实现 mock 硬件接口

为 WQ7036AX 的 I2C 驱动编写 mock 实现，使依赖 I2C 的模块可在 PC 上测试：

```c
// 原始 I2C 接口
typedef struct {
    bool (*init)(uint32_t freq);
    bool (*read)(uint8_t dev_addr, uint8_t reg_addr, uint8_t *data, uint16_t len);
    bool (*write)(uint8_t dev_addr, uint8_t reg_addr, const uint8_t *data, uint16_t len);
} i2c_hal_t;

// 请补全 mock 实现
// 要求：
// 1. 模拟一个 I2C 温度传感器，地址 0x48
// 2. 寄存器 0x00 返回温度值（25.5 度 = 0x0FF）
// 3. 其他寄存器返回 0x00
// 4. 验证 write 后再 read 能返回正确的值
```

## 自测与验收

1. 嵌入式测试金字塔分哪三层？哪一层应该最多？
2. 为什么要把纯逻辑和硬件操作分离？分离后测试有什么好处？
3. Unity 框架适合测试什么类型的代码？有什么特点？
4. 嵌入式项目中哪些代码值得写单元测试？哪些不值得？
5. 双目标编译（Dual Targeting）是什么？解决了什么问题？

## 延伸阅读

- [[debug-methodology-嵌入式调试方法论]] — 测试和调试的互补关系
- [[data-structure-state-machine-数据结构与状态机]] — 状态机是最值得单元测试的模式
- [[ring-buffer-环形缓冲区]] — 环形缓冲区的单元测试示例
- [[c-core-C语言核心]] — 函数指针、条件编译
- [Unity Test Framework](http://www.throwtheswitch.org/unity) — 官方文档
- [CMock](http://www.throwtheswitch.org/cmock) — 自动 mock 生成工具

#flashcard
问：嵌入式测试金字塔分哪三层？
答：单元测试（PC 上跑，最多）→ 集成测试（开发板上跑）→ 硬件在环 HIL（真实硬件+模拟环境，最少）。

问：为什么要把纯逻辑和硬件操作分离？
答：分离后纯逻辑可以在 PC 上编译和测试，不需要硬件，速度快、成本低、可自动化。硬件操作通过 mock 替换，在集成测试中验证。

问：Unity 框架的特点是什么？
答：极轻量，仅 3 个源文件，纯 C 语言，适合嵌入式固件的纯逻辑单元测试，可在 PC 上编译运行。

问：嵌入式项目中哪些代码值得写单元测试？
答：协议解析状态机、数据校验算法、编解码逻辑、业务逻辑判断、环形缓冲区操作。不值的：硬件寄存器操作、简单 getter/setter、初始化代码、延时函数。

问：嵌入式项目合理的测试覆盖率是多少？
答：60-70% 行覆盖率就很好了。不需要追求 90%+，因为约 30% 的代码是硬件寄存器操作，在 PC 上无法测试。