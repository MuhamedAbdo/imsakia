package com.muhamed.imsakia

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.Manifest
import android.net.Uri
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.engine.FlutterEngineCache
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "imsakia/notifications"
    private val ATHAN_CHANNEL = "imsakia/athan_control"
    private val NOTIFICATION_PERMISSION_CODE = 1001

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Android 8.1+ Show when locked
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }

        // Request notification permissions immediately when app starts
        requestNotificationPermission()
    }


    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        FlutterEngineCache.getInstance().put("main_engine", flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestNotificationPermission" -> {
                    requestNotificationPermission()
                    result.success(true)
                }
                "openNotificationSettings" -> {
                    openNotificationSettings()
                    result.success(true)
                }
                "openBatteryOptimizationSettings" -> {
                    openBatteryOptimizationSettings()
                    result.success(true)
                }
                "openAutostartSettings" -> {
                    openAutostartSettings()
                    result.success(true)
                }
                "openOverlaySettings" -> {
                    openOverlaySettings()
                    result.success(true)
                }
                "isMiui" -> {
                    result.success(isMiui())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ATHAN_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleAthanAlarm" -> {
                    val id = call.argument<Int>("id") ?: 0
                    val timeMs = call.argument<Long>("timeMs") ?: 0L
                    val prayerAr = call.argument<String>("prayerAr") ?: ""
                    val prayerEn = call.argument<String>("prayerEn") ?: ""
                    val assetPath = call.argument<String>("assetPath") ?: ""
                    val prayerImage = call.argument<String>("image") ?: ""
                    scheduleAthanAlarm(id, timeMs, prayerAr, prayerEn, assetPath, prayerImage)
                    result.success(true)
                }
                "cancelAthanAlarm" -> {
                    val id = call.argument<Int>("id") ?: 0
                    cancelAthanAlarm(id)
                    result.success(true)
                }
                "stopNativeAudio" -> {
                    NativeAudioController.stop(this@MainActivity)
                    result.success(true)
                }
                "updateAthanVolume" -> {
                    try {
                        val volume = when (call.arguments) {
                            is Double -> (call.arguments as Double).toFloat()
                            is Float -> call.arguments as Float
                            is Int -> (call.arguments as Int).toFloat()
                            else -> 1.0f
                        }

                        NativeAudioController.setVolume(volume)
                        result.success(null)

                    } catch (e: Exception) {
                        result.error("VOLUME_ERROR", e.message, null)
                    }
                }
                "checkAthanPlaying" -> {
                    try {
                        result.success(NativeAudioController.isReallyPlaying(this@MainActivity))
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleAthanIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        handleAthanIntent(intent)
    }

    private fun handleAthanIntent(currentIntent: Intent?) {
        if (currentIntent?.getBooleanExtra("open_athan_screen", false) == true) {
            val prayerAr = currentIntent.getStringExtra("prayer_ar") ?: ""
            val prayerEn = currentIntent.getStringExtra("prayer_en") ?: ""
            val prayerImage = currentIntent.getStringExtra("image") ?: ""

            try {
                FlutterEngineCache.getInstance().get("main_engine")?.let { engine ->
                    MethodChannel(engine.dartExecutor.binaryMessenger, ATHAN_CHANNEL)
                        .invokeMethod("open_athan", mapOf(
                            "prayer" to prayerAr,
                            "prayerEn" to prayerEn,
                            "image" to prayerImage
                        ))
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
            
            // Remove so it doesn't trigger again on subsequent resumes
            currentIntent.removeExtra("open_athan_screen")
        }
    }

    private fun scheduleAthanAlarm(id: Int, timeMs: Long, prayerAr: String, prayerEn: String, assetPath: String, prayerImage: String) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AthanTriggerReceiver::class.java).apply {
            putExtra("prayer_ar", prayerAr)
            putExtra("prayer_en", prayerEn)
            putExtra("asset_path", assetPath)
            putExtra("prayer_image", prayerImage)
            putExtra("notification_id", id)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMs, pendingIntent)
            } else {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMs, pendingIntent)
            }
            // Persist for boot recovery
            saveAlarmMetadata(id, timeMs, prayerAr, prayerEn, assetPath, prayerImage)
        } catch (e: SecurityException) {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMs, pendingIntent)
            saveAlarmMetadata(id, timeMs, prayerAr, prayerEn, assetPath, prayerImage)
        }
    }

    private fun saveAlarmMetadata(id: Int, timeMs: Long, prayerAr: String, prayerEn: String, assetPath: String, image: String) {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val alarmsJson = prefs.getString("flutter.native_scheduled_alarms", "[]")
        
        try {
            val array = JSONArray(alarmsJson)
            // Remove if exists
            val newArray = JSONArray()
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                if (obj.getInt("id") != id) {
                    newArray.put(obj)
                }
            }
            
            val newAlarm = JSONObject().apply {
                put("id", id)
                put("timeMs", timeMs)
                put("prayerAr", prayerAr)
                put("prayerEn", prayerEn)
                put("assetPath", assetPath)
                put("image", image)
            }
            newArray.put(newAlarm)
            
            prefs.edit().putString("flutter.native_scheduled_alarms", newArray.toString()).apply()
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to save alarm metadata: ${e.message}")
        }
    }

    private fun cancelAthanAlarm(id: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AthanTriggerReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
        removeAlarmMetadata(id)
    }

    private fun removeAlarmMetadata(id: Int) {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val alarmsJson = prefs.getString("flutter.native_scheduled_alarms", "[]")
        try {
            val array = JSONArray(alarmsJson)
            val newArray = JSONArray()
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                if (obj.getInt("id") != id) {
                    newArray.put(obj)
                }
            }
            prefs.edit().putString("flutter.native_scheduled_alarms", newArray.toString()).apply()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Android 13+ (API 33+) - Request POST_NOTIFICATIONS
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATION_PERMISSION_CODE)
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Android 12 (API 31+) - Request SCHEDULE_EXACT_ALARM
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.SCHEDULE_EXACT_ALARM) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.SCHEDULE_EXACT_ALARM), NOTIFICATION_PERMISSION_CODE)
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
            val intent = Intent()
            intent.action = android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
            intent.data = Uri.parse("package:$packageName")
            startActivity(intent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun openAutostartSettings() {
        try {
            val intent = Intent()
            intent.component = android.content.ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")
            startActivity(intent)
        } catch (e: Exception) {
            try {
                val intent = Intent("miui.intent.action.OP_AUTO_START").addCategory(Intent.CATEGORY_DEFAULT)
                startActivity(intent)
            } catch (ex: Exception) {
                openAppInfoSettings()
            }
        }
    }

    private fun openOverlaySettings() {
        try {
            val intent = Intent(android.provider.Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
            startActivity(intent)
        } catch (e: Exception) {
            openAppInfoSettings()
        }
    }

    private fun isMiui(): Boolean {
        return try {
            val c = Class.forName("android.os.SystemProperties")
            val get = c.getMethod("get", String::class.java)
            val miuiVersion = get.invoke(c, "ro.miui.ui.version.name") as String
            Build.MANUFACTURER.contains("Xiaomi", ignoreCase = true) || miuiVersion.isNotBlank()
        } catch (e: Exception) {
            try {
                val p = Runtime.getRuntime().exec("getprop ro.miui.ui.version.name")
                val reader = java.io.BufferedReader(java.io.InputStreamReader(p.inputStream))
                val line = reader.readLine()
                Build.MANUFACTURER.contains("Xiaomi", ignoreCase = true) || !line.isNullOrBlank()
            } catch (ex: Exception) {
                Build.MANUFACTURER.contains("Xiaomi", ignoreCase = true)
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            NOTIFICATION_PERMISSION_CODE -> {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    // Permission granted
                } else {
                    // Permission denied
                }
            }
        }
    }
}
