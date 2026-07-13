package com.example.voskasr.audio.baidu

import com.example.voskasr.audio.Recognizer
import com.example.voskasr.audio.RecognizerResult
import com.example.voskasr.audio.RecognizerState
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okio.ByteString
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID
import java.util.concurrent.TimeUnit

class BaiduRealtimeAsrRecognizer(
    private val scope: CoroutineScope,
    private val config: BaiduAsrConfig
) : Recognizer, WebSocketListener() {

    override val displayName: String = "百度实时 ASR"

    private val _state = MutableStateFlow<RecognizerState>(RecognizerState.Idle)
    override val state = _state.asStateFlow()

    private val _results = MutableSharedFlow<RecognizerResult>(extraBufferCapacity = 64)
    override val results = _results.asSharedFlow()

    private var client: OkHttpClient? = null
    private var ws: WebSocket? = null

    private val pcmBuffer = ByteArrayOutputStream()
    private val bufferLock = Any()

    private val sessionLock = Mutex()
    private var openDeferred: CompletableDeferred<Boolean>? = null
    private var heartbeatJob: Job? = null

    @Volatile private var accessToken: String? = null
    @Volatile private var tokenExpiresAtMs: Long = 0L

    override suspend fun start() = sessionLock.withLock {
        if (_state.value is RecognizerState.Ready) return@withLock
        teardownWs()
        if (!config.isUsable()) {
            _state.value = RecognizerState.Error("百度配置缺失，请选择 Vosk 离线")
            return@withLock
        }
        val token = ensureAccessToken()
        if (token == null) {
            _state.value = RecognizerState.Error("百度 access_token 获取失败")
            return@withLock
        }
        _state.value = RecognizerState.Connecting

        val client = OkHttpClient.Builder()
            .pingInterval(PING_INTERVAL_SEC, TimeUnit.SECONDS)
            .build()
        this.client = client

        val sn = UUID.randomUUID().toString()
        val req = Request.Builder()
            .url("${config.websocketUrl}?sn=$sn")
            .build()

        openDeferred = CompletableDeferred()
        val ws = client.newWebSocket(req, this)
        this.ws = ws

        val ok = withTimeoutOrNull(START_TIMEOUT_MS) { openDeferred?.await() } ?: false
        if (!ok) {
            _state.value = RecognizerState.Error("百度 WebSocket 建连超时")
            teardownWs()
        }
    }

    override fun onOpen(webSocket: WebSocket, response: Response) {
        val startFrame = JSONObject().apply {
            put("type", "START")
            put("data", JSONObject().apply {
                put("appid", config.appId)
                put("appkey", config.apiKey)
                put("access_token", accessToken ?: "")
                put("dev_pid", config.devPid)
                put("cuid", config.cuid)
                put("format", "pcm")
                put("sample", 16000)
            })
        }
        webSocket.send(startFrame.toString())
        _state.value = RecognizerState.Ready
        startHeartbeat()
        openDeferred?.complete(true)
    }

    override fun onMessage(webSocket: WebSocket, text: String) {
        try {
            val json = JSONObject(text)
            val type = json.optString("type")
            val errNo = json.optInt("err_no", 0)
            val errMsg = json.optString("err_msg", "")
            val result = json.optString("result", "")
            when (type) {
                "MID_TEXT" -> {
                    if (result.isNotEmpty()) {
                        _results.tryEmit(
                            RecognizerResult(
                                type = RecognizerResult.Type.PARTIAL,
                                text = result,
                                engine = displayName
                            )
                        )
                    }
                }
                "FIN_TEXT" -> {
                    if (errNo == 0) {
                        val startTime = json.optLong("start_time", -1L).takeIf { it >= 0 }
                        val endTime = json.optLong("end_time", -1L).takeIf { it >= 0 }
                        _results.tryEmit(
                            RecognizerResult(
                                type = RecognizerResult.Type.FINAL,
                                text = result,
                                startTimeMs = startTime,
                                endTimeMs = endTime,
                                engine = displayName
                            )
                        )
                    } else {
                        emitError("$errNo: $errMsg")
                    }
                }
                "ERROR" -> emitError("$errNo: $errMsg")
                "HEARTBEAT" -> { /* server heartbeat ack, ignore */ }
            }
        } catch (_: Exception) {
            // JSON parse failure shouldn't kill the session
        }
    }

    override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
        // Baidu realtime ASR protocol is text-only; ignore binary frames
    }

    override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
        heartbeatJob?.cancel()
        try {
            webSocket.close(NORMAL_CLOSURE_STATUS, null)
        } catch (_: IllegalArgumentException) {
            webSocket.cancel()
        }
    }

    override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
        heartbeatJob?.cancel()
        _state.value = RecognizerState.Closed
    }

    override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
        heartbeatJob?.cancel()
        val msg = t.message ?: "WebSocket failure"
        _state.value = RecognizerState.Error(msg)
        openDeferred?.complete(false)
    }

    override fun feedPcm(pcm: ByteArray) {
        if (pcm.isEmpty()) return
        val chunksToSend = synchronized(bufferLock) {
            pcmBuffer.write(pcm)
            val out = ArrayList<ByteArray>(pcm.size / FRAME_SIZE + 1)
            while (pcmBuffer.size() >= FRAME_SIZE) {
                val all = pcmBuffer.toByteArray()
                val frame = all.copyOfRange(0, FRAME_SIZE)
                pcmBuffer.reset()
                if (all.size > FRAME_SIZE) {
                    pcmBuffer.write(all, FRAME_SIZE, all.size - FRAME_SIZE)
                }
                out.add(frame)
            }
            out
        }
        val socket = ws ?: return
        for (chunk in chunksToSend) {
            socket.send(ByteString.of(*chunk))
        }
    }

    override suspend fun stop() {
        sessionLock.withLock {
            heartbeatJob?.cancel()
            try {
                ws?.send("""{"type":"FINISH"}""")
            } catch (_: Exception) { }
            try {
                ws?.close(NORMAL_CLOSURE_STATUS, null)
            } catch (_: Exception) {
                ws?.cancel()
            }
        }
    }

    override fun destroy() {
        heartbeatJob?.cancel()
        teardownWs()
        synchronized(bufferLock) { pcmBuffer.reset() }
    }

    private fun emitError(message: String) {
        _results.tryEmit(
            RecognizerResult(
                type = RecognizerResult.Type.ERROR,
                text = message,
                engine = displayName
            )
        )
        _state.value = RecognizerState.Error(message)
    }

    private fun startHeartbeat() {
        heartbeatJob?.cancel()
        heartbeatJob = scope.launch {
            while (isActive) {
                delay(HEARTBEAT_INTERVAL_MS)
                if (_state.value is RecognizerState.Ready) {
                    try {
                        ws?.send("""{"type":"HEARTBEAT"}""")
                    } catch (_: Exception) { }
                }
            }
        }
    }

    private fun teardownWs() {
        try { ws?.cancel() } catch (_: Exception) { }
        ws = null
        try { client?.dispatcher?.executorService?.shutdown() } catch (_: Exception) { }
        client = null
    }

    private suspend fun ensureAccessToken(): String? {
        val now = System.currentTimeMillis()
        val cur = accessToken
        if (cur != null && now < tokenExpiresAtMs - 60_000L) return cur
        return withContext(Dispatchers.IO) {
            try {
                val url = URL(
                    "https://aip.baidubce.com/oauth/2.0/token" +
                        "?grant_type=client_credentials" +
                        "&client_id=${config.apiKey}" +
                        "&client_secret=${config.secretKey}"
                )
                val conn = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    connectTimeout = 5000
                    readTimeout = 5000
                }
                val body = conn.inputStream.use { it.bufferedReader().readText() }
                val j = JSONObject(body)
                val t = j.getString("access_token")
                val expiresIn = j.optLong("expires_in", 2592000L)
                accessToken = t
                tokenExpiresAtMs = now + expiresIn * 1000L
                t
            } catch (e: Exception) {
                e.printStackTrace()
                null
            }
        }
    }

    companion object {
        const val FRAME_SIZE = 5120  // 160ms @ 16kHz/16bit/mono
        const val HEARTBEAT_INTERVAL_MS = 3000L
        const val PING_INTERVAL_SEC = 15L
        const val START_TIMEOUT_MS = 3000L
        const val NORMAL_CLOSURE_STATUS = 1000
    }
}
