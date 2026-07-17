---
type: concept
created: 2026-07-16
tags: [protocol, i2c, bus, sensor, 总线, 传感器]
aliases: [I2C, IIC, Inter-Integrated Circuit]
---

# I2C 基础：从两根线到真实驱动

> **一句话结论**：I2C（Inter-Integrated Circuit，集成电路间总线）不是”把两个字节发出去”这么简单，它是一套由开漏电气结构、时钟和数据时序、地址、应答、器件寄存器约定以及控制器错误处理共同组成的总线协议。真正会用 I2C，意味着你能从原理图、波形、设备树或 SDK API 一直追到传感器读写结果。

## 30 秒先看懂

I2C 解决的是”多个设备用最少的线通信”的问题，就像一间教室里老师点名（地址），只有被喊到的学生回答。两根线（时钟和数据）都是开漏的——设备只能把线拉低，不能主动推高，高电平靠上拉电阻恢复。初学者先记住：I2C 只需要两根线就能挂几十个设备，但开漏结构限制了速度，一般不超过 400 kHz。

本篇的代码锚点来自两个真实工程：

- **WQ7036AX**：`/home/ys/wq7036a/wq-audio/wqcore/driver/periph/common/hal/i2c/wq_i2c.h`、`wq_i2c.c`、`wqcore/driver/periph/bbb/hw/i2c.h/.c`，以及 `wq-adk/examples/glass/acore/app/src/app_light_sensor.c`。
- **V861/reGlasses**：`/home/ys/aiglass/reglasses/bsp/drivers/vin/modules/sensor/ov13b10_mipi.c` 和 `device/configs/reglasses/linux-6.6-xuantie/board.dts`。

文中凡是标为“通用原理”的内容，是 I2C 协议本身；凡是标为“SDK 事实”的内容，只针对上述源码和配置，不应自动推广到别的芯片。

## 学完以后应该能做什么

学完本篇，不以“背出 I2C 是两根线”为验收标准，而要能完成下面这些事情：

1. 解释为什么 I2C 的 SDA/SCL 使用开漏（open-drain，设备只能主动拉低、释放后由上拉恢复高电平）。
2. 从一帧波形中指出 Start、地址、R/W 位、ACK、数据和 Stop 的位置。
3. 区分 7-bit 从设备地址、线上发送的地址字节，以及 Linux `i2c_msg.addr` 这三种表达。
4. 根据器件手册判断应该使用普通写、写后读、Repeated START（重复起始）还是连续读。
5. 看懂 WQ HAL 的轮询/中断/组合写读 API，知道每个 API 的边界和缓冲区生命周期。
6. 看懂 V861 Linux 驱动通过 `i2c_adapter`、`i2c_msg`、`i2c_transfer` 控制 TCA9539 的调用路径。
7. 面对 NACK、SDA 拉低、读回错误数据或偶发超时，提出可验证的假设，而不是先改寄存器碰运气。

## 前置知识

- 会读十六进制、位运算和 C 函数声明；可先看 [[c-core-C语言核心]]。
- 知道 GPIO 的输入、输出、上拉和复用；可先看 [[gpio-config-GPIO配置]]。
- 知道寄存器地址、复位值和时序图的基本含义；可先看 [[datasheet-reading-芯片手册阅读法]]。
- 如果要理解 WQ 驱动回调和应用任务，还需要 [[rtos-freertos-RTOS原理与FreeRTOS]]。

## 术语先讲清楚

| 术语 | 英文 | 在 I2C 中具体指什么 |
|---|---|---|
| 总线 | bus | 多个设备共享 SDA 和 SCL 的连接，而不是某一个控制器外设 |
| 控制器 | controller/master | 发起事务、产生 SCL、决定读写方向的一方；旧资料常写 master |
| 目标设备 | target/slave | 被地址选中、响应控制器的一方；旧资料常写 slave |
| 开漏 | open-drain | 输出低电平靠晶体管拉到地，输出高电平靠释放线路和上拉电阻恢复 |
| 上拉电阻 | pull-up resistor | 在设备都释放线路时把 SDA/SCL 拉到电源电压 |
| 事务 | transaction | 从 Start 到 Stop，或从 Start 到后续 Repeated START/Stop 的一组总线操作 |
| 应答 | ACK | 接收者在第 9 个时钟周期把 SDA 拉低，表示当前字节已接收 |
| 非应答 | NACK | 第 9 个时钟周期 SDA 保持高电平，可能表示设备不存在、拒绝数据或读完了 |
| 重复起始 | Repeated START | 不先发 Stop，直接再次发 Start，用于保持总线占有并切换读写阶段 |
| 时钟拉伸 | clock stretching | 目标设备把 SCL 拉低，要求控制器等待自己准备好 |
| 总线恢复 | bus recovery | 设备异常占线时，通过释放/切换引脚和产生时钟脉冲把线路恢复为空闲 |

---

## 第一层：用费曼技巧建立心智模型

