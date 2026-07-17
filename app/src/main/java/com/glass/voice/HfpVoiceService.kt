package com.glass.voice

import android.app.*
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.os.IBinder
import android.util.Log
import kotlinx.coroutines.*

class HfpVoiceService : Service() {

    companion object {
        private const val TAG = "HfpVoiceSvc"
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "glass_voice"

        fun start(context: Context) {
            context.startForegroundService(Intent(context, HfpVoiceService::class.java))
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, HfpVoiceService::class.java))
        }
    }

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private lateinit var scoCapture: ScoCaptureManager
    private lateinit var asrClient: BaiduAsrClient
    private var voiceActive = false
    private var scoReceiver: BroadcastReceiver? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        scoCapture = ScoCaptureManager(this, scope)

        asrClient = BaiduAsrClient(
            apiKey = "g1AH0YiytsW1CFMs1R5qpSoS",
            secretKey = "kXnHfBWhnG8qWjaQXXPGj8gQpFyWyCx2"
        )
        asrClient.onResult = { text, isFinal ->
            Log.i(TAG, "ASR ${if (isFinal) "FINAL" else "PARTIAL"}: $text")
            if (isFinal && text.isNotBlank()) {
                Log.i(TAG, "=== ASR RESULT: $text ===")
                stopVoiceCapture()
            }
        }
        asrClient.onError = { err -> Log.e(TAG, "ASR error: $err"); stopVoiceCapture() }
        asrClient.onReady = { Log.i(TAG, "ASR ready") }

        // WQ KEY_1 → SCO 连接 → 本广播触发 → ASR
        registerScoReceiver()
        Log.i(TAG, "Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(
            NOTIFICATION_ID,
            buildNotification("等待语音指令"),
            android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
        )
        return START_STICKY
    }

    private fun registerScoReceiver() {
        if (scoReceiver != null) return
        scoReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val state = intent?.getIntExtra(AudioManager.EXTRA_SCO_AUDIO_STATE, -1) ?: return
                val prevState = intent?.getIntExtra(AudioManager.EXTRA_SCO_AUDIO_PREVIOUS_STATE, -1)
                val device = intent?.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
                Log.i(TAG, "SCO: $prevState → $state  dev=${device?.address}")

                when (state) {
                    AudioManager.SCO_AUDIO_STATE_CONNECTED -> {
                        if (!voiceActive) {
                            updateNotification("正在识别...")
                            scope.launch { startVoiceCapture() }
                        }
                    }
                    AudioManager.SCO_AUDIO_STATE_DISCONNECTED -> {
                        stopVoiceCapture()
                        updateNotification("等待语音指令")
                    }
                }
            }
        }
        registerReceiver(scoReceiver, IntentFilter(AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED))
    }

    private suspend fun startVoiceCapture() {
        if (voiceActive) return
        voiceActive = true

        Log.i(TAG, "Starting ASR via SCO...")

        val ok = scoCapture.capture(null)
        if (!ok) {
            Log.e(TAG, "SCO capture failed")
            voiceActive = false
            return
        }

        asrClient.start()
        scope.launch {
            scoCapture.pcmFrames.collect { pcm -> asrClient.feedPcm(pcm) }
        }
    }

    private fun stopVoiceCapture() {
        if (!voiceActive) return
        voiceActive = false
        asrClient.stop()
        scoCapture.stop()
        Log.i(TAG, "Voice capture stopped")
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopVoiceCapture()
        scoReceiver?.let { try { unregisterReceiver(it) } catch (_: Exception) {} }
        scoReceiver = null
        scope.cancel()
        Log.i(TAG, "Service destroyed")
        super.onDestroy()
    }

    // ---- Notification ----

    private fun createNotificationChannel() {
        val channel = NotificationChannel(CHANNEL_ID, "Glass Voice", NotificationManager.IMPORTANCE_DEFAULT).apply {
            description = "WQ voice assistant status"
            setShowBadge(false)
        }
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(channel)
    }

    private fun buildNotification(text: String): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pending = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE)
        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("Glass Voice")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(pending)
            .setOngoing(true)
            .build()
    }

    private fun updateNotification(text: String) {
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify(NOTIFICATION_ID, buildNotification(text))
    }
}
