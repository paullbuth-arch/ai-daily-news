package com.glass.voice

import android.companion.AssociationInfo
import android.companion.CompanionDeviceService
import android.util.Log

class GlassCompanionService : CompanionDeviceService() {

    override fun onDeviceAppeared(info: AssociationInfo) {
        Log.i("GlassCompanion", "WQ appeared: ${info.displayName}")
        HfpVoiceService.start(this)
    }

    override fun onDeviceDisappeared(info: AssociationInfo) {
        Log.i("GlassCompanion", "WQ disappeared: ${info.displayName}")
        HfpVoiceService.stop(this)
    }
}