### 1.1 I2C 像一间只有一块黑板的教室

把一条 I2C 总线想成一间教室：

- 控制器是老师，决定什么时候开始点名；
- SDA 是说话内容，SCL 是全班必须遵守的节拍；
- 每个目标设备有一个地址，老师先喊地址，只有被喊到的设备回答；
- 所有设备都可以把线路拉低，但没有设备直接强行把线路推高；
- 老师说“请确认”时，收到数据的设备在第 9 拍把 SDA 拉低，这就是 ACK；
- 老师发现没有人确认，或者读完了最后一个字节，就会看到 NACK。

这个类比有一个重要边界：I2C 不是 UART。UART 的 TX 可以直接输出高低电平，I2C 的高电平是“大家都释放线路以后由上拉电阻形成”的结果。因此 I2C 的速度、波形和设备数量会受到真实电气负载影响。

### 1.2 两根线分别做什么

- **SCL（Serial Clock Line，串行时钟线）**：控制器提供节拍；某些目标设备可以通过时钟拉伸暂时把它保持为低电平。
- **SDA（Serial Data Line，串行数据线）**：地址、R/W 位、数据和 ACK/NACK 都在这根线上传输。

SDA 的数据通常在 SCL 为低电平时改变，在 SCL 为高电平时保持稳定。Start 和 Stop 是两个特殊例外：

```text
空闲：SCL=1，SDA=1

Start：SCL 保持高，SDA 从 1 变 0
数据：SDA 在 SCL 低电平期间改变，SCL 高电平期间保持
Stop ：SCL 保持高，SDA 从 0 变 1
```

如果逻辑分析仪显示 SDA 在 SCL 高电平期间频繁跳变，优先怀疑：

- 抓到的并非正确的 I2C 解码；
- 信号受到噪声或边沿过慢影响；
- 控制器或 GPIO 复用配置错误；
- 起始/停止条件附近的边沿被误判。

### 1.3 为什么设备不能直接输出高电平

假设设备 A 强推高电平，设备 B 同时强推低电平，线路就可能形成很大的短路电流。I2C 使用开漏结构后，设备只负责两件事：

- 需要低电平时，把线拉到 GND；
- 需要高电平时，释放线路，不主动驱动高电平。

当所有设备释放线路，上拉电阻把线路拉高；当任意一个设备拉低，线路就是低电平。这种“低电平占优”的结构带来两个结果：

1. 多个设备可以安全地共享一根线。
2. 高电平不是主动驱动出来的，而是电阻和线路电容共同决定上升速度。

这就是为什么“电路图上连通了两根线”并不代表总线一定能跑到 400 kHz。

### 1.4 一个字节为什么需要 9 个时钟

I2C 一个字节传 8 个数据位，随后再占用第 9 个时钟周期传 ACK/NACK：

```text
SCL：  _/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_
SDA：  D7   D6   D5   D4   D3   D2   D1   D0   ACK
                                                   ↑
                                          接收者在第 9 拍回应
```

发送地址或数据时，接收方负责 ACK；读取数据时，控制器在每个接收字节之后决定 ACK 还是 NACK。典型读操作中，控制器对“还要继续读”的字节发 ACK，对最后一个字节发 NACK，然后发送 Stop。最后一个 NACK 不是错误，而是“我读完了”的协议表达。

---

## 第二层：电气层与速率边界

### 2.1 上拉电阻和总线电容

I2C 的高电平上升过程可以近似看成一个 RC（电阻-电容）充电过程：

- `R_p` 是上拉电阻；
- `C_b` 是总线总电容，包括控制器引脚、目标设备引脚、PCB 走线、连接器和探头；
- `R_p` 越小，上升更快，但低电平时器件需要吸收更大的电流；
- `R_p` 越大，静态功耗较小，但上升沿变慢，可能违反时序。

工程上常用一阶估算：

```text
t_r ≈ 0.8473 × R_p × C_b
R_p(max) ≈ t_r(max) / (0.8473 × C_b)
R_p(min) ≈ (VDD - V_OL(max)) / I_OL(max)
```

这些公式只是选型起点。最终仍要以具体 I2C 速率模式的最大上升时间、目标器件的低电平灌电流能力、电源电压和实测波形为准。

检查上拉时要问：

1. 线路上是否已经有板载上拉？多个模块的上拉是否并联后过小？
2. SDA 和 SCL 的电平是否与所有设备的 I/O 电压兼容？
3. 设备是否允许当前上拉值和当前总线速度？
4. 逻辑分析仪探头是否显著增加了 `C_b`？
5. 线路是否经过排线、连接器或较长走线，导致噪声和边沿变差？

### 2.2 速率模式不是“随便填一个数字”

常见 I2C 速率包括：

