package com.glass.voice

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.util.Log
import kotlinx.coroutines.*

class HfpVoiceService : Service() {

    companion object {
        private const val TAG = "HfpVoiceSvc"
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "glass_voice"

        private val _state = java.util.concurrent.atomic.AtomicReference(ServiceState.IDLE)
        enum class ServiceState { IDLE, CONNECTING, READY, LISTENING }

        fun start(context: Context) {
            context.startForegroundService(Intent(context, HfpVoiceService::class.java))
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, HfpVoiceService::class.java))
        }
    }

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private lateinit var hfpMonitor: HfpConnectionMonitor
    private lateinit var scoCapture: ScoCaptureManager
    private lateinit var asrClient: BaiduAsrClient
    private val sppChannel = SppCommandChannel(scope)

    private var voiceActive = false

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        hfpMonitor = HfpConnectionMonitor(this)
        scoCapture = ScoCaptureManager(this, scope)

        asrClient = BaiduAsrClient(
            apiKey = "g1AH0YiytsW1CFMs1R5qpSoS",
            secretKey = "kXnHfBWhnG8qWjaQXXPGj8gQpFyWyCx2"
        )

        asrClient.onResult = { text, isFinal ->
            Log.i(TAG, "ASR ${if (isFinal) "FINAL" else "PARTIAL"}: $text")
            if (isFinal && text.isNotBlank()) {
                sppChannel.sendResult(text)
                // Auto-stop after getting final result (single-shot mode)
                stopVoiceCapture()
            }
        }

        asrClient.onError = { err ->
            Log.e(TAG, "ASR error: $err")
            sppChannel.sendResult("ERROR:$err")
            stopVoiceCapture()
        }

        asrClient.onReady = { Log.i(TAG, "ASR ready") }

        sppChannel.onVoiceStart = { scope.launch { startVoiceCapture() } }
        sppChannel.onVoiceStop = { stopVoiceCapture() }

        Log.i(TAG, "Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, buildNotification("就绪"))
        scope.launch { runSetup() }
        return START_STICKY
    }

    private suspend fun runSetup() {
        _state.set(ServiceState.CONNECTING)
        updateNotification("等待 WQ 连接...")

        // 1. Wait for HFP
        val device = hfpMonitor.waitForConnection()
        if (device == null) {
            Log.w(TAG, "HFP connection failed, stopping")
            stopSelf()
            return
        }

        _state.set(ServiceState.CONNECTING)
        updateNotification("连接 SPP...")

        // 2. Connect SPP command channel
        val sppOk = sppChannel.connect(device)
        if (!sppOk) {
            Log.w(TAG, "SPP connection failed")
            stopSelf()
            return
        }

        _state.set(ServiceState.READY)
        updateNotification("Glass Voice 就绪")
        Log.i(TAG, "Service ready — waiting for KEY_1 trigger")
    }

    private suspend fun startVoiceCapture() {
        if (voiceActive) return
        voiceActive = true
        _state.set(ServiceState.LISTENING)
        updateNotification("正在识别...")

        val device = hfpMonitor.wqDevice ?: return
        val hs = hfpMonitor.headset ?: return

        Log.i(TAG, "Starting SCO + ASR...")

        // Start SCO capture
        scope.launch {
            val ok = scoCapture.capture(device, hs)
            if (!ok) {
                Log.e(TAG, "SCO capture failed")
                sppChannel.sendResult("ERROR:SCO_FAILED")
                stopVoiceCapture()
                return@launch
            }

            // Start ASR
            asrClient.start()

            // Feed PCM to ASR
            launch {
                scoCapture.pcmFrames.collect { pcm -> asrClient.feedPcm(pcm) }
            }
        }
    }

    private fun stopVoiceCapture() {
        if (!voiceActive) return
        voiceActive = false

        asrClient.stop()
        scoCapture.stop()

        _state.set(ServiceState.READY)
        updateNotification("Glass Voice 就绪")
        Log.i(TAG, "Voice capture stopped")
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopVoiceCapture()
        sppChannel.disconnect()
        hfpMonitor.headset?.let {
            android.bluetooth.BluetoothAdapter.getDefaultAdapter()
                ?.closeProfileProxy(android.bluetooth.BluetoothProfile.HEADSET, it)
        }
        scope.cancel()
        Log.i(TAG, "Service destroyed")
        super.onDestroy()
    }

    // ---- Notification ----

    private fun createNotificationChannel() {
        val channel = NotificationChannel(CHANNEL_ID, "Glass Voice", NotificationManager.IMPORTANCE_LOW).apply {
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
