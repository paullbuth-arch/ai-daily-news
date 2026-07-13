package com.example.voskasr.repository

import android.bluetooth.BluetoothDevice
import android.content.Context
import android.util.Log
import com.example.voskasr.audio.AsrEngine
import com.example.voskasr.audio.EngineManager
import com.example.voskasr.audio.OpusDecoder
import com.example.voskasr.audio.PcmWavRecorder
import com.example.voskasr.audio.RecognizerResult
import com.example.voskasr.audio.RecognizerState
import com.example.voskasr.audio.VoskRecognizerAdapter
import com.example.voskasr.audio.baidu.BaiduAsrConfig
import com.example.voskasr.audio.baidu.BaiduRealtimeAsrRecognizer
import com.example.voskasr.bluetooth.control.VadControlChannel
import com.example.voskasr.bluetooth.data.VadDataChannel
import com.example.voskasr.domain.ConnectionState
import com.example.voskasr.domain.StreamingState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.concurrent.atomic.AtomicInteger

class GlassAudioRepository(
    context: Context,
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.IO + Job())
) {

    private val appContext = context.applicationContext
    private val controlChannel = VadControlChannel()
    private val dataChannel = VadDataChannel()
    private val opusDecoder = OpusDecoder()
    private val wavRecorder = PcmWavRecorder(appContext)
    private val hfpScoManager = com.example.voskasr.bluetooth.HfpScoManager(appContext, scope)

    private val voskAdapter = VoskRecognizerAdapter(appContext, scope)
    private val baiduAdapter = BaiduRealtimeAsrRecognizer(scope, BaiduAsrConfig.fromBuildConfig())
    private val engineManager = EngineManager(voskAdapter, baiduAdapter, scope)

    private val _connectionState = MutableStateFlow<ConnectionState>(ConnectionState.Disconnected)
    val connectionState: StateFlow<ConnectionState> = _connectionState.asStateFlow()

    private val _streamingState = MutableStateFlow<StreamingState>(StreamingState.Idle)
    val streamingState: StateFlow<StreamingState> = _streamingState.asStateFlow()

    private val _scoReady = MutableStateFlow(false)
    val scoReady: StateFlow<Boolean> = _scoReady.asStateFlow()

    val scoState: StateFlow<com.example.voskasr.bluetooth.HfpScoManager.ScoState>
        get() = hfpScoManager.scoState

    private val _modelLoaded = MutableStateFlow(false)
    val modelLoaded: StateFlow<Boolean> = _modelLoaded.asStateFlow()

    private val _partialText = MutableStateFlow("")
    val partialText: StateFlow<String> = _partialText.asStateFlow()

    private val _finalText = MutableStateFlow("")
    val finalText: StateFlow<String> = _finalText.asStateFlow()

    val selectedEngine: StateFlow<AsrEngine> = engineManager.selected
    val activeEngineName: StateFlow<String> = engineManager.activeEngineName
    val engineState: StateFlow<RecognizerState> = engineManager.activeState

    private val _logs = MutableSharedFlow<String>(extraBufferCapacity = 256)
    val logs: SharedFlow<String> = _logs.asSharedFlow()

    private val frameCounter = AtomicInteger(0)
    private var pcmBytesReceived: Long = 0
    private var firstPcmLogged = false

    @Volatile private var wqDevice: BluetoothDevice? = null
    @Volatile private var hfpConnected = false

    init {
        if (!opusDecoder.init()) {
            log("[opus] native decoder init failed")
        }
        engineManager.warmUpOffline()
        scope.launch { collectVoskReadiness() }
        scope.launch { collectEngineResults() }
    }

    private suspend fun collectVoskReadiness() {
        voskAdapter.state.collect { st ->
            _modelLoaded.value = st is RecognizerState.Ready
            if (st is RecognizerState.Error) {
                log("Vosk: ${st.message}")
            }
        }
    }

    private suspend fun collectEngineResults() {
        engineManager.activeResults.collect { r ->
            when (r.type) {
                RecognizerResult.Type.PARTIAL -> _partialText.value = r.text
                RecognizerResult.Type.FINAL -> {
                    _partialText.value = ""
                    if (r.text.isNotEmpty()) {
                        _finalText.value = _finalText.value.let {
                            if (it.isNotEmpty()) "$it\n${r.text}" else r.text
                        }
                    }
                }
                RecognizerResult.Type.ERROR -> log("[${r.engine}] err: ${r.text}")
            }
        }
    }

    suspend fun connect(device: BluetoothDevice): Boolean {
        wqDevice = device
        _connectionState.value = ConnectionState.ConnectingControl
        log("连接控制通道...")
        val controlOk = controlChannel.connect(device)
        if (!controlOk) {
            _connectionState.value = ConnectionState.Error("控制通道连接失败")
            return false
        }

        _connectionState.value = ConnectionState.ConnectingData
        log("连接数据通道...")
        val dataOk = dataChannel.connect(device)
        if (!dataOk) {
            _connectionState.value = ConnectionState.Error("数据通道连接失败")
            return false
        }

        log("SPP 通道已连接")

        log("等待 HFP 连接...")
        _connectionState.value = ConnectionState.ConnectingControl
        hfpScoManager.setupHeadsetProxy(wqMacFilter = device.address) { ok, dev ->
            hfpConnected = ok
            _scoReady.value = ok
            if (ok) {
                log("HFP 就绪, 可开始语音识别")
            } else {
                log("HFP 未连接 —— 请确认系统蓝牙设置中 WQ 已配对且「通话」profile 已连接")
            }
            _connectionState.value = ConnectionState.Connected(control = true, data = true)
        }
        return true
    }

    suspend fun startStreaming(): Boolean {
        if (_connectionState.value !is ConnectionState.Connected) {
            log("未连接，无法开始推流")
            return false
        }
        if (!hfpConnected) {
            log("HFP 未连接，无法开始推流")
            return false
        }

        _streamingState.value = StreamingState.Starting
        pcmBytesReceived = 0
        firstPcmLogged = false

        log("启动 SCO 语音识别...")

        val (ok, detail) = hfpScoManager.startScoCapture()
        if (!ok) {
            log("SCO 失败: $detail")
            _streamingState.value = StreamingState.Idle
            return false
        }

        val rate = hfpScoManager.actualSampleRate
        log("SCO 就绪 (${detail})")

        // sync sample rate to WAV recorder so header is correct
        wavRecorder.sampleRate = rate

        try {
            engineManager.startActive()
        } catch (e: Exception) {
            log("引擎启动异常: ${e.message}")
        }

        _streamingState.value = StreamingState.Streaming
        wavRecorder.start()
        log("已开始推流 (${rate}Hz SCO), 录音中...")

        scope.launch { collectScoFrames() }
        return true
    }

    suspend fun stopStreaming(): Boolean {
        if (_streamingState.value !is StreamingState.Streaming) {
            return false
        }
        _streamingState.value = StreamingState.Stopping
        log("停止 SCO 语音识别 (收到 ${pcmBytesReceived / 1024}KB PCM)")
        hfpScoManager.stopScoCapture()
        try {
            engineManager.stopActive()
        } catch (e: Exception) {
            log("引擎停止异常: ${e.message}")
        }
        val wavPath = wavRecorder.stop()
        if (wavPath != null) {
            log("录音已保存: $wavPath")
        }
        _streamingState.value = StreamingState.Idle
        return true
    }

    suspend fun setEngine(engine: AsrEngine) {
        val wasStreaming = _streamingState.value is StreamingState.Streaming
        if (wasStreaming) {
            try { engineManager.stopActive() } catch (_: Exception) { }
        }
        engineManager.select(engine)
        log("引擎切换 → ${engine.name}")
        if (wasStreaming) {
            try { engineManager.startActive() } catch (_: Exception) { }
        }
    }

    fun clearResults() {
        _partialText.value = ""
        _finalText.value = ""
    }

    fun disconnect() {
        controlChannel.disconnect()
        dataChannel.disconnect()
        hfpScoManager.release()
        opusDecoder.release()
        voskAdapter.destroy()
        baiduAdapter.destroy()
        wavRecorder.stop()
        wqDevice = null
        hfpConnected = false
        _scoReady.value = false
        _connectionState.value = ConnectionState.Disconnected
        _streamingState.value = StreamingState.Idle
    }

    private suspend fun collectScoFrames() {
        hfpScoManager.pcmFrames.collect { pcm ->
            if (!firstPcmLogged) {
                firstPcmLogged = true
                log("收到第一帧 PCM: ${pcm.size} bytes")
            }
            pcmBytesReceived += pcm.size
            processPcm(pcm)
        }
    }

    private fun processPcm(pcm: ByteArray) {
        wavRecorder.feed(pcm)
        frameCounter.incrementAndGet()
        engineManager.feedPcm(pcm)
    }

    private fun log(message: String) {
        Log.i(TAG, message)
        _logs.tryEmit(message)
    }

    companion object {
        private const val TAG = "GlassAudioRepo"
    }
}
