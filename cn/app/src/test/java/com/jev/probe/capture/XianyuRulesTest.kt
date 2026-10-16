package com.jev.probe.capture

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 闲鱼解析规则的回归测试。
 *
 * **下面每个输入都是从真机 dump 里原样抄下来的**（RMX6699 / Android 17 /
 * 1440×3136，2026-10-15），不是编的。两个已修复的 bug 各自对应一组用例。
 */
class XianyuRulesTest {

    // ══════════════════════════════════════════════════════════════
    // Bug 1：长消息被腰斩
    // 早先规则是"有换行就取第一行"，把多行消息的后半截全丢了。
    // ══════════════════════════════════════════════════════════════

    @Test
    fun `多行消息完整保留，换行压成空格`() {
        val raw = "正在营业中，马上就回来+请等待一下喔。\n\n本店均是一机一图，都是实价，" +
            "喜欢的话直接拍下即可\n\n有什么想了解的都可以直接问我，上线了都会一一回复❤❤！"
        val out = XianyuRules.cleanBubble(raw)
        assertTrue("第二段不能丢", out.contains("本店均是一机一图"))
        assertTrue("第三段不能丢", out.contains("有什么想了解的"))
        assertTrue("不该有换行", !out.contains('\n'))
        assertTrue("不该有连续空格", !out.contains("  "))
    }

    @Test
    fun `单行消息原样返回`() {
        assertEquals("没", XianyuRules.cleanBubble("没"))
        assertEquals("我要用一下", XianyuRules.cleanBubble("我要用一下"))
    }

    // ══════════════════════════════════════════════════════════════
    // Bug 2：引用回复把昵称和原文混进正文
    // 形态是 `正文, 昵称\n被引用的原文`，半角 `, ` 才是分隔符。
    // ══════════════════════════════════════════════════════════════

    @Test
    fun `引用回复只留正文，剥掉昵称和引用原文`() {
        val raw = "找不到了，太久了[捂脸哭][捂脸哭], 乌托邦摘草莓的深海鳗鲡\n" +
            "那个卖家的购买记录可以发给我吗"
        val out = XianyuRules.cleanBubble(raw)
        assertEquals("找不到了，太久了[捂脸哭][捂脸哭]", out)
        assertFalse("昵称要剥掉", out.contains("乌托邦"))
        assertFalse("引用原文要剥掉", out.contains("那个卖家的购买记录"))
    }

    @Test
    fun `正文里的全角逗号不受影响`() {
        val out = XianyuRules.cleanBubble("你好，请问，这个还在吗")
        assertEquals("你好，请问，这个还在吗", out)
    }

    @Test
    fun `半角逗号后面接很长的内容时不当作昵称`() {
        // 超过昵称长度上限（32）就认为那是正文的一部分，不切
        val long = "价格是 100, 然后运费另算, 走顺丰的话要加钱, 你看行不行呢"
        val out = XianyuRules.cleanBubble(long)
        assertTrue("不该被误切", out.contains("走顺丰的话要加钱"))
    }

    // ══════════════════════════════════════════════════════════════
    // 元信息识别 —— 日期和已读标记不是正文
    // ══════════════════════════════════════════════════════════════

    @Test
    fun `行的元信息被识别出来`() {
        assertTrue(XianyuRules.looksLikeMeta("10-09 17:56"))
        assertTrue(XianyuRules.looksLikeMeta("10-10 21:11\n已读"))
        assertTrue(XianyuRules.looksLikeMeta("已读"))
        assertTrue(XianyuRules.looksLikeMeta("未读"))
        assertTrue(XianyuRules.looksLikeMeta("智能回复·\n已读"))
        assertTrue(XianyuRules.looksLikeMeta("昨天 08:44"))
        assertTrue(XianyuRules.looksLikeMeta("10月15日 09:30"))
    }

    @Test
    fun `真正的消息不会被当成元信息`() {
        assertFalse(XianyuRules.looksLikeMeta("这个能操作吗"))
        assertFalse(XianyuRules.looksLikeMeta("没"))
        assertFalse(XianyuRules.looksLikeMeta("8点我再看看"))
        assertFalse(XianyuRules.looksLikeMeta(""))
    }

    // ══════════════════════════════════════════════════════════════
    // chrome 过滤 —— 顶栏/商品卡的按钮文案不能变成消息
    // 顶栏 `[0,160][1440,336]` 同样是全宽+focusable，不过滤会抓出 `me: 更多`
    // ══════════════════════════════════════════════════════════════

    @Test
    fun `顶栏和商品卡的文案被挡掉`() {
        assertTrue(XianyuRules.isChrome("返回"))
        assertTrue(XianyuRules.isChrome("更多"))
        assertTrue(XianyuRules.isChrome("修改"))
        assertTrue(XianyuRules.isChrome("商品图片"))
        assertTrue(XianyuRules.isChrome("商品信息, ¥1788.00\n含运费0.00元\n广东·深圳"))
        assertTrue(XianyuRules.isChrome("TA买过你的宝贝\ntbNick_2r4g1\n会员名：t***3"))
        assertTrue(
            XianyuRules.isChrome("引导您脱离闲鱼平台并且联系客服缴费的都是诈骗行为！"),
        )
    }

    @Test
    fun `正常消息不会被 chrome 过滤误伤`() {
        assertFalse(XianyuRules.isChrome("这个能操作吗"))
        assertFalse(XianyuRules.isChrome("你先用着吧，想删除东西的话手动删除一下"))
    }

    // ══════════════════════════════════════════════════════════════
    // 顶栏昵称 / 商品上下文
    // ══════════════════════════════════════════════════════════════

    @Test
    fun `从顶栏 desc 里取出对方昵称`() {
        assertEquals(
            "tbNick_2r4g1",
            XianyuRules.titleFromTopBar("TA买过你的宝贝\ntbNick_2r4g1\n会员名：t***3"),
        )
        assertEquals(
            "失约于月光",
            XianyuRules.titleFromTopBar("TA买过你的宝贝\n失约于月光\n会员名：t***9"),
        )
    }

    @Test
    fun `不是顶栏格式就返回 null`() {
        assertNull(XianyuRules.titleFromTopBar("这个能操作吗"))
        assertNull(XianyuRules.titleFromTopBar("会员名：t***9"))
        assertNull(XianyuRules.titleFromTopBar(""))
    }

    @Test
    fun `商品上下文压成单行`() {
        val out = XianyuRules.productContext("商品信息, ¥1788.00\n含运费0.00元\n广东·深圳")
        assertEquals("商品信息, ¥1788.00 含运费0.00元 广东·深圳", out)
    }

    @Test
    fun `不是商品卡就返回 null`() {
        assertNull(XianyuRules.productContext("这个能操作吗"))
        assertNull(XianyuRules.productContext(""))
    }
}
