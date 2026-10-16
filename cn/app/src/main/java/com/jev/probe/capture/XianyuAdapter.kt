package com.jev.probe.capture

import android.content.res.Resources
import android.graphics.Rect
import android.view.accessibility.AccessibilityNodeInfo
import com.jev.probe.core.ChatSnapshot
import com.jev.probe.core.Msg

/**
 * 闲鱼私信（com.taobao.idlefish）。
 *
 * 实测环境：RMX6699 / Android 17 (SDK 37) / 1440×3136，2026-10-15。
 *
 * 页面是 Flutter 混合工程（`com.idlefish.flutterbridge.flutterboost.boost.
 * FishFlutterBoostActivity`），所以**跟 QQ 那套完全不一样**：
 * - `text` 恒为空，正文一律在 `content-desc` 里
 * - 没有可用的 resource-id（全树只有 `android:id/content` 这类框架 id）
 * - class 只有 View / ImageView / FrameLayout / ScrollView 四种
 *
 * 实测节点形态：
 * ```
 * View [0,624][1440,1176] desc='10-09 17:56'          ← 消息行（全宽）
 *   ImageView [48,896][240,1072]  desc='头像'          ← 头像贴左 → 对方
 *   View      [240,896][1260,1144] desc='<正文>'
 * View [0,1416][1440,2024] desc='10-10 21:10\n未读'
 *   View      [624,1688][1200,1896] desc='<正文>'
 *   ImageView [1232,1696][1392,1856] desc='头像'       ← 头像贴右 → 我
 * ```
 *
 * 文本层面的规则都在 [XianyuRules] 里（纯函数、可单测）；这里只负责在无障碍树上跑。
 *
 * ## 两个必须知道的取舍
 *
 * 1. **「我/对方」只信头像位置。** 不能用气泡中心判断——宽气泡的中心会跨过屏幕
 *    中线，实测一条我发的消息中心在 x=686（屏幕中心 720），按中心判会得出"对方"。
 *    上游在 QQ 上也踩过同一个坑。
 *
 * 2. **屏幕最顶部只露头的那条消息读不到。** 它的头像已经滚出屏幕，而"必须有头像"
 *    是排除顶栏的必要条件（顶栏 `[0,160][1440,336]` 同样全宽+focusable，放开就会
 *    被当成一条 `me: 更多` 的假消息）。影响有限：那条消息在完整显示时已经被
 *    `ContextBuilder` 记进历史日志了。
 *
 * 只读。不点任何东西，不发任何消息。
 */
class XianyuAdapter : ChatAppAdapter {
    override val pkg = XianyuRules.PACKAGE

    override fun extract(root: AccessibilityNodeInfo, res: Resources): ChatSnapshot? {
        val width = res.displayMetrics.widthPixels
        val height = res.displayMetrics.heightPixels
        // 只排除状态栏。顶栏/商品卡不靠 y 排除——它们没有头像，collectRow 会挡掉。
        val topBand = (height * 0.02).toInt()
        // 输入栏所在的那条带不进消息区
        val bottomBand = (height * 0.88).toInt()

        var inChat = false
        var title: String? = null
        var productInfo: String? = null
        val rows = ArrayList<Row>()

        val stack = ArrayDeque<AccessibilityNodeInfo>()
        stack.addLast(root)
        var guard = 0
        while (stack.isNotEmpty() && guard < 6000) {
            guard++
            val node = stack.removeLast()
            val cls = node.className?.toString() ?: ""
            val desc = node.contentDescription?.toString()?.trim().orEmpty()

            // 输入栏存在 = 在聊天页。可编辑语义没暴露，只能靠占位提示认。
            if (!inChat && desc == XianyuRules.INPUT_HINT && node.isClickable) {
                inChat = true
            }

            if (title == null) {
                val b = Rect()
                node.getBoundsInScreen(b)
                if (b.top < (height * 0.2).toInt()) {
                    XianyuRules.titleFromTopBar(desc)?.let { title = it }
                }
            }

            if (productInfo == null) {
                val b = Rect()
                node.getBoundsInScreen(b)
                if (b.top < (height * 0.3).toInt()) {
                    XianyuRules.productContext(desc)?.let { productInfo = it }
                }
            }

            if (cls == "android.view.View" && node.isFocusable) {
                val b = Rect()
                node.getBoundsInScreen(b)
                val fullWidth = b.left <= 0 && b.right >= width
                val saneHeight = b.height() in 1..(height * 0.6).toInt()
                if (fullWidth && saneHeight && b.bottom > topBand && b.top < bottomBand) {
                    collectRow(node, b, width)?.let { rows.add(it) }
                }
            }

            for (i in node.childCount - 1 downTo 0) node.getChild(i)?.let { stack.addLast(it) }
        }

        if (!inChat) return null

        if (rows.isEmpty()) {
            // 在聊天页但没解析出正文 —— 交给截屏 + OCR 兜底
            return ChatSnapshot(title, emptyList(), extraContext = productInfo)
        }

        rows.sortBy { it.top }
        return ChatSnapshot(
            title,
            rows.map { Msg(it.side, it.text) },
            extraContext = productInfo,
        )
    }

    private data class Row(val top: Int, val side: String, val text: String)

    /**
     * 把一行消息节点拆成 (说话方, 正文)。返回 null 表示**这行不是消息**。
     *
     * 必须有头像 —— 商品卡、「确认收货」按钮、反诈提示条、顶栏都没有头像，
     * 靠这一条就能全部挡掉。
     *
     * 必须**递归**找：实测左对齐（对方）的头像是直接子节点，右对齐（我）的头像
     * 被多包了一层变成孙节点。早先版本只遍历直接子节点，结果我发的消息一条都读不到。
     */
    private fun collectRow(row: AccessibilityNodeInfo, rowBounds: Rect, width: Int): Row? {
        var avatarCenterX = -1
        var bubbleText: String? = null

        val queue = ArrayDeque<AccessibilityNodeInfo>()
        for (i in 0 until row.childCount) row.getChild(i)?.let { queue.addLast(it) }
        var guard = 0
        while (queue.isNotEmpty() && guard < 300) {
            guard++
            val node = queue.removeFirst()
            val cls = node.className?.toString() ?: ""
            val desc = node.contentDescription?.toString()?.trim().orEmpty()

            if (desc == XianyuRules.AVATAR) {
                if (avatarCenterX < 0) {
                    val b = Rect()
                    node.getBoundsInScreen(b)
                    avatarCenterX = b.centerX()
                }
                continue // 头像内部不再往下看
            }

            if (bubbleText == null && desc.isNotEmpty() &&
                !XianyuRules.isChrome(desc) && !XianyuRules.looksLikeMeta(desc)
            ) {
                when {
                    desc.startsWith("图片消息") -> bubbleText = "[图片]"
                    cls == "android.view.View" -> bubbleText = XianyuRules.cleanBubble(desc)
                }
            }

            for (i in 0 until node.childCount) node.getChild(i)?.let { queue.addLast(it) }
        }

        if (avatarCenterX < 0) return null
        val text = bubbleText?.takeIf { it.isNotBlank() } ?: return null

        return Row(rowBounds.top, if (avatarCenterX > width / 2) "me" else "other", text)
    }
}
