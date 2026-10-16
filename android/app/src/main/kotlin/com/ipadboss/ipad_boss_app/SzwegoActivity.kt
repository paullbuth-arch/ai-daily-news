package com.ipadboss.ipad_boss_app

import android.app.Activity
import android.content.ContentValues
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.webkit.ConsoleMessage
import android.webkit.CookieManager
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import java.io.ByteArrayInputStream
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 微购相册网页版，用**原生 WebView** 打开。
 *
 * ## 为什么不用 Flutter 的 webview_flutter
 *
 * 该站按运行环境判断设备：认出手机就只渲染一页「请在电脑上打开，或使用App」。
 * 实测 `setUserAgentString` 只改 UA 字符串，[android.webkit.WebView] 的
 * `navigator.userAgentData.mobile` / `platform` / `maxTouchPoints` 照样报手机；
 * 而在 `onPageStarted` 里 `evaluateJavascript` 注入**跑得太晚**——注入虽然生效了
 * （能在页面里读到改后的值），但拦截页已经渲染完了。
 *
 * 换 `loadDataWithBaseURL` 能把脚本内联进 `<head>` 抢先执行，可那种页面 origin
 * 不透明，`localStorage` 存不住，而该站把登录 token 存在那里——重进就掉登录。
 *
 * 所以走原生：用 [WebViewClient.shouldInterceptRequest] **只拦主 HTML 文档**，
 * 自己按桌面身份取回来、在 `<head>` 里插一段脚本，再交还给 WebView 渲染。
 * URL 和 origin 都是真的，Cookie 与 localStorage 保持原生行为。
 *
 * ## 几条硬规矩
 *
 * - **只拦主文档**（[WebResourceRequest.isForMainFrame]），JS/CSS/图片/XHR 一律
 *   返回 null 放行，让 WebView 走它自己的流程——缓存、CORS、Cookie 都不受影响。
 * - **不跟重定向**。`szwego.com/` 会 302 到 `/static/index.html`；如果我们自己
 *   跟着跳，WebView 的地址栏还停在原地址，SPA 的 hash 路由会错乱。放行让 WebView
 *   自己去跳，只在落地那个 `.html` 上做注入。
 * - **不复制 Content-Length / Content-Encoding / Transfer-Encoding**：响应体被我们
 *   改过，长度和编码都对不上了，照抄会让 WebView 解析失败。
 */
class SzwegoActivity : Activity() {

