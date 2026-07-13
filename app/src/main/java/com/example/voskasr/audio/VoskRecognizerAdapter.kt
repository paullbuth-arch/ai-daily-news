package com.example.voskasr.audio

import android.content.Context
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.json.JSONObject

/**
 * Adapts the existing synchronous [VoskRecognizer] into the async [Recognizer] interface.
 * The delegate class is left untouched to preserve the native/Vosk code path.
 */
class VoskRecognizerAdapter(
    context: Context,
    private val scope: CoroutineScope
) : Recognizer {

    override val displayName: String = "Vosk 离线"

    private val delegate = VoskRecognizer(context)

    private val _state = MutableStateFlow<RecognizerState>(RecognizerState.Idle)
    override val state = _state.asStateFlow()

    private val _results = MutableSharedFlow<RecognizerResult>(extraBufferCapacity = 64)
    override val results = _results.asSharedFlow()

    @Volatile
    private var ready = false

    suspend fun warmUp() {
        _state.value = RecognizerState.Connecting
        val ok = delegate.initModel()
        ready = ok
        _state.value = if (ok) RecognizerState.Ready
                       else RecognizerState.Error("Vosk 模型加载失败")
    }

    override suspend fun start() {
        // Vosk is always-on once warmed up; nothing to do per session.
    }

    override fun feedPcm(pcm: ByteArray) {
        if (!ready) return
        val (isFinal, text) = delegate.feedPcm(pcm)
        if (text.isEmpty()) return
        try {
            val parsed = parseVoskResult(text, isFinal)
            if (parsed.isNotEmpty()) {
                _results.tryEmit(
                    RecognizerResult(
                        type = if (isFinal) RecognizerResult.Type.FINAL
                               else RecognizerResult.Type.PARTIAL,
                        text = parsed,
                        engine = displayName
                    )
                )
            }
        } catch (_: Exception) {
            // JSON parse failure: pass through raw text as a fallback so the user still sees output
            _results.tryEmit(
                RecognizerResult(
                    type = if (isFinal) RecognizerResult.Type.FINAL
                           else RecognizerResult.Type.PARTIAL,
                    text = text,
                    engine = displayName
                )
            )
        }
    }

    override suspend fun stop() {
        // Vosk is always-on; nothing to do per session.
    }

    override fun destroy() {
        ready = false
        delegate.destroy()
        _state.value = RecognizerState.Closed
    }

    private fun parseVoskResult(json: String, isFinal: Boolean): String {
        val obj = JSONObject(json)
        return if (isFinal) {
            obj.optString("text", "")
        } else {
            obj.optString("partial", "")
        }
    }
}
