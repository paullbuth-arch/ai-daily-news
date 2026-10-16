# 领域耦合点（Seams）

> 范围：`E:\personal\xianyu-copilot` 仓库中所有「恋爱领域假设」与「闲鱼领域需求」咬合的地方。
> 每条给：**文件 + 行号 + 为什么耦合 + 改法**，并归入 **必改 / 可改 / 别动** 三类。
> **本文档只描述改法，不改任何代码。**

---

## 0. 读法

- 仓库根：`E:\personal\xianyu-copilot`。下文路径**相对 `cn/`**（Android 工程根）。
- 行号基准：**当前工作区**（commit `fdf8d28` + 未提交改动，见 §5）。改动后行号会漂移。
- 三类定义：

| 类别 | 判定标准 |
|---|---|
| **必改** | 不改，AI 说出来的话、判出来的东西就仍是恋爱向；或验收标准与真实平台行为直接冲突 |
| **可改** | 改了更对，不改也能跑（措辞、示例、调试设施） |
| **别动** | 店主明令，或属于硬约束 / 已定死的跨阶段契约 / 上游通用引擎 |

- 与 `docs/DOMAIN-MAP.md` 的关系：**DOMAIN-MAP 定「改成什么」，SEAMS 定「改哪里」**。SEAMS 里凡写「待店主确认」的，指的是 DOMAIN-MAP 第 4 节那 21 条裁定，裁定前不要动这些行。

---

## 1. 必改（13 组）

### 1.1 `app/src/main/java/com/jev/probe/jev/JevQuestions.kt` — 判断层主体

| 项 | 内容 |
|---|---|
| 位置 | :43-167（七道题的 instructions / criteria）、:205-223（`rankQuestion` 排序判据） |
| 为什么耦合 | 整个判断层就是这七道题，而它们**是为恋爱与人际关系写的**：`literal_question` 的判据是「考验你记不记得、在不在乎」；`true_intent` 的 `confirm_you_care` 是「确认你在不在乎」；`danger_level` 档 8/9 写着「分手 / 今晚就去告你 / 不跟你合作」；`should_reply_now` 判据里写着「背出她让你说的内容」；`she_needs` 直接以「她」命名；`rankQuestion` 的反面样本是「含糊的道歉」。Jev 是**决策模型，判什么就只答什么**——题目不变，换多少界面词都没用 |
| 改法 | 按 DOMAIN-MAP §2.1 的裁定重写 instructions 与 criteria（英文，保持 `CLAUDE.md:38` 的口径）；**J3b / J4b 两句直接删**；出题 key 名与 `JudgeClient` / `OverlayController` 同步。:21-22 的 `BACKGROUND_NOTE` 保留（工程字段） |
| 连带 | `jev/JudgeClient.kt:34-40`、`overlay/OverlayController.kt:640-650`、`tools/jev/questions.py`、`tools/jev/fixtures/labeled_set.json` |

### 1.2 `jev/ReplyClient.kt:36-40` — 生成提示词（唯一决定 AI「说什么」的生成层）

| 项 | 内容 |
|---|---|
| 为什么耦合 | 三条策略的第三条写死「**一条简短低姿态**」——这是哄人的姿态；真实闲鱼对话里卖家是给判断、给替代做法的一方（DOMAIN-MAP D1.1 / D1.8）。40 字上限也是聊天节奏，交易回复常要带型号 / 成色 / 电池 / 配件 |
| 改法 | 按 DOMAIN-MAP G1 的裁定重写 system prompt；G2 的字数上限**在店主给阈值前不要动** |
| 连带 | 无（此签名不含判断结果，可独立改、独立验收） |

### 1.3 `jev/ReplyClient.kt:56-57` — 知识块提示词

| 项 | 内容 |
|---|---|
| 为什么耦合 | 「以下是关于**我和对方**的背景与知识库…不要编造知识库里没有的事实」。后半句是防编造的护栏（必须留），前半句的指代是恋爱语境的「我和对方」 |
| 改法 | 保留护栏句，替换指代（与 DOMAIN-MAP U4 用同一个词） |

### 1.4 `jev/ReplyClient.kt:80-81` — 摘要提示词

| 项 | 内容 |
|---|---|
| 为什么耦合 | 「只保留事实、**偏好**、承诺和待办」是人际语境；且该函数在 v1.3 已被明确推迟不接（`docs/v1.3-plan.md:117`：`autoSummary` 推迟、`summarize` 留着不接） |
| 改法 | 按 DOMAIN-MAP G4 裁定；未裁定前**不要接进主链路** |

### 1.5 `core/Prefs.kt:350` — `DEFAULT_REL`

