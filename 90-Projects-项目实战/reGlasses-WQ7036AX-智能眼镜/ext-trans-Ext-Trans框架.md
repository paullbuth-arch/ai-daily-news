---
type: concept
created: 2026-07-16
updated: 2026-07-17
tags: [sdk, ext-trans, framework, 框架, 插件, IO, protocol]
aliases: [Ext Trans, 外部传输框架, External Transmission, 外部传输]
---

# Ext Trans 框架

**一句话结论**：Ext Trans（外部传输）框架是 SDK 中一个"万能插座"式的 IO 抽象层——你选择物理接口（UART/SPI/I2S/Flash）和协议层（STTP/WQ Protocol/裸数据），框架帮你处理开关调度，你只关心数据收发。

---

## 30 秒先看懂

- Ext Trans 框架将 IO 设备（物理接口）和协议层（数据打包/解包）解耦，通过组合而非继承实现扩展。
- 核心函数 `ext_trans_io_create` 接受三个参数：dev_func（用 UART 还是 SPI）、protocol（用 STTP 还是裸数据）、arg（端口号）。
- 框架内部维护一个 `ext_trans_io_t` 结构体，封装了统一接口：send、recv、open、close、destroy。
- IO 设备层（`ext_trans_dev_func_t`）是必须的，协议层（`ext_trans_protocol_t`）是可选的，不需要协议时填 NULL。
- 在 SDK 中，STTP 协议和 UART/I2S 通信都通过这个框架集成。

---

## 学完以后应该能做什么

**第一遍学完**：
- 能画出 Ext Trans 框架的两层架构图（IO 设备层 + 协议层）
- 能说出 `ext_trans_io_create` 的三个参数含义
- 能解释 STTP 是如何通过 Ext Trans 框架集成到 UART 上的

**进阶目标**：
- 能自己注册一个新的 IO 设备类型（如通过 SPI 连接的外部设备）
- 能实现一个自定义协议层，挂接到 Ext Trans 框架
- 能理解框架设计中的策略模式思想

---

## 前置知识

- [[uart-basics-UART基础]] — UART IO 设备的底层实现
- [[STTP 协议]] — 常见的协议层实现
- [[wq-audio-protocol-WQ-Audio-Protocol]] — 另一种可作为协议层实现的帧格式
- [[i2s-protocol-I2S协议]] — I2S IO 设备的底层

---

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 外部传输 | Ext Trans (External Transmission) | SDK 中用于抽象 IO 设备和协议层的框架 |
| IO 设备层 | IO Device Layer | 封装物理接口的驱动层，实现 open/close/out/in 等操作 |
| 协议层 | Protocol Layer | 可选的数据打包/解包层，实现 pack/unpack 操作 |
| 设备函数表 | Device Function Table | 包含 init/deinit/open/close/out/in/duplex 的函数指针结构体 |
| IO 实例 | IO Instance | `ext_trans_io_create` 返回的句柄，代表一个 IO 通道 |
| 端口 ID | Port ID | 标识用哪个物理端口（如 UART0、UART1、I2S0） |

---

## 第一层：费曼心智模型

### 类比：万能插座 + 适配器

Ext Trans 框架就像一套**模块化的插座系统**：

| 组件 | 类比 | 说明 |
|------|------|------|
| `ext_trans_io_create` | 安装插座 | 选择用什么接口和协议 |
| `ext_trans_dev_func_t` | 插座类型 | 两孔（UART）、三孔（SPI）、USB（I2S） |
| `ext_trans_protocol_t` | 适配器 | 稳压器（STTP）、转换头（WQ Protocol）、直通（NULL） |
| `arg` | 插座编号 | 客厅插座（UART0）、厨房插座（UART1） |
| 返回的 `io` 句柄 | 插好电的设备 | 通了电，直接用 send/recv |

**为什么需要这个框架？** 因为项目中需要同时用 UART 和 V881 通信、用 I2S 传输音频、用 SPI 连接 Flash。如果每个都单独写一套逻辑，代码会重复且难以维护。Ext Trans 把它们统一抽象为"IO 设备 + 协议"。

### 边界

- IO 设备层**必须**提供，否则无法进行物理收发
- 协议层**可选**，不需要协议打包时填 NULL（比如裸数据传输）
- 一个 IO 实例只能绑定一个设备和一个协议
- 框架不负责内存管理，buffer 由调用方提供

### 场景推演

**场景：新增一个通过 UART 连接的传感器**

1. 选择 IO 设备：`ext_trans_dev_func_get(EXT_TRANS_IO_ID_UART)`
2. 选择协议：不需要特殊协议，填 NULL（应用层自己解析数据）
3. 选择端口：UART1
4. 调用 `ext_trans_io_create` 创建实例
5. 调用 `ext_trans_io_open` 打开 UART 并配置波特率
6. 调用 `ext_trans_io_data_send` 发送查询命令
7. 在回调中接收传感器数据，自行解析

---

## 第二层：原理、时序与约束

### 架构

