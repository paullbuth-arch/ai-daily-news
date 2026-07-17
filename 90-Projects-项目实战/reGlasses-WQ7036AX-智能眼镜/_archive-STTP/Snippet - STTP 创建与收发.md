---
type: snippet
created: 2026-07-16
tags: [snippet, sttp, uart, template, deprecated]
aliases: [STTP 模板, STTP 代码]
---

# Snippet - STTP 创建与收发

> ⚠️ **已弃用**：STTP 因项目只需要传语音指令，其复杂的实例创建、通道注册和主循环处理流程已被更轻量的 [[uart-basics-UART基础 (app_uart_cmd)]] 替代。当前项目请使用 [[Snippet - UART 命令收发模板]]。本笔记保留作为历史参考。

> 参考 `glass/acore/app/app_customer_ext_trans/` 下的实现。

## 创建 STTP 实例

```c
#include "sttp.h"

// ============ IO 回调 (UART) ============

static int64_t uart_read_cb(void *usr, void *buf, uint32_t len)
{
    // 从 UART 读取数据到 STTP 接收缓冲区
    return (int64_t)wq_uart_read((WQ_UART_PORT)usr, (uint8_t *)buf, len);
}

static int64_t uart_write_cb(void *usr, const void *buf, uint32_t len)
{
    // 通过 UART 发送 STTP 帧
    wq_uart_write((WQ_UART_PORT)usr, (const char *)buf, len, NULL);
    return (int64_t)len;
}

// ============ 接收回调 ============

static int32_t control_recv_cb(void *usr, const void *data, uint32_t len)
{
    // chn=1 控制指令接收
    LOGI("STTP chn1 recv, len=%d\n", len);
    // 处理控制指令...
    return 0;
}

static int32_t audio_recv_cb(void *usr, const void *data, uint32_t len)
{
    // chn=2 音频数据接收
    // 处理音频数据...
    return 0;
}

// ============ 初始化 ============

static STTP_Obj_t *g_sttp = NULL;

// STTP 缓冲区 (需要预分配)
static uint8_t sttp_rx_buf[4096];
static uint8_t sttp_tx_buf[4096];

void sttp_init(void)
{
    STTP_Info_t info = {
        .rxBuf  = sttp_rx_buf,
        .rxLen  = sizeof(sttp_rx_buf),
        .txBuf  = sttp_tx_buf,
        .txLen  = sizeof(sttp_tx_buf),
    };

    STTP_Io_t io = {
        .usr   = (void *)WQ_UART_PORT_1,  // UART1
        .read  = uart_read_cb,
        .write = uart_write_cb,
    };

    // 创建 STTP 实例 (WQ7036AX 作为 Client)
    g_sttp = STTP_New(E_STTP_MODE_CLIENT, &info, &io);
    assert(g_sttp);

    // 注册通道接收回调
    STTP_AddReceiver(g_sttp, 1, control_recv_cb, NULL);  // chn1: 控制
    STTP_AddReceiver(g_sttp, 2, audio_recv_cb, NULL);    // chn2: 音频
    STTP_AddReceiver(g_sttp, 4, telemetry_recv_cb, NULL); // chn4: 遥测

    // 发起连接
    STTP_Connect(g_sttp);
}

// ============ 发送数据 ============

void sttp_send_control(void *data, uint32_t len)
{
    // chn=1, 需要 ACK
    STTP_Send(g_sttp, 1, data, len, 1);
}

void sttp_send_audio(void *data, uint32_t len)
{
    // chn=2, 不需要 ACK (流数据)
    STTP_Send(g_sttp, 2, data, len, 0);
}

// ============ 主循环处理 ============

// 需要在任务循环中定期调用
void sttp_process_task(void)
{
    uint64_t time_ns = os_get_ticks() * 1000000; // 转为纳秒
    STTP_Process(g_sttp, time_ns);
}
```

## 关键注意点

1. `STTP_Process()` 必须在主循环中**定期调用**，否则无法处理超时重传和接收
2. `STTP_Send()` 的 `needCheck` 参数控制是否要求 ACK
3. STTP 缓冲区大小决定最大帧长度
4. `E_STTP_MODE_CLIENT` = WQ7036AX 主动发起连接
5. `E_STTP_MODE_SERVER` = V881 等待连接

## 关联概念

- [[STTP 协议]] — 协议总览
- [[STTP 通道分配]] — chn 分配方案
- [[STTP 连接管理]] — 连接生命周期
- [[uart-basics-UART基础]] — 物理层
