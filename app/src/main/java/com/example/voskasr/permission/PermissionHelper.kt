package com.example.voskasr.permission

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat

class PermissionHelper(private val activity: AppCompatActivity) {

    private val requestLauncher = activity.registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        val allGranted = permissions.values.all { it }
        onResult?.invoke(allGranted)
    }

    private var onResult: ((Boolean) -> Unit)? = null

    fun hasBluetoothPermissions(): Boolean {
        return getRequiredPermissions().all {
            ContextCompat.checkSelfPermission(activity, it) == PackageManager.PERMISSION_GRANTED
        }
    }

    fun requestBluetoothPermissions(onResult: (Boolean) -> Unit) {
        this.onResult = onResult
        val permissions = getRequiredPermissions()
        if (permissions.isEmpty()) {
            onResult(true)
            return
        }
        val missing = permissions.filter {
            ContextCompat.checkSelfPermission(activity, it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isEmpty()) {
            onResult(true)
            return
        }
        requestLauncher.launch(missing.toTypedArray())
    }

    private fun getRequiredPermissions(): Array<String> {
        val permissions = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            permissions.add(Manifest.permission.BLUETOOTH_SCAN)
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
        }
        permissions.add(Manifest.permission.BLUETOOTH)
        permissions.add(Manifest.permission.BLUETOOTH_ADMIN)
        // RECORD_AUDIO is required for AudioRecord — Android 6+ must request at runtime
        permissions.add(Manifest.permission.RECORD_AUDIO)
        return permissions.toTypedArray()
    }
}