```
ext_trans_io_t (统一接口: send / recv / open / close)
    │
    ├── ext_trans_dev_func_t  (IO 设备层, 必须)
    │   │  "用什么物理接口传输?"
    │   ├── UART ops → wq_uart_open / write / read
    │   ├── SPI ops  → wq_spi_open / write / read
    │   ├── I2S ops
    │   ├── Flash ops
    │   └── VCOM ops (虚拟串口)
    │
    └── ext_trans_protocol_t  (协议层, 可选)
        │  "数据需要打包/解包吗?"
        ├── pack()     — 发送前: 加上帧头/CRC
        ├── unpack()   — 接收后: 去掉帧头/校验
        ├── cmd_pack() — 控制命令打包
        └── cmd_unpack() — 控制命令解包
```

### IO 设备函数表

```c
typedef struct _ext_trans_dev_func {
    WQ_RET (*init)(void *hdl, uint32_t arg);     // 初始化
    WQ_RET (*deinit)(uint32_t arg);              // 反初始化
    WQ_RET (*open)(uint32_t arg);                // 打开 (配置外设)
    WQ_RET (*close)(uint32_t arg);               // 关闭
    WQ_RET (*out)(uint32_t arg, void *buf,       // 发送
                  uint32_t len, void *cb, void *param);
    WQ_RET (*in)(uint32_t arg, void *buf,        // 接收
                 uint32_t len, void *cb, void *param);
    WQ_RET (*duplex)(uint32_t arg,               // 全双工
                     void *outbuf, size_t outlen,
                     uint8_t *inbuf, size_t inlen,
                     void *cb, void *param);
} ext_trans_dev_func_t;
```

### 使用示例 (UART + STTP)

```c
// 1. 选择 IO 设备 = UART, 协议 = STTP
ext_trans_io_param_t param = {
    .dev_func = ext_trans_dev_func_get(EXT_TRANS_IO_ID_UART),
    .protocol = &my_sttp_protocol,  // STTP 的 pack/unpack
    .arg = WQ_UART_PORT_1,          // UART1
};

// 2. 创建
void *io = ext_trans_io_create(&param);

// 3. 打开 (内部调用 uart_open + STTP_Connect)
ext_trans_io_open(io);

// 4. 发送 (内部: protocol.pack → dev_func.out)
ext_trans_io_data_send(io, buffer, length, callback, param);

// 5. 接收 (通过回调)
ext_trans_io_data_recv(io, buffer, length, callback, param);

// 6. 关闭 + 销毁
ext_trans_io_close(io);
ext_trans_io_destory(io);
```

### Kconfig 配置

```
CONFIG_EXT_TRANS_ENABLE=y              # 启用框架
CONFIG_EXT_TRANS_CUSTOMER_ENABLE=y     # 启用自定义实现
CONFIG_EXT_TRANS_IO_UART_ENABLE=y      # UART IO 可用
CONFIG_EXT_TRANS_IO_I2S_ENABLE=y       # I2S IO 可用
CONFIG_EXT_TRANS_IO_SPI_ENABLE=y       # SPI IO 可用
CONFIG_EXT_TRANS_IO_FLASH_ENABLE=y     # Flash IO 可用
```

---

## 第三层：真实 SDK 代码

### 核心头文件

**文件路径**：`wq-adk/components/ext_trans/inc/ext_trans_io.h`

```c
typedef struct ext_trans_io_param {
    ext_trans_dev_func_t *dev_func;   // 必须：IO 设备函数指针
    ext_trans_protocol_t *protocol;   // 可选：协议层，不需要时填 NULL
    uint32_t arg;                     // 端口 ID 或设备信息
} ext_trans_io_param_t;

void *ext_trans_io_create(ext_trans_io_param_t *param);
void ext_trans_io_destory(void *io);
void ext_trans_io_open(void *io);
void ext_trans_io_close(void *io);
```

### IO 设备实现

**文件路径**：`wq-adk/components/ext_trans/src/ext_trans_dev_uart.c`

UART IO 设备的实现，封装了 `wq_uart_init`、`wq_uart_write`、`wq_uart_read` 等底层 API，满足 `ext_trans_dev_func_t` 接口。

**文件路径**：`wq-adk/components/ext_trans/src/ext_trans_dev_i2s.c`

I2S IO 设备的实现，用于音频数据传输。

### 调用示例（reGlasses 中）

在 `app_uart_cmd.c` 中，通过 Ext Trans 框架创建 UART IO 实例，用于与 V881 通信：

```c
// 创建 UART IO 实例（伪代码）
ext_trans_io_param_t param = {
    .dev_func = ext_trans_dev_func_get(EXT_TRANS_IO_ID_UART),
    .protocol = NULL,  // 或 STTP 协议
    .arg = WQ_UART_PORT_1,
};
void *uart_io = ext_trans_io_create(&param);
ext_trans_io_open(uart_io);
```

---

## 第四层：正常与异常路径

### 正常路径

创建 IO 实例 → 打开设备 → 发送数据（协议层 pack → 设备层 out） → 接收数据（设备层 in → 协议层 unpack） → 关闭设备 → 销毁实例

### 异常路径