| 项 | 内容 |
|---|---|
| 为什么耦合 | 字面写着「对方是我的**伴侣**」。它会作为 `chat.relationship` 直接进 Jev 的 state，等于给模型的第一个领域前提就是恋爱 |
| 改法 | 按 DOMAIN-MAP C1 裁定改文案。注意作用域：只有**从没手动改过设置**的用户吃这个默认值（`Prefs.kt:179-181`），已改过的用户不受影响——所以改它不会覆盖店主自己的配置 |

### 1.6 `overlay/OverlayController.kt:640-650` — 三张标签映射表

| 项 | 内容 |
|---|---|
| 为什么耦合 | `INTENT`（6 项）、`NEEDS`（5 项）、`ACTION`（7 项）是 key → 中文的静态映射。**只改判断层不改这三张表，面板会出现英文 key 或错词** |
| 改法 | 与 1.1 的最终选项集合**逐字同步**；集合未定 → 等 DOMAIN-MAP 第 4 节 A 类裁定。这三张表必须与判断层**同一次改动**落地（S1:995-997 的判断成立：只换标签会让标签写着「问成色」、底层判的却是恋爱逻辑） |

### 1.7 `overlay/OverlayController.kt:502,506,508,510` — 四条字面量

| 项 | 内容 |
|---|---|
| 为什么耦合 | :502「**对方**真实意图：」；:506「要」+ NEEDS 值；:508「可给**实质** / 先别给实质」；:510「✓ **紧张**已缓解」——四个词全部来自恋爱语义 |
| 改法 | :502 换指代（U4）；:506 结构保留、值随 1.6 改；:508 随 J4 改；:510 随 J7 改 |

### 1.8 `overlay/OverlayController.kt:615-626` — 危险度词与配色门槛

| 项 | 内容 |
|---|---|
| 为什么耦合 | `dangerWord()` 输出「很危险 / 偏危险 / 留神 / 安全」——说的是**感情**风险；配色的门槛（≥6 红 / ≥3 橙 / 其余绿）挂在同一段里 |
| 改法 | 词按 DOMAIN-MAP U8 裁定换；门槛（U8b）是纯显示约定，可保留 |

### 1.9 `core/ChatModels.kt:52,55` + `jev/JudgeClient.kt:36,39` — 字段名与 JSON key

| 项 | 内容 |
|---|---|
| 为什么耦合 | `Analysis.sheNeeds` / `Analysis.tensionResolved` 与解析用的 `"she_needs"` / `"tension_resolved"` 是恋爱命名，且**改一处要连动 4 个文件**：`JevQuestions` → `JudgeClient` → `ChatModels` → `OverlayController` |
| 改法 | 按 DOMAIN-MAP M1 / M2 / M3 裁定。**改就四处一起改**，且必须与 1.1 的出题 key 同批；不改也能跑（纯命名） |

### 1.10 `KnowledgeActivity.kt:107,148,153,187` — 知识库四条引导

| 项 | 内容 |
|---|---|
| 为什么耦合 | 四条全部是恋爱 / 生活示例：:107「习惯、忌口、项目代号、约定过的时间」；:148 标题例「口味忌口」；:153 标签例「吃饭，周末」；:187 导入示例「口味忌口 / 不吃香菜，海鲜过敏 / 项目代号 / 内部叫小蓝」 |
| 改法 | 按 DOMAIN-MAP U12 裁定改。这四条**直接决定店主会往知识库里填什么**，填错方向等于判断层的 background 全是废料 |

### 1.11 `MainActivity.kt:67,96` + `SettingsActivity.kt:75,313,321` — 界面文案

| 项 | 内容 |
|---|---|
| 为什么耦合 | `MainActivity.kt:67`「读**对方**消息（已支持 QQ、X、飞书、WhatsApp）」——平台表缺闲鱼；:96「密钥 · 模型 · **关系** · 透明度 · 会话白名单」；`SettingsActivity.kt:75`「读对方消息…」；:313-314「**关系描述**（给 Jev 判断用）」；:321「**对方**发消息时自动分析」 |
| 改法 | 按 DOMAIN-MAP U14 / U15 / C2 / U19 裁定。纯显示，不影响判断，但影响店主自己看不看得懂 |

### 1.12 `tools/jev/**` — 题目集、校准脚手架、标注集、演示脚本

