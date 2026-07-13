package com.example.voskasr.viewmodel

import com.example.voskasr.audio.AsrEngine
import com.example.voskasr.audio.RecognizerState
import com.example.voskasr.bluetooth.HfpScoManager
import com.example.voskasr.domain.ConnectionState
import com.example.voskasr.domain.StreamingState

data class MainUiState(
    val connectionState: ConnectionState = ConnectionState.Disconnected,
    val streamingState: StreamingState = StreamingState.Idle,
    val modelLoaded: Boolean = false,
    val scoReady: Boolean = false,
    val scoState: HfpScoManager.ScoState = HfpScoManager.ScoState.DISCONNECTED,
    val partialText: String = "",
    val finalText: String = "",
    val logs: List<String> = emptyList(),
    val isConnecting: Boolean = false,
    val isStreaming: Boolean = false,
    val selectedEngine: AsrEngine = AsrEngine.VOSK,
    val engineState: RecognizerState = RecognizerState.Idle,
    val activeEngineName: String = ""
)