    private lateinit var web: WebView
    private lateinit var title: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(BG)
        }
        // targetSdk 36 → Android 15+ 强制 edge-to-edge，内容默认画到状态栏底下。
        // 不补这个 padding，工具栏的标题和按钮会和状态栏图标糊在一起。
        ViewCompat.setOnApplyWindowInsetsListener(root) { v, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            v.setPadding(0, bars.top, 0, bars.bottom)
            insets
        }
        root.addView(buildToolbar())
        web = buildWebView()
        root.addView(
            web,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )
        setContentView(root)

        web.loadUrl(START_URL)
    }

    // ── 界面 ────────────────────────────────────────────────────────────

    private fun buildToolbar(): View {
        val bar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setBackgroundColor(BG)
            setPadding(dp(6), dp(10), dp(6), dp(10))
        }
        bar.addView(barButton("‹") { finish() })
        title = TextView(this).apply {
            text = "微购相册"
            setTextColor(FG)
            textSize = 17f
            gravity = Gravity.CENTER
        }
        bar.addView(
            title,
            LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f),
        )
        bar.addView(barButton("转存") { dumpStructure() })
        bar.addView(barButton("⟳") { web.reload() })
        return bar
    }

    private fun barButton(label: String, onClick: () -> Unit) = TextView(this).apply {
        text = label
        setTextColor(FG)
        textSize = 15f
        gravity = Gravity.CENTER
        setPadding(dp(14), dp(8), dp(14), dp(8))
        setOnClickListener { onClick() }
    }

    private fun buildWebView(): WebView = WebView(this).apply {
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.databaseEnabled = true
        settings.useWideViewPort = true
        settings.loadWithOverviewMode = true
        settings.builtInZoomControls = true
        settings.displayZoomControls = false
        settings.cacheMode = WebSettings.LOAD_DEFAULT
        // 桌面身份。配合下面的请求头改写，让页面里里外外都像电脑。
        settings.userAgentString = DESKTOP_UA
        CookieManager.getInstance().setAcceptCookie(true)
        CookieManager.getInstance().setAcceptThirdPartyCookies(this, true)
        webViewClient = InjectingClient()
        webChromeClient = ConsoleReporter()
    }

    /** 临时：把页面的 JS 报错弹出来。console 回调在 WebChromeClient 上。 */
    private inner class ConsoleReporter : WebChromeClient() {
        override fun onConsoleMessage(msg: ConsoleMessage): Boolean {
            // 只报错误级，普通 log 会刷屏。
            if (msg.messageLevel() == ConsoleMessage.MessageLevel.ERROR) {
                toast("[JS] ${msg.message().take(150)}")
            }
            return false
        }
    }

    // ── 注入 ────────────────────────────────────────────────────────────

    private inner class InjectingClient : WebViewClient() {

        override fun shouldInterceptRequest(
            view: WebView,
            request: WebResourceRequest,
        ): WebResourceResponse? {
            // 子资源全部放行。只碰主文档，其余交给 WebView 原生处理。
            if (!request.isForMainFrame) return null
            val url = request.url ?: return null
            val host = url.host ?: return null
            if (!host.endsWith("szwego.com")) return null
            // 只处理 HTML 文档。`szwego.com/` 本身不匹配，于是 WebView 自己去跟
            // 302，落地到 /static/index.html 时才会进到这里。
            val path = url.path ?: return null
            if (!path.endsWith(".html")) return null

            return try {
                fetchAndInject(url.toString())
            } catch (e: Exception) {
                // 注入是加分项，失败就让 WebView 照常请求——页面不能因此打不开。
                null
            }
        }

        // ── 临时的错误上报。站自己的错误页只画一个感叹号、不带原因，
        //    必须从底层把失败原因掏出来，否则只能靠猜。定位完删掉。
        override fun onReceivedError(
            view: WebView,
            request: WebResourceRequest,
            error: WebResourceError,
        ) {
            if (request.isForMainFrame) {
                toast("主文档失败 ${error.errorCode} ${error.description}")
            }
        }

        override fun onReceivedHttpError(
            view: WebView,
            request: WebResourceRequest,
            response: WebResourceResponse,
        ) {
            if (request.isForMainFrame) {
                toast("主文档 HTTP ${response.statusCode}")
            }
        }

        override fun onPageFinished(view: WebView, url: String) {
            super.onPageFinished(view, url)
            // 页面没有 <title> 时 getTitle() 会退回 URL（形如 `szwego.com/static/…`，
            // 不带协议头），直接显示会把标题栏撑成一长条，认出来就用兜底文案。
            val t = view.title?.trim().orEmpty()
            val looksLikeUrl = t.startsWith("http") || t.contains("szwego.com") ||
                t.contains('/') || t.contains(' ')
            title.text = if (t.isNotEmpty() && !looksLikeUrl) t else "微购相册"
        }
    }

    /**
     * 按桌面身份取回文档，把伪装脚本插到 `<head>` 开头。
     *
     * Cookie 从 [CookieManager] 显式取——`request.requestHeaders` 里不一定带，
     * 少发 Cookie 会直接掉登录态。
     */
    private fun fetchAndInject(url: String): WebResourceResponse? {
        val conn = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = 15000
            readTimeout = 20000
            instanceFollowRedirects = false
            requestMethod = "GET"
            setRequestProperty("User-Agent", DESKTOP_UA)
            setRequestProperty("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
            setRequestProperty("Accept-Language", "zh-CN,zh;q=0.9,en;q=0.8")
            // 请求头也照桌面报，别只在 JS 里撒谎——两者不一致本身就是破绽。
            setRequestProperty("Sec-CH-UA-Mobile", "?0")
            setRequestProperty("Sec-CH-UA-Platform", "\"Windows\"")
            CookieManager.getInstance().getCookie(url)?.let {
                setRequestProperty("Cookie", it)
            }
        }

        val code = conn.responseCode
        if (code !in 200..299) {
            conn.disconnect()
            return null // 非 2xx 交回 WebView，让它按自己的规则处理
        }
        // 这两个字段必须在 disconnect() 之前取：断开后再读会抛异常。
        val reason = conn.responseMessage ?: "OK"

        // 服务器若在这条响应上发 Cookie，必须替它写进 CookieManager——
        // 响应是我们造的，WebView 不会自己处理 Set-Cookie。
        conn.headerFields["Set-Cookie"]?.forEach { raw ->
            raw?.split(";")?.firstOrNull()?.let { CookieManager.getInstance().setCookie(url, it) }
        }

        val bytes = conn.inputStream.use { it.readBytes() }
        conn.disconnect()

        val html = String(bytes, Charsets.UTF_8)
        val patched = injectIntoHead(html).toByteArray(Charsets.UTF_8)

        val headers = HashMap<String, String>()
        headers["Content-Type"] = "text/html; charset=utf-8"
        headers["Cache-Control"] = "no-cache"

        return WebResourceResponse(
            "text/html",
            "utf-8",
            code,
            reason,
            headers,
            ByteArrayInputStream(patched),
        )
    }

    private fun injectIntoHead(html: String): String {
        val script = "<script>$SPOOF_JS</script>"
        val head = html.indexOf("<head>", ignoreCase = true)
        if (head >= 0) {
            val at = head + "<head>".length
            return html.substring(0, at) + script + html.substring(at)
        }
        // 没有 <head> 就插到最前面，一样能保证先于页面脚本执行。
        return script + html
    }

    // ── 转存页面结构 ────────────────────────────────────────────────────

    /**
     * 把当前 DOM 导出成 html 写到公共下载目录。
     *
     * 商品字段的解析规则必须照着真实结构写，所以先把它存出来。
     * 写公共目录而不是分享：用 adb 直接 pull 走，少一步人工转发。
     */
    private fun dumpStructure() {
        web.evaluateJavascript("document.documentElement.outerHTML") { raw ->
            val html = unquoteJsString(raw)
            if (html.isNullOrBlank()) {
                toast("页面还是空的，等加载完再试")
                return@evaluateJavascript
            }
            try {
                val name = "szwego_页面结构_" +
                    SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date()) + ".html"
                val where = saveToDownloads(name, html.toByteArray(Charsets.UTF_8))
                toast("已导出 ${html.length / 1024}KB → $where")
            } catch (e: Exception) {
                toast("导出失败：${e.message}")
            }
        }
    }

    /** `evaluateJavascript` 返回的是 JSON 字符串（外面多一层引号、内部转义）。 */
    private fun unquoteJsString(raw: String?): String? {
        var s = raw ?: return null
        if (s == "null") return null
        if (s.length >= 2 && s.startsWith("\"") && s.endsWith("\"")) {
            s = s.substring(1, s.length - 1)
        }
        return s.replace("\\u003C", "<")
            .replace("\\u003E", ">")
            .replace("\\\"", "\"")
            .replace("\\\\", "\\")
            .replace("\\n", "\n")
            .replace("\\r", "\r")
            .replace("\\t", "\t")
            .replace("\\/", "/")
    }

    /** 走 MediaStore 写公共 Download/货脉抓取/；低版本直接写外部存储。 */
    private fun saveToDownloads(name: String, bytes: ByteArray): String {
        val dir = "货脉抓取"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.MediaColumns.MIME_TYPE, "text/html")
                put(
                    MediaStore.MediaColumns.RELATIVE_PATH,
                    "${Environment.DIRECTORY_DOWNLOADS}/$dir",
                )
            }
            val uri = contentResolver.insert(
                MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY),
                values,
            ) ?: throw IllegalStateException("MediaStore 拒绝写入")
            contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw IllegalStateException("打不开输出流")
            return "下载/$dir/$name"
        }
        @Suppress("DEPRECATION")
        val target = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            "$dir/$name",
        )
        target.parentFile?.mkdirs()
        target.writeBytes(bytes)
        return target.absolutePath
    }

    // ── 杂项 ────────────────────────────────────────────────────────────

    /** 返回键先退回网页上一页，退无可退才关掉这个 Activity。 */
    @Suppress("DEPRECATION", "OVERRIDE_DEPRECATION")
    override fun onBackPressed() {
        if (web.canGoBack()) web.goBack() else super.onBackPressed()
    }

    private fun toast(msg: String) =
        Toast.makeText(this, msg, Toast.LENGTH_LONG).show()

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()

    private companion object {
        const val BG = 0xFF14161C.toInt()
        const val FG = 0xFFE9ECF1.toInt()

        /**
         * 起始地址。
         *
         * 用 `#/pc_login` 而不是站点根：根地址会 302 到 `link_type=pc_login`，
         * 那条路一样。直接落到登录路由，登进去之后站点自己会跳回首页。
         *
         * 游客态的「我」页面**没有登录入口**，所以必须从这条路由进。
         */
        const val START_URL = "https://www.szwego.com/static/index.html#/pc_login"

        const val DESKTOP_UA =
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
                "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

        /**
         * 把 Client Hints 和触摸能力一并伪装成桌面。
         *
         * 这段必须**内联进文档**执行（见 [injectIntoHead]）。实测在
         * `onPageStarted` 里用 `evaluateJavascript` 注入虽然生效，但拦截页
         * 已经渲染完了——那时序上已经输了。
         */
        val SPOOF_JS = """
(function () {
  var def = function (o, k, v) {
    try { Object.defineProperty(o, k, { get: function () { return v; }, configurable: true }); } catch (e) {}
  };
  var fake = {
    mobile: false,
    platform: 'Windows',
    brands: [{ brand: 'Chromium', version: '120' }, { brand: 'Not_A Brand', version: '8' }],
    getHighEntropyValues: function () { return Promise.resolve(fake); }
  };
  def(navigator, 'userAgentData', fake);
  try { def(Navigator.prototype, 'userAgentData', fake); } catch (e) {}
  def(navigator, 'platform', 'Win32');
  def(navigator, 'maxTouchPoints', 0);
  def(navigator, 'msMaxTouchPoints', 0);
  try { delete window.ontouchstart; } catch (e) { window.ontouchstart = undefined; }
  var d = function (q, m) {
    return {
      matches: m, media: q, onchange: null,
      addListener: function () {}, removeListener: function () {},
      addEventListener: function () {}, removeEventListener: function () {},
      dispatchEvent: function () { return false; }
    };
  };
  var mm = window.matchMedia ? window.matchMedia.bind(window) : null;
  if (mm) {
    window.matchMedia = function (q) {
      var s = String(q).toLowerCase();
      if (s.indexOf('coarse') >= 0) return d(q, false);
      if (s.indexOf('pointer: fine') >= 0 || s.indexOf('hover: hover') >= 0) return d(q, true);
      if (s.indexOf('pointer: none') >= 0) return d(q, false);
      return mm(q);
    };
  }
})();
""".trimIndent()
    }
}
