package com.example.voskasr.viewmodel

import android.bluetooth.BluetoothDevice
import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.voskasr.audio.AsrEngine
import com.example.voskasr.audio.RecognizerState
import com.example.voskasr.bluetooth.HfpScoManager
import com.example.voskasr.domain.ConnectionState
import com.example.voskasr.domain.StreamingState
import com.example.voskasr.repository.GlassAudioRepository
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class MainViewModel(context: Context) : ViewModel() {

    private val repository = GlassAudioRepository(context, viewModelScope)

    private val _uiState = MutableStateFlow(MainUiState())
    val uiState: StateFlow<MainUiState> = _uiState.asStateFlow()

    private val _events = MutableSharedFlow<UiEvent>(extraBufferCapacity = 64)
    val events: SharedFlow<UiEvent> = _events.asSharedFlow()

    private val _logs = mutableListOf<String>()

    private var selectedDevice: BluetoothDevice? = null

    init {
        viewModelScope.launch {
            repository.connectionState.collect { state ->
                _uiState.value = _uiState.value.copy(
                    connectionState = state,
                    isConnecting = state is ConnectionState.ConnectingControl || state is ConnectionState.ConnectingData
                )
                log("连接: $state")
            }
        }
        viewModelScope.launch {
            repository.streamingState.collect { state ->
                _uiState.value = _uiState.value.copy(
                    streamingState = state,
                    isStreaming = state is StreamingState.Streaming
                )
                log("推流: $state")
            }
        }
        viewModelScope.launch {
            repository.scoReady.collect { ready ->
                _uiState.value = _uiState.value.copy(scoReady = ready)
                log("SCO 就绪: $ready")
            }
        }
        viewModelScope.launch {
            repository.scoState.collect { state ->
                _uiState.value = _uiState.value.copy(scoState = state)
            }
        }
        viewModelScope.launch {
            repository.modelLoaded.collect { loaded ->
                _uiState.value = _uiState.value.copy(modelLoaded = loaded)
            }
        }
        viewModelScope.launch {
            repository.partialText.collect { partial ->
                _uiState.value = _uiState.value.copy(partialText = partial)
            }
        }
        viewModelScope.launch {
            repository.finalText.collect { finalText ->
                _uiState.value = _uiState.value.copy(finalText = finalText)
            }
        }
        viewModelScope.launch {
            repository.selectedEngine.collect { engine ->
                _uiState.value = _uiState.value.copy(selectedEngine = engine)
            }
        }
        viewModelScope.launch {
            repository.engineState.collect { st ->
                _uiState.value = _uiState.value.copy(engineState = st)
                log("引擎: ${labelOf(st)}")
            }
        }
        viewModelScope.launch {
            repository.activeEngineName.collect { name ->
                _uiState.value = _uiState.value.copy(activeEngineName = name)
            }
        }
        viewModelScope.launch {
            repository.logs.collect { msg ->
                log(msg)
            }
        }
    }

    fun selectDevice(device: BluetoothDevice) {
        selectedDevice = device
    }

    fun connect() {
        val device = selectedDevice ?: return
        viewModelScope.launch {
            val ok = repository.connect(device)
            if (!ok) {
                _events.emit(UiEvent.Toast("连接失败"))
            }
        }
    }

    fun disconnect() {
        repository.disconnect()
    }

    fun startStreaming() {
        viewModelScope.launch {
            val ok = repository.startStreaming()
            if (!ok) {
                _events.emit(UiEvent.Toast("开始推流失败"))
            }
        }
    }

    fun stopStreaming() {
        viewModelScope.launch {
            val ok = repository.stopStreaming()
            if (!ok) {
                _events.emit(UiEvent.Toast("停止推流失败"))
            }
        }
    }

    fun setEngine(engine: AsrEngine) {
        viewModelScope.launch { repository.setEngine(engine) }
    }

    fun clearResults() {
        repository.clearResults()
    }

    fun clearLogs() {
        _logs.clear()
        _uiState.value = _uiState.value.copy(logs = emptyList())
    }

    fun copyLogs(): String {
        return _logs.joinToString("\n")
    }

    private fun log(message: String) {
        _logs.add(message)
        if (_logs.size > 200) {
            _logs.removeAt(0)
        }
        _uiState.value = _uiState.value.copy(logs = _logs.toList())
    }

    override fun onCleared() {
        super.onCleared()
        repository.disconnect()
    }

    sealed class UiEvent {
        data class Toast(val message: String) : UiEvent()
    }
}

private fun labelOf(state: RecognizerState): String = when (state) {
    is RecognizerState.Idle -> "空闲"
    is RecognizerState.Connecting -> "连接中"
    is RecognizerState.Ready -> "就绪"
    is RecognizerState.Error -> "错误: ${state.message}"
    is RecognizerState.Closed -> "已关闭"
}