| 模式 | 常见上限 | 适用提醒 |
|---|---:|---|
| Standard-mode | 100 kbit/s | 兼容性最好，适合低速传感器 |
| Fast-mode | 400 kbit/s | reGlasses V861 的 TWI 配置中出现了 `400000`，但仍需结合器件和波形验证 |
| Fast-mode Plus | 1 Mbit/s | 需要控制器、器件、上拉和板级设计共同支持 |
| High-speed mode | 3.4 Mbit/s | 不是普通 I2C 外设都支持，不能只改软件速率 |

WQ HAL 的 `wq_i2c_config_t` 有 `baudrate` 字段，`wq_i2c.c` 会结合 `clock_get_xtal_clock_mhz()` 计算分频并调用硬件层的 `i2c_set_baudrate()`。这说明 SDK 允许软件配置目标速率，但不等于板上设备和上拉已经满足该速率。

### 2.3 内部上拉不等于外部电气设计完成

WQ HAL 的 `wq_i2c_gpio_config()` 会：

1. 通过 `gpio_claim_group()` 申请 SCL/SDA；
2. 调用硬件层 `i2c_gpio_config()` 设置复用；
3. 调用 `gpio_set_pull_mode(..., GPIO_PULL_MODE_UP)` 设置 GPIO 上拉模式。

这段代码说明 SDK 会配置内部 GPIO 上拉选项，但它不能证明内部上拉的阻值、驱动能力和上升时间已经满足 I2C 规范。实际硬件仍要检查原理图上的外部上拉和示波器/逻辑分析仪波形。

### 2.4 电平转换和混合电压

当控制器是 1.8 V、目标设备是 3.3 V 时，不能简单把 SDA/SCL 直接相连。常见方案是使用适合开漏总线的双向电平转换器，并让两侧分别有对应电压的上拉。

需要特别注意：

- 普通单向电平转换器不一定适合 SDA，因为 SDA 是双向的；
- SCL 在支持时钟拉伸时也可能由目标设备拉低，因此也不能默认它是单向输出；
- 上电顺序和未上电设备的钳位二极管可能导致线路被异常拉低；
- “能读到一次设备 ID”不能证明电压、电平和时序长期可靠。

---

## 第三层：协议层逐拍理解

### 3.1 地址字节和数据字节

I2C 通常用 7-bit 目标地址 `A6:A0` 标识设备。控制器在线上发送的第一个字节是：

```text
bit7...bit1 = 7-bit address
bit0        = R/W

写地址字节 = (address << 1) | 0
读地址字节 = (address << 1) | 1
```

这里最容易混淆的是三个概念：

| 表达 | 例子 | 谁通常使用 |
|---|---|---|
| 7-bit 设备地址 | `0x3A` | 数据手册、Linux `i2c_msg.addr` 常见表达 |
| 线上写地址字节 | `0x74` | 总线波形中第一个字节，等于 `0x3A << 1` |
| 线上读地址字节 | `0x75` | 总线波形中第一个字节，最低位为 1 |

不能看到一个 `0x74` 就直接断言它一定是 7-bit 或 8-bit 地址，必须看它出现在哪一层。V861 的 TCA9539 代码在 `struct i2c_msg` 中使用 `msg.addr = TCA9539_ADDR`，其中 `TCA9539_ADDR` 是 `0x74`；这是 Linux 驱动源码的事实。其他传感器驱动可能使用厂商 CCI/VIN 约定的地址表达，必须以该驱动的接口和设备树约定为准。

### 3.2 写寄存器事务

典型的“向寄存器写一个字节”是：

```text
Start
→ 目标地址 + W
→ ACK
→ 寄存器地址
→ ACK
→ 数据字节
→ ACK
→ Stop
```

但这只是协议层的骨架。具体器件可能要求：

- 8 位、16 位甚至 24 位寄存器地址；
- 高字节先发或低字节先发；
- 写入多个字节时地址自动递增，或者必须遵守页边界；
- 写后需要等待内部 EEPROM/Flash 完成，期间设备会 NACK；
- 写入某个控制寄存器前必须先解除复位或打开电源。

因此，“I2C 写成功”只表示总线事务被接收，不表示器件功能已经按预期生效。

### 3.3 随机读和连续读

常见的寄存器随机读是组合事务：

```text
Start
→ 目标地址 + W
→ ACK
→ 寄存器地址
→ ACK
→ Repeated START
→ 目标地址 + R
→ ACK
→ 数据 0
→ 控制器 ACK
→ 数据 1
→ 控制器 NACK
→ Stop
```

Repeated START 的意义是：在不释放总线的情况下从“写寄存器地址”切换到“读数据”。WQ HAL 直接提供 `wq_i2c_write_read_poll()` 和中断模式的 `wq_i2c_write_read()`，其接口文档明确包含“先写设备地址阶段，再读数据阶段”，适合承载这种组合读；最终是否产生 Repeated START，应结合硬件层 `I2C_MODE_WRITE_READ` 的实现和逻辑分析仪验证。

### 3.4 ACK/NACK 的位置和含义

