---
type: concept
created: 2026-07-16
updated: 2026-07-17
tags: [design-patterns, embedded, 设计模式, 回调, 状态机, 发布订阅, 策略模式]
aliases: [嵌入式设计模式, Embedded Design Patterns, 嵌入式架构模式]
---

# 嵌入式设计模式

**一句话结论**：嵌入式里最常用的四种设计模式是回调（观察者模式）、发布订阅（事件总线）、状态机（状态模式）、策略模式（编解码器切换）。识别出这些模式，代码会少很多 bug。

---

## 30 秒先看懂

- 回调模式是嵌入式中最常见的模式——UART 接收中断触发回调函数，其实就是"事情发生时通知我"。
- 发布订阅模式解耦了事件发送者和接收者——系统中多个模块可以订阅同一个事件，如 BLE 连接事件同时通知 UI 和 LED。
- 状态机模式是协议解析的核心——在什么状态下收到什么事件做什么，避免了复杂的 if-else 嵌套。
- 策略模式让你在运行时切换算法——如 Opus 和 SBC 编解码器之间无缝切换。
- WQ7036AX SDK 中大量使用了这些模式：`wq_uart_register_rx_callback`（回调）、`app_uart_cmd.c` 的帧解析（状态机）、`codec_factory`（策略模式）。

---

## 学完以后应该能做什么

**第一遍学完**：
- 能说出嵌入式最常用的四种设计模式及其应用场景
- 能在 SDK 代码中识别出每种模式的使用
- 能写出回调函数的注册和实现

**进阶目标**：
- 能设计一个事件总线（发布订阅）系统
- 能用状态表驱动替代 switch-case 状态机
- 能理解策略模式在编解码器切换中的应用

---

## 前置知识

- [[ext-trans-Ext-Trans框架]] — SDK 中策略模式的应用实例
- [[interrupt-concurrency-中断并发同步]] — 理解回调与中断的关系
- [[data-structure-state-machine-数据结构与状态机]] — 状态机实现

---

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 回调函数 | Callback Function | 注册给框架的函数，在特定事件发生时被调用 |
| 观察者模式 | Observer Pattern | 一个对象状态变化时通知所有依赖它的对象 |
| 发布订阅 | Publish-Subscribe | 事件发送者不直接通知接收者，而是通过事件总线分发 |
| 状态机 | State Machine | 在有限状态间切换的数学模型，当前状态决定行为 |
| 策略模式 | Strategy Pattern | 定义一系列算法，运行时可以互相替换 |
| 反模式 | Anti-Pattern | 常见但有害的编程习惯，应避免 |
| 状态表 | State Table | 用表格形式定义状态机的状态、事件和动作 |

---

## 第一层：费曼心智模型

### 四种模式的类比

| 模式 | 一句话 | 生活类比 | 嵌入式例子 |
|------|--------|---------|-----------|
| **回调（观察者）** | "事情发生时通知我" | 给快递员留电话，包裹到了打电话 | UART 接收中断 → 回调函数 |
| **发布订阅** | "广播消息，谁关心谁订阅" | 广播电台播新闻，谁想听谁打开收音机 | 系统事件总线、BLE 连接事件 |
| **状态机** | "在什么状态下做什么事" | 红绿灯：红灯停、绿灯行、黄灯等 | 协议解析、按键处理 |
| **策略模式** | "运行时切换算法" | 坐地铁 vs 打车，根据情况选交通方式 | 编解码器切换（Opus vs SBC） |

### 边界

- 回调模式适合**一对一的异步通知**，但不适合一对多的广播场景。
- 发布订阅模式适合**一对多的解耦场景**，但增加了事件处理的延迟。
- 状态机适合**状态明确的场景**，但状态太多时状态表会变得复杂。
- 策略模式适合**算法可替换的场景**，但增加了间接调用开销。

### 场景推演

**场景：BLE 连接成功后的系统响应**

