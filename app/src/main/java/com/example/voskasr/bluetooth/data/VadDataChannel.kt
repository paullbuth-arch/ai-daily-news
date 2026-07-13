package com.example.voskasr.bluetooth.data

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.util.Log
import com.example.voskasr.bluetooth.BluetoothChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.IOException
import java.io.InputStream
import java.util.UUID

class VadDataChannel : BluetoothChannel {

    private val scope = CoroutineScope(Dispatchers.IO + Job())
    private val dataUuid: UUID = UUID.fromString("00001102-0000-1000-8000-00805F9B34FB")

    private var socket: BluetoothSocket? = null
    private var inputStream: InputStream? = null

    private val _frames = MutableSharedFlow<ByteArray>(extraBufferCapacity = 256)
    val frames: SharedFlow<ByteArray> = _frames.asSharedFlow()

    private val _events = MutableSharedFlow<DataChannelEvent>(extraBufferCapacity = 64)
    val events: SharedFlow<DataChannelEvent> = _events.asSharedFlow()

    private var parser: VadPacketParser? = null

    @Volatile
    override var isConnected: Boolean = false
        private set

    override suspend fun connect(device: BluetoothDevice): Boolean = withContext(Dispatchers.IO) {
        if (isConnected) return@withContext true
        try {
            val newSocket = device.createRfcommSocketToServiceRecord(dataUuid)
            this@VadDataChannel.socket = newSocket
            newSocket.connect()
            inputStream = newSocket.inputStream
            isConnected = true
            parser = VadPacketParser { frames ->
                frames.forEach { _frames.tryEmit(it) }
            }
            startReadLoop()
            true
        } catch (e: SecurityException) {
            Log.e(TAG, "connect SecurityException: ${e.message}")
            disconnect()
            false
        } catch (e: IOException) {
            Log.e(TAG, "connect IOException: ${e.message}")
            disconnect()
            false
        }
    }

    override fun disconnect() {
        isConnected = false
        scope.coroutineContext[Job]?.cancel("disconnect")
        try { socket?.close() } catch (_: IOException) {}
        try { inputStream?.close() } catch (_: IOException) {}
        socket = null
        inputStream = null
        parser?.clear()
    }

    private fun startReadLoop() {
        scope.launch {
            val stream = inputStream ?: return@launch
            val tmp = ByteArray(8192)
            while (isConnected) {
                try {
                    val len = stream.read(tmp)
                    if (len > 0) {
                        parser?.feed(tmp, len)
                    } else if (len < 0) {
                        Log.w(TAG, "read loop closed by remote")
                        break
                    }
                } catch (e: IOException) {
                    Log.e(TAG, "read loop IOException: ${e.message}")
                    break
                }
            }
            if (isConnected) {
                isConnected = false
                _events.tryEmit(DataChannelEvent.Disconnected)
            }
        }
    }

    companion object {
        private const val TAG = "VadDataChannel"
    }
}

sealed class DataChannelEvent {
    data object Disconnected : DataChannelEvent()
}
