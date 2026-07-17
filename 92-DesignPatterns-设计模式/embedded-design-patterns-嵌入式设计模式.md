# 嵌入式设计模式

**一句话结论（20% 核心）**：设计模式不是 Java 程序员的专利——嵌入式里到处是回调（观察者模式）、事件总线（发布订阅）、状态机（状态模式）、策略模式（编解码器切换）。识别出这些模式，代码会少很多 bug。

---

## 第一层：核心认知（必须先看懂）

### 1.1 嵌入式最常用的四种模式

| 模式 | 一句话 | 嵌入式里的例子 |
|------|--------|---------------|
| **回调（观察者）** | "事情发生时通知我" | UART 接收中断→回调函数、按键事件→回调 |
| **发布订阅** | "广播消息，谁关心谁订阅" | 系统事件总线、WQ Protocol 消息分发 |
| **状态机** | "在什么状态下收到什么事件做什么" | 协议解析、按键处理、设备管理 |
| **策略模式** | "运行时切换算法" | 编解码器切换（Opus vs SBC）、降噪算法选择 |

### 1.2 回调模式（最常见）

```c
// WQ7036AX SDK 里到处都是回调
typedef void (*uart_rx_callback_t)(uint8_t *data, uint32_t len);

// 注册回调：UART 收到数据时自动调用我的函数
wq_uart_register_rx_callback(port, buffer, size, my_rx_handler);

// 回调函数：数据到达时被调用
void my_rx_handler(uint8_t *data, uint32_t len) {
    // 处理收到的数据
}
```

### 1.3 发布订阅模式（事件总线）

```c
// 系统中多个模块关心同一个事件
// 不用 if-else 判断，而是发布事件，订阅者自动收到

typedef enum {
    EVENT_KEY_PRESS,
    EVENT_BLE_CONNECTED,
    EVENT_CHARGE_STATE_CHANGE,
} event_t;

// 订阅者注册
event_subscribe(EVENT_BLE_CONNECTED, on_ble_connected);
event_subscribe(EVENT_BLE_CONNECTED, on_led_update);  // LED 也关心

// 发布事件
event_publish(EVENT_BLE_CONNECTED, &conn_info);
// → on_ble_connected 和 on_led_update 都会被调用
```

### 1.4 如果只记得一件事

> 嵌入式设计模式 = 回调（通知）+ 状态机（行为）+ 发布订阅（解耦）+ 策略（切换）。WQ7036AX SDK 里回调是最常见的模式，状态机是协议解析的核心。

---

## 第二层：实战理解

### 2.1 策略模式：编解码器切换

```c
// 策略接口
typedef struct {
    int (*encode)(const int16_t *pcm, uint8_t *out, int len);
    int (*decode)(const uint8_t *in, int16_t *pcm, int len);
} codec_strategy_t;

// 具体策略
codec_strategy_t opus_codec = {
    .encode = opus_encode,
    .decode = opus_decode,
};

codec_strategy_t sbc_codec = {
    .encode = sbc_encode,
    .decode = sbc_decode,
};

// 运行时切换
codec_strategy_t *current_codec = &opus_codec;
current_codec->encode(pcm_data, encoded, len);
current_codec = &sbc_codec;  // 切换到 SBC
```

### 2.2 常见反模式

| 反模式 | 现象 | 改进 |
|--------|------|------|
| 巨型 switch-case | 一个函数 500 行，全是 case | 改成状态表驱动 |
| 全局变量满天飞 | 哪个函数改了某个变量完全不知道 | 封装成结构体+接口函数 |
| 硬编码依赖 | 换一个芯片要改几百处 | 用 HAL 抽象硬件差异 |

### 2.3 在 reGlasses 项目中怎么用

WQ7036AX SDK 中观察得出来的设计模式：
- **回调**：`wq_uart_register_rx_callback`、`aud_sv_register_data_callback`、GPIO 中断回调
- **状态机**：`app_uart_cmd.c` 的帧解析状态机、按键状态机
- **策略**：`codec_factory` 组件的编解码器切换

---

## 第三层：延伸阅读

- [[data-structure-state-machine-数据结构与状态机]] — 状态机的详细实现
- [[ext-trans-Ext-Trans框架]] — SDK 的插件化 IO+Protocol 架构