| 位置 | ACK/NACK 的发送者 | 常见含义 |
|---|---|---|
| 地址字节后 | 被寻址目标设备 | ACK 表示地址匹配且准备响应；NACK 可能是地址错误、设备未上电或设备忙 |
| 写入寄存器地址后 | 目标设备 | ACK 表示接受这个地址字节，不保证寄存器值合法 |
| 写入数据后 | 目标设备 | NACK 可能表示只读寄存器、非法值、内部忙或事务不符合器件要求 |
| 控制器读到非最后字节后 | 控制器 | ACK 表示还要继续读 |
| 控制器读到最后字节后 | 控制器 | NACK 表示读到此结束，随后通常发 Stop |

### 3.5 时钟拉伸和多主仲裁

**时钟拉伸**是目标设备把 SCL 保持低电平，告诉控制器“我还没准备好”。控制器必须先确认物理线路真的回到高电平，才能继续下一拍。不是所有控制器、目标设备和系统配置都允许它。

WQ 的 `wq_i2c.h` 在 `CONFIG_BUILD_SERIES_HORNET` 下提供 `wq_i2c_wait_enable()`，注释写明它用于决定是否允许目标设备把控制器置于等待状态。这是一个真实的芯片系列差异，不应泛化到所有 WQ 芯片。

**多主仲裁**中，多个控制器可能同时开始发送。因为低电平占优，一个控制器发送 1 却读到 0，就知道自己失去仲裁。很多嵌入式产品只使用单控制器，此时仍要知道这个机制存在，但不能假设当前 SDK 已经为多主场景提供完整支持。

---

## 第四层：WQ7036AX SDK 实战

### 4.1 WQ HAL 的软件分层

WQ 的 I2C 代码可以按三层理解：

```text
glass 应用
  app_light_sensor.c
    ↓ light_sensor_init / light_sensor_set_enable / event callback
传感器抽象或设备驱动
    ↓ wq_i2c_* HAL
wqcore/driver/periph/common/hal/i2c/wq_i2c.c
    ↓ i2c_set_mode / i2c_fifo_* / i2c_transfer_start / IRQ
wqcore/driver/periph/bbb/hw/i2c.c + i2c_master_reg.h
```

这条分层很重要：应用层不应该因为要读一个光照值，就直接操作 I2C 寄存器；硬件层也不应该知道“光照值”的业务含义。

### 4.2 真实 HAL 接口：先从头文件读契约

以下是 `wqcore/driver/periph/common/hal/i2c/wq_i2c.h` 中的真实接口形态，省略版权头和注释，只保留用于学习的声明：

```c
WQ_RET wq_i2c_init(WQ_I2C_PORT port);
WQ_RET wq_i2c_open(WQ_I2C_PORT port,
                   const wq_i2c_gpio_cfg_t *gpio,
                   const wq_i2c_config_t *cfg);

WQ_RET wq_i2c_write_poll(WQ_I2C_PORT port,
                         uint16_t dev_addr,
                         const uint8_t *buffer,
                         uint32_t length);

WQ_RET wq_i2c_read_poll(WQ_I2C_PORT port,
                        uint16_t dev_addr,
                        uint8_t *buffer,
                        uint32_t length);

WQ_RET wq_i2c_write_read_poll(WQ_I2C_PORT port,
                              uint16_t dev_addr,
                              const uint8_t *write_buf,
                              uint8_t write_length,
                              uint8_t *read_buf,
                              uint32_t read_length);
```

从这组声明可以读出几个工程约束：

- 初始化和打开是两个阶段；调用 `open` 前必须已经完成 `init`；
- `gpio` 和 `cfg` 是外部传入的总线配置，不是函数内部自动猜出来的；
- 普通读写和组合写读是不同的 API；
- `write_read_poll` 的写缓冲区长度限制为 1—4 字节地址宽度，读写数据长度也有头文件规定的上限；
- `wq_i2c_write`/`read` 的回调模式要求调用方保证回调完成前缓冲区仍然有效。

不要把 `dev_addr` 直接理解成“永远传 8-bit 地址”。WQ 实现里有 `i2c_dev_addr_mode_union`，把地址和读写模式放在一个 7+1 位结构中；真正使用某个具体设备时，要同时看 HAL 实现、设备驱动调用点和波形。

### 4.3 真实实现：GPIO、速率、NACK 和 busy

`wqcore/driver/periph/common/hal/i2c/wq_i2c.c` 的 `wq_i2c_gpio_config()` 做了真实的资源管理：

```c
if (gpio_claim_group(gpio_group, 2, false) != WQ_RET_OK) {
    return WQ_RET_INVAL;
}

i2c_gpio_config(port, gpio->scl, gpio->sda);

gpio_set_pull_mode(gpio->scl, GPIO_PULL_MODE_UP);
gpio_set_pull_mode(gpio->sda, GPIO_PULL_MODE_UP);
```

这段代码体现了三个关键点：

1. SCL/SDA 不是普通变量，而是需要被独占申请的硬件资源；
2. GPIO 复用和 I2C 控制器配置必须成对出现；
3. SDK 设置了 GPIO 上拉选项，但仍不能代替板级外部上拉的设计和实测。

