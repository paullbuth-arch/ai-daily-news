package com.example.voskasr

import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.appcompat.app.AppCompatActivity
import com.example.voskasr.permission.PermissionHelper
import com.example.voskasr.ui.MainScreen
import com.example.voskasr.ui.theme.VoskAsrTheme

class MainActivity : AppCompatActivity() {

    private lateinit var permissionHelper: PermissionHelper

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        permissionHelper = PermissionHelper(this)
        requestPermissionsIfNeeded()

        setContent {
            VoskAsrTheme {
                MainScreen()
            }
        }
    }

    private fun requestPermissionsIfNeeded() {
        if (!permissionHelper.hasBluetoothPermissions()) {
            permissionHelper.requestBluetoothPermissions { allGranted ->
                if (!allGranted) {
                    // Permissions are required for Bluetooth SPP.
                }
            }
        }
    }
}