1. BLE 协议栈检测到连接成功
2. 使用发布订阅模式：`event_publish(EVENT_BLE_CONNECTED, &conn_info)`
3. 两个模块同时收到通知：
   - UI 模块：更新屏幕显示"已连接"
   - LED 模块：LED 从闪烁变常亮
4. 如果使用回调模式，BLE 层需要分别调用两个函数，耦合度高
5. 使用发布订阅，BLE 层不需要知道谁关心这个事件，实现了完全解耦

---

## 第二层：原理、时序与约束

### 1. 回调模式（最常见）

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

**回调的注意事项**：
- 回调函数在中断上下文中执行时，不能做阻塞操作
- 回调函数中不能做耗时操作，应尽快返回
- 注册回调时要注意生命周期，避免回调已销毁的对象

### 2. 发布订阅模式（事件总线）

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

### 3. 状态机模式

```c
// 按键状态机
typedef enum {
    KEY_STATE_IDLE,       // 空闲
    KEY_STATE_PRESSED,    // 按下
    KEY_STATE_LONG_PRESS, // 长按
} key_state_t;

void key_state_machine(key_state_t state, key_event_t event) {
    switch (state) {
    case KEY_STATE_IDLE:
        if (event == KEY_DOWN) {
            start_timer(1000);  // 启动长按计时
            state = KEY_STATE_PRESSED;
        }
        break;
    case KEY_STATE_PRESSED:
        if (event == KEY_UP && timer_remain > 0) {
            handle_short_press();  // 短按
            state = KEY_STATE_IDLE;
        } else if (event == KEY_TIMEOUT) {
            handle_long_press();   // 长按
            state = KEY_STATE_LONG_PRESS;
        }
        break;
    case KEY_STATE_LONG_PRESS:
        if (event == KEY_UP) {
            state = KEY_STATE_IDLE;
        }
        break;
    }
}
```

### 4. 策略模式

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

---

## 第三层：真实 SDK 代码

### 回调模式在 SDK 中的应用

**文件路径**：`wq-adk/components/audio_service/api/aud_sv_api.h`

```c
// 音频数据回调
aud_sv_register_data_callback(callback);
```

**文件路径**：`wq-adk/components/apps/acore/ota/src/ota_transport_ble.c`

```c
// BLE GATT 写回调
static void write_callback(uint8_t index, const uint8_t *data, uint16_t len);
```

### 状态机模式在 SDK 中的应用

**文件路径**：`wq-adk/examples/glass/acore/app/app_customer_ext_trans/app_uart_cmd.c`

UART 命令解析使用状态机来处理帧接收：
- 等待帧头（0xAA）→ 接收长度 → 接收命令字 → 接收 payload → 校验 CRC → 处理命令

### 策略模式在 SDK 中的应用

**文件路径**：`wqcore/components/codec_factory/`

编解码器通过统一的 `audio_encoder_ops` 接口，支持 Opus、SBC、AAC、LC3 等的运行时切换。

### 反模式警告

| 反模式 | 现象 | 改进 |
|--------|------|------|
| 巨型 switch-case | 一个函数 500 行，全是 case | 改成状态表驱动 |
| 全局变量满天飞 | 哪个函数改了某个变量完全不知道 | 封装成结构体+接口函数 |
| 硬编码依赖 | 换一个芯片要改几百处 | 用 HAL 抽象硬件差异 |

---

## 第四层：正常与异常路径

### 正常路径

正确识别设计模式 → 按模式规范实现代码 → 代码清晰、可维护、易扩展

### 异常路径

| 问题 | 现象 | 根因 |
|------|------|------|
| 回调中做阻塞操作 | 系统卡死 | 回调在中断上下文中执行，不能阻塞 |
| 忘记取消订阅 | 模块释放后还被调用，野指针崩溃 | 生命周期管理不当 |
| 状态机状态遗漏 | 某些输入组合无响应 | 状态转移表未覆盖所有情况 |
| 策略模式过度使用 | 代码间接层太多，难以调试 | 模式滥用，策略数量少于 3 个时不需要 |
| 发布订阅滥用 | 事件太多，难以追踪数据流 | 不必要的事件全部走总线 |