`wq_i2c_config()` 则使用配置中的 `baudrate` 计算时钟分频，并调用 `i2c_set_nack_wait_time()` 设置 NACK 等待窗口。驱动还维护 `is_open` 和 `is_busy` 状态；轮询发送前会检查端口是否已打开、当前传输是否占用，并在超时或 NACK 时清理状态。

这告诉我们：一个“读传感器”的函数至少要处理三类失败：

- API 调用前置条件失败：端口未初始化、GPIO 申请失败；
- 总线状态失败：端口 busy、目标 NACK、等待超时；
- 器件语义失败：总线收到了数据，但寄存器值、芯片 ID 或状态位不符合预期。

### 4.4 应用层不是直接读总线

`wq-adk/examples/glass/acore/app/src/app_light_sensor.c` 展示了应用层的真实使用方式：

```c
static WQ_RET app_light_sensor_init(void) {
    WQ_RET ret = light_sensor_init(light_sensor_event_handler);
    if (ret != WQ_RET_OK) {
        DBGLOG_APP_LS_ERR("[LS] init failed: %d\n", ret);
        return ret;
    }

    ret = light_sensor_set_enable(true);
    return ret;
}
```

应用层拿到的是 `light_sensor_init()`、`light_sensor_set_enable()` 和事件回调，而不是 `wq_i2c_read_poll()`。当回调收到 `LIGHT_SENSOR_EVT_ERROR` 时，应用记录 `[LS] I2C error`；这是一条从底层总线错误向上层业务传播的真实路径。

学习这个例子时，要继续向下追：

1. `light_sensor_init()` 实际注册了哪个设备驱动？
2. 设备驱动如何选择 I2C 端口和目标地址？
3. 读写使用轮询还是中断模式？
4. 设备 NACK 时，底层返回什么 `WQ_RET`，上层是否重试或降级？
5. 数据回调运行在哪个任务上下文，是否可能与控制命令并发访问同一个总线？

如果当前 SDK 中的传感器驱动没有公开给你，就不能在知识库中虚构其内部 API；应把“应用层真实调用已确认，底层设备驱动仍需继续追源码”写清楚。

### 4.5 WQ HAL 的轮询和中断模式取舍

| 模式 | WQ 接口 | 优点 | 风险 |
|---|---|---|---|
| 轮询 | `wq_i2c_write_poll`、`read_poll`、`write_read_poll` | 调用链直观，适合初始化和短事务 | 会占用当前任务，超时策略必须明确 |
| 中断 | `wq_i2c_write`、`read`、`write_read` | 传输期间可让出 CPU，适合异步工作 | 缓冲区生命周期、回调上下文和并发保护更复杂 |
| 硬件寄存器层 | `i2c_set_mode`、`i2c_fifo_write/read`、`i2c_transfer_start` | 适合理解控制器和定位底层问题 | 应用层直接使用会破坏分层和资源管理 |

WQ 硬件层的 `I2C_MODE` 包含 `I2C_MODE_WRITE`、`READ`、`BUSRT`、`WRITE_READ` 和 `STOP`；`I2C_INT_TYPE` 包含完成、FIFO、NACK 等状态。这些符号可以用来读懂中断状态机，但不应该在应用文档中伪造一套新的 `i2c_transfer()` API。

---

## 第五层：V861/reGlasses 的 Linux I2C 实战

### 5.1 Linux I2C 和 WQ HAL 的根本区别

WQ7036AX 示例是 MCU/SoC HAL 风格：应用或设备抽象调用 `wq_i2c_*`。V861 Linux 则通过内核 I2C 子系统访问总线：

```text
摄像头驱动 / GPIO 扩展逻辑
  ↓ struct i2c_msg + i2c_transfer
Linux I2C core
  ↓ struct i2c_adapter
V861 TWI 控制器驱动
  ↓
TWI1/TWI2 引脚和真实总线
```

Linux 的 `struct i2c_msg.addr` 通常使用 7-bit 目标地址，读方向通过 `I2C_M_RD` 标志表示；它不是把 R/W 位手动塞进地址值。这个层次差异必须和 WQ HAL 的 `dev_addr` 调用约定分开记录。

### 5.2 reGlasses 的 TWI 配置事实

`/home/ys/aiglass/reglasses/device/configs/reglasses/linux-6.6-xuantie/board.dts` 中，当前板级配置包含：

```dts
&twi1 {
    clock-frequency = <400000>;
    pinctrl-0 = <&twi1_pins_default>;
    pinctrl-names = "default";
    twi_drv_used = <1>;
    status = "okay";

    gpio_ext: tca9539@74 {
        compatible = "nxp,pca9539";
        reg = <0x74>;
        gpio-controller;
        #gpio-cells = <2>;
        status = "okay";
    };
};
```

这段配置能支持的结论是：

