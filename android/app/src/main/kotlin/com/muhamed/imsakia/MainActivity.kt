package com.muhamed.imsakia

import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import android.Manifest
import android.util.Log
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {

    private val NOTIFICATIONS_CHANNEL = "imsakia/notifications"
    private val ATHAN_CONTROL_CHANNEL = "imsakia/athan_control"
    private val NOTIFICATION_PERMISSION_CODE = 1001
    private val TAG = "MainActivity"

    private var pendingAthanArgs: Map<String, String?>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }

        requestNotificationPermission()
        handleAthanIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleAthanIntent(intent)
    }

    private fun handleAthanIntent(intent: Intent?) {
        if (intent?.getBooleanExtra("show_athan", false) != true) return

        val args = mapOf(
            "prayer" to (intent.getStringExtra("prayer_ar") ?: "الصلاة"),
            "prayerEn" to (intent.getStringExtra("prayer_en") ?: "Prayer"),
            "image" to (intent.getStringExtra("prayer_image") ?: "")
        )

        pendingAthanArgs = args

        Log.d(TAG, "Athan intent detected")

        window.decorView.postDelayed({
            try {
                val engine = FlutterEngineCache.getInstance().get("main_engine")
                if (engine != null) {
                    MethodChannel(engine.dartExecutor.binaryMessenger, ATHAN_CONTROL_CHANNEL)
                        .invokeMethod("open_athan", args)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error sending athan event: ${e.message}")
            }
        }, 500)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        FlutterEngineCache.getInstance().put("main_engine", flutterEngine)

        // 🔥 Channel الخاص بالإشعارات
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NOTIFICATIONS_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {

                "openBatteryOptimizationSettings" -> {
                    openBatteryOptimizationSettings()
                    result.success(true)
                }

                "openNotificationSettings" -> {
                    openNotificationSettings()
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }

        // 🔥 Channel الأذان
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ATHAN_CONTROL_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {

                "getPendingAthanIntent" -> {
                    val args = pendingAthanArgs
                    pendingAthanArgs = null
                    result.success(args)
                }

                "is_open_from_athan" -> {
                    val isOpen = intent?.getBooleanExtra("show_athan", false) == true
                    result.success(isOpen)
                    intent?.removeExtra("show_athan")
                }

                "openXiaomiPermissions" -> {
                    openXiaomiPermissions()
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun isXiaomi(): Boolean {
        return Build.MANUFACTURER.equals("Xiaomi", ignoreCase = true)
    }

    private fun openXiaomiPermissions() {
        if (!isXiaomi()) return
        try {
            // 1. Open Autostart Management
            val intent = Intent()
            intent.component = android.content.ComponentName(
                "com.miui.securitycenter",
                "com.miui.permcenter.autostart.AutoStartManagementActivity"
            )
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
            try {
                // Fallback for different MIUI versions or Permissions page
                val intent = Intent("miui.intent.action.OP_PERMISSIONS_EDITOR")
                intent.setClassName("com.miui.securitycenter", "com.miui.permcenter.permissions.PermissionsEditorActivity")
                intent.putExtra("extra_pkgname", packageName)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
            } catch (e2: Exception) {
                // Final fallback to App Settings / Battery Optimization
                try {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    intent.data = Uri.parse("package:$packageName")
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                } catch (e3: Exception) {
                    Log.e(TAG, "Failed to open Xiaomi settings: ${e3.message}")
                }
            }
        }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(
                    this, Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    NOTIFICATION_PERMISSION_CODE
                )
            }
        }
    }

    private fun openNotificationSettings() {
        try {
            val intent = Intent()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                intent.action = "android.settings.APP_NOTIFICATION_SETTINGS"
                intent.putExtra("android.provider.extra.APP_PACKAGE", packageName)
            } else {
                intent.action = "android.settings.APPLICATION_DETAILS_SETTINGS"
                intent.data = Uri.fromParts("package", packageName, null)
            }
            startActivity(intent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun openBatteryOptimizationSettings() {
        try {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
            intent.data = Uri.parse("package:$packageName")
            startActivity(intent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}