| 项 | 内容 |
|---|---|
| 位置 | `tools/jev/questions.py:5-206`（题目集，Kotlin 侧是它的逐字移植）、:229-241（排序题）；`tools/jev/calibrate.py`（指标口径）；`tools/jev/fixtures/labeled_set.json`（标注集）；`tools/jev/demo_meme.py:20-24,67,91-95`（恋爱演示对话 + 「relationship: romantic partners」+ 期望值） |
| 为什么耦合 | 这是**判断层的真源**：`JevQuestions.kt:9-12` 的注释写明「ported verbatim from tools/jev/questions.py (the wording that passed calibration)」。标注集全部是恋爱片段（`TASK.md:73` 列的场景：情侣拌嘴、对方生气、约饭、阴阳怪气、最后通牒），所以**现在没有任何闲鱼校准数据**。⚠️ **2026-10-15 补审更正：两侧并非「逐字一致」**——Kotlin 侧 `noul/choice/score`（`:26/:32/:38`）给七道题**全部**追加 `BACKGROUND_NOTE`（`:21-22`），Python 侧没有；state schema 是 `me/other` vs `her/me`；另有 3 处 `-` vs `—`。**即：现在校准的不是 App 实际在跑的那套题** |
| 改法 | 题目集与 Kotlin 侧同步改；标注集按 DOMAIN-MAP T1 重建（样本必须来自真实对话，**不许编**）；`demo_meme.py` 的演示对话换成闲鱼真实对话。**注意**：`tools/jev/report/` 目录在仓库里不存在，说明这套校准从未在本仓库留过档（见 §6） |

### 1.13 `docs/acceptance.md:19-20,26` — 验收口径

| 项 | 内容 |
|---|---|
| 为什么耦合 | :19-20 的指标名就是恋爱题目名（`danger_level` MAE < 1.0、`true_intent` / `she_needs` 命中率 ≥ 60%）；:26「点**填入**后输入框出现文本，且未发送」在闲鱼**不成立**（DOMAIN-MAP D1.6 / P2：输入框 `editable=false`，actions 里没有 `ACTION_SET_TEXT`） |
| 改法 | :19-20 随题目改名；:26 改成「点填入 / 复制后剪贴板有文本，且没有发送」。新阈值按 DOMAIN-MAP T2 由店主定 |

---

## 2. 可改（改了更对，不改也能跑）

| # | 位置 | 为什么耦合 | 改法 |
|---|---|---|---|
| 2.1 | `overlay/OverlayController.kt:298-302`（悬浮窗菜单五项）、:496（「知识库 N 条 · 历史 M 条」）、:519（「候选回复（Jev 排序）」）、:544-546（重试 / 换一组） | 全部领域中立 | 可不动。若店主想在闲鱼侧强调「只能复制」，可在这里加一项显式的复制入口 |
| 2.2 | `MainActivity.kt:132-141`（隐私提示 + 平台风险提示） | 领域中立，且与平台反诈条（DOMAIN-MAP P1）同向 | 可不动；平台表更新时顺带核对措辞 |
| 2.3 | `app/src/main/res/values/strings.xml:3`（无障碍说明） | 领域中立 | 可不动 |
| 2.4 | `core/kb/KbSelfCheck.kt:22-26,54-73,103-105`（自检样例：「项目代号叫小蓝」、`background("默认关系")`） | 样例事实是恋爱 / 生活向 | 换成闲鱼向的虚构事实（**必须是虚构**，别把真实价格写进代码）；自检逻辑本身不用改 |
| 2.5 | `core/kb/KbModels.kt:76-94`（`background()` 的「关系：」「关于X：」「过往摘要：」前缀） | 措辞级 | 按需微调；改了要同步 `ReplyClient.kt:56-57` 的说法 |
| 2.6 | `core/kb/ContextBuilder.kt:19-22`（`BUDGET_CHARS=1500`、`MAX_HIT_NOTES=5`） | 交易消息信息密度高（DOMAIN-MAP D2.4 一条消息装了价格 / 运费 / 快递 / 征询） | 按 DOMAIN-MAP K3 裁定后再调；**不要先调** |
| 2.7 | `core/kb/KbStore.kt:475`（`MAX_LOG`，2026-10-15 已由 300 改为 **800**） | 同上（DOMAIN-MAP K4，已裁定） | 已落地 |
| 2.8 | `KnowledgeActivity.kt:312-318`（`appLabel()` 包名 → 中文） | 已含「闲鱼」（`com.taobao.idlefish`） | 可不动；将来适配新 App 时在这里加一行 |
| 2.9 | `capture/ChatCaptureService.kt:365-368,928-1001`（闲鱼诊断写盘 `filesDir/xianyu_diag.txt`） | 排查设施，不参与回复流程；每次闲鱼采集都会写一次盘 | 稳定后可拆掉或加开关（DOMAIN-MAP T3 已把它列为 1.5s 冒烟指标的变量） |
| 2.10 | `capture/ChatCaptureService.kt:1067`（`NO_SCREENSHOT_PKGS`） | 目前只含 WhatsApp | 闲鱼要不要禁截屏识别 → DOMAIN-MAP X5 待店主确认 |
| 2.11 | `docs/v1.3-plan.md:78`（注入方式的描述文字） | 主控文档里写的是「以下是关于我和对方的背景与知识库」 | 与 1.3 同批更新，保持文档与代码一致 |
| 2.12 | 仓库根 `README.md:5,15-23,63-73,77-91` 与 `cn/README.md`、`cn/CHANGELOG.md` | 平台表、已知限制、改动清单 | 判断层 / 生成层改完后按真实结果更新（README:73 已写明「未测的消息类型」） |

