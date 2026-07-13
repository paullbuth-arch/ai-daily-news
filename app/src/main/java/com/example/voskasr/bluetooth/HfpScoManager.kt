package com.example.voskasr.bluetooth

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothHeadset
import android.bluetooth.BluetoothProfile
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
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/**
 * 仿系统通话上行路径：通过 HFP Voice Recognition (AT+BVRA) 建立 SCO 链路，
 * 使用 setCommunicationDevice (API 31+) 或 startBluetoothSco (旧 API)
 * 将 BT SCO 音频路由到 AudioRecord。
 *
 * 数据流:
 *   WQ mic → HFP SCO (mSBC 16kHz) → Android BT stack →
 *   AudioRecord → PCM → ASR 引擎
 */
class HfpScoManager(
    private val context: Context,
    private val scope: CoroutineScope
) {
    companion object {
        private const val TAG = "HfpScoManager"
        private val TRY_SAMPLE_RATES = intArrayOf(16000, 8000)
        private const val CHANNEL = AudioFormat.CHANNEL_IN_MONO
        private const val ENCODING = AudioFormat.ENCODING_PCM_16BIT
    }

    enum class ScoState {
        DISCONNECTED, CONNECTING, CONNECTED, ERROR
    }

    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private var headset: BluetoothHeadset? = null
    private var targetDevice: BluetoothDevice? = null
    private var recordJob: Job? = null
    private var audioRecord: AudioRecord? = null
    private var scoReceiver: BroadcastReceiver? = null

    val actualSampleRate: Int get() = _actualSampleRate
    @Volatile private var _actualSampleRate = 0

    private val _scoState = MutableStateFlow(ScoState.DISCONNECTED)
    val scoState: StateFlow<ScoState> = _scoState.asStateFlow()

    private val _pcmFrames = MutableSharedFlow<ByteArray>(extraBufferCapacity = 256)
    val pcmFrames: SharedFlow<ByteArray> = _pcmFrames.asSharedFlow()

    // ---- BluetoothHeadset proxy ----

    fun setupHeadsetProxy(wqMacFilter: String? = null, onReady: (Boolean, BluetoothDevice?) -> Unit) {
        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null) { onReady(false, null); return }

        @Suppress("DEPRECATION")
        adapter.getProfileProxy(context, object : BluetoothProfile.ServiceListener {
            override fun onServiceConnected(profile: Int, proxy: BluetoothProfile?) {
                if (profile != BluetoothProfile.HEADSET) return
                headset = proxy as? BluetoothHeadset
                val devices = headset?.connectedDevices ?: emptyList()
                Log.i(TAG, "Headset proxy ready, ${devices.size} HFP device(s): ${devices.map { "${it.name} ${it.address}" }}")

                val device = if (wqMacFilter != null)
                    devices.find { it.address.equals(wqMacFilter, ignoreCase = true) }
                else devices.firstOrNull()

                targetDevice = device
                if (device != null) {
                    Log.i(TAG, "WQ HFP device: ${device.name} ${device.address}")
                    onReady(true, device)
                } else {
                    Log.w(TAG, "No WQ device in HFP connected devices")
                    onReady(false, null)
                }
            }
            override fun onServiceDisconnected(profile: Int) {
                if (profile == BluetoothProfile.HEADSET) {
                    headset = null; targetDevice = null
                }
            }
        }, BluetoothProfile.HEADSET)
    }

    // ---- SCO audio state receiver ----

    private fun registerScoReceiver() {
        if (scoReceiver != null) return
        scoReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val state = intent?.getIntExtra(AudioManager.EXTRA_SCO_AUDIO_STATE, AudioManager.SCO_AUDIO_STATE_ERROR) ?: return
                val device = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
                Log.i(TAG, "SCO broadcast state=$state device=${device?.address}")
                when (state) {
                    AudioManager.SCO_AUDIO_STATE_CONNECTED -> {
                        Log.i(TAG, "SCO connected")
                        _scoState.value = ScoState.CONNECTED
                    }
                    AudioManager.SCO_AUDIO_STATE_DISCONNECTED -> _scoState.value = ScoState.DISCONNECTED
                    AudioManager.SCO_AUDIO_STATE_ERROR -> _scoState.value = ScoState.ERROR
                }
            }
        }
        context.registerReceiver(scoReceiver, IntentFilter(AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED))
    }

    private fun unregisterScoReceiver() {
        scoReceiver?.let { try { context.unregisterReceiver(it) } catch (_: Exception) {} }
        scoReceiver = null
    }

    // ---- route communication audio to BT SCO (API 31+) ----

    private fun routeCommsToSco(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            Log.i(TAG, "API < 31, using startBluetoothSco for routing")
            return false // use legacy path
        }

        val scoDevices = audioManager.availableCommunicationDevices
            .filter { it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO }

        if (scoDevices.isEmpty()) {
            Log.w(TAG, "No BT SCO device in availableCommunicationDevices. " +
                    "Available: ${audioManager.availableCommunicationDevices.map { "${it.type}:${it.productName}" }}")
            return false
        }

        val scoDev = scoDevices.first()
        Log.i(TAG, "Setting communication device to BT SCO: ${scoDev.productName} (type=${scoDev.type})")
        val result = audioManager.setCommunicationDevice(scoDev)
        Log.i(TAG, "setCommunicationDevice returned: $result")

        // Also try startBluetoothSco as fallback
        @Suppress("DEPRECATION")
        audioManager.startBluetoothSco()
        @Suppress("DEPRECATION")
        audioManager.setBluetoothScoOn(true)

        return result
    }

    // ---- SCO capture ----

    fun isReady(): Boolean {
        val device = targetDevice ?: return false
        val hs = headset ?: return false
        return hs.getConnectionState(device) == BluetoothHeadset.STATE_CONNECTED
    }

    suspend fun startScoCapture(): Pair<Boolean, String> {
        val device = targetDevice
        val hs = headset
        if (device == null || hs == null) {
            val msg = "HFP proxy 未就绪 (device=${device != null} headset=${hs != null})"
            Log.e(TAG, msg); _scoState.value = ScoState.ERROR
            return Pair(false, msg)
        }

        val connState = hs.getConnectionState(device)
        if (connState != BluetoothHeadset.STATE_CONNECTED) {
            val msg = "HFP 状态不是已连接 (state=$connState)"
            Log.e(TAG, msg); _scoState.value = ScoState.ERROR
            return Pair(false, msg)
        }

        _scoState.value = ScoState.CONNECTING

        // Step 1: communication mode
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
        Log.i(TAG, "Audio mode = MODE_IN_COMMUNICATION")

        // Step 2: startVoiceRecognition → AT+BVRA=1 to WQ
        @Suppress("DEPRECATION")
        val vraOk = hs.startVoiceRecognition(device)
        Log.i(TAG, "startVoiceRecognition(${device.address}): $vraOk")

        // Step 3: route audio — try setCommunicationDevice (API31+) first, fallback to startBluetoothSco
        registerScoReceiver()
        val routed = routeCommsToSco()
        Log.i(TAG, "Audio routing: setCommunicationDevice=${routed}")

        if (!routed) {
            // Legacy path: API < 31 or no SCO device found
            @Suppress("DEPRECATION")
            audioManager.startBluetoothSco()
            @Suppress("DEPRECATION")
            audioManager.setBluetoothScoOn(true)
            Log.i(TAG, "Legacy SCO start requested")
        }

        // Step 4: wait a moment for SCO setup, then create AudioRecord
        delay(500)
        return startAudioRecord()
    }

    private fun startAudioRecord(): Pair<Boolean, String> {
        // Try multiple audio sources. VOICE_COMMUNICATION is preferred (BT SCO),
        // but some ROMs block it without a real call.
        val sources = listOf(
            "VOICE_COMMUNICATION" to MediaRecorder.AudioSource.VOICE_COMMUNICATION,
            "MIC" to MediaRecorder.AudioSource.MIC,
            "DEFAULT" to MediaRecorder.AudioSource.DEFAULT,
            "UNPROCESSED" to MediaRecorder.AudioSource.UNPROCESSED
        )
        val errors = mutableListOf<String>()

        for ((srcName, src) in sources) {
            for (tryRate in TRY_SAMPLE_RATES) {
                val minBuf = AudioRecord.getMinBufferSize(tryRate, CHANNEL, ENCODING)
                if (minBuf <= 0) {
                    errors.add("$srcName@${tryRate}Hz: minBuf=$minBuf")
                    continue
                }
                val bufSize = maxOf(minBuf, tryRate / 25 * 4)

                @Suppress("MissingPermission")
                val rec = AudioRecord(src, tryRate, CHANNEL, ENCODING, bufSize)
                if (rec.state == AudioRecord.STATE_INITIALIZED) {
                    _actualSampleRate = tryRate
                    audioRecord = rec
                    rec.startRecording()
                    Log.i(TAG, "AudioRecord OK: $srcName @ ${tryRate}Hz buf=$bufSize")

                    val theRecord = rec
                    val theRate = tryRate
                    recordJob = scope.launch(Dispatchers.IO) {
                        val frameSize = theRate / 50 * 2
                        val buf = ByteArray(frameSize)
                        var total = 0L
                        var sil = 0
                        while (isActive) {
                            val rd = theRecord.read(buf, 0, buf.size)
                            if (rd > 0) { sil = 0; total += rd
                                if (total % (frameSize * 50L) < frameSize) Log.i(TAG, "PCM: ${total / 1024}KB")
                                _pcmFrames.tryEmit(buf.copyOf(rd))
                            } else if (rd == 0) { sil++; if (sil == 50) Log.w(TAG, "1s silence") }
                            else { Log.e(TAG, "read error: $rd"); break }
                        }
                        Log.i(TAG, "AudioRecord ended, total=${total / 1024}KB")
                    }
                    return Pair(true, "$srcName ${tryRate}Hz")
                }
                errors.add("$srcName@${tryRate}Hz: state=${rec.state}")
                rec.release()
            }
        }

        val msg = "AudioRecord 创建失败，所有源/采样率组合均失败: ${errors.joinToString("; ")}"
        Log.e(TAG, msg)
        _scoState.value = ScoState.ERROR
        return Pair(false, msg)
    }

    // ---- stop ----

    fun stopScoCapture() {
        recordJob?.cancel(); recordJob = null
        audioRecord?.let { try { it.stop() } catch (_: Exception) {}; try { it.release() } catch (_: Exception) {} }
        audioRecord = null
        unregisterScoReceiver()

        @Suppress("DEPRECATION")
        audioManager.setBluetoothScoOn(false)
        @Suppress("DEPRECATION")
        audioManager.stopBluetoothSco()
        val device = targetDevice
        val hs = headset
        if (device != null && hs != null) {
            @Suppress("DEPRECATION")
            hs.stopVoiceRecognition(device)
            Log.i(TAG, "stopVoiceRecognition: done")
        }
        audioManager.mode = AudioManager.MODE_NORMAL
        _scoState.value = ScoState.DISCONNECTED
        Log.i(TAG, "SCO stopped")
    }

    fun release() {
        stopScoCapture()
        headset?.let { BluetoothAdapter.getDefaultAdapter()?.closeProfileProxy(BluetoothProfile.HEADSET, it) }
        headset = null; targetDevice = null
    }
}
