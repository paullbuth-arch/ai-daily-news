package com.example.voskasr.audio.baidu

import com.example.voskasr.BuildConfig

data class BaiduAsrConfig(
    val appId: Int,
    val apiKey: String,
    val secretKey: String,
    val devPid: Int = DEV_PID_MANDARIN_STRONG_PUNCT,
    val cuid: String = DEFAULT_CUID,
    val websocketUrl: String = WEBSOCKET_URL
) {
    fun isUsable(): Boolean {
        return appId > 0 && apiKey.isNotBlank() && secretKey.isNotBlank()
    }

    companion object {
        const val WEBSOCKET_URL = "wss://vop.baidu.com/realtime_asr"
        const val DEV_PID_MANDARIN_STRONG_PUNCT = 15372
        const val DEV_PID_ENGLISH_STRONG_PUNCT = 17372
        const val DEFAULT_CUID = "wq-glass-001"

        fun fromBuildConfig(): BaiduAsrConfig = BaiduAsrConfig(
            appId = BuildConfig.BAIDU_APP_ID,
            apiKey = BuildConfig.BAIDU_API_KEY,
            secretKey = BuildConfig.BAIDU_SECRET_KEY
        )
    }
}
