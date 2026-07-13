package com.glass.voice

import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Auto-start the voice service when WQ device connects via BT ACL.
 * Auto-stop when it disconnects. No background battery drain.
 */
class BltReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BltReceiver"
        private const val WQ_MAC_PREFIX = "B0:A1:87"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val device = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
        val addr = device?.address ?: return

        if (!addr.regionMatches(0, WQ_MAC_PREFIX, 0, WQ_MAC_PREFIX.length, ignoreCase = true)) return

        Log.i(TAG, "${intent.action} device=$addr")

        when (intent.action) {
            "android.bluetooth.device.action.ACL_CONNECTED" ->
                HfpVoiceService.start(context)
            "android.bluetooth.device.action.ACL_DISCONNECTED" ->
                HfpVoiceService.stop(context)
        }
    }
}
