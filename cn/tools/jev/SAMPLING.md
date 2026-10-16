# 闲鱼真实对话采样模板

> 给店主（以及替店主跑腿的人）。
> 目的：把「这七道题到底准不准」从传闻变成有据可查的数字。
> **现在仓库里一条闲鱼样本都没有**——`fixtures/labeled_set.json` 那 30 条全是恋爱片段。
> 这些样本只能从真实对话里来。任何人替你编，都不算数，而且会把后面的标定数字一起带偏。

---

## 0. 三条红线（先读这段，再往下）

1. **不许编造样本。** 一条都不行。没有就写「没有」，不要"补一条差不多的"。编出来的样本会让标定数字看起来漂亮，然后让判断层在真机上翻车。
2. **不许把真实价格写进仓库。** 商品卡里就带着价格（`商品信息, ¥<PRICE> 含运费<SHIPPING> 广东·深圳` 这种形态），抄的时候一律换成占位符。
3. **不许把买家个人信息原样落盘。** 昵称、手机号、订单号、地址，全部脱敏（第 3 节）。拉下来的 dump 原文只放 `%TEMP%`，抄完删掉。

另外两条来自 `cn/CLAUDE.md` 的硬约束，采样时同样适用：**不碰钱**（转账/红包界面只看不点）、**绝不自动发送任何消息**（采样就是看，不要为了"制造场景"去发消息）。

---

## 1. 采什么：13 个场景

每个场景至少 2 条；下面标 3 的是建议值。**合计下限 26 条，建议 30 条。**

| scenario | 中文 | 为什么采 | 目标 | 采集方式 |
|---|---|---|---|---|
| `haggle` | 砍价 | 最常见的议价；要看清是"试探"还是"已经决定买只差价" | 3 | dump |
| `probe_price` | 装傻套价 | 反复问价但不表态，探你的底价 | 2 | dump |
| `peer_scout` | 同行探底 | 问进货渠道 / 成本 / 货源 / 成色口径 | 2 | dump |
| `offsite_contact` | 要微信 / 站外 | 平台唯一自己写出来的红线（私信页常驻反诈条） | 3 | dump |
| `urge_shipping` | 催发货 | 时间承诺类；判断层最容易给出"乱承诺"的地方 | 2 | dump |
| `condition_dispute` | 成色争议 | 收货后说和描述不符 | 3 | dump（+ 截图核对） |
| `return_after_sale` | 退货售后 | 退 / 换 / 补差价 / 平台介入 | 3 | dump（+ 截图核对） |
| `bad_review_threat` | 差评威胁 | 危险度高档的主要形态 | 2 | dump |
| `ask_no_buy` | 只问不买 | 最常见的空转；判"要不要继续投入" | 2 | dump |
| `voice_message` | 语音消息 | **dump 里有没有正文目前未知**，这条本身就是要确认的事实 | 2 | dump + 截图 |
| `image_message` | 图片消息 | 同上；买家发图问成色 / 发截图要凭证 | 2 | dump + 截图 |
| `transfer_card` | 转账 / 红包卡片 | 硬约束第 4 条「不碰钱」；判断层要不要识别这种卡片 | 2 | 截图（dump 大概率读不到） |
| `multi_item_thread` | 同一会话多件商品 | 商品卡（`extraContext`）会随会话变，一次会话聊两单很常见 | 2 | dump |

**怎么算一条**：同一个会话里**连续**的若干条消息（一般 3~6 条，最多 10 条），不是从不同对话里各挑一句拼起来。
**为什么最多 10 条**：`questions.build_state()` 只带最近 10 条，多出来的会被静默丢掉（自检脚本会提醒你）。

---

## 2. 怎么采

### 2.1 方式 A：真机 dump（首选，覆盖上表 11 个场景）

**前置**

- 手机上装的必须是 **debug 版**（`com.jev.probe`）。release 版 `run-as` 会被拒。
- 打开闲鱼 → 进到要采的那个私信会话 → **停 3 秒**（等采集服务触发一次写盘）。
- 一个会话采一次；换会话要重新停 3 秒。

**拉取（pwsh 7）**

```powershell
# 中文 Windows 上不加这行，中文会变乱码
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$adb = Join-Path $env:ANDROID_HOME 'platform-tools/adb.exe'
& $adb devices                      # 记下设备序列号

$dev = '<你的设备序列号>'
$out = Join-Path $env:TEMP 'xianyu_diag.txt'
& $adb -s $dev exec-out run-as com.jev.probe cat files/xianyu_diag.txt > $out
Get-Item $out | Select-Object Length, FullName
```

**这个文件长什么样**（三个 section，来自 `ChatCaptureService.writeXianyuDiag()`）：

```text
screen=[0,0][1440,3136]
bottomStart=2508

===== 适配器解析结果 =====
title=<买家昵称>
extraContext=商品信息, ¥<PRICE> 含运费<SHIPPING> <发货地>
messages=4
  [0] me: <店主这条的原文>
  [1] other: <买家这条的原文>
  ...

===== 屏幕上实际有的节点（对照用，看漏没漏）=====
  [l,t-r,b] View '<content-desc 原文>'
  ...

===== 底部节点能力 =====
（判据：actions 里有没有 2097152=ACTION_SET_TEXT / 32768=ACTION_PASTE）
```

