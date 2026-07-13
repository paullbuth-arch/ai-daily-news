package com.example.voskasr.bluetooth.control

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.util.Log
import com.example.voskasr.bluetooth.BluetoothChannel
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.io.IOException
import java.io.InputStream
import java.util.UUID

class VadControlChannel : BluetoothChannel {

    private val scope = CoroutineScope(Dispatchers.IO + Job())
    private val controlUuid: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

    private var socket: BluetoothSocket? = null
    private var inputStream: InputStream? = null

    private val pendingAcks = mutableMapOf<VadControlCommand, CompletableDeferred<Boolean>>()
    private val pendingLock = Mutex()

    private val _events = MutableSharedFlow<VadControlEvent>(extraBufferCapacity = 64)
    val events: SharedFlow<VadControlEvent> = _events.asSharedFlow()

    @Volatile
    override var isConnected: Boolean = false
        private set

    override suspend fun connect(device: BluetoothDevice): Boolean = withContext(Dispatchers.IO) {
        if (isConnected) return@withContext true
        try {
            val newSocket = device.createRfcommSocketToServiceRecord(controlUuid)
            this@VadControlChannel.socket = newSocket
            newSocket.connect()
            inputStream = newSocket.inputStream
            isConnected = true
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
    }

    suspend fun sendCommand(command: VadControlCommand, timeoutMs: Long = 2000): Boolean {
        val s = socket
        if (s == null || !isConnected) {
            return false
        }
        val deferred = CompletableDeferred<Boolean>()
        pendingLock.withLock {
            pendingAcks[command] = deferred
        }
        return try {
            withContext(Dispatchers.IO) {
                val packet = VadControlPacket.build(command)
                s.outputStream.write(packet)
                s.outputStream.flush()
            }
            val result = withTimeoutOrNull(timeoutMs) { deferred.await() }
            result == true
        } finally {
            pendingLock.withLock {
                pendingAcks.remove(command)
            }
        }
    }

    private fun startReadLoop() {
        scope.launch {
            val stream = inputStream ?: return@launch
            val buffer = ByteArray(4096)
            while (isConnected) {
                try {
                    val len = stream.read(buffer)
                    if (len > 0) {
                        val data = buffer.copyOf(len)
                        handleIncoming(data)
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
                _events.tryEmit(VadControlEvent.Disconnected)
            }
        }
    }

    private suspend fun handleIncoming(data: ByteArray) {
        var offset = 0
        while (offset + 10 <= data.size) {
            if (looksLikeAck(data, offset)) {
                val cmdId = data[offset + 6]
                val command = VadControlCommand.fromCode(cmdId)
                val chunk = data.copyOfRange(offset, offset + 10)
                if (command != null && VadControlPacket.isValidAck(chunk, command)) {
                    pendingLock.withLock {
                        pendingAcks.remove(command)?.complete(true)
                    }
                    _events.emit(VadControlEvent.Ack(command))
                } else {
                    _events.emit(VadControlEvent.Raw(chunk))
                }
                offset += 10
            } else {
                offset++
            }
        }
        if (offset < data.size) {
            _events.emit(VadControlEvent.Raw(data.copyOfRange(offset, data.size)))
        }
    }

    private fun looksLikeAck(data: ByteArray, offset: Int): Boolean {
        if (offset + 2 > data.size) return false
        val hdr = (data[offset].toInt() and 0xFF) or ((data[offset + 1].toInt() and 0xFF) shl 8)
        return hdr == 0xFF09
    }

    companion object {
        private const val TAG = "VadControlChannel"
    }
}

sealed class VadControlEvent {
    data class Ack(val command: VadControlCommand) : VadControlEvent()
    data object Disconnected : VadControlEvent()
    data class Raw(val data: ByteArray) : VadControlEvent() {
        override fun equals(other: Any?): Boolean {
            if (this === other) return true
            if (other !is Raw) return false
            return data.contentEquals(other.data)
        }

        override fun hashCode(): Int = data.contentHashCode()
    }
}
