# 嵌入式测试

**一句话结论（20% 核心）**：嵌入式测试比 PC 软件测试难——没有屏幕、资源有限、硬件依赖。分三层：单元测试（PC 上测纯逻辑）、集成测试（开发板上测模块交互）、硬件在环测试（真实硬件+模拟环境）。至少写单元测试，用 Unity 框架，3 个文件就能跑起来。关键思路：**把纯逻辑和硬件操作分离**。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：造汽车的质量检测

- **单元测试** = 检测每个零件：发动机单独测试马力、刹车单独测试制动力
- **集成测试** = 检测零件组装后是否配合：发动机+变速箱装在一起，看能否正常运转
- **硬件在环（HIL）** = 上路测试，但用电脑模拟危险场景：在实验室里用电脑发送"前方有障碍物"信号，看自动刹车是否响应

### 1.2 嵌入式测试的分层和成本

```
         ┌──────────────────────┐  ← 最贵，最真实，最难自动化
         │  硬件在环 (HIL)       │
         ├──────────────────────┤
         │  集成测试              │  ← 需要真实硬件
         ├──────────────────────┤
         │  单元测试              │  ← 最便宜，最快，最容易自动化
         └──────────────────────┘
```

**测试金字塔**：底层（单元测试）应该最多，顶层（HIL）应该最少。但实际上很多嵌入式项目正好反过来——几乎没有单元测试，全靠在板子上手动测。

### 1.3 嵌入式测试框架对比

| 框架 | 语言 | 运行位置 | 特点 | 适合场景 |
|------|------|---------|------|---------|
| **Unity** | C | PC | 3 个文件，极轻量 | MCU 固件逻辑 |
| **CppUTest** | C/C++ | PC | 支持 mock，内存泄漏检测 | 有 C++ 的嵌入式项目 |
| **CMock** | C | PC | 自动生成 mock 函数 | 需要 mock 硬件接口 |
| **Google Test** | C++ | PC | 功能全面，社区大 | Linux 应用层 |
| **Ceedling** | C | PC | Unity+CMock 的打包工具 | 快速搭建测试环境 |

### 1.4 如果只记得一件事

> 嵌入式测试 = 单元测试（PC 上测，用 Unity）+ 集成测试（板子上测）+ HIL（真实硬件+模拟）。把纯逻辑和硬件操作分离，纯逻辑在 PC 上测，硬件操作 mock 掉。

---

## 第二层：实战理解

### 2.1 怎么把代码改造成可测试的？

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
    int (*read_byte)(uint8_t *byte);  // 函数指针
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

### 2.2 Mock 硬件接口

```c
// 用 CMock 自动生成 mock 函数
// 在头文件中声明要被 mock 的函数
// gpio.h:
void gpio_set_level(int pin, int level);

// CMock 自动生成 mock_gpio_set_level.c:
void gpio_set_level(int pin, int level) {
    mock().actualCall("gpio_set_level")
        .withIntParams("pin", pin)
        .withIntParams("level", level);
}

// 测试中验证调用
void test_led_on(void) {
    // 期望 gpio_set_level 被调用一次，参数是 LED_PIN 和 1
    gpio_set_level_Expect(LED_PIN, 1);

    led_on();  // 被测函数
}
```

### 2.3 在 CI 中运行测试

```makefile
# Makefile 中集成测试目标
test:
    gcc -o test_runner test_wq_protocol.c wq_protocol.c unity.c
    ./test_runner

# GitHub Actions / Jenkins 中
test:
    script:
        - make test
        - if [ $? -ne 0 ]; then exit 1; fi
```

### 2.4 什么值得测、什么不值得测

| 值得测（高 ROI） | 不值得测（低 ROI） |
|-----------------|-------------------|
| 协议解析状态机（WQ Protocol unpack） | 硬件寄存器操作（`*(volatile *)0x40000000 = val`） |
| 数据校验算法（CRC、checksum） | 简单 getter/setter |
| 编解码逻辑（Opus 帧封装） | 平台相关的初始化代码（`wq_uart_init`） |
| 业务逻辑判断（命令路由） | 临界区保护和中断处理（时序依赖） |
| 环形缓冲区操作 | 延时函数（`vTaskDelay`） |

### 2.5 在 reGlasses 项目中怎么用

WQ7036AX SDK 目前没有正式的单元测试框架。建议从以下模块开始加测试：

1. **WQ Protocol 帧解包/打包**（`wq_protocol.h` 中的函数）——纯逻辑，最适合单元测试
2. **环形缓冲区操作**——独立数据结构，无硬件依赖
3. **命令路由逻辑**（`app_trans.c` 中的 switch-case）——业务逻辑，容易出错
4. **CRC 校验函数**——数学运算，输入输出明确

V881 侧可以用 Google Test 测试 C++ 应用层代码（摄像头服务、WiFi 服务）。

---

## 第三层：深入扩展

### 3.1 双目标编译（Dual Targeting）

```makefile
# 同一份代码编译两次：
# ① 目标平台（WQ7036AX）：用 RISC-V GCC，跑在芯片上
# ② 测试平台（PC）：用 x86 GCC，跑在 PC 上

# 条件编译隔离硬件相关代码
#ifdef TEST_BUILD
    #include "mock_gpio.h"
#else
    #include "wq_gpio.h"
#endif
```

### 3.2 常见问题

- **测试覆盖率要多少？** 嵌入式项目 60-70% 行覆盖率就很好了。不要追求 90%+，因为 30% 的代码是硬件寄存器操作，在 PC 上无法测试。
- **单元测试能替代硬件测试吗？** 不能。单元测试保证逻辑正确，但不能保证时序正确、中断正确、DMA 正确。硬件测试永远不可替代。
- **什么时候写测试？** 理想是 TDD（先写测试再写代码），但实际中更可行的是：修 bug 时补测试，加新功能时补测试。不要试图给已有代码全部补测试，从最核心的模块开始。

### 3.3 延伸阅读

- [[data-structure-state-machine-数据结构与状态机]] — 状态机是最值得单元测试的模式
- [[debug-methodology-嵌入式调试方法论]] — 测试和调试的互补关系
- [[ring-buffer-环形缓冲区]] — 环形缓冲区的单元测试示例