**怎么用**

1. 只取 `===== 适配器解析结果 =====` 段的 `[i] side: 正文` 行，按屏幕顺序抄进 `messages`。
2. **`side=other` 要改写成 `her`**。真机 dump 用的是 `other/me`，校准 schema（`questions.build_state`）只认 `her/me`；直接粘贴会在第一条例子上抛 `ValueError`。自检脚本会把这一条单独报出来。
3. `extraContext`（商品卡）脱敏后写进 `note`。同一会话多件商品时，这一步就是证据。
4. 第二段（节点对照）在**「适配器解析结果」条数不对**时才用：拿它核对是漏读了，还是屏幕上本来就没有。语音 / 图片 / 转账卡片这三种，重点看这里有没有正文——**没有正文就照实写"dump 里读不到"**，这本身就是结论。
5. 抄完把 `%TEMP%` 里的 dump 删掉。

> 已验证（2026-10-16，RMX6699 / Android 17）：`com.jev.probe` 与 `com.taobao.idlefish` 均在本机设备上，
> `files/xianyu_diag.txt` 存在（4052 字节 / 51 行），上面这条 `exec-out run-as ... cat` 命令可跑通。
> 同机型 2026-10-15 的一份完整 dump（`messages=4`）在 `E:/personal/padtest/xianyu_diag.txt`。

### 2.2 方式 B：截图（补充，只用于 dump 读不到正文的场景）

适用：语音消息、图片消息、转账 / 红包卡片、成色争议里的实物图。

- 截图**只作为你自己的核对材料**，不要提交进仓库。
- 截图里读到的文字仍然要**手抄**进 `messages`，并在 `note` 写明"来自截图，dump 里没有正文"。
- 转账 / 红包卡片：**只看，不点**。抄下卡片上显示的文字即可。

### 2.3 方式 C：手抄（没有 adb 时的兜底）

- 逐字抄。**不要润色、不要补标点、不要改错别字、不要把表情符号删掉**——语气就是判断依据，改一个字这条样本就废了。
- 顺序必须是屏幕上的顺序（从上到下）。
- 抄完在 `source` 写 `manual`。

---

## 3. 脱敏要求

只替换**标识符**。语气、错别字、表情、断句、标点**一个字都不要动**。

| 原文里出现的 | 换成 | 说明 |
|---|---|---|
| 买家昵称 | `<BUYER>` | 顶栏那行完整昵称要换；引用回复里粘在正文后面的昵称也要换 |
| 店主自己的昵称 | `<ME>` | |
| 手机号 | `<PHONE>` | 包括买家主动发来的、和图片里出现的 |
| 微信号 / QQ 号 | `<WECHAT>` / `<QQ>` | 场景本身（"要微信"）要保留，号本身不能留 |
| 订单号 / 快递单号 | `<ORDER>` / `<TRACKING>` | |
| 收货地址 / 收件人 | `<ADDR>` | |
| 商品标题 | `<ITEM>` | |
| 价格 / 运费 | `<PRICE>` / `<SHIPPING>` | **硬红线**：真实价格不进仓库 |
| 绝对日期 | `<DAY>` | 「昨天」「前天」「刚」这类相对时间**保留**，它有用 |
| 发货地（如"广东·深圳"） | `<CITY>` | |

> 闲鱼自己已经把 `会员名` 脱敏成 `t***9` 了，但**顶栏那个完整昵称没有**，别漏。

自检脚本会按类别扫这些（手机号 / 身份证 / 邮箱 / 订单号 / 收货信息 / 价格 / 微信号），
**报告里只写"哪条样本哪个字段有问题"，不会回显原文**，所以你可以放心把报告贴出来。

---

## 4. 存放路径与命名

| 项 | 规定 |
|---|---|
| 目标文件 | `cn/tools/jev/fixtures/xianyu_samples.json`（UTF-8 无 BOM，顶层是 JSON 数组） |
| id | `x01` … `x99`，连续、不重复。**不要用 `c01`**，那是恋爱标注集的编号 |
| 分几次采 | 可以分文件（如 `xianyu_samples_batch2.json`）先放着，合并后再跑自检；最终要合成上面那一个文件 |
| 不要动 | `fixtures/labeled_set.json`（恋爱集）原样留着做对照 |
| 截图 / 原始 dump | 不进仓库。要留档就放 `cn/_archive/xianyu-samples-<日期>/`，且先脱敏 |

---

## 5. 每条样本要标什么

```json
{
  "id": "x01",
  "scenario": "haggle",
  "source": "dump",
  "relationship": "闲鱼买家与卖家；from=me 的是我（卖家）发的，from=her 的是买家发的",
  "messages": [
    ["her", "<买家这条的原文，脱敏后>"],
    ["me",  "<店主这条的原文，脱敏后>"]
  ],
  "note": "<你自己的话：这条买家到底想要什么、哪句你不确定>",
  "expect": {
    "literal_question": true,
    "true_intent": "",
    "danger_level": 2,
    "should_reply_now": false,
    "best_action": "",
    "she_needs": "",
    "tension_resolved": true
  }
}
```

