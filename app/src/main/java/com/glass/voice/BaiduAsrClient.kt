package com.glass.voice

import android.util.Log
import okhttp3.*
import okio.ByteString
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

class BaiduAsrClient(
    private val apiKey: String,
    private val secretKey: String,
    private val appId: Int = 7907655,
    private val devPid: Int = 15372
) : WebSocketListener() {

    private var client: OkHttpClient? = null
    private var ws: WebSocket? = null
    private val started = AtomicBoolean(false)
    private val pcmBuffer = ByteArrayOutputStream()

    @Volatile var onResult: ((String, Boolean) -> Unit)? = null // text, isFinal
    @Volatile var onError: ((String) -> Unit)? = null
    @Volatile var onReady: (() -> Unit)? = null

    @Volatile var accessToken: String? = null

    fun start(): Boolean {
        if (started.get()) return true

        val token = fetchAccessToken() ?: run { onError?.invoke("token获取失败"); return false }
        accessToken = token

        client = OkHttpClient.Builder().pingInterval(15, TimeUnit.SECONDS).build()
        val sn = UUID.randomUUID().toString()
        val req = Request.Builder().url("wss://vop.baidu.com/realtime_asr?sn=$sn").build()
        ws = client!!.newWebSocket(req, this)
        started.set(true)
        return true
    }

    override fun onOpen(webSocket: WebSocket, response: Response) {
        val frame = JSONObject().apply {
            put("type", "START")
            put("data", JSONObject().apply {
                put("appid", appId)
                put("appkey", apiKey)
                put("access_token", accessToken ?: "")
                put("dev_pid", devPid)
                put("cuid", "wq-glass-001")
                put("format", "pcm")
                put("sample", 16000)
            })
        }
        webSocket.send(frame.toString())
        onReady?.invoke()
        Log.i("BaiduASR", "WebSocket opened, START sent")
    }

    override fun onMessage(webSocket: WebSocket, text: String) {
        try {
            val json = JSONObject(text)
            val type = json.optString("type")
            val result = json.optString("result", "")
            val errNo = json.optInt("err_no", 0)

            when {
                type == "FIN_TEXT" && errNo != 0 -> onError?.invoke("ASR err: $errNo ${json.optString("err_msg")}")
                type == "FIN_TEXT" && result.isNotEmpty() -> onResult?.invoke(result, true)
                type == "MID_TEXT" && result.isNotEmpty() -> onResult?.invoke(result, false)
            }
        } catch (_: Exception) {}
    }

    override fun onMessage(webSocket: WebSocket, bytes: ByteString) {}

    override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
        onError?.invoke("WS failure: ${t.message}")
    }

    override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
        started.set(false)
    }

    fun feedPcm(pcm: ByteArray) {
        if (pcm.isEmpty()) return
        synchronized(pcmBuffer) {
            pcmBuffer.write(pcm)
            while (pcmBuffer.size() >= FRAME_SIZE) {
                val all = pcmBuffer.toByteArray()
                val frame = all.copyOfRange(0, FRAME_SIZE)
                pcmBuffer.reset()
                if (all.size > FRAME_SIZE) pcmBuffer.write(all, FRAME_SIZE, all.size - FRAME_SIZE)
                ws?.send(ByteString.of(*frame))
            }
        }
    }

    fun stop() {
        try { ws?.send("""{"type":"FINISH"}""") } catch (_: Exception) {}
        try { ws?.close(1000, null) } catch (_: Exception) { ws?.cancel() }
        ws = null
        client?.dispatcher?.executorService?.shutdown()
        client = null
        started.set(false)
        synchronized(pcmBuffer) { pcmBuffer.reset() }
    }

    private fun fetchAccessToken(): String? {
        return try {
            val url = URL("https://aip.baidubce.com/oauth/2.0/token?grant_type=client_credentials&client_id=$apiKey&client_secret=$secretKey")
            val conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"; connectTimeout = 5000; readTimeout = 5000
            }
            JSONObject(conn.inputStream.bufferedReader().readText()).getString("access_token")
        } catch (e: Exception) { null }
    }

    companion object {
        const val FRAME_SIZE = 5120
    }
}