- reGlasses 使用 TWI1 挂载一个兼容 PCA9539 的 TCA9539 GPIO 扩展器；
- 设备树给 TWI1 配置了 400 kHz；
- `reg = <0x74>` 是 Linux 设备节点的地址表达；
- GPIO 扩展器以 `gpio-controller` 身份向其他驱动提供 GPIO。

它不能单独证明板上的外部上拉阻值、总线波形或所有设备都能稳定运行；那些要看原理图和实测数据。

### 5.3 真实 Linux 代码：用两个 `i2c_msg` 完成寄存器读

`/home/ys/aiglass/reglasses/bsp/drivers/vin/modules/sensor/ov13b10_mipi.c` 中的 TCA9539 访问逻辑使用 Linux 标准接口：

```c
msg[0].addr = TCA9539_ADDR;
msg[0].flags = 0;
msg[0].buf = &addr;
msg[0].len = 1;

msg[1].addr = TCA9539_ADDR;
msg[1].flags = I2C_M_RD;
msg[1].buf = val;
msg[1].len = 1;

ret = i2c_transfer(adap, msg, 2);
return ret == 2 ? 0 : -EIO;
```

这个片段很适合用来理解“寄存器读不是一次普通 read”：

1. 第一条消息先发送寄存器地址；
2. 第二条消息带 `I2C_M_RD`，读取寄存器数据；
3. 两条消息交给 `i2c_transfer()`，由 Linux I2C core 组织为一个组合事务；
4. 返回值是成功完成的消息数量，期望值是 2；不等于 2 时转换为 `-EIO`。

相同文件还把 TCA9539 的 `OUT0 = 0x02`、`CFG0 = 0x06` 和摄像头控制位定义为宏，并通过 `tca9539_update_bits()` 先读后改再写，避免覆盖同一寄存器中的其他 GPIO 位。这个“读-改-写”模式比直接写常量更安全，但它仍然要考虑并发访问和总线错误。

### 5.4 TCA9539 与摄像头启动的关系

在 reGlasses 中，TCA9539 不只是“一个 I2C 例子”，它参与摄像头上电/复位路径：

- TCA9539 地址为 `0x74`；
- `ov13b10_mipi.c` 定义了 Camera2 的 reset/pwdn 控制位；
- 设备树通过 `gpio_ext` 暴露 GPIO 控制器；
- 摄像头驱动在识别和配置传感器前，需要先让相关 GPIO 和供电状态满足要求；
- 摄像头传感器本身还有自己的 I2C/CCI 寄存器读写，不能把 GPIO 扩展器地址和传感器地址混为一谈。

这体现了嵌入式 I2C 最容易被忽略的一层：总线事务本身可能完全正确，但设备仍然不工作，因为复位、供电、时钟、MIPI 数据链路或器件初始化顺序不满足要求。

---

## 第六层：器件寄存器适配

### 6.1 设备手册中的地址宽度

“寄存器地址”不是 I2C 目标地址。常见组合如下：

```text
目标地址 + 写方向
    ↓
寄存器地址（可能 1/2/3/4 字节）
    ↓
寄存器数据（可能 1/2/4 字节或变长）
```

WQ HAL 的 `wq_i2c_write_read_poll()` 允许写入长度为 1—4 字节的寄存器地址，这正是因为不同器件的内部地址宽度不同。驱动还在硬件层定义了 `I2C_ADDR_WIDTH_1BYTE` 到 `I2C_ADDR_WIDTH_4BYTE`。

使用前必须从器件手册确认：

- 寄存器地址是 8 位还是 16 位；
- 多字节地址的大小端顺序；
- 连续读取时地址是否自动递增；
- 是否允许跨页写；
- 写入后是否需要等待内部操作完成；
- 读状态寄存器是否会清除中断或改变状态；
- 是否需要先写命令再读数据，而不是直接读某个地址。

### 6.2 初始化时序比“写几个寄存器”更重要

一个真实器件初始化通常包含：

1. 使能电源和参考时钟；
2. 释放或保持复位；
3. 等待数据手册规定的启动时间；
4. 读取 Chip ID，确认通信和器件型号；
5. 写入模式、采样率、量程或中断阈值；
6. 清理旧状态；
7. 使能数据就绪或开始采样；
8. 轮询状态位并读取数据。

如果第 1—3 步错误，后面看到的 NACK 可能不是地址错误；如果第 4 步没有做，后面写错器件也可能看起来“通信成功”。

### 6.3 读写数据的端序

一个两字节寄存器值可能按以下两种顺序返回：

```text
大端寄存器：high byte → low byte
小端寄存器：low byte → high byte
```

不能根据 CPU 是小端就直接决定总线数据顺序。总线顺序由器件手册定义；驱动的拼接代码必须与之对应。调试时可以选择已知固定值的寄存器，分别打印原始字节和最终整数，避免只看最终换算值。

---

## 第七层：故障诊断

### 7.1 先看线路，再看协议，再看软件

遇到 I2C 故障，按证据顺序排查：

