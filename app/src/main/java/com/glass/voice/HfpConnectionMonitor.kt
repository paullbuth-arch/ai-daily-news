package com.glass.voice

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothHeadset
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.util.Log
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

class HfpConnectionMonitor(private val context: Context) {

    enum class State { DISCONNECTED, CONNECTING, CONNECTED }

    private val _state = MutableStateFlow(State.DISCONNECTED)
    val state: StateFlow<State> = _state

    @Volatile var headset: BluetoothHeadset? = null
    @Volatile var wqDevice: BluetoothDevice? = null

    suspend fun waitForConnection(macPrefix: String = "B0:A1:87", timeoutMs: Long = 8000): BluetoothDevice? {
        Log.i("HfpMonitor", "Waiting for HFP connection...")
        val adapter = BluetoothAdapter.getDefaultAdapter() ?: return null

        // Get proxy
        val proxy = kotlinx.coroutines.suspendCancellableCoroutine<BluetoothHeadset?> { cont ->
            @Suppress("DEPRECATION")
            adapter.getProfileProxy(context, object : BluetoothProfile.ServiceListener {
                override fun onServiceConnected(profile: Int, proxy: BluetoothProfile?) {
                    if (profile == BluetoothProfile.HEADSET) cont.resume(proxy as? BluetoothHeadset) {}
                }
                override fun onServiceDisconnected(profile: Int) {}
            }, BluetoothProfile.HEADSET)
        }

        headset = proxy ?: return null

        // Poll until HFP connected
        val deadline = System.currentTimeMillis() + timeoutMs
        while (System.currentTimeMillis() < deadline) {
            val devices = headset?.connectedDevices ?: emptyList()
            val found = devices.find { it.address.regionMatches(0, macPrefix, 0, 3, true) }
            if (found != null) {
                _state.value = State.CONNECTED
                wqDevice = found
                Log.i("HfpMonitor", "HFP connected: ${found.address}")
                return found
            }
            delay(500)
        }
        Log.w("HfpMonitor", "HFP connection timeout")
        return null
    }

    fun isConnected(): Boolean = _state.value == State.CONNECTED && wqDevice != null
}
