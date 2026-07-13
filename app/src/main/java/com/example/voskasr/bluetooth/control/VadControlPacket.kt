package com.example.voskasr.bluetooth.control

object VadControlPacket {

    private const val PHONE_MAGIC: Int = 0xEE08
    private const val GROUP_ID: Byte = 0x07
    private const val STATUS_FLAG: Byte = 0x01
    private const val HEADER_SIZE = 9
    private const val CHECKSUM_SIZE = 1

    fun build(command: VadControlCommand): ByteArray {
        val packet = ByteArray(HEADER_SIZE + CHECKSUM_SIZE)
        // hdr: 0xEE08 little-endian -> bytes [08, EE]
        packet[0] = (PHONE_MAGIC and 0xFF).toByte()
        packet[1] = ((PHONE_MAGIC shr 8) and 0xFF).toByte()
        packet[2] = 0 // pkt_amount
        packet[3] = 0 // pkt_seq
        packet[4] = STATUS_FLAG
        packet[5] = GROUP_ID
        packet[6] = command.code
        // cmd_len = 10 (9-byte header + 1-byte checksum)
        val cmdLen = HEADER_SIZE + CHECKSUM_SIZE
        packet[7] = (cmdLen and 0xFF).toByte()
        packet[8] = ((cmdLen shr 8) and 0xFF).toByte()
        packet[9] = computeChecksum(packet, 0, HEADER_SIZE)
        return packet
    }

    fun computeChecksum(data: ByteArray, offset: Int = 0, length: Int = data.size): Byte {
        var sum = 0
        for (i in offset until offset + length) {
            sum += data[i].toInt() and 0xFF
        }
        return (sum and 0xFF).toByte()
    }

    fun isValidAck(data: ByteArray, expectedCommand: VadControlCommand): Boolean {
        if (data.size < 10) return false
        val hdr = (data[0].toInt() and 0xFF) or ((data[1].toInt() and 0xFF) shl 8)
        if (hdr != 0xFF09) return false
        val cmdId = data[6]
        if (cmdId != expectedCommand.code) return false
        val statusFlag = data[4].toInt() and 0xFF
        if (statusFlag != 0x01) return false
        val groupId = data[5].toInt() and 0xFF
        if (groupId != 0x07) return false
        val checksum = computeChecksum(data, 0, 9)
        if (checksum != data[9]) return false
        return true
    }
}