```text
线路空闲吗？
  ├─ SDA/SCL 任一为低 → 查上电、复位、短路、被占线设备、总线恢复
  └─ 两线均为高 → 抓一次完整事务

有 Start 和地址吗？
  ├─ 没有 → 查 GPIO 复用、时钟、控制器 open/init、任务是否执行
  └─ 有 → 看地址字节和 R/W 方向

地址后 ACK 吗？
  ├─ NACK → 查地址表达、电源、复位、设备是否忙、总线是否选错
  └─ ACK → 继续看寄存器地址和数据

数据正确吗？
  ├─ 不正确 → 查寄存器宽度、端序、时序、初始化和数据有效条件
  └─ 正确但业务失败 → 查上层状态机、电源、时钟、IRQ 和数据解释
```

### 7.2 典型现象与证据

| 现象 | 第一假设 | 需要的证据 | 不要先做什么 |
|---|---|---|---|
| 两线空闲时 SDA 一直低 | 目标设备卡在传输中、复位异常或线路短路 | 万用表、示波器、逐个断开设备 | 不要只提高波特率 |
| 地址后 NACK | 地址格式、电源、复位或设备忙 | 地址字节波形、设备电源、手册时序 | 不要盲目把地址左移两次 |
| 寄存器写成功但读回不对 | 地址宽度/端序/页边界/写完成等待错误 | 原始字节、读写事务波形、手册 | 不要只改最终换算公式 |
| 偶发 NACK | 上升时间、噪声、供电、目标内部忙、并发访问 | 长时间波形、温度/负载、任务调用记录 | 不要只加无限重试 |
| WQ API 返回 busy | 同一端口被并发使用或上一次事务未收尾 | `is_busy` 状态、任务调用关系、回调完成时刻 | 不要直接清零全局状态 |
| V861 `i2c_transfer` 返回值不是消息数 | adapter/目标设备/总线事务失败 | `ret`、内核日志、TWI 波形 | 不要把返回值当字节数解释 |

### 7.3 NACK 和超时处理的工程边界

WQ `wq_i2c.c` 中的 `wq_check_timeover()` 会检查等待计数和 NACK 中断，并清理 NACK 状态与 FIFO；代码还通过 `wq_i2c_clear_nack_count()` 复位控制器并恢复分频和 NACK 等待设置。这不是“发生错误就重试三次”那么简单，而是：

1. 识别错误来源；
2. 清除控制器内部状态；
3. 保证下一次事务从干净状态开始；
4. 将失败返回给上层，由上层决定重试、降级还是报告设备故障。

重试必须有上限和原因记录。对于设备未上电、地址错误或复位未释放，重试只会扩大故障时间。

### 7.4 总线恢复应该验证什么

I2C 目标设备可能在收到字节中途复位，导致它以为自己还持有 SDA。通用总线恢复的思路是：

1. 停止控制器自动事务并确认当前没有合法事务在进行；
2. 将 SCL/SDA 切换为符合开漏语义的 GPIO 控制；
3. 在 SDA 被释放前产生有限个 SCL 脉冲，让目标设备移出残留状态；
4. 产生一个合法的 Stop 条件；
5. 重新初始化控制器和引脚复用；
6. 重新读取一个已知 ID 或状态寄存器验证恢复结果。

这是恢复算法，不代表 WQ 或 V861 当前工程已经提供同名的通用 API。若实际项目没有实现，应在文档中写“需要补充的能力”，不能把伪代码写成现成 SDK。

---

## 第八层：练习与验收

### 练习一：从波形标注一笔寄存器读

准备一份真实 I2C 逻辑分析仪抓包，标出：

- Start；
- 地址字节和 R/W 位；
- 每个 ACK/NACK；
- 寄存器地址；
- Repeated START；
- 最后一个数据字节和控制器 NACK；
- Stop。

**通过标准**：能解释每一拍是谁驱动 SDA、下一拍为什么出现，而不是只认出一串十六进制数。

### 练习二：读 WQ HAL 的 API 契约

打开 `wqcore/driver/periph/common/hal/i2c/wq_i2c.h`，回答：

1. `wq_i2c_init()` 和 `wq_i2c_open()` 的先后顺序是什么？
2. 轮询和回调模式的缓冲区约束有什么区别？
3. `write_read_poll` 为什么要同时传写缓冲区和读缓冲区？
4. `wq_i2c_wait_enable()` 为什么被条件编译限制在 Hornet？

**通过标准**：能把头文件声明对应到 `wq_i2c.c` 的状态字段、错误处理和硬件层调用。

### 练习三：追踪 WQ glass 光传感器调用链

从 `wq-adk/examples/glass/acore/app/src/app_light_sensor.c` 开始，向下查找 `light_sensor_init()` 的实现，画出：

```text
app_light_sensor_init
  → light_sensor_init
  → 传感器初始化/寄存器读写
  → light_sensor_event_handler
  → ALS/PS 数据或 LIGHT_SENSOR_EVT_ERROR
```

