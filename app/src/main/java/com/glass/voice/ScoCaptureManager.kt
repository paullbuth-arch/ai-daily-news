package com.glass.voice

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothHeadset
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioDeviceInfo
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.util.Log
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow

class ScoCaptureManager(private val context: Context, private val scope: CoroutineScope) {

    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var audioRecord: AudioRecord? = null
    private var recordJob: Job? = null
    private var scoReceiver: BroadcastReceiver? = null

    private val _pcmFrames = MutableSharedFlow<ByteArray>(extraBufferCapacity = 256)
    val pcmFrames: SharedFlow<ByteArray> = _pcmFrames

    @Volatile var sampleRate = 0

    suspend fun capture(device: BluetoothDevice, headset: BluetoothHeadset): Boolean {
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION

        @Suppress("DEPRECATION")
        headset.startVoiceRecognition(device)

        // Route to BT SCO (API 31+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val scoDev = audioManager.availableCommunicationDevices
                .find { it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO }
            if (scoDev != null) audioManager.setCommunicationDevice(scoDev)
        }

        registerScoReceiver()
        @Suppress("DEPRECATION")
        audioManager.startBluetoothSco()
        @Suppress("DEPRECATION")
        audioManager.setBluetoothScoOn(true)

        delay(300) // brief wait for SCO setup

        return buildAudioRecord()
    }

    private fun buildAudioRecord(): Boolean {
        val sources = listOf(
            MediaRecorder.AudioSource.VOICE_COMMUNICATION,
            MediaRecorder.AudioSource.MIC,
            MediaRecorder.AudioSource.DEFAULT
        )

        for (src in sources) {
            for (rate in intArrayOf(16000, 8000)) {
                val minBuf = AudioRecord.getMinBufferSize(rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
                if (minBuf <= 0) continue

                @Suppress("MissingPermission")
                val rec = AudioRecord(src, rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, maxOf(minBuf, rate / 25 * 4))
                if (rec.state == AudioRecord.STATE_INITIALIZED) {
                    sampleRate = rate
                    audioRecord = rec
                    rec.startRecording()
                    Log.i("ScoCapture", "AudioRecord OK: src=$src rate=$rate")

                    recordJob = scope.launch(Dispatchers.IO) {
                        val buf = ByteArray(rate / 50 * 2)
                        while (isActive) {
                            val rd = rec.read(buf, 0, buf.size)
                            if (rd > 0) _pcmFrames.tryEmit(buf.copyOf(rd))
                            else if (rd < 0) break
                        }
                    }
                    return true
                }
                rec.release()
            }
        }
        return false
    }

    fun stop() {
        recordJob?.cancel(); recordJob = null
        audioRecord?.let { try { it.stop() } catch (_: Exception) {}; try { it.release() } catch (_: Exception) {} }
        audioRecord = null
        unregisterScoReceiver()
        @Suppress("DEPRECATION")
        audioManager.setBluetoothScoOn(false)
        @Suppress("DEPRECATION")
        audioManager.stopBluetoothSco()
        audioManager.mode = AudioManager.MODE_NORMAL
    }

    private fun registerScoReceiver() {
        if (scoReceiver != null) return
        scoReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val state = intent?.getIntExtra(AudioManager.EXTRA_SCO_AUDIO_STATE, -1) ?: return
                Log.i("ScoCapture", "SCO state=$state")
            }
        }
        context.registerReceiver(scoReceiver, IntentFilter(AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED))
    }

    private fun unregisterScoReceiver() {
        scoReceiver?.let { try { context.unregisterReceiver(it) } catch (_: Exception) {} }
        scoReceiver = null
    }
}