---

## 3. 别动

### 3.1 店主明令（本任务硬约束）

| 位置 | 说明 |
|---|---|
| `app/src/main/java/com/jev/probe/capture/XianyuAdapter.kt` 全文 | 闲鱼采集逻辑。真机踩坑结论都在注释里（:33-41 头像判边、:121-129 递归找头像） |
| `app/src/main/java/com/jev/probe/capture/XianyuRules.kt` 全文 | 闲鱼纯文本规则（可 JVM 单测）。:35-42 引用回复拆解、:49-57 元信息、:72-83 chrome 词表、:86-99 顶栏与商品卡 |
| `app/src/test/java/com/jev/probe/capture/XianyuRulesTest.kt` 全文 | 13 个回归测试，输入全部来自真机 dump（DOMAIN-MAP D2） |

### 3.2 硬约束 / 安全护栏

| 位置 | 为什么别动 |
|---|---|
| `cn/CLAUDE.md` 全文（尤其 :7-14） | 店主明令不许改；八条硬约束是所有人的边界 |
| `capture/GuardedInputWriter.kt:17-43` | 「填入后停手」的四级降级链，绝不点发送的护栏。闲鱼侧它落到最后一级（剪贴板）是**正确行为**，不是 bug |
| `capture/ChatCaptureService.kt:860-865`（`setTextRaw`）、:835-858（`fillInput`） | 全工程唯一的写入动作路径 |
| `capture/ChatCaptureService.kt:496,505-513,1069`（`isBlocked` / `showBlocked` / `BLOCKED_PKGS`） | 屏蔽清单（微信 / Soul）是设计边界，不由闲鱼需求决定 |
| `app/src/main/res/xml/accessibility_service_config.xml` | 不加 `isAccessibilityTool` 是硬约束第 3 条；`canTakeScreenshot` 的改动要重新开关无障碍才生效 |
| `capture/ocr/**`（`ScreenCapture.kt` / `MlKitOcr.kt` / `OcrEngine.kt`） | OCR 引擎与限频 / 退避逻辑，与领域无关 |

### 3.3 已定死的跨阶段契约 / 上游通用引擎

