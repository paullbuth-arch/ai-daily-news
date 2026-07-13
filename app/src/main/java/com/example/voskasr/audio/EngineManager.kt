package com.example.voskasr.audio

import com.example.voskasr.audio.baidu.BaiduRealtimeAsrRecognizer
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

/**
 * Routes PCM + lifecycle calls to the active [Recognizer].
 * Local validation must stay on Vosk unless Baidu is selected explicitly.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class EngineManager(
    private val vosk: VoskRecognizerAdapter,
    private val baidu: BaiduRealtimeAsrRecognizer,
    private val scope: CoroutineScope
) {
    private val _active = MutableStateFlow<Recognizer>(vosk)
    val active: StateFlow<Recognizer> = _active.asStateFlow()

    private val _selected = MutableStateFlow(AsrEngine.VOSK)
    val selected: StateFlow<AsrEngine> = _selected.asStateFlow()

    private val _activeEngineName = MutableStateFlow(vosk.displayName)
    val activeEngineName: StateFlow<String> = _activeEngineName.asStateFlow()

    val activeState: StateFlow<RecognizerState> = _active
        .flatMapLatest { it.state }
        .stateIn(scope, SharingStarted.Eagerly, RecognizerState.Idle)

    val activeResults: Flow<RecognizerResult> = _active
        .flatMapLatest { it.results }

    fun select(engine: AsrEngine) {
        _selected.value = engine
        // Direct selection: switch active immediately. AUTO resolves on next startActive().
        val next: Recognizer = when (engine) {
            AsrEngine.VOSK -> vosk
            AsrEngine.BAIDU -> baidu
            AsrEngine.AUTO -> vosk
        }
        if (_active.value !== next) {
            _active.value = next
            _activeEngineName.value = next.displayName
        }
    }

    suspend fun startActive() {
        val current = _active.value
        if (_selected.value == AsrEngine.AUTO && current === baidu) {
            scope.launch { watchBaiduForFallback() }
        }
        try {
            current.start()
            if (_selected.value == AsrEngine.AUTO && current.state.value is RecognizerState.Error) {
                fallbackToVosk()
            }
        } catch (e: Exception) {
            if (_selected.value == AsrEngine.AUTO) fallbackToVosk()
        }
    }

    suspend fun stopActive() {
        _active.value.stop()
    }

    fun feedPcm(pcm: ByteArray) {
        _active.value.feedPcm(pcm)
    }

    fun warmUpOffline() {
        scope.launch { vosk.warmUp() }
    }

    private suspend fun fallbackToVosk() {
        try { baidu.stop() } catch (_: Exception) { }
        _active.value = vosk
        _activeEngineName.value = "${vosk.displayName}（回退）"
        try { vosk.start() } catch (_: Exception) { }
    }

    private suspend fun watchBaiduForFallback() {
        try {
            baidu.state.first { st ->
                st is RecognizerState.Error || st is RecognizerState.Closed
            }
        } catch (_: Exception) {
            return
        }
        if (_selected.value == AsrEngine.AUTO && _active.value === baidu) {
            fallbackToVosk()
        }
    }
}
