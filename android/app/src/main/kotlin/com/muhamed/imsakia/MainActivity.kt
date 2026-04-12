package com.muhamed.imsakia

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.content.ComponentName
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
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.widget.Toast
import android.os.Handler
import android.os.Looper
import android.media.AudioManager
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import androidx.work.*
import java.util.concurrent.TimeUnit
import android.appwidget.AppWidgetManager

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "imsakia/notifications"
    private val PREFS_NAME = "athan_schedules"
    private val TAG = "ImsakiaMainActivity"
    private val NOTIFICATION_PERMISSION_CODE = 1001
    private val ATHAN_CHANNEL_ID = "athan_sovereign_v2"
    private var isMethodChannelSet = false
    private val ATHAN_NATIVE_PREFS = "athan_native_prefs"

    // Smart Exit Tracking
    private var wasLockedOnStart = false
    private var wasInAppOnStart = false

    private val completionReceiver = object : android.content.BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.muhamed.imsakia.ATHAN_COMPLETED") {
                
                // 1. Notify Flutter to dismiss the overlay
                flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                    MethodChannel(messenger, CHANNEL).invokeMethod("dismissAthanOverlay", null)
                }
                
                // 2. 🔥 لضمان اختفاء الشاشة السوداء في حالة الـ Cold Start أو الظهور فوق القفل
                // المطلب الجديد: لا نستدعي هذا الأمر إلا إذا كان التطبيق مغلقاً أو في الخلفية وقت حدوث الأذان
                Handler(Looper.getMainLooper()).postDelayed({
                    if (!isFinishing && (wasLockedOnStart || !wasInAppOnStart)) {
                        moveTaskToBack(true)
                    } else {
                    }
                }, 1000)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // 🔥 1. Priority Theme & Window Flags (BEFORE super.onCreate/setContentView)
        val isAthanIntent = intent?.getBooleanExtra("trigger_athan_overlay", false) == true || 
                            intent?.hasExtra("prayer_name") == true
        if (isAthanIntent) {
            setTheme(android.R.style.Theme_Black_NoTitleBar_Fullscreen)
        }

        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                setInheritShowWhenLocked(true)
            }

            // 🔥 Root Cause Fix: 200ms delay to ensure activity covers screen before dismissing keyguard
            Handler(Looper.getMainLooper()).postDelayed({
                keyguardManager.requestDismissKeyguard(this, null)
            }, 200)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        // ✅ 2. super.onCreate
        super.onCreate(savedInstanceState)
        
        // Track state for Smart Exit
        wasLockedOnStart = keyguardManager.isKeyguardLocked
        wasInAppOnStart = false 

        // Register receiver for audio completion
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(completionReceiver, android.content.IntentFilter("com.muhamed.imsakia.ATHAN_COMPLETED"), Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(completionReceiver, android.content.IntentFilter("com.muhamed.imsakia.ATHAN_COMPLETED"))
        }

        requestNotificationPermission()
        createNotificationChannel()
        checkAndShowAthanOverlay()
        setupWidgetHeartbeat()
    }

    private fun setupWidgetHeartbeat() {
        val workRequest = PeriodicWorkRequestBuilder<WidgetUpdateWorker>(15, TimeUnit.MINUTES)
            .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.NOT_REQUIRED).build())
            .build()
        
        WorkManager.getInstance(this).enqueueUniquePeriodicWork(
            "WidgetHeartbeat",
            ExistingPeriodicWorkPolicy.KEEP,
            workRequest
        )
    }

    override fun onResume() {
        super.onResume()
        // Refresh widget on app return
        val widgetIntent = Intent(this, PrayerWidget::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        }
        val ids = AppWidgetManager.getInstance(this)
            .getAppWidgetIds(ComponentName(this, PrayerWidget::class.java))
        widgetIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        sendBroadcast(widgetIntent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        
        if (isMethodChannelSet) {
            return
        }

        try {
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
                
                when (call.method) {
                    "scheduleExactAthan" -> {
                        val timeInMillis = call.argument<Long>("timeInMillis") ?: 0L
                        val id = call.argument<Int>("id") ?: 0
                        val prayerName = call.argument<String>("prayerName") ?: "الصلاة"
                        val prayerKey = call.argument<String>("prayerKey") ?: "dhuhr"
                        val isSilent = call.argument<Boolean>("isSilent") ?: false
                        
                        if (timeInMillis > 0) {
                            scheduleExactAthan(timeInMillis, id, prayerName, prayerKey, isSilent)
                            result.success(true)
                        } else {
                            result.error("INVALID_TIME", "Time must be > 0", null)
                        }
                    }
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
                    "openComprehensivePermissions" -> {
                        openComprehensivePermissions()
                        result.success(true)
                    }
                    "getInitialPayload" -> {
                        val payload = intent?.getStringExtra("payload")
                        result.success(payload)
                    }
                    "cancelAthan" -> {
                        val id = call.argument<Int>("id") ?: 0
                        cancelAthan(id)
                        result.success(true)
                    }
                    "stopAthan" -> {
                        val serviceIntent = Intent(this, AthanService::class.java)
                        stopService(serviceIntent)
                        result.success(true)
                    }
                    "getPendingAthan" -> {
                        val prefs = getSharedPreferences(ATHAN_NATIVE_PREFS, Context.MODE_PRIVATE)
                        val prayerName = prefs.getString("pending_prayer_name", null)
                        val timestamp = prefs.getLong("pending_timestamp", 0)
                        val now = System.currentTimeMillis()
                        
                        if (prayerName != null && (now - timestamp) < 30000) { // خلال 30 ثانية فقط
                            result.success(prayerName)
                        } else {
                            // تنظيف البيانات القديمة
                            prefs.edit().remove("pending_prayer_name").remove("pending_timestamp").commit()
                            result.success(null)
                        }
                    }
                    "clearPendingAthan" -> {
                        val prefs = getSharedPreferences(ATHAN_NATIVE_PREFS, Context.MODE_PRIVATE)
                        prefs.edit().remove("pending_prayer_name").remove("pending_timestamp").commit()
                        result.success(true)
                    }
                    "getShouldExitFlag" -> {
                        val prefs = getSharedPreferences(ATHAN_NATIVE_PREFS, Context.MODE_PRIVATE)
                        val shouldExit = prefs.getBoolean("should_exit_to_background", false)
                        result.success(shouldExit)
                    }
                    "clearShouldExitFlag" -> {
                        val prefs = getSharedPreferences(ATHAN_NATIVE_PREFS, Context.MODE_PRIVATE)
                        prefs.edit().remove("should_exit_to_background").commit()
                        result.success(true)
                    }
                    "clearAllAlarms" -> {
                        clearAllAlarms()
                        forceClearSystemAlarms()
                        result.success(true)
                    }
                    "forceClearSystemAlarms" -> {
                        forceClearSystemAlarms()
                        result.success(true)
                    }
                    "pingNative" -> {
                        val response = "PONG from Native at ${System.currentTimeMillis()}"
                        result.success(response)
                    }
                    "finalizeAthanSession" -> {
                        if (wasLockedOnStart || !wasInAppOnStart) {
                            moveTaskToBack(true)
                            if (!isFinishing) {
                                finish()
                            }
                        } else {
                        }
                        result.success(true)
                    }
                    "performSmartExit" -> {
                        // Re-routing to finalizeAthanSession logic for consistency
                        if (wasLockedOnStart || !wasInAppOnStart) {
                            moveTaskToBack(true)
                            if (!isFinishing) finish()
                        }
                        result.success(true)
                    }
                    "forceExit" -> {
                        moveTaskToBack(true)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
            isMethodChannelSet = true
            
            // 🔥 تحقق من وجود نية أذان معلقة عند بدء التطبيق
            checkAndShowAthanOverlay()
            
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        
        // 🔥 Immediate Keyguard Dismissal on New Intent with 200ms delay
        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            Handler(Looper.getMainLooper()).postDelayed({
                keyguardManager.requestDismissKeyguard(this, null)
            }, 200)
        }
        
        wasLockedOnStart = keyguardManager.isKeyguardLocked
        wasInAppOnStart = true 
        
        checkAndShowAthanOverlay()
    }

    private fun checkAndShowAthanOverlay() {
        val currentIntent = intent
        
        // 🔥 Hard Guard: منع الـ Overlay في الوضع الصامت تماماً
        val isSilent = currentIntent?.getBooleanExtra("is_silent", false) ?: false
        if (isSilent) {
            intent.removeExtra("prayer_name")
            intent.removeExtra("ATHAN_PRAYER_NAME")
            intent.removeExtra("is_silent")
            intent.removeExtra("trigger_athan_overlay")
            return
        }

        val prayerName = currentIntent?.getStringExtra("prayer_name") ?: 
                         currentIntent?.getStringExtra("ATHAN_PRAYER_NAME") ?: 
                         null

        
        if (prayerName == null) return
        
        // 🔥 إضافة الـ Flag لضمان بقاء النسخة الحالية للأكتيفيتي
        intent.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)

        val messenger = flutterEngine?.dartExecutor?.binaryMessenger
        if (messenger != null) {
            // ✅ إرسال فوري للـ Flutter
            MethodChannel(messenger, CHANNEL).invokeMethod("showAthanOverlay", mapOf(
                "prayerName" to prayerName,
                "timestamp" to System.currentTimeMillis()
            ))
            // ✅ إعادة تعيين الـ Intent لمنع التكرار
            intent.removeExtra("prayer_name")
            intent.removeExtra("ATHAN_PRAYER_NAME")
        } else {
            // ✅ احتياطي: حفظ في SharedPreferences منفصل
            val prefs = getSharedPreferences(ATHAN_NATIVE_PREFS, Context.MODE_PRIVATE)
            prefs.edit()
                .putString("pending_prayer_name", prayerName)
                .putLong("pending_timestamp", System.currentTimeMillis())
                .commit()
        }
    }

    private fun scheduleExactAthan(timeInMillis: Long, id: Int, prayerName: String, prayerKey: String, isSilent: Boolean) {
        try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
            
            // ... check permission ...
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (!alarmManager.canScheduleExactAlarms()) {
                    return
                }
            }
            
            // Persist for Reboot
            val prefs = getSharedPreferences("athan_schedules", Context.MODE_PRIVATE)
            prefs.edit()
                .putLong(id.toString(), timeInMillis)
                .putString("${id}_data", "$prayerName|$prayerKey|$isSilent")
                .commit()

            // 1. Intent for BroadcastReceiver (Actual Alarm Action)
            val broadcastIntent = Intent(this, AthanReceiver::class.java).apply {
                putExtra("prayer_name", prayerName)
                putExtra("prayer_key", prayerKey)
                putExtra("alarm_id", id)
                putExtra("is_silent", isSilent)
            }
            val alarmPendingIntent = android.app.PendingIntent.getBroadcast(
                this, id, broadcastIntent, 
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )

            // 2. Intent for System UI (Opening app when clicking the clock icon)
            val activityIntent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            }
            val uiPendingIntent = android.app.PendingIntent.getActivity(
                this, id + 500, activityIntent, 
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )

            // Schedule with AlarmClockInfo (Shows the icon ⏰)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val clockInfo = android.app.AlarmManager.AlarmClockInfo(timeInMillis, uiPendingIntent)
                alarmManager.setAlarmClock(clockInfo, alarmPendingIntent)
            } else {
                alarmManager.setExact(android.app.AlarmManager.RTC_WAKEUP, timeInMillis, alarmPendingIntent)
            }
        } catch (e: Exception) {
        }
    }

    private fun cancelAthan(id: Int) {
        try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
            val intent = Intent(this, AthanReceiver::class.java)
            val pIntent = android.app.PendingIntent.getBroadcast(
                this, id, intent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pIntent)
            
            // Remove from prefs
            val prefs = getSharedPreferences("athan_schedules", Context.MODE_PRIVATE)
            prefs.edit().remove(id.toString()).remove("${id}_data").commit()
        } catch (e: Exception) {
        }
    }

    private fun clearAllAlarms() {
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
            prefs.edit().clear().commit()
        } catch (e: Exception) {
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
        }
    }

    private fun openBatteryOptimizationSettings() {
        try {
            val intent = Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
        } catch (e: Exception) {
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
        val intent = Intent("miui.intent.action.APP_PERMS_EDITOR")
        intent.setClassName("com.miui.securitycenter", "com.miui.permcenter.permissions.PermissionsEditorActivity")
        intent.putExtra("extra_pkgname", packageName)
        
        try {
            startActivity(intent)
        } catch (e: Exception) {
            try {
                // Fallback for different MIUI versions
                val intentFallback = Intent("interactive.intent.action.APP_PERMS_EDITOR")
                intentFallback.putExtra("extra_pkgname", packageName)
                startActivity(intentFallback)
            } catch (e2: Exception) {
                // Last resort: Genius Fallback
                openAppSettings()
            }
        }
    }

    private fun openComprehensivePermissions() {
        val manufacturer = Build.MANUFACTURER.lowercase()
        try {
            when {
                manufacturer.contains("xiaomi") -> {
                    try {
                        val intent = Intent()
                        intent.component = ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")
                        startActivity(intent)
                    } catch (e: Exception) {
                        openAppSettings()
                    }
                }
                manufacturer.contains("oppo") || manufacturer.contains("realme") -> {
                    try {
                        val intent = Intent()
                        intent.component = ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")
                        startActivity(intent)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent()
                            intent.component = ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity")
                            startActivity(intent)
                        } catch (e2: Exception) {
                            openAppSettings()
                        }
                    }
                }
                manufacturer.contains("huawei") -> {
                    try {
                        val intent = Intent()
                        intent.component = ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity")
                        startActivity(intent)
                    } catch (e: Exception) {
                        openAppSettings()
                    }
                }
                manufacturer.contains("samsung") -> {
                    try {
                        val intent = Intent(android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        startActivity(intent)
                    } catch (e: Exception) {
                        openAppSettings()
                    }
                }
                else -> {
                    openAppSettings()
                }
            }
        } catch (e: Exception) {
            openAppSettings()
        }
    }

    private fun openAppSettings() {
        try {
            val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            intent.data = Uri.fromParts("package", packageName, null)
            startActivity(intent)
        } catch (e: Exception) {
            // Ultimate fallback
        }
    }

    private fun forceClearSystemAlarms() {
        try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
            for (id in 100..120) {
                // 1. Cancel Broadcast Intent
                val bIntent = Intent(this, AthanReceiver::class.java)
                val pbIntent = android.app.PendingIntent.getBroadcast(
                    this, id, bIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                alarmManager.cancel(pbIntent)

                // 2. Cancel UI Activity Intent
                val aIntent = Intent(this, MainActivity::class.java)
                val paIntent = android.app.PendingIntent.getActivity(
                    this, id + 500, aIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                alarmManager.cancel(paIntent)
            }
        } catch (e: Exception) {
        }
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(completionReceiver)
        } catch (e: Exception) {}
        super.onDestroy()
    }
}
