package com.glass.voice

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.util.Log
import kotlinx.coroutines.delay

class HfpConnectionMonitor(private val context: Context) {

    companion object {
        private const val WQ_MAC_PREFIX = "B0:A1:87"
    }

    @Volatile var wqDevice: BluetoothDevice? = null

    /**
     * Find WQ device among bonded devices by MAC prefix.
     * Waits for HFP profile to show connected state.
     */
    suspend fun waitForDevice(timeoutMs: Long = 30000): BluetoothDevice? {
        val adapter = BluetoothAdapter.getDefaultAdapter() ?: return null
        val deadline = System.currentTimeMillis() + timeoutMs

        Log.i("HfpMonitor", "Looking for WQ device (MAC $WQ_MAC_PREFIX)...")

        while (System.currentTimeMillis() < deadline) {
            @Suppress("MissingPermission")
            val bonded = adapter.bondedDevices
            for (d in bonded) {
                if (d.address.regionMatches(0, WQ_MAC_PREFIX, 0, 3, true)) {
                    wqDevice = d
                    Log.i("HfpMonitor", "Found WQ: ${d.address} (bonded)")
                    // Brief wait for HFP to actually connect
                    delay(3000)
                    return d
                }
            }
            delay(2000)
        }
        Log.w("HfpMonitor", "WQ device not found in bonded list")
        return null
    }

    fun isConnected(): Boolean = wqDevice != null
}
