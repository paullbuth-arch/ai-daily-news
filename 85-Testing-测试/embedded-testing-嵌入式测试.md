# 嵌入式测试

**一句话结论（20% 核心）**：嵌入式测试比 PC 软件测试难——没有屏幕、资源有限、硬件依赖。分三层：单元测试（测函数逻辑，在 PC 上跑）、集成测试（测模块交互，在开发板上跑）、硬件在环测试（测完整系统，真实硬件）。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：造汽车的质量检测

- **单元测试** = 检测每个零件（发动机、刹车、方向盘）是否符合规格
- **集成测试** = 检测零件组装后是否配合（发动机+变速箱能否正常运转）
- **硬件在环（HIL）** = 上路测试，但用模拟器替代真实危险场景（用电脑模拟雨天，测试刹车）

### 1.2 嵌入式测试的分层

```
         ┌──────────────────────┐
         │  硬件在环 (HIL)       │  ← 真实硬件 + 模拟环境
         ├──────────────────────┤
         │  集成测试              │  ← 在开发板上跑，测模块交互
         ├──────────────────────┤
         │  单元测试              │  ← 在 PC 上跑，测纯逻辑函数
         └──────────────────────┘
```

### 1.3 嵌入式单元测试框架

| 框架 | 语言 | 特点 |
|------|------|------|
| **Unity** | C | 最轻量，3 个文件，非常适合嵌入式 |
| **CppUTest** | C/C++ | 功能更强，支持 mock |
| **CMock** | C | 自动生成 mock 函数 |
| **Google Test** | C++ | 需要 C++ 编译，适合 Linux 侧 |

### 1.4 如果只记得一件事

> 嵌入式测试 = 单元测试（PC 上测函数）+ 集成测试（板子上测模块）+ HIL（真实硬件+模拟环境）。至少写单元测试，用 Unity 框架，3 个文件就能跑起来。

---

## 第二层：实战理解

### 2.1 Unity 单元测试最小示例

```c
// test_calc.c
#include "unity.h"
#include "calc.h"

void setUp(void) {}      // 每个测试前运行
void tearDown(void) {}   // 每个测试后运行

void test_add_positive(void) {
    TEST_ASSERT_EQUAL(5, add(2, 3));
}

void test_add_negative(void) {
    TEST_ASSERT_EQUAL(-1, add(2, -3));
}

void test_add_overflow(void) {
    // 测试溢出保护
    TEST_ASSERT_EQUAL(INT32_MAX, add(INT32_MAX, 1));
}

int main(void) {
    UNITY_BEGIN();
    RUN_TEST(test_add_positive);
    RUN_TEST(test_add_negative);
    RUN_TEST(test_add_overflow);
    return UNITY_END();
}
```

### 2.2 什么值得测、什么不值得测

| 值得测 | 不值得测 |
|--------|---------|
| 协议解析函数（状态机） | 硬件寄存器操作（依赖硬件） |
| 数据校验算法（CRC） | 简单的 getter/setter |
| 编解码逻辑 | 平台相关的初始化代码 |
| 业务逻辑判断 | 临界区保护（时序依赖） |

### 2.3 在 reGlasses 项目中怎么用

WQ7036AX SDK 目前没有正式的单元测试框架。建议从协议解析（WQ Protocol 解包/打包）和数据处理函数开始加测试。V881 侧可以用 Google Test 或 CppUTest。关键思路：**把纯逻辑函数和硬件操作分离**，纯逻辑在 PC 上测，硬件操作在板子上测。

---

## 第三层：延伸阅读

- [[data-structure-state-machine-数据结构与状态机]] — 状态机是最值得单元测试的模式
- [[debug-methodology-嵌入式调试方法论]] — 测试和调试的互补关系