| 问题 | 现象 | 根因 |
|------|------|------|
| IO 创建失败 | `ext_trans_io_create` 返回 NULL | dev_func 为 NULL 或 arg 无效 |
| 设备打开失败 | `ext_trans_io_open` 返回错误 | 外设硬件故障或端口已被占用 |
| 发送超时 | 数据未发出 | 设备未打开或硬件故障 |
| 协议解包失败 | 收到数据但解析错误 | 协议层 pack/unpack 不匹配或 CRC 错误 |
| 回调未触发 | 接收数据后无响应 | 回调函数指针为 NULL |
| 内存泄漏 | 反复创建销毁 IO 实例 | 未调用 `ext_trans_io_destory` |

---

## 第五层：调试方法

### 1. 确认框架是否启用

检查 `sdkconfig` 中 `CONFIG_EXT_TRANS_ENABLE=y`，确认框架已编译进固件。

### 2. 验证 IO 设备注册

调用 `ext_trans_dev_func_get` 获取设备函数表，检查返回指针是否为 NULL。如果为 NULL，说明该 IO 设备未注册。

### 3. 追踪数据收发

在 `ext_trans_io_data_send` 和 `ext_trans_io_data_recv` 中添加日志，打印发送和接收的数据长度和内容。

### 4. 检查协议层

在 `protocol->pack` 和 `protocol->unpack` 中打印帧头和帧尾，确认协议打包/解包正确。

### 5. 外设硬件检查

如果 IO 设备操作失败，用逻辑分析仪抓取对应引脚的波形，确认物理层通信正常。

---

## 第六层：实战练习

### 练习 1：在 SDK 中定位 Ext Trans 框架文件

在 `wq-adk/components/ext_trans/` 目录下，找到以下文件并阅读其核心内容：
- `inc/ext_trans_io.h` — 框架核心接口
- `inc/ext_trans_dev.h` — IO 设备层接口
- `inc/ext_trans_protocol.h` — 协议层接口
- `src/ext_trans_dev_uart.c` — UART IO 设备实现

### 练习 2：实现一个自定义协议层

假设需要一个新的协议层 "MyProtocol"，它只在数据前加 2 字节长度头。请根据 `ext_trans_protocol_t` 的结构，实现 `pack` 和 `unpack` 函数，并说明如何注册到 Ext Trans 框架。

### 练习 3：分析 STTP 如何通过 Ext Trans 集成

在 `app_uart_cmd.c` 中找到使用 Ext Trans 的代码，说明 STTP 协议的 `pack`/`unpack` 是如何通过 `ext_trans_protocol_t` 接口挂接到 UART 设备上的。

### 练习 4：阅读真实源代码

打开 `wq-adk/components/ext_trans/src/ext_trans_io.c`，阅读 `ext_trans_io_create` 函数的实现，分析它如何将 `dev_func` 和 `protocol` 组合成一个统一的 IO 实例。画出 `ext_trans_io_data_send` 的调用链。

---

## 自测与验收

1. Ext Trans 框架的两层架构是什么？各层的作用是什么？
2. `ext_trans_io_create` 的三个参数分别是什么？哪个是必须的？
3. 如果不需要协议层，protocol 参数应该填什么？
4. 在 SDK 中，UART IO 设备的实现文件在哪里？
5. Ext Trans 框架使用的设计模式是什么？
6. 如何注册一个新的 IO 设备类型？
7. `ext_trans_io_data_send` 内部是如何调用协议层和设备层的？
8. 如果 `ext_trans_io_create` 返回 NULL，可能的原因是什么？
9. 框架中 `arg` 参数的作用是什么？
10. 一个 IO 实例可以被多个协议层同时使用吗？

---

## 延伸阅读

- [[STTP 协议]] — 通过 Ext Trans UART IO 运行的协议层
- [[wq-audio-protocol-WQ-Audio-Protocol]] — 另一种可作为协议层实现的帧格式
- [[uart-basics-UART基础]] — Ext Trans UART IO 的底层
- [[i2s-protocol-I2S协议]] — Ext Trans I2S IO 的底层
- [[embedded-design-patterns-嵌入式设计模式]] — 策略模式在框架中的应用

#flashcard
问：Ext Trans 框架的两个核心组件是什么？
答：ext_trans_dev_func_t（IO 设备层，必选）和 ext_trans_protocol_t（协议层，可选）。IO 负责物理收发，协议负责数据打包/解包。

问：ext_trans_io_create 的三个参数分别选什么？
答：① dev_func = 用什么物理接口（UART/SPI/I2S）② protocol = 跑什么协议（STTP/WQ Protocol/NULL）③ arg = 用哪个端口号。

问：Ext Trans 框架在 SDK 中的代码路径是什么？
答：`wq-adk/components/ext_trans/`，核心头文件在 `inc/` 下，实现文件在 `src/` 下。

问：Ext Trans 框架使用的设计模式是什么？
答：策略模式。IO 设备层和协议层都是通过函数指针表实现的策略接口，运行时可选择不同的实现。

问：如果不需要协议层，protocol 参数应填什么？
答：填 NULL。框架会跳过协议层的 pack/unpack，直接调用 IO 设备层的 out/in。