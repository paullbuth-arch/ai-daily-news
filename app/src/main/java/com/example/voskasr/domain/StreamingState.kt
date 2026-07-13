package com.example.voskasr.domain

sealed class StreamingState {
    data object Idle : StreamingState()
    data object Starting : StreamingState()
    data object Streaming : StreamingState()
    data object Stopping : StreamingState()
}
