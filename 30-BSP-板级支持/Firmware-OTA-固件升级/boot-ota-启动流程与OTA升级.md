# 启动流程与 OTA 升级

**一句话结论（20% 核心）**：启动流程是芯片从复位到 main() 的全过程——BootROM → Bootloader → APP，每一级验证下一级的合法性再跳转；OTA（Over-The-Air，空中升级）是不插线通过无线方式更新固件，核心要解决"安全下载、完整写入、断电回滚"三个问题。

---

## 第一层：核心认知

### 1.1 启动流程：三级跳转

```
上电/复位
   ↓
[1] BootROM（芯片内置，不可修改）
   │  验证 Bootloader 签名
   ↓
[2] Bootloader（Flash 中的第一段程序）
   │  验证 APP 固件签名，选择启动哪个版本
   ↓
[3] APP（用户应用程序，从 main() 开始）
```

**为什么要三级？**

- **BootROM**：芯片出厂时烧入，不可修改。它只信任有合法签名的 Bootloader。这是安全启动（Secure Boot）的根。
- **Bootloader**：可以更新。负责选择启动哪个 APP 版本、执行 OTA 升级。
- **APP**：用户实际的应用程序，可以频繁更新。

### 1.2 费曼类比

启动流程就像公司门禁：

1. **BootROM**：大门保安——只认有工牌（签名）的人进。
2. **Bootloader**：前台——检查来访者的预约信息，决定带你去哪个会议室。
3. **APP**：会议室里的实际工作。

OTA 升级就像远程更新会议室里的资料：

1. 从云端下载新版资料（下载固件）
2. 检查资料是否完整（校验固件）
3. 放到备用会议室（写入新分区）
4. 通知前台下次带人去新会议室（更新启动标记）

### 1.3 OTA 升级基本流程

```
1. 下载新固件（通过蓝牙/WiFi/4G）
   ↓
2. 校验完整性（CRC/SHA256/签名验证）
   ↓
3. 写入 Flash 新分区（不能覆盖正在运行的固件）
   ↓
4. 更新启动标记（告诉 Bootloader "下次启动新版本"）
   ↓
5. 复位重启
   ↓
6. Bootloader 读取标记，启动新固件
   ↓
7. 新固件自检验证成功 → 标记为"已确认"
   新固件自检失败 → 回滚到旧版本
```

### 1.4 如果只记得一件事

> 启动 = BootROM → Bootloader → APP 三级跳转；OTA = 下载 → 校验 → 写新分区 → 重启切换。核心原则：永远不能覆盖正在运行的固件，升级失败必须能回滚。

---

## 第二层：实战理解

### 2.1 WQ7036A 启动流程详解

WQ7036A 是三核 SoC，启动流程更复杂：

```
上电/复位
   ↓
BootROM 运行（芯片内置）
   ↓
加载 SBL（Secondary Boot Loader）到 ACORE
   ↓
SBL 初始化硬件（时钟、Flash、GPIO）
   ↓
SBL 加载 ACORE APP → ACORE 跳到 main()
   ↓
ACORE main() 初始化 IPC
   ↓
ACORE 通过 IPC 启动 BCORE（加载 BCORE 固件，释放复位）
   ↓
ACORE 通过 IPC 启动 DCORE（加载 DCORE 固件，释放复位）
   ↓
三核全部运行
```

**WQ7036A 的 Flash 分区布局**：

```
Flash 空间：
├─ SBL 区（不可修改，出厂烧入）
├─ Key-Value 区（配置参数）
├─ ACORE APP 区
├─ BCORE APP 区
├─ DCORE APP 区
└─ OTA 暂存区（下载新固件用）
```

### 2.2 A/B 双分区升级

最安全的 OTA 方案——两个分区交替使用：

```
当前运行：分区 A（版本 1.0）
OTA 下载：写入分区 B（版本 2.0）
重启后：  从分区 B 启动（版本 2.0）
如果失败：回滚到分区 A（版本 1.0）
下次 OTA：写入分区 A（版本 3.0）
```

| 方案 | 优点 | 缺点 |
|---|---|---|
| **A/B 双分区** | 回滚可靠，不怕断电 | 需要两倍 Flash 空间 |
| **单分区 + 备份** | 省空间 | 回滚需要重新写入旧版本，慢 |
| **差分升级** | 下载量小 | 需要精确的版本匹配 |

### 2.3 OTA 断电保护

OTA 最怕的就是写到一半断电：

| 断电时刻 | 后果 | 解决方法 |
|---|---|---|
| 下载中断 | 新固件不完整 | 校验失败，不切换，继续用旧版本 |
| 写入 Flash 中断 | 新分区数据损坏 | CRC 校验失败，回滚旧分区 |
| 切换标记写入中断 | 不知道启动哪个 | 标记写入用"原子操作"（见下方） |

**原子标记写入**：

```c
// 启动标记写入的安全方式
// 不能直接写 magic + version，否则可能写到一半断电

// 错误做法：
struct boot_flag { uint32_t magic; uint32_t version; };
flash_write(BOOT_FLAG_ADDR, &flag, sizeof(flag));  // 可能写到一半断电

// 正确做法：用两阶段写入
// 第 1 步：清除旧标记
flash_erase(BOOT_FLAG_SECTOR);
// 第 2 步：写入新标记（一次写入，不擦除）
flash_write(BOOT_FLAG_ADDR, &flag, sizeof(flag));
// 如果第 1 步后断电：标记无效，Bootloader 启动默认分区
// 如果第 2 步完成：标记有效，Bootloader 启动新分区
```