| 字段 | 必填 | 说明 |
|---|---|---|
| `id` | 是 | `x01` 起 |
| `scenario` | 是 | 第 1 节那 13 个之一（写英文 id） |
| `source` | 是 | `dump` / `screenshot` / `manual` |
| `relationship` | 是 | 一句话事实描述。有证据的那半句是「from=me 的是我（卖家）发的，from=her 的是买家发的」；最终措辞等 C1 裁定 |
| `messages` | 是 | `[["her","…"],["me","…"]]`，最多 10 条 |
| `note` | 强烈建议 | 你自己的话。这条是**最值钱的字段**：选项集定下来之后，全靠它把标签映射过去 |
| `expect.literal_question` | 是 | `true` / `false` |
| `expect.should_reply_now` | 是 | `true` / `false` |
| `expect.tension_resolved` | 是 | `true` / `false` |
| `expect.danger_level` | 是 | 0~9 整数，见下 |
| `expect.true_intent` / `best_action` / `she_needs` | **暂缓** | 先填空串 `""`，见下 |

### `danger_level` 怎么打（临时锚点）

**这不是题目文案**——10 档每档写什么由 J3 裁定。采样阶段只要一个你自己的粗判断：

- **0** = 完全正常的买卖问答，没有任何压力
- **5** = 明显不满 / 开始施压（催、质疑、反复追问）
- **9** = 已经闹翻（平台介入 / 明确要曝光 / 交易破裂）
- 中间档按直觉放；拿不准就写进 `note`

### 为什么 `true_intent` / `best_action` / `she_needs` 先空着

这三个是选择题，**选项集还没定**（见 `cn/docs/DOMAIN-MAP.md` 的 J2 / J5 / J6：6 项里删哪几个、加哪几个，要你拍板）。
现在硬填 key，等于把恋爱选项集套到闲鱼上，标出来的东西是假的。
所以：

1. **先把原料采齐**：`messages` + `scenario` + `note` + 三个是非题 + `danger_level`。这一步现在就能做完，而且它才是真正稀缺的东西。
2. 选项集定下来之后，再照 `note` 把三个 key 补上。

自检脚本对空串**只警告不报错**，就是为了让这个"待办"一直可见，而不是假装已经标完了。

---

## 6. 采完自检

```powershell
python cn/tools/jev/check_samples.py
```

它会做四件事：

1. **结构检查**：id 唯一、`messages` 是 `["her"|"me", 正文]` 两元组、`from='other'` 单独报错、`expect` 七个键齐不齐、`danger_level` 在 0~9、超 10 条消息提醒。
2. **脱敏检查**：按类别扫 PII 与真实价格，**只报位置和类别，不回显原文**。
3. **覆盖统计**：13 个场景各几条，哪几个还是 0。
4. **空串提醒**：三个选择题还没填，会逐条警告。

退出码：0 = 通过，1 = 有错误（先修完再拿去标定）。

想先看一条样本长什么样、又不想编对话，可以打印骨架：

```powershell
python cn/tools/jev/check_samples.py --print-skeleton
```

骨架里的尖括号是占位符，**不是示例对话**。

---

## 7. 数量口径冲突（要你裁定，本文件不定）

| 出处 | 说法 |
|---|---|
| `cn/tools/jev/TASK.md:68` | 标注集**不少于 25 条** |
| `cn/docs/acceptance.md:18` | 标注集**不少于 20 条** |
| 现状 `fixtures/labeled_set.json` | 实际 **30 条**（两个口径都满足） |

本模板按 **13 场景 × 2 条 = 26 条**给下限（两个口径都覆盖），建议 30 条。
**最终以哪个数字为准，由你定**；定了之后 `acceptance.md` 和 `TASK.md` 要改成同一个数。

---

## 8. 采完之后会发生什么（别急着跑 calibrate.py）

采完**不等于**能跑标定。`questions.py` 现在还是恋爱题目集，直接拿闲鱼样本去跑，
出来的数字没有任何意义。正确顺序：

1. 采样（本文件）→ 跑 `check_samples.py` 清零错误
2. 店主裁定 J2 / J5 / J6（选项集）、J3（危险档文案）、J7（`tension_resolved` 留不留）
3. 改 `questions.py`（Kotlin 侧 `JevQuestions.kt` 要同批改，它是逐字移植）
4. 照 `note` 把三个 choice key 补上
5. 把 `xianyu_samples.json` 合成一份，跑 `calibrate.py`（需要 `OPENROUTER_API_KEY`）
6. 没有 key 也想先验证脚手架通不通：`python cn/tools/jev/dry_run.py`

第 5 步之前想确认脚手架本身是好的，用第 6 步——它不联网、不要 key、也不产生任何标定数字。
