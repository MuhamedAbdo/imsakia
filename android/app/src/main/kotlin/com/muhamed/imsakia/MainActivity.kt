package com.muhamed.imsakia

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.Manifest
import android.net.Uri
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import android.os.Bundle
import android.app.KeyguardManager
import android.content.Context
import android.view.WindowManager
import android.widget.Toast

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "imsakia/notifications"
    private val PREFS_NAME = "athan_schedules"
    private val TAG = "ImsakiaMainActivity"
    private val NOTIFICATION_PERMISSION_CODE = 1001
    private val ATHAN_CHANNEL_ID = "athan_sovereign_v2"
    private var isMethodChannelSet = false

    override fun onCreate(savedInstanceState: Bundle?) {
        // ✅ Call super first
        super.onCreate(savedInstanceState)
        
        // 🔥 ضمان ظهور التطبيق فوق شاشة القفل وتنشيط الشاشة
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }

        // 🔥 Indestructible breadcrumbs (Visual + Terminal + Log)
        val timestamp = System.currentTimeMillis()
        Toast.makeText(this, "✅ MainActivity STARTED $timestamp", Toast.LENGTH_LONG).show()
        android.util.Log.e(TAG, "=== onCreate CALLED at $timestamp ===")
        System.err.println("!!! ATHAN DEBUG: onCreate CALLED at $timestamp !!!")
        System.err.println("!!! ATHAN DEBUG: Activity hashCode=${this.hashCode()} !!!")
        
        // Keyguard management
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        }

        requestNotificationPermission()
        createNotificationChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        System.err.println("!!! ATHAN DEBUG: configureFlutterEngine CALLED !!!")
        System.err.println("!!! ATHAN DEBUG: Engine hashCode=${flutterEngine.dartExecutor.hashCode()} !!!")
        
        if (isMethodChannelSet) {
            System.err.println("!!! ATHAN DEBUG: MethodChannel already set, skipping !!!")
            return
        }

        try {
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
                System.err.println("!!! ATHAN DEBUG: MethodCall received: ${call.method} !!!")
                
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
                    "openXiaomiOtherPermissions" -> {
                        openXiaomiOtherPermissions()
                        result.success(true)
                    }
                    "getInitialPayload" -> {
                        val payload = intent?.getStringExtra("payload")
                        result.success(payload)
                    }
                    "scheduleExactAthan" -> {
                        val timeInMillis = call.argument<Long>("timeInMillis") ?: 0L
                        val id = call.argument<Int>("id") ?: 0
                        System.err.println("!!! ATHAN DEBUG: Scheduling ID=$id, Time=$timeInMillis !!!")
                        
                        if (timeInMillis > 0) {
                            scheduleExactAthan(timeInMillis, id)
                            result.success(true)
                        } else {
                            result.error("INVALID_TIME", "Time must be > 0", null)
                        }
                    }
                    "clearAllAlarms" -> {
                        clearAllAlarms()
                        result.success(true)
                    }
                    "pingNative" -> {
                        // Quick connectivity test
                        val response = "PONG from Native at ${System.currentTimeMillis()}"
                        System.err.println("!!! ATHAN DEBUG: $response !!!")
                        result.success(response)
                    }
                    else -> result.notImplemented()
                }
            }
            isMethodChannelSet = true
            System.err.println("!!! ATHAN DEBUG: MethodChannel registered successfully !!!")
        } catch (e: Exception) {
            System.err.println("!!! ATHAN DEBUG: FAILED to register MethodChannel: ${e.message} !!!")
            e.printStackTrace()
        }
    }

    private fun scheduleExactAthan(timeInMillis: Long, id: Int) {
        val uniqueId = System.currentTimeMillis().toInt()
        System.err.println("!!! MAIN ACTIVITY: Scheduling Alarm UNIQUE_ID=$uniqueId (Target ID=$id) !!!")
        try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
            
            // Check Permission
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (!alarmManager.canScheduleExactAlarms()) {
                    System.err.println("!!! MAIN ACTIVITY: Permission Missing !!!")
                    return
                }
            }
            
            // Persist for Reboot
            val prefs = getSharedPreferences("athan_schedules", Context.MODE_PRIVATE)
            prefs.edit().putLong(id.toString(), timeInMillis).apply()

            // 1. Intent for BroadcastReceiver (Actual Alarm Action)
            val broadcastIntent = Intent(this, AthanReceiver::class.java)
            val alarmPendingIntent = android.app.PendingIntent.getBroadcast(
                this, uniqueId, broadcastIntent, 
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )

            // 2. Intent for System UI (Opening app when clicking the clock icon)
            val activityIntent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            }
            val uiPendingIntent = android.app.PendingIntent.getActivity(
                this, uniqueId + 1, activityIntent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )

            // Schedule with AlarmClockInfo (Shows the icon ⏰)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val clockInfo = android.app.AlarmManager.AlarmClockInfo(timeInMillis, uiPendingIntent)
                alarmManager.setAlarmClock(clockInfo, alarmPendingIntent)
                System.err.println("!!! MAIN ACTIVITY: Scheduled via setAlarmClock with UI Intent !!!")
            } else {
                alarmManager.setExact(android.app.AlarmManager.RTC_WAKEUP, timeInMillis, alarmPendingIntent)
            }
        } catch (e: Exception) {
            System.err.println("!!! MAIN ACTIVITY: Error scheduling: ${e.message} !!!")
        }
    }

    private fun clearAllAlarms() {
        System.err.println("!!! ATHAN DEBUG: clearAllAlarms CALLED !!!")
        try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            for ((idStr, _) in prefs.all) {
                val id = idStr.toIntOrNull() ?: continue
                val intent = Intent(this, AthanReceiver::class.java)
                val pIntent = android.app.PendingIntent.getBroadcast(
                    this, id, intent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                alarmManager.cancel(pIntent)
            }
            prefs.edit().clear().apply()
            System.err.println("!!! ATHAN DEBUG: All alarms cleared !!!")
        } catch (e: Exception) {
            System.err.println("!!! ATHAN DEBUG: Error clearing: ${e.message} !!!")
        }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATION_PERMISSION_CODE)
            }
        }
    }

    private fun openNotificationSettings() {
        try {
            val intent = Intent().apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    action = "android.settings.APP_NOTIFICATION_SETTINGS"
                    putExtra("android.provider.extra.APP_PACKAGE", packageName)
                } else {
                    action = "android.settings.APPLICATION_DETAILS_SETTINGS"
                    data = Uri.fromParts("package", packageName, null)
                }
            }
            startActivity(intent)
        } catch (e: Exception) {
            System.err.println("!!! ATHAN DEBUG: Failed settings open: ${e.message} !!!")
        }
    }

    private fun openBatteryOptimizationSettings() {
        try {
            val intent = Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
        } catch (e: Exception) {
            System.err.println("!!! ATHAN DEBUG: Failed battery settings: ${e.message} !!!")
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val importance = android.app.NotificationManager.IMPORTANCE_HIGH
            val channel = android.app.NotificationChannel(ATHAN_CHANNEL_ID, "Athan Sovereign", importance).apply {
                description = "High-precision prayer alerts"
                setBypassDnd(true)
                enableLights(true)
                enableVibration(true)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                setSound(null, null)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun openXiaomiOtherPermissions() {
        try {
            val intent = Intent("interactive.intent.action.APP_PERMS_EDITOR").apply {
                putExtra("extra_pkgname", packageName)
            }
            startActivity(intent)
        } catch (e: Exception) {
            val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.fromParts("package", packageName, null)
            }
            startActivity(intent)
        }
    }
}
