package com.jev.probe.capture

/**
 * 闲鱼私信的纯文本规则。**刻意不依赖任何 Android 类**，这样可以在 JVM 单测里
 * 跑真实 dump 下来的字符串 —— 照 `WhatsAppRules` 的做法。
 *
 * 这里的每条规则都是真机调试踩出来的（RMX6699 / Android 17 / 1440×3136）：
 * 屏幕上的原文长什么样、适配器该拿哪一段。
 */
internal object XianyuRules {

    const val PACKAGE = "com.taobao.idlefish"

    /** 头像节点的 content-desc。它是消息行的标志（商品卡/顶栏都没有）。 */
    const val AVATAR = "头像"

    /** 输入框占位提示（可编辑语义没暴露，只能靠这个认位置）。 */
    const val INPUT_HINT = "想跟TA说点什么..."

    /**
     * 气泡 desc 清理 —— 闲鱼把两种东西塞进同一个字段：
     *
     * ```
     * 引用回复：正文, 昵称\n被引用的原文     → 只要"正文"
     * 多行消息：第一行\n\n第二行\n\n第三行   → 全都要
     * ```
     *
     * 判据是**第一行是否以半角 `, 昵称` 结尾**，不是"有没有换行"。
     * 正文里的逗号是全角 `，`，半角 `, ` 是闲鱼拼昵称用的，所以不会误伤。
     *
     * 早先版本一律按"有换行就取第一行"处理，把多行消息的后半截全丢了：
     * 一条「正在营业中…\n\n本店均是一机一图…\n\n有什么想了解的…」的自动回复
     * 只剩第一句。
     */
    fun cleanBubble(desc: String): String {
        val firstLine = desc.substringBefore('\n')
        val cut = firstLine.lastIndexOf(", ")
        if (cut > 0 && firstLine.length - cut <= MAX_ALIAS_LEN) {
            return firstLine.substring(0, cut).trim()
        }
        return desc.replace('\n', ' ').replace(Regex("""\s{2,}"""), " ").trim()
    }

    /**
     * 行的 desc 是不是**元信息**（日期、已读/未读标记）—— 这些不是消息正文。
     *
     * 实测形态：`'10-09 17:56'`、`'10-10 21:10\n未读'`、`'已读'`、`'智能回复·\n已读'`。
     */
    fun looksLikeMeta(text: String): Boolean {
        val t = text.trim()
        if (t.isEmpty()) return false
        if (t == "未读" || t == "已读") return true
        if (t.startsWith("已读") || t.startsWith("智能回复")) return true
        // 多行的话逐行看，全是元信息才算
        val lines = t.split('\n').map { it.trim() }.filter { it.isNotEmpty() }
        return lines.isNotEmpty() && lines.all { isTimestamp(it) || it == "未读" || it == "已读" }
    }

    /** `08:44` / `10-09 17:56` / `10月15日 09:30` / `昨天 08:44` */
    fun isTimestamp(t: String): Boolean {
        val s = t.trim()
        return Regex("""^\d{1,2}[:：]\d{2}$""").matches(s) ||
            Regex("""^\d{1,2}-\d{1,2}\s+\d{1,2}[:：]\d{2}$""").matches(s) ||
            Regex("""^\d+月\d+日(\s+\d{1,2}[:：]\d{2})?$""").matches(s) ||
            Regex("""^(昨天|今天|前天|星期[一二三四五六日])(\s+\d{1,2}[:：]\d{2})?$""").matches(s)
    }

    /**
     * 顶栏和底栏的功能文案。它们也是 `View` + 非空 desc，不挡掉的话
     * 顶栏那个全宽行会被当成一条消息，抓出 `me: 更多` 这种假数据。
     */
    private val CHROME = setOf(
        "返回", "更多", "修改", "商品图片", "语音按钮", "表情按钮", "更多选择",
    )

    fun isChrome(desc: String): Boolean {
        val d = desc.trim()
        if (d in CHROME) return true
        return d.startsWith("商品信息") ||
            d.startsWith("TA买过") ||
            d.startsWith("引导您脱离闲鱼平台") ||
            d.startsWith("闲鱼私聊")
    }

    /** 顶栏昵称：`'TA买过你的宝贝\ntbNick_2r4g1\n会员名：t***3'` → `tbNick_2r4g1` */
    fun titleFromTopBar(desc: String): String? {
        if (!desc.contains("会员名") || !desc.contains('\n')) return null
        val lines = desc.split('\n').map { it.trim() }.filter { it.isNotEmpty() }
        val idx = lines.indexOfFirst { it.contains("会员名") }
        val name = if (idx > 0) lines[idx - 1] else lines.firstOrNull()
        return name?.takeIf { it.isNotBlank() }
    }

    /** 商品卡：`'商品信息, ¥1788.00\n含运费0.00元\n广东·深圳'` → 单行文本 */
    fun productContext(desc: String): String? {
        val d = desc.trim()
        if (!d.startsWith("商品信息")) return null
        return d.replace('\n', ' ').replace(Regex("""\s{2,}"""), " ").trim()
    }

    /** 昵称最长按这个长度算；超过就认为 `, ` 是正文里的一部分，不切。 */
    private const val MAX_ALIAS_LEN = 32
}
