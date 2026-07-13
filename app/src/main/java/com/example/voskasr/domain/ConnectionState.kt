package com.example.voskasr.domain

sealed class ConnectionState {
    data object Disconnected : ConnectionState()
    data object ConnectingControl : ConnectionState()
    data object ConnectingData : ConnectionState()
    data class Connected(val control: Boolean = false, val data: Boolean = false) : ConnectionState()
    data class Error(val reason: String) : ConnectionState()
}
