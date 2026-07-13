package com.example.voskasr.bluetooth.control

enum class VadControlCommand(val code: Byte) {
    ENABLE_VAD(0x81.toByte()),
    DISABLE_VAD(0x82.toByte()),
    START_STREAMING_BY_SPP(0x83.toByte()),
    STOP_STREAMING(0x86.toByte());

    companion object {
        fun fromCode(code: Byte): VadControlCommand? {
            return entries.find { it.code == code }
        }
    }
}