**通过标准**：能说出 I2C 错误如何从底层传播到应用层；如果中间实现不在当前可见源码中，要明确指出缺口。

### 练习四：对照 V861 的 TCA9539

阅读 `aiglass/reglasses/bsp/drivers/vin/modules/sensor/ov13b10_mipi.c` 和 `board.dts`，回答：

1. TCA9539 挂在哪条 TWI 总线上？
2. `i2c_transfer(adap, msg, 2)` 的两条消息分别做什么？
3. 为什么 `msg.addr` 不能直接按“线上地址字节”理解？
4. TCA9539 的 GPIO 输出状态如何影响摄像头 reset/pwdn？

**通过标准**：能把设备树、Linux I2C API、GPIO 扩展器和摄像头驱动启动顺序串起来。

### 练习五：设计故障定位实验

给出一个现象：设备 ID 偶尔读不到，但把总线降到 100 kHz 后概率下降。要求写出至少三个可证伪假设：

- 上拉和总线电容导致上升时间不满足；
- 设备电源或复位时序偶发不满足；
- 任务并发访问导致控制器状态或器件内部状态被打断。

每个假设都要写出要抓的波形、日志或代码证据。

## 自测题

1. **为什么 I2C 需要上拉？**
   - 因为设备采用开漏结构，只主动拉低；线路释放后由上拉恢复高电平，同时允许多个设备安全共享总线。
2. **ACK 是谁发的？**
   - 谁接收当前字节，谁在第 9 个时钟周期发 ACK 或 NACK；读取数据时，控制器是接收者，所以最后一个字节由控制器发 NACK。
3. **7-bit 地址和线上地址字节有什么区别？**
   - 7-bit 地址是设备身份；线上地址字节把它左移一位，并把最低位作为 R/W 位。Linux `i2c_msg.addr` 通常保存前者。
4. **为什么读寄存器常用 Repeated START？**
   - 先用写方向告诉设备要读哪个寄存器，再不释放总线地切换到读方向；具体器件是否支持这种事务要看手册。
5. **WQ HAL 的 `GPIO_PULL_MODE_UP` 能否证明板子上拉设计正确？**
   - 不能。它只是 SDK 的 GPIO 上拉配置；阻值、总电容、上升时间和电平兼容仍需看硬件设计和实测。
6. **V861 的 `i2c_transfer()` 返回 2 说明什么？**
   - 在 `ov13b10_mipi.c` 的 TCA9539 读操作中，说明传入的两条 `i2c_msg` 都完成；它不是返回读取了 2 个字节。

## 常见反例

- 把 SCL 写成 SCK。SCK 常用于 SPI；I2C 的时钟线是 SCL。
- 把所有 `0x74` 都当作同一种地址格式。必须先确认它是数据手册地址、线上字节、Linux `msg.addr` 还是厂商 CCI 参数。
- 只看 ACK，不读回 Chip ID 或状态位。总线收到了不代表设备配置正确。
- 发现 NACK 就无限重试。设备未上电、地址错和复位未释放都不会因为重试自动修好。
- 应用层直接操作 I2C 寄存器。这样会绕过设备驱动、并发保护、错误传播和资源管理。
- 把内部 GPIO 上拉当成外部电气设计。高频率、长走线和多设备负载必须靠计算和波形验证。

## 参考资料

- NXP, *UM10204 I2C-bus specification and user manual*：https://www.nxp.com/docs/en/user-guide/UM10204.pdf
- Linux kernel I2C documentation：https://www.kernel.org/doc/html/latest/i2c/index.html
- [[gpio-config-GPIO配置]] — GPIO 复用、输入输出和上拉
- [[platform-driver-外设驱动框架]] — Linux 设备与驱动匹配
- [[devicetree-DeviceTree设备树]] — V861 设备树配置
- [[debug-tools-常用调试工具链]] — 逻辑分析仪和示波器
- [[elm2713-ELM2713光传感器]] — reGlasses 传感器项目映射
- [[snippet-i2c-I2C读写寄存器]] — 项目代码片段

#flashcard

问：I2C 一个数据字节为什么需要第 9 个时钟？
答：第 9 拍用于接收者发送 ACK/NACK，表示当前字节已接收或不再接受/继续。

问：Linux `i2c_msg.addr` 要不要手动左移一位？
答：Linux I2C API 通常使用 7-bit 地址，读方向由 `I2C_M_RD` 表示；不要把线上地址字节直接传进去，除非具体厂商接口另有约定。

问：WQ 的 `wq_i2c_write_read_poll()` 解决了什么问题？
答：它提供先写设备内部地址、再读数据的组合操作接口；是否产生 Repeated START 仍应结合硬件实现和波形确认。

问：I2C 设备 ID 读不到，最先看什么？
答：先看 SDA/SCL 是否空闲、地址后是否 ACK，再看电源/复位、上拉和波形，最后检查寄存器地址宽度、初始化顺序和上层解释。
