---
type: guide
created: 2026-07-16
tags: [obsidian, 工作流, 学习, 嵌入式]
---

# Obsidian 嵌入式学习工作流指南

## 一、核心理念

```
读资料 → 写原子笔记 → [[链接]]已有知识 → 图谱梳理 → 间隔复习 → AI问答巩固
```

Obsidian 的价值不是"存笔记"，而是**在写和链接的过程中强迫自己理解**，再通过间隔重复和 AI 辅助真正记住。

---

## 二、文件夹结构（建议）

```
yuan/
├── Inbox/            # 临时抓取、未分类的内容
├── Concepts/         # 原子笔记 —— 一个概念一条
│   ├── MCU/          # 单片机相关
│   ├── C/            # C 语言
│   ├── Protocol/     # 通信协议
│   └── Toolchain/    # 编译、调试、工具链
├── Projects/         # 项目笔记
│   └── stm32-xxx/
├── Bugs/             # 踩坑记录（问题→原因→解决→预防）
├── Snippets/         # 可复用代码片段
├── Daily/            # 每日学习日志
├── MOC/              # Maps of Content（内容地图，大主题索引）
└── Attachments/      # 图片、PDF 等附件
```

---

## 三、笔记怎么写（原子笔记法）

### 3.1 一条笔记只写一个概念

**好例子：`GPIO.md`**
```markdown
---
type: concept
tags: [mcu, stm32, gpio]
---

# GPIO

## 是什么
General Purpose Input/Output，通用输入输出口。

## 关键特性（以 STM32F4 为例）
- 每个 GPIO 端口有 16 个引脚
- 可配置模式：输入、输出、复用功能、模拟
- 输出类型：推挽、开漏
- 速度：低速/中速/高速/超高速
- 上下拉：无/上拉/下拉

## 寄存器
- `MODER` — 模式选择
- `OTYPER` — 输出类型
- `OSPEEDR` — 输出速度
- `PUPDR` — 上下拉
- `IDR` — 输入数据
- `ODR` — 输出数据
- `BSRR` — 位设置/复位

## 关联概念
- [[定时器]] — 定时器输出比较模式可产生 PWM
- [[中断]] — 外部中断需要 GPIO 配置
- [[I2C]] — I2C 的 SCL/SDA 是复用功能
- [[USART]] — 串口 TX/RX 也是复用功能
```

### 3.2 链接原则

- 每条笔记至少链接 2 条已有笔记
- 写一行说明**为什么**要链接
- 例：`参见 [[定时器]] — 定时器可通过输出比较产生精确延时`

### 3.3 闪卡（间隔复习标记）

```markdown
问：GPIO 的 8 种配置模式是哪 8 种？ #flashcard
答：输入浮空、输入上拉、输入下拉、模拟输入、
    开漏输出、推挽输出、复用开漏、复用推挽
```

用 `Spaced Repetition` 插件自动复习。

---

## 四、每日学习工作流

### 每天开始
1. 打开 Daily Notes → 写今天的日期
2. 用 Templater 模板插入学习日志格式

### 学习过程中
```
1. 读资料/看视频 → 提炼关键概念
2. 打开 Obsidian → 写原子笔记到 Concepts/
3. 用 [[双链]] 连接已有知识
4. 想画图？→ Ctrl+P → Excalidraw
5. 遇到问题？→ 记到 Bugs/
```

### 每天结束
1. 标记今天学过的内容为 `#flashcard`
2. 运行 Spaced Repetition 复习
3. 写 3 句话总结今天学到了什么

### 每周结束
1. 整理 Inbox → 分类到对应文件夹
2. 检查 Graph View → 有没有孤立笔记
3. 把碎片笔记合并成 MOC

---

## 五、知识图谱怎么看

- `Ctrl+G` 打开图谱
- 橙色点 = 链接最多的笔记（核心知识）
- 孤立点 = 还没链接的笔记（需要补充关联）
- 点击任意节点 → 按 `Ctrl+Alt+→` 展开关联

---

## 六、Copilot + DeepSeek 用法

你已经配好了 Copilot 插件的 DeepSeek-V4-Flash（1M 上下文），可以这样用：

### 6.1 解释代码 / 概念
```
选中一段代码 → Copilot Chat → 
"解释这段代码的逻辑"
```
或直接问：
```
"STM32 的 DMA 是怎么工作的？看看我哪条笔记有写"
```

### 6.2 跨笔记总结
```
"总结我最近一周关于定时器的笔记内容"
```
Copilot 会自动搜你的 vault 做语义搜索。

### 6.3 回答疑问
```
"USART 中断和 EXTI 中断有什么区别？
根据我笔记里的内容来回答"
```

### 6.4 帮忙复习
```
"根据我的笔记，生成 5 道关于 I2C 的复习题"
```

---

## 七、推荐插件清单

### 学习必备
| 插件 | 作用 | 安装命令（Ctrl+P → 输入） |
|------|------|--------------------------|
| **Spaced Repetition** | 间隔重复、闪卡复习 | 社区插件搜 Spaced Repetition |
| **Excalidraw** | 画电路图、流程图、时序图 | 社区插件搜 Excalidraw |
| **Templater** | 高级模板引擎，自动插入笔记模板 | 社区插件搜 Templater |

### 效率必备
| 插件 | 作用 |
|------|------|
| **Folder Bridge** | 挂载 vault 外的文件夹（代码工程、参考手册等） |
| **QuickAdd** | 一键捕获内容到 Inbox |
| **Dataview** | 按标签/属性查询笔记，生成动态列表 |
| **Calendar** | 日历视图，快速跳转 Daily Notes |

### Copilot 相关
| 插件 | 作用 |
|------|------|
| **Copilot** | ✅ 已装。AI 问答+语义搜索+Agent |
| **模型** | deepseek-v4-flash \| anthropic |
| **Base URL** | https://api.deepseek.com/anthropic |

---

## 八、如何访问 vault 外的文件夹

### 方法 A：Folder Bridge 插件（推荐）

1. 社区插件搜 **Folder Bridge** 安装
2. 设置里添加外部文件夹路径
3. Obsidian 里就能直接访问了

适合：挂载代码工程目录、PDF 参考手册、datasheet 等。

### 方法 B：符号链接（Windows）

```powershell
# 以管理员运行 PowerShell
mklink /J "D:\02-Obsidian\yuan\Projects\stm32-project" "D:\code\stm32-project"
```

适合：希望文件夹像本地一样存在 vault 里。

---

## 九、常见误区

- ❌ **追求完美分类** → 先写，再整理
- ❌ **只存不看** → 记了就要复习，否则等于没记
- ❌ **孤立笔记** → 每一条至少连 2 个 `[[链接]]`
- ❌ **过度插件** → 先从核心 3-5 个开始，需求到了再加
- ✅ **核心就一条**：**用自己的话重写一遍，然后连到已有知识**

---

## 十、快速启动（你现在就能做的）

```
1. 装 Excalidraw + Spaced Repetition + Templater
2. Daily Notes 写今天的日志
3. 把你最近学的知识点写成 3 条原子笔记
   → Concepts/MCU/GPIO.md
   → Concepts/MCU/定时器.md  
   → Concepts/MCU/PWM.md
4. 打开 Copilot Chat → "帮我检查一下这些笔记之间的关联"
5. 加 #flashcard 标记，开始复习
```

---

*本指南由 Claude 生成，配合 Copilot + DeepSeek V4 Flash（1M）使用效果最佳。*
