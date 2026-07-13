package com.example.voskasr.bluetooth

import android.bluetooth.BluetoothDevice

interface BluetoothChannel {
    val isConnected: Boolean
    suspend fun connect(device: BluetoothDevice): Boolean
    fun disconnect()
}
