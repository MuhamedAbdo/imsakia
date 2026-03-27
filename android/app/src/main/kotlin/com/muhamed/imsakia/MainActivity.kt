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
                    val prayerImage = call.argument<String>("prayerImage") ?: ""
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
            val prayerImage = currentIntent.getStringExtra("prayer_image") ?: ""

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
        } catch (e: SecurityException) {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMs, pendingIntent)
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
            intent.action = "android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"
            intent.data = Uri.parse("package:$packageName")
            startActivity(intent)
        } catch (e: Exception) {
            e.printStackTrace()
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