### 2.4 固件签名与加密

| 安全措施 | 防什么 | 怎么做 |
|---|---|---|
| **CRC32/SHA256** | 数据损坏（传输错误） | 下载后校验哈希 |
| **数字签名（RSA/ECDSA）** | 固件被篡改/伪造 | 用私钥签名，芯片用公钥验签 |
| **固件加密（AES）** | 固件被逆向 | 芯片内解密后执行 |

**安全启动链**：

```
BootROM 内置公钥（不可篡改）
   ↓ 验签
Bootloader（必须签名正确才能运行）
   ↓ 验签
APP 固件（必须签名正确才能运行）
```

### 2.5 WPK 固件包格式

WQ7036A 的最终固件包是 `.wpk` 格式（本质是 ZIP）：

```
firmware-v1.0.0.wpk (ZIP)
├── acore.elf.bin     # ACORE 固件二进制
├── bcore.elf.bin     # BCORE 固件二进制
├── dcore.elf.bin     # DCORE 固件二进制
├── memory_config.json # Flash 分区地址配置
├── version.txt       # 版本信息
└── manifest.json     # 元数据（校验和、兼容性）
```

OTA 升级时，手机端/云端下载 .wpk 文件，解包后分别写入三核的 Flash 分区。

### 2.6 常见坑

1. **OTA 分区大小不够**：新固件比旧的大，写入溢出到相邻分区。
2. **版本号比较逻辑有 bug**：`"1.10" < "1.9"`（字符串比较 vs 数值比较）。
3. **升级完忘记清除旧标记**：下次启动又跑到旧版本。
4. **Bootloader 本身无法 OTA**：Bootloader 出了 bug 就只能返厂。

---

## 第三层：深入扩展

### 3.1 Bootloader 跳转机制

Bootloader 跳转到 APP 时需要做的事：

```c
void bootloader_jump_to_app(uint32_t app_addr)
{
    // 1. 关闭所有中断
    __disable_irq();

    // 2. 关闭所有外设（APP 期望初始状态）
    disable_all_peripherals();

    // 3. 读取 APP 的栈顶地址（存在 APP 向量表的第一个 word）
    uint32_t stack_top = *(uint32_t *)app_addr;

    // 4. 读取 APP 的入口地址（向量表第二个 word = Reset Handler）
    uint32_t entry = *(uint32_t *)(app_addr + 4);

    // 5. 设置栈指针
    __set_MSP(stack_top);

    // 6. 重定位中断向量表（如果是 ARM）
    SCB->VTOR = app_addr;

    // 7. 跳转到 APP
    void (*app_entry)(void) = (void (*)(void))entry;
    app_entry();  // 不会返回
}
```

### 3.2 Flash 擦写寿命

Flash 有擦写次数限制（通常 10 万次），OTA 设计要考虑：

- 不要在同一个扇区反复写入
- 启动标记的写入要分散到不同扇区（磨损均衡）
- Key-Value 存储也需要磨损均衡

### 3.3 差分升级（Delta OTA）

只下载新旧版本的差异部分，减少下载量：

```
旧固件: 100 KB
新固件: 102 KB
差异包: 5 KB（只包含变化的部分）

下载 5 KB 差异包 → 在芯片上用旧固件 + 差异包生成新固件 → 写入新分区
```

**优点**：下载量小，适合窄带连接（BLE）。
**缺点**：需要精确的版本匹配，生成差异包的工具链复杂。

### 3.4 常见问题

- **OTA 升级中最重要的三个保护是什么？** 校验完整性、断电回滚、不覆盖运行中的固件。
- **A/B 分区和单分区升级的优缺点？** A/B 可靠但费空间，单分区省空间但回滚慢。
- **什么是安全启动（Secure Boot）？** 从 BootROM 开始，每一级都用数字签名验证下一级的合法性，防止运行未授权的固件。
- **为什么 Bootloader 跳转前要关外设？** APP 期望所有外设在初始状态，如果 Bootloader 留了外设开启，APP 可能会行为异常。

### 3.5 核心术语表

| 英文 | 中文 | 说明 |
|---|---|---|
| Bootloader | 引导加载器 | 负责加载和验证 APP |
| BootROM | 引导 ROM | 芯片内置，不可修改 |
| OTA | 空中升级 | Over-The-Air |
| A/B Partition | A/B 分区 | 双分区交替升级 |
| Secure Boot | 安全启动 | 签名验证启动链 |
| Rollback | 回滚 | 升级失败时恢复旧版本 |
| Flash Wear Leveling | 磨损均衡 | 分散 Flash 擦写 |
| Delta OTA | 差分升级 | 只下载差异部分 |
| WPK | WQ 固件包 | WQ7036A 的 ZIP 格式固件包 |
| SBL | 二级引导加载器 | Secondary Boot Loader |

### 3.6 延伸阅读

- [[compile-link-startup-编译链接与启动流程]] —— 启动文件、链接脚本详解
- [[computer-arch-mcu-计算机组成与MCU架构]] —— Flash 布局、地址映射
- [[ipc-multicore-多核通信与IPC]] —— WQ7036A 三核启动顺序
- [[reliability-exception-系统可靠性与异常处理]] —— OTA 失败时的恢复策略