---

## 第五层：调试方法

### 1. 回调调试

在回调函数入口添加日志，确认回调被正确触发。注意回调执行的上下文（中断级还是任务级）。

### 2. 状态机调试

打印状态转移日志：
```c
printf("STATE: %s -> EVENT: %s -> NEXT: %s\r\n",
       state_name(old_state), event_name(event), state_name(new_state));
```

### 3. 策略模式调试

在策略切换时打印当前使用的策略名称。

### 4. 发布订阅调试

在事件发布和接收时打印事件 ID 和订阅者数量。

---

## 第六层：实战练习

### 练习 1：在 SDK 中识别设计模式

在 SDK 中找出以下模式的使用实例：
- 回调模式：至少 3 个注册回调函数的 API
- 状态机模式：`app_uart_cmd.c` 中的帧解析状态机
- 策略模式：`codec_factory` 中的编解码器接口

### 练习 2：实现一个按键状态机

为 reGlasses 的三个按键（KEY_1、KEY_2、KEY_3）设计一个状态机，支持：
- 短按（<1s）
- 长按（>1s）
- 双击
请画出状态转移图，并写出 C 代码框架。

### 练习 3：分析事件总线设计

假设需要为 reGlasses 设计一个事件总线，以下事件需要通过总线分发：
- BLE 连接/断开
- 按键事件
- 充电状态变化
- 佩戴检测结果
请设计事件枚举、订阅者注册函数和事件发布函数。

### 练习 4：阅读真实源代码

打开 `wqcore/components/codec_factory/` 目录，找到编解码器策略接口的定义，分析 `audio_encoder_ops` 结构体中的函数指针。列出 Opus 和 SBC 编码器各自的 encode/decode 函数实现。

---

## 自测与验收

1. 嵌入式最常用的四种设计模式是什么？各举一个 SDK 中的例子。
2. 回调模式中，回调函数在中断上下文中执行时有什么限制？
3. 发布订阅模式相比回调模式有什么优势？
4. 状态机模式适合什么场景？不适合什么场景？
5. 策略模式在 SDK 编解码器中的具体应用是什么？
6. 什么是反模式？请举出嵌入式中的三个反模式。
7. 巨型 switch-case 应该用什么模式替代？
8. 全局变量满天飞的反模式应该怎么改进？
9. 硬编码依赖的反模式应该怎么改进？
10. 什么时候不适合使用策略模式？

---

## 延伸阅读

- [[data-structure-state-machine-数据结构与状态机]] — 状态机的详细实现
- [[ext-trans-Ext-Trans框架]] — SDK 的插件化 IO+Protocol 架构（策略模式）
- [[wq7036ax-audio-pipeline-WQ7036AX音频管道]] — 编解码器策略模式的应用
- [[interrupt-concurrency-中断并发同步]] — 回调与中断的关系

#flashcard
问：嵌入式最常用的四种设计模式是什么？
答：① 回调（观察者模式） ② 发布订阅（事件总线） ③ 状态机（状态模式） ④ 策略模式。

问：回调模式中，回调函数在中断上下文中执行时有什么限制？
答：不能做阻塞操作（如 I2C 读写、延时等待），不能做耗时操作，应尽快返回。耗时操作应发消息到任务中处理。

问：SDK 中策略模式的应用实例是什么？
答：`codec_factory` 组件的编解码器切换。通过统一的 `audio_encoder_ops` 接口，在 Opus、SBC、AAC 等编码器之间运行时切换。

问：三个常见的嵌入式反模式是什么？
答：① 巨型 switch-case（应改为状态表驱动） ② 全局变量满天飞（应封装为结构体+接口） ③ 硬编码依赖（应用 HAL 抽象硬件差异）。

问：发布订阅模式相比回调模式有什么优势？
答：解耦。事件发布者不需要知道谁订阅了事件，新增订阅者不需要修改发布者代码。适合一对多场景。