| 位置 | 为什么别动 |
|---|---|
| `core/Prefs.kt:29-69`（密钥迁移、Bocha 反种子）、:272-348`（provider 预设与默认地址 / 模型） | A 阶段契约，`docs/v1.3-plan.md:106-113` 逐条定死；密钥与预设跟领域无关 |
| `jev/HttpJson.kt`、`jev/VisionClient.kt` | 传输与视觉，与领域无关 |
| `capture/ConversationSession.kt`、`capture/NewMessageGate.kt`、`capture/KeepAliveService.kt` | 会话身份、新消息判定、保活；纯工程 |
| `capture/ChatAppAdapter.kt:90-412`（QQAdapter / XAdapter / FeishuAdapter）、`capture/WhatsAppAdapter.kt` 及 `app/src/test/resources/whatsapp/**` | 其它四个 App 的适配器与录屏数据；闲鱼需求不该动它们 |
| `core/kb/KbStore.kt`（存储、单锁、原子写、损坏备份，:26-473） | 数据安全设施，与领域无关 |
| `global/**` | 海外版（WhatsApp 全球版），`README.md:212` 写明「只在 `cn/` 上工作，`global/` 原样保留」 |

---

## 4. 连带影响与改动顺序

### 4.1 必须同批改的（拆开改会出半成品状态）

1. **判断层三件套**：`JevQuestions.kt`（1.1）+ `OverlayController.kt:640-650`（1.6）+ 面板字面量（1.7）。
   只改其一 → 面板显示英文 key，或标签写着新词、底层判的还是恋爱逻辑。
2. **改名四件套**（若店主决定改名）：`JevQuestions.kt` → `JudgeClient.kt:36,39` → `ChatModels.kt:52,55` → `OverlayController.kt:640-650`。
3. **校准三件套**：`questions.py` + `fixtures/labeled_set.json` + `acceptance.md:19-20` 的指标名与阈值。

### 4.2 可以独立先做的

- **生成层**（1.2 / 1.3）：`ReplyClient.draft()` 的签名是 `draft(snapshot, relationship, ctx, count, avoid)`（`ReplyClient.kt:25-31`），**不含 Jev 的判断结果**。所以「只改生成层」这一步能单独验收：判断层一行不动，候选回复先变成卖家味。（S1:477-478 的这个判断，与代码核对后成立。）
- **界面文案**（1.11 / 2.1-2.4）：纯显示，随时可改，不影响判断。
- **知识库引导**（1.10）：只影响店主填什么，不影响既有行为。

### 4.3 顺序建议

`生成层 → 界面文案 + 知识库引导 → 判断层与映射表同批 → 题目集与标注集重建 → 验收口径 → 真机标定`

理由：前三步零风险、可单独验收；判断层一旦改，就必须重跑标定（`acceptance.md:12-21` 的 C 段），否则没有任何数字支撑。

---

## 5. 现状快照（写本文档时的工作区）

`git status`（仓库根 `E:\personal\xianyu-copilot`，HEAD = `fdf8d28`）：

**已修改（未提交）**

| 文件 | 与领域的关系 |
|---|---|
| `cn/app/src/main/java/com/jev/probe/capture/ChatCaptureService.kt`（+144 行） | 注册 `XianyuAdapter`、`inputFor()` 加闲鱼分支、新增 `findXianyuInput()` / `writeXianyuDiag()` |
| `cn/app/src/main/java/com/jev/probe/core/ChatModels.kt` | `ChatSnapshot.extraContext`（商品上下文） |
| `cn/app/src/main/java/com/jev/probe/core/kb/KbModels.kt` | `ChatContext.extra`，在 `background()` 里排最前 |
| `cn/app/src/main/java/com/jev/probe/core/kb/ContextBuilder.kt` | 透传 `extraContext` |
| `cn/app/src/main/java/com/jev/probe/KnowledgeActivity.kt` | `appLabel()` 加「闲鱼」 |
| `cn/gradle/wrapper/gradle-wrapper.properties`、`cn/settings.gradle.kts` | 本机构建适配（Gradle 8.13、阿里云镜像、rootProject 改名），与领域无关 |

**未跟踪（新增）**：`cn/app/src/main/java/com/jev/probe/capture/XianyuAdapter.kt`、`cn/app/src/main/java/com/jev/probe/capture/XianyuRules.kt`、`cn/app/src/test/java/com/jev/probe/capture/XianyuRulesTest.kt`（三者=别动）、仓库根 `README.md`、`activate.ps1`、`env.sh`

**含义**：闲鱼侧目前只做到「读得到、看得对」。**判断层与生成层一行都没改**，所以现在面板上半部分仍是恋爱判断——这与 DOMAIN-MAP 的结论一致：必改的 13 组里，只有 M7 / X1 / X2 / N1 / N3 这几项已经落地。

---

## 6. 自验缺口

1. **没跑构建、没跑测试**。本文档只做静态阅读（`read` / `grep`），所有行号未经过编译器或测试验证。
2. **行号会漂移**：基准是当前工作区（含未提交改动）。只要有人动过 `ChatCaptureService.kt` / `OverlayController.kt`，行号就要重核。
3. **`_reports/` 目录不存在**：`cn/CLAUDE.md:52` 规定报告写 `_reports/<任务名>_report.md`，但仓库里没有这个目录。
4. **`tools/jev/report/` 不存在**：`tools/jev/TASK.md:78` 要求校准脚本产出 `report/calibration.json` 与 `.md`，仓库里也没有。→ 说明 C 段（`acceptance.md:12-21`）的校准数字**在本仓库没有任何留档**，无法核对「已标定」这个说法。S1:1017-1019 说这七道题的措辞「是标定过的」，本仓库无法自证。
5. **未核对的项**：`capture/ocr/**`、`global/**`、`app/build/**` 里的产物没有逐行读；本文档把它们整块归入「别动」，依据是 `cn/CLAUDE.md:44-52` 的目录归属与 `README.md:212` 的说明，不是逐行核对。
6. **跨仓库耦合未查**：闲鱼文案 / 选品域在另一个工程（`E:\personal\padtest\ipad_boss_app`，DOMAIN-MAP 记作 S2）。本文档只确认了「域不同」，没有核对两个工程之间有没有共享代码或数据格式。
