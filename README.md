# xianyu-copilot — 闲鱼回复副驾

基于 [jev-chat-jarvis](https://github.com/jev-chat/jev-chat-jarvis)（MIT）改造，为**闲鱼 App**（`com.taobao.idlefish`）增加读屏支持。

挂在闲鱼旁边：读到对方最新消息 → 调 Jev 判断意图与风险 → 悬浮窗给出分析和候选回复 → **你一键复制，自己粘贴发送**。

---

## 当前状态（2026-10-15 真机验证）

目标机：**RMX6699 / Android 17 (SDK 37) / 1440×3136**

| 能力 | 状态 |
|---|---|
| 读消息正文 | ✅ 真机验证，逐条对得上 |
| 区分「我 / 对方」 | ✅ |
| 取对方昵称当会话标题 | ✅ |
| 提取商品上下文（价格/运费/发货地） | ✅ |
| 图片消息 | ✅ 识别为 `[图片]` |
| 引用回复拆解 | ✅ 只留正文 |
| 多行长消息 | ✅ 完整保留 |
| **一键填入输入框** | ❌ **闲鱼不支持**（见下） |
| 一键复制到剪贴板 | ✅ 上游现成路径 |

---

## ❌ 为什么填不进输入框（实测证据）

闲鱼输入框节点的**可执行动作列表**：

```
class=android.view.View  bounds=[208,2880][1072,3024]
editable=false           ← 不可编辑
actions=[16,64]          ← 只有两个动作
```

解码 `AccessibilityAction`：

| 值 | 动作 | 闲鱼 |
|---|---|---|
| 16 | `ACTION_CLICK` | ✅ |
| 64 | `ACTION_ACCESSIBILITY_FOCUS` | ✅ |
| 2097152 | `ACTION_SET_TEXT` | ❌ |
| 32768 | `ACTION_PASTE` | ❌ |

上游 `GuardedInputWriter` 的四级降级链，闲鱼只吃得住最后一级：

| 步骤 | 依赖 | 闲鱼 |
|---|---|---|
| 1. `setText()` | `ACTION_SET_TEXT` | ❌ |
| 2. `focus()` 后重试 | `ACTION_CLICK` | ✅ |
| 3. `paste()` | `ACTION_PASTE` | ❌ |
| 4. **复制到剪贴板** | 系统 API，不依赖节点 | ✅ |

**根因**：闲鱼那个节点只是个"可点击区域"——占位文字塞在 `content-desc`，整块当成一个 `View`，**真正的输入框语义（`editable` + `setText`）没有暴露**。Flutter 的 `TextField` 本来能暴露，说明这是自研控件。

> 这与微信不同：微信是**主动掏空整棵树**（`class=""`、`bounds=[0,0][0,0]`、`enabled=false`），连读都读不到。闲鱼是"没做这一步"——视障用户打字靠系统输入法，自绘输入框大概没加 Semantics。性质不同，结果一样。

**唯一的绕过办法是自建输入法（IME）**——另一个 App，用户要切换输入法，可能被检测包名，上游完全没有这块。**判断：不值得。**剪贴板多两步，成本几乎为零。

---

## ⚠️ 已知限制

1. **只读屏幕上可见的消息。** 适配器不会自己滚屏。滚出去的历史读不到——上游的 `ContextBuilder` 会把它"见过"的攒进本地日志（每人 ≤300 行），但只从你开始用它那天算起。

2. **屏幕最顶部只露头的那条消息读不到。** 它的头像已滚出屏幕，而"行内必须有头像"是排除顶栏的必要条件——顶栏 `[0,160][1440,336]` 同样全宽+focusable，放开判据就会抓出 `me: 更多` 这种假消息。影响有限：那条消息在完整显示时已被记进历史日志。

3. **不能用气泡中心判断说话方。** 宽气泡的中心会跨过屏幕中线——实测一条我发的消息中心在 x=686（屏幕中心 720），按中心判会得出"对方"。**只信头像位置。**

4. **`extraContext`（商品信息）目前只在适配器 → `ContextBuilder` → Jev 的 `background` 这条链上。** 它不占知识库的 1500 字符预算。

5. **未测的消息类型**：语音、视频、订单卡片、红包、转账、系统提示。样本只有一个会话。

---

## 适配闲鱼改了什么

**新增**
- `capture/XianyuAdapter.kt` — 无障碍树上的采集逻辑
- `capture/XianyuRules.kt` — **纯文本规则**（不依赖 Android 类，可 JVM 单测），照 `WhatsAppRules` 的做法
- `test/.../XianyuRulesTest.kt` — 13 个回归测试，**输入全部从真机 dump 原样抄下来**

**改动**
| 文件 | 改什么 |
|---|---|
| `capture/ChatCaptureService.kt` | 注册适配器；`inputFor()` 加闲鱼分支；新增 `findXianyuInput()` / `writeXianyuDiag()` |
| `core/ChatModels.kt` | `ChatSnapshot` 加 `extraContext`（默认 `null`，其它适配器行为不变） |
| `core/kb/KbModels.kt` | `ChatContext` 加 `extra`，`background()` 里排在最前 |
| `core/kb/ContextBuilder.kt` | 透传 `extraContext` |
| `KnowledgeActivity.kt` | 显示名加「闲鱼」 |

---

## 调试工具：诊断文件

服务每次在闲鱼采集成功，都会把当前状态写进：

```
filesDir/xianyu_diag.txt     （adb pull 得到）
```

内容三段：

```
===== 适配器解析结果 =====          ← 适配器拿到了什么
title=失约于月光
extraContext=商品信息, ¥1788.00 含运费0.00元 广东·深圳
messages=4
  [0] me: ...

===== 屏幕上实际有的节点（对照用，看漏没漏）=====   ← 屏幕上真正有什么
  [240,896-1260,1144] View '那个卖家的购买记录可以发给我吗'
  ...

===== 底部节点能力 =====
（判据：actions 里有没有 2097152=ACTION_SET_TEXT / 32768=ACTION_PASTE）
  class=android.view.View ... editable=false ... actions=[16,64]
```

**前后两段对照，"漏没漏"不用听别人说，自己就能核。**

取文件：

```bash
adb shell run-as com.jev.probe cat files/xianyu_diag.txt
```

---

## 继承上游的硬约束（不可违反）

来自上游 `cn/CLAUDE.md`：

1. **不 hook、不 Xposed、不改目标 App、不读其数据库**。只用系统无障碍服务与截屏。
2. **绝不自动发送消息**，绝不点任何 App 的发送按钮。填入输入框后停手。
3. **只读目标 App 正常开放给无障碍服务的内容**；`accessibility_service_config.xml` **不加 `isAccessibilityTool`**；**目标 App 隐藏控件树或开了防截屏，就视为不支持**——不做绕过。
4. **不碰钱**：不触碰转账、红包、收款码相关任何界面元素。
5. **路径全 ASCII**。
6. **密钥不落盘、不进日志、不进 git**。
7. 编码一律 UTF-8。
8. 禁止 `git commit` / `git push`，由人拍板。

> 第 3 条是**设计边界**。上游把微信写进了屏蔽清单：
> ```kotlin
> private val BLOCKED_PKGS = setOf("com.tencent.mm", "cn.soulapp.android")
> ```
> 对微信：不读树、不截屏、不 OCR、不填入，只弹一次"暂不支持"。
> 网上流传的"伪装成 `SelectToSpeakService`"技巧**不在官方仓库里**，本项目也不采用。

---

## 闲鱼节点结构（实测备忘）

```
页面：com.idlefish.flutterbridge.flutterboost.boost.FishFlutterBoostActivity
      → Flutter 混合工程。text 恒空，正文全在 content-desc；无可用 resource-id。

消息行（全宽 + focusable，desc 是日期/已读）：
  View [0,624][1440,1176] desc='10-09 17:56'
    ImageView [48,896][240,1072]  desc='头像'          ← 贴左 → 对方
    View      [240,896][1260,1144] desc='<正文>'

  View [0,1416][1440,2024] desc='10-10 21:10\n未读'
    View      [624,1688][1200,1896] desc='<正文>'
    View      [1200,1444][1392,1620]                   ← ★ 多包一层
      ImageView [1232,1452][1392,1612] desc='头像'      ← 孙节点 → 我

顶栏  View [0,160][1440,336]  ← 同样全宽+focusable，必须靠"无头像"排除
  ImageView [144,160][1232,336] desc='TA买过你的宝贝\ntbNick_2r4g1\n会员名：t***3'
商品卡 View [304,384][1392,608] desc='商品信息, ¥1788.00\n含运费0.00元\n广东·深圳'
输入栏 View [208,2880][1072,3024] desc='想跟TA说点什么...'  actions=[16,64]
```

**左上 vs 右上的头像层级不一样**（右边多包了一层），所以必须递归找 —— 这是踩过的坑。

---

## 本机构建

工具链统一在 `E:\personal\devtools`，**项目里不放工具链**。

```bash
source env.sh                       # 或 pwsh -File activate.ps1
cd cn
./gradlew :app:assembleDebug        # 产物 cn/app/build/outputs/apk/debug/
./gradlew :app:testDebugUnitTest    # 40 个单测
```

**装到手机后必须做的两步**（realme/OPPO 把 `appops` 和 `pm grant` 都堵死了，只能手动）：

1. 设置 → 应用管理 → Jev助手 → 权限 → **悬浮窗**（不给的话悬浮窗起不来，`canDrawOverlays=false`）
2. 无障碍服务可用 adb 开：
   ```bash
   adb shell settings put secure enabled_accessibility_services com.jev.probe/com.jev.probe.capture.ChatCaptureService
   adb shell settings put secure accessibility_enabled 1
   ```

已做的本机适配：

- `cn/local.properties` → `sdk.dir` 指向 `devtools\android-sdk`（已 gitignore）
- `cn/settings.gradle.kts` → 加了**阿里云镜像**（上游只配了 google/mavenCentral）
- `cn/gradle/wrapper/` → **Gradle 8.13**（上游 8.9-bin）；AGP 8.7.3 需要 8.9+，且 8.13 在 `devtools\gradle-home` 已有缓存，用官方 URL 可零下载命中
  > 换机器若无缓存需改镜像：`https://mirrors.cloud.tencent.com/gradle/gradle-8.13-all.zip`
  > （`services.gradle.org` 会 **307 跳到 github.com**，国内不可达）

---

## 与上游的关系

- `upstream` remote 指向原仓库，可 `git fetch upstream` 拉更新
- 只在 `cn/`（中文版）上工作，`global/`（WhatsApp 全球版）原样保留
- 上游 MIT，`LICENSE` / `NOTICE` 原样保留
