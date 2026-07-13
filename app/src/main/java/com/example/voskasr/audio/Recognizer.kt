package com.example.voskasr.audio

import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow

enum class AsrEngine { VOSK, BAIDU, AUTO }

sealed class RecognizerState {
    data object Idle : RecognizerState()
    data object Connecting : RecognizerState()
    data object Ready : RecognizerState()
    data class Error(val message: String) : RecognizerState()
    data object Closed : RecognizerState()
}

data class RecognizerResult(
    val type: Type,
    val text: String,
    val startTimeMs: Long? = null,
    val endTimeMs: Long? = null,
    val engine: String = ""
) {
    enum class Type { PARTIAL, FINAL, ERROR }
}

interface Recognizer {
    val displayName: String
    val state: StateFlow<RecognizerState>
    val results: SharedFlow<RecognizerResult>

    suspend fun start()
    fun feedPcm(pcm: ByteArray)
    suspend fun stop()
    fun destroy()
}
