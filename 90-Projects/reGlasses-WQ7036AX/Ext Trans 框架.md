---
type: concept
created: 2026-07-16
tags: [sdk, ext-trans, framework, 框架, 插件, IO]
aliases: [Ext Trans, 外部传输框架, External Transmission]
---

# Ext Trans 框架

## 一句话理解

Ext Trans (External Transmission，外部传输) 框架就像**一个万能插座**：你可以把不同的"电器" (UART/SPI/I2S/Flash) 插进去，也可以给电器配上不同的"适配器" (STTP 协议/WQ Protocol/无协议)。框架帮你处理开关和调度，你只关心数据进出。

## 为什么学它

[[STTP 协议]] 在 SDK 中**不是直接调用 UART API**，而是通过 Ext Trans 框架集成。你要理解这个框架才能知道 STTP 的 `read/write` 是怎么接到 UART 的，以及 `pack/unpack` 协议层是怎么串进去的。

## 第一步：在 Source Insight 中找到框架

1. **`Ctrl+Comma`** 搜索 `ext_trans_io_create` → 跳到 `ext_trans_io.c`
2. 看创建函数的参数：

```c
typedef struct ext_trans_io_param {
    ext_trans_dev_func_t *dev_func;   // IO 设备 (必须) — 用 UART 还是 SPI?
    ext_trans_protocol_t *protocol;   // 协议层 (可选) — 用 STTP 还是裸数据?
    uint32_t arg;                      // 端口 ID — 用 UART0 还是 UART1?
} ext_trans_io_param_t;

void *ext_trans_io_create(ext_trans_io_param_t *param);
```

三个参数就是万能插座的三个选择：**用什么接口 + 跑什么协议 + 用哪个端口**。

## 架构

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

## IO 设备函数表

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

## 使用示例 (UART + STTP)

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

## Kconfig 配置

```
CONFIG_EXT_TRANS_ENABLE=y              # 启用框架
CONFIG_EXT_TRANS_CUSTOMER_ENABLE=y     # 启用自定义实现
CONFIG_EXT_TRANS_IO_UART_ENABLE=y      # UART IO 可用
CONFIG_EXT_TRANS_IO_I2S_ENABLE=y       # I2S IO 可用
CONFIG_EXT_TRANS_IO_SPI_ENABLE=y       # SPI IO 可用
CONFIG_EXT_TRANS_IO_FLASH_ENABLE=y     # Flash IO 可用
```

## 验收标准

- [ ] 能画出 Ext Trans 的两层架构 (IO 设备层 + 协议层)
- [ ] 能说出 `ext_trans_io_create` 的三个参数含义
- [ ] 能解释 STTP 是如何通过 Ext Trans 框架集成到 UART 上的

## 关联概念

- [[STTP 协议]] — 通过 Ext Trans UART IO 运行
- [[WQ Audio Protocol]] — 可作为 protocol 层的 pack/unpack 实现
- [[UART 基础]] — Ext Trans UART IO 的底层
- [[I2S 协议]] — Ext Trans I2S IO 的底层

#flashcard
问：Ext Trans 框架的两个核心组件是什么？
答：ext_trans_dev_func_t (IO 设备层，必选) 和 ext_trans_protocol_t (协议层，可选)。IO 负责物理收发，协议负责数据打包/解包。

问：ext_trans_io_create 的三个参数分别选什么？
答：①dev_func = 用什么物理接口 (UART/SPI/I2S) ②protocol = 跑什么协议 (STTP/WQ Protocol/NULL) ③arg = 用哪个端口号。
