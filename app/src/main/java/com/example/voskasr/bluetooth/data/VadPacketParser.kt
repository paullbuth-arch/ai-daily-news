package com.example.voskasr.bluetooth.data

class VadPacketParser(private val onFrames: (List<ByteArray>) -> Unit) {

    private val bufferLock = Object()
    private val buffer = mutableListOf<Byte>()

    fun feed(bytes: ByteArray, length: Int = bytes.size) {
        synchronized(bufferLock) {
            for (i in 0 until length) {
                buffer.add(bytes[i])
            }
        }
        processBuffer()
    }

    private fun processBuffer() {
        while (true) {
            val headerIndex = findHeader()
            if (headerIndex < 0) {
                trimBuffer()
                break
            }

            if (headerIndex > 0) {
                removeBytes(headerIndex)
            }

            // Recompute available after dropping garbage to avoid out-of-bounds snapshot
            var available = synchronized(bufferLock) { buffer.size }
            if (available < FRAME_HEADER_SIZE) {
                break
            }

            val cmdLen = readCmdLen()
            if (cmdLen < MIN_PACKET_SIZE || cmdLen > MAX_PACKET_SIZE) {
                removeBytes(1)
                continue
            }

            if (available < cmdLen) {
                break
            }

            val packet = synchronized(bufferLock) {
                val arr = ByteArray(cmdLen)
                for (i in 0 until cmdLen) {
                    arr[i] = buffer[i]
                }
                arr
            }

            if (!validateChecksum(packet)) {
                removeBytes(1)
                continue
            }

            val frames = parsePacket(packet)
            if (frames == null) {
                removeBytes(1)
                continue
            }

            onFrames(frames)
            removeBytes(cmdLen)
        }
    }

    private fun findHeader(): Int {
        synchronized(bufferLock) {
            var i = 0
            while (i < buffer.size - 1) {
                val b0 = buffer[i].toInt() and 0xFF
                val b1 = buffer[i + 1].toInt() and 0xFF
                if (b0 == 0xFF && b1 == 0x09) {
                    if (i + OFF_CMD_ID < buffer.size) {
                        val groupId = buffer[i + OFF_GROUP_ID].toInt() and 0xFF
                        val cmdId = buffer[i + OFF_CMD_ID].toInt() and 0xFF
                        if (groupId == GROUP_ID && cmdId == CMD_ID) {
                            return i
                        }
                    } else {
                        return i
                    }
                }
                i++
            }
            return -1
        }
    }

    private fun readCmdLen(): Int {
        synchronized(bufferLock) {
            val b0 = buffer[OFF_CMD_LEN].toInt() and 0xFF
            val b1 = buffer[OFF_CMD_LEN + 1].toInt() and 0xFF
            return b0 or (b1 shl 8)
        }
    }

    private fun validateChecksum(packet: ByteArray): Boolean {
        if (packet.size < 2) return false
        var sum = 0
        for (i in 0 until packet.size - 1) {
            sum += packet[i].toInt() and 0xFF
        }
        val expected = (sum and 0xFF).toByte()
        return expected == packet[packet.size - 1]
    }

    private fun parsePacket(packet: ByteArray): List<ByteArray>? {
        if (packet.size < MIN_PACKET_SIZE) return null

        val blockCnt = packet[OFF_BLOCK_CNT].toInt() and 0xFF
        val payloadEnd = packet.size - 1
        if (payloadEnd < FRAME_HEADER_SIZE) return null

        var pos = FRAME_HEADER_SIZE
        val frames = ArrayList<ByteArray>(blockCnt.coerceAtLeast(1))

        for (i in 0 until blockCnt) {
            if (pos + BLOCK_HEADER_SIZE > payloadEnd) return null
            val blockLen = (packet[pos + 2].toInt() and 0xFF) or
                    ((packet[pos + 3].toInt() and 0xFF) shl 8)
            pos += BLOCK_HEADER_SIZE
            if (blockLen <= 0 || pos + blockLen > payloadEnd) return null
            frames.add(packet.copyOfRange(pos, pos + blockLen))
            pos += blockLen
        }

        if (pos != payloadEnd) return null
        return frames
    }

    private fun trimBuffer() {
        synchronized(bufferLock) {
            while (buffer.size > MAX_TRAILING_BYTES) {
                buffer.removeAt(0)
            }
        }
    }

    private fun removeBytes(count: Int) {
        synchronized(bufferLock) {
            repeat(count.coerceAtMost(buffer.size)) { buffer.removeAt(0) }
        }
    }

    fun clear() {
        synchronized(bufferLock) {
            buffer.clear()
        }
    }

    companion object {
        private const val OFF_GROUP_ID = 5
        private const val OFF_CMD_ID = 6
        private const val OFF_CMD_LEN = 7
        private const val OFF_BLOCK_CNT = 13

        private const val FRAME_HEADER_SIZE = 14
        private const val BLOCK_HEADER_SIZE = 4
        private const val MIN_PACKET_SIZE = FRAME_HEADER_SIZE + 1
        private const val MAX_PACKET_SIZE = 4096
        private const val MAX_TRAILING_BYTES = 1024

        private const val GROUP_ID = 0x07
        private const val CMD_ID = 0x8F
    }
}
