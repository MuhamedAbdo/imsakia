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
            // Sovereignty: Force flags if it's an Athan intent
            applyLockScreenFlags()
        }

        // Always apply flags as a safety measure but with higher priority on Athan
        applyLockScreenFlags()

        // ✅ 2. super.onCreate
        super.onCreate(savedInstanceState)
        
        // Schedule Midnight Rollover Alarm
        MidnightReceiver.scheduleMidnightAlarm(this)

        // Track state for Smart Exit
        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
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
        // تهيئة قنوات إشعارات الأذكار والمناسبات
        NotificationReceiver.createNotificationChannels(this)
        checkAndShowAthanOverlay()
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
                    "openAutoStartSettings", "openComprehensivePermissions" -> {
                        openAutoStartSettings(result)
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
                    "isEmergencyAthanMode" -> {
                        val isEmergency = intent?.getBooleanExtra("emergency_athan_mode", false) ?: false
                        result.success(isEmergency)
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
                    "openAutoStartSettings" -> {
                        openAutoStartSettings()
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
                    "isExactAlarmGranted" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            try {
                                val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
                                val canSchedule = alarmManager.canScheduleExactAlarms()
                                android.util.Log.d("ImsakiaNative", "canScheduleExactAlarms = $canSchedule")
                                result.success(canSchedule)
                            } catch (e: Exception) {
                                android.util.Log.w("ImsakiaNative", "Error checking exact alarm: ${e.message}")
                                result.success(false)
                            }
                        } else {
                            // Android 11 and below: always considered granted
                            result.success(true)
                        }
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
                    "isBatteryOptimizationGranted" -> {
                        val isIgnored = isBatteryOptimizationGranted()
                        android.util.Log.d("ImsakiaNative", "isBatteryOptimizationGranted = $isIgnored")
                        result.success(isIgnored)
                    }
                    // Fires AthanReceiver directly, bypassing AlarmManager
                    "testDirectBroadcast" -> {
                        try {
                            val intent = Intent(this, AthanReceiver::class.java).apply {
                                action = "com.muhamed.imsakia.ATHAN_ALARM_999"
                                putExtra("prayer_name", "اختبار مباشر")
                                putExtra("prayer_key", "dhuhr")
                                putExtra("alarm_id", 999)
                                putExtra("scheduled_time", System.currentTimeMillis())
                            }
                            val receiver = AthanReceiver()
                            receiver.onReceive(this, intent)
                            android.util.Log.d("ZadAthan", "testDirectBroadcast: onReceive called directly")
                            result.success("تم الاستدعاء المباشر")
                        } catch (e: Exception) {
                            android.util.Log.e("ZadAthan", "Crash in direct onReceive", e)
                            result.error("ERROR", e.message, null)
                        }
                    }

                    // ════════════════════════════════════════════════════════════════════
                    // 🔔 Native Text Notifications (الأذكار + المناسبات)
                    // ════════════════════════════════════════════════════════════════════

                    "scheduleNativeNotification" -> {
                        val id = call.argument<Int>("id") ?: run {
                            result.error("INVALID_ARGS", "id is required", null); return@setMethodCallHandler
                        }
                        val timeInMillis = call.argument<Long>("timeInMillis") ?: run {
                            result.error("INVALID_ARGS", "timeInMillis is required", null); return@setMethodCallHandler
                        }
                        val title = call.argument<String>("title") ?: run {
                            result.error("INVALID_ARGS", "title is required", null); return@setMethodCallHandler
                        }
                        val body = call.argument<String>("body") ?: ""
                        val payload = call.argument<String>("payload") ?: ""
                        val channelId = call.argument<String>("channelId") ?: NotificationReceiver.CHANNEL_AZKAR

                        // 🛡️ GUARD: فحص صلاحية المنبهات الدقيقة على Android 12+
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                            val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
                            if (!alarmManager.canScheduleExactAlarms()) {
                                android.util.Log.w(TAG, "scheduleNativeNotification: EXACT_ALARM permission denied for ID=$id")
                                result.error(
                                    "EXACT_ALARM_PERMISSION_DENIED",
                                    "صلاحية المنبهات الدقيقة غير مفعّلة. يرجى تفعيلها من الإعدادات.",
                                    null
                                )
                                return@setMethodCallHandler
                            }
                        }

                        if (timeInMillis <= System.currentTimeMillis()) {
                            result.error("INVALID_TIME", "timeInMillis must be in the future", null)
                            return@setMethodCallHandler
                        }

                        val success = NotificationReceiver.scheduleNotification(
                            context = this,
                            id = id,
                            timeInMillis = timeInMillis,
                            title = title,
                            body = body,
                            payload = payload,
                            channelId = channelId
                        )
                        result.success(success)
                    }

                    "cancelNativeNotification" -> {
                        val id = call.argument<Int>("id") ?: run {
                            result.error("INVALID_ARGS", "id is required", null); return@setMethodCallHandler
                        }
                        NotificationReceiver.cancelNotification(this, id)
                        result.success(true)
                    }

                    "cancelNativeNotificationsInRange" -> {
                        val fromId = call.argument<Int>("fromId") ?: run {
                            result.error("INVALID_ARGS", "fromId is required", null); return@setMethodCallHandler
                        }
                        val toId = call.argument<Int>("toId") ?: run {
                            result.error("INVALID_ARGS", "toId is required", null); return@setMethodCallHandler
                        }
                        NotificationReceiver.cancelNotificationsInRange(this, fromId, toId)
                        result.success(true)
                    }

                    "cancelSpecificNativeNotifications" -> {
                        val ids = call.argument<List<Int>>("ids") ?: run {
                            result.error("INVALID_ARGS", "ids is required", null); return@setMethodCallHandler
                        }
                        Thread {
                            for (id in ids) {
                                NotificationReceiver.cancelNotification(this, id)
                            }
                        }.start()
                        result.success(true)
                    }

                    "getInitialNotificationPayload" -> {
                        // يُستدعى عند بدء التطبيق (Cold Start) للتحقق من فتحه عبر إشعار
                        val payload = intent?.getStringExtra(NotificationReceiver.EXTRA_PAYLOAD)
                        android.util.Log.d(TAG, "getInitialNotificationPayload: $payload")
                        // مسح الـ extra لمنع إعادة القراءة عند onNewIntent
                        if (payload != null) {
                            intent?.removeExtra(NotificationReceiver.EXTRA_PAYLOAD)
                        }
                        result.success(payload)
                    }

                    "openExactAlarmSettings" -> {
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                            try {
                                val settingsIntent = android.content.Intent(
                                    android.provider.Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                                    android.net.Uri.parse("package:$packageName")
                                )
                                startActivity(settingsIntent)
                                android.util.Log.d(TAG, "openExactAlarmSettings: opened exact alarm settings")
                                result.success(true)
                            } catch (e: Exception) {
                                android.util.Log.w(TAG, "openExactAlarmSettings: fallback to app details: ${e.message}")
                                try {
                                    val fallbackIntent = android.content.Intent(
                                        android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                                    ).apply {
                                        data = android.net.Uri.parse("package:$packageName")
                                    }
                                    startActivity(fallbackIntent)
                                } catch (e2: Exception) {
                                    android.util.Log.e(TAG, "openExactAlarmSettings fallback failed: ${e2.message}")
                                }
                                result.success(false)
                            }
                        } else {
                            // أندرويد ≤ 11: لا حاجة للصلاحية
                            result.success(true)
                        }
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
        
        // 🔥 Immediate Lock Screen Breakthrough on New Intent
        applyLockScreenFlags()
        
        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        wasLockedOnStart = keyguardManager.isKeyguardLocked
        wasInAppOnStart = true 
        
        checkAndShowAthanOverlay()

        // 🔔 معالجة النقر على إشعار أذكار/مناسبات (Warm Start)
        val notificationPayload = intent.getStringExtra(NotificationReceiver.EXTRA_PAYLOAD)
        if (notificationPayload != null && notificationPayload.isNotEmpty() &&
            !notificationPayload.startsWith("athan")) {
            android.util.Log.d(TAG, "onNewIntent: notification payload received = $notificationPayload")
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, CHANNEL).invokeMethod("notificationPayloadReceived", notificationPayload)
            }
            // مسح الـ payload من الـ Intent لمنع إعادة القراءة
            intent.removeExtra(NotificationReceiver.EXTRA_PAYLOAD)
        }
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

        // ALWAYS save to prefs for guaranteed delivery on cold start
        val prefs = getSharedPreferences(ATHAN_NATIVE_PREFS, Context.MODE_PRIVATE)
        prefs.edit()
            .putString("pending_prayer_name", prayerName)
            .putLong("pending_timestamp", System.currentTimeMillis())
            .commit()

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
        }
    }

    private fun scheduleExactAthan(timeInMillis: Long, id: Int, prayerName: String, prayerKey: String, isSilent: Boolean) {
        android.util.Log.d("ImsakiaNative", "!!! NATIVE: Received schedule request for $prayerName (ID: $id) at $timeInMillis !!!")
        try {
            cancelAthan(id) // منع التداخل: مسح أي منبه قديم يحمل نفس المعرف
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager

            // Log permission status
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val canSchedule = alarmManager.canScheduleExactAlarms()
                android.util.Log.d("ImsakiaNative", "!!! NATIVE: canScheduleExactAlarms = $canSchedule !!!")
                if (!canSchedule) {
                    android.util.Log.e("ImsakiaNative", "!!! NATIVE: CANNOT SCHEDULE EXACT ALARM - PERMISSION MISSING !!!")
                    return
                }
            }

            // Persist for Reboot
            val prefs = getSharedPreferences("athan_schedules", Context.MODE_PRIVATE)
            prefs.edit()
                .putLong(id.toString(), timeInMillis)
                .putString("${id}_data", "$prayerName|$prayerKey|$isSilent")
                .commit()

            // Ensure Midnight Rollover is always scheduled when alarms are updated
            MidnightReceiver.scheduleMidnightAlarm(this)
            
            val now = System.currentTimeMillis()
            val delayMs = timeInMillis - now
            android.util.Log.e("AZAN_TRACE", "SCHEDULE REQUEST\nprayerName=$prayerName\nprayerKey=$prayerKey\nid=$id\ntimeInMillis=$timeInMillis\nnow=$now\ndelayMs=$delayMs\nisSilent=$isSilent")

            // ── 1. Intent للـ BroadcastReceiver (الحدث الفعلي) ──────────────────────
            // ✅ يحمل scheduled_time ليستخدمه AthanReceiver في Stale Guard
            val broadcastIntent = Intent(this, AthanReceiver::class.java).apply {
                action = "com.muhamed.imsakia.ATHAN_ALARM"
                putExtra("prayer_name", prayerName)
                putExtra("prayer_key", prayerKey)
                putExtra("alarm_id", id)
                putExtra("is_silent", isSilent)
                putExtra("scheduled_time", timeInMillis) // ← للـ Stale Guard
            }
            val alarmPendingIntent = android.app.PendingIntent.getBroadcast(
                this, id, broadcastIntent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )

            // ── 2. Intent لواجهة النظام (فتح التطبيق عند النقر على أيقونة الساعة) ──
            val activityIntent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            }
            val uiPendingIntent = android.app.PendingIntent.getActivity(
                this, id + 500, activityIntent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )

            // ── 3. جدولة المنبه الأصلي بـ setAlarmClock لكسر Doze/MIUI ───────────────
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val clockInfo = android.app.AlarmManager.AlarmClockInfo(timeInMillis, uiPendingIntent)
                alarmManager.setAlarmClock(clockInfo, alarmPendingIntent)
            } else {
                alarmManager.setExact(android.app.AlarmManager.RTC_WAKEUP, timeInMillis, alarmPendingIntent)
            }
            android.util.Log.e("AZAN_TRACE", "ALARM REGISTERED\nprayerName=$prayerName\nid=$id\ntriggerAt=$timeInMillis\nnow=${System.currentTimeMillis()}\ndelayMs=${timeInMillis - System.currentTimeMillis()}")
            android.util.Log.d("ImsakiaNative", "!!! NATIVE: Main Athan Alarm Scheduled for $prayerName (ID: $id) at $timeInMillis !!!")

            // ════════════════════════════════════════════════════════════════════
            // ── 4. جدولة المنبه الاستباقي (PreWarm) قبل 1 دقيقة ─────────────────
            // هدفه: إجبار MIUI على الاستيقاظ مبكراً، والانتظار بدقة حتى الثانية الصفر.
            // ════════════════════════════════════════════════════════════════════
            val preWarmTime = timeInMillis - (1 * 60 * 1000L) // قبل 1 دقيقة
            if (preWarmTime > System.currentTimeMillis()) {
                // ✅ يحمل scheduled_time (وقت الصلاة الفعلي) للانتظار الدقيق داخل PreWarmReceiver
                val preWarmIntent = Intent(this, PreWarmReceiver::class.java).apply {
                    action = "com.muhamed.imsakia.PREWARM_ALARM"
                    putExtra("prayer_name", prayerName)
                    putExtra("prayer_key", prayerKey)
                    putExtra("alarm_id", id)
                    putExtra("is_silent", isSilent)
                    putExtra("scheduled_time", timeInMillis) // ← وقت الصلاة الفعلي (لا PreWarm)
                }
                // requestCode = id + 10000 لتمييزه عن المنبه الأصلي
                val preWarmPI = android.app.PendingIntent.getBroadcast(
                    this,
                    id + 10000,
                    preWarmIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )

                val preWarmUiPendingIntent = android.app.PendingIntent.getActivity(
                    this, id + 1500, activityIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                // استخدام setAlarmClock للـ PreWarm أيضاً لكسر قيود MIUI
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    val preWarmClockInfo = android.app.AlarmManager.AlarmClockInfo(preWarmTime, preWarmUiPendingIntent)
                    alarmManager.setAlarmClock(preWarmClockInfo, preWarmPI)
                } else {
                    alarmManager.setExact(android.app.AlarmManager.RTC_WAKEUP, preWarmTime, preWarmPI)
                }
                android.util.Log.d(
                    "ImsakiaNative",
                    "!!! NATIVE: PreWarm Alarm Scheduled for $prayerName (ID: ${id + 10000}) at $preWarmTime (1min early) !!!"
                )
            } else {
                android.util.Log.d("ImsakiaNative", "--- PreWarm skipped: less than 1 min until prayer $prayerName ---")
            }

        } catch (e: Exception) {
            android.util.Log.e("ImsakiaNative", "scheduleExactAthan error: ${e.message}")
        }
    }

    private fun cancelAthan(id: Int) {
        try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager

            // إلغاء المنبه الأصلي
            val intent = Intent(this, AthanReceiver::class.java).apply {
                action = "com.muhamed.imsakia.ATHAN_ALARM"
            }
            val pIntent = android.app.PendingIntent.getBroadcast(
                this, id, intent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pIntent)

            // ✅ إلغاء المنبه الاستباقي (PreWarm) المرتبط بنفس الصلاة
            val preWarmIntent = Intent(this, PreWarmReceiver::class.java).apply {
                action = "com.muhamed.imsakia.PREWARM_ALARM"
            }
            val preWarmPIntent = android.app.PendingIntent.getBroadcast(
                this,
                id + 10000, // نفس الـ requestCode المستخدم في الجدولة
                preWarmIntent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(preWarmPIntent)

            // Remove from prefs
            val prefs = getSharedPreferences("athan_schedules", Context.MODE_PRIVATE)
            prefs.edit().remove(id.toString()).remove("${id}_data").commit()

            android.util.Log.d("ImsakiaNative", "--- cancelAthan: Cancelled main + PreWarm alarms for ID=$id ---")
        } catch (e: Exception) {
            android.util.Log.e("ImsakiaNative", "cancelAthan error for ID=$id: ${e.message}")
        }
    }

    private fun clearAllAlarms() {
        try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            for ((idStr, _) in prefs.all) {
                val id = idStr.toIntOrNull() ?: continue
                // 1. Cancel Main Alarm
                val intent = Intent(this, AthanReceiver::class.java).apply {
                    action = "com.muhamed.imsakia.ATHAN_ALARM"
                }
                val pIntent = android.app.PendingIntent.getBroadcast(
                    this, id, intent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                alarmManager.cancel(pIntent)
                
                // 2. Cancel PreWarm Alarm
                val preWarmIntent = Intent(this, PreWarmReceiver::class.java).apply {
                    action = "com.muhamed.imsakia.PREWARM_ALARM"
                }
                val preWarmPIntent = android.app.PendingIntent.getBroadcast(
                    this, id + 10000, preWarmIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                alarmManager.cancel(preWarmPIntent)
            }
            prefs.edit().clear().commit()
        } catch (e: Exception) {
            android.util.Log.e("ImsakiaNative", "clearAllAlarms error: ${e.message}")
        }
    }

    private fun openAutoStartSettings() {
        try {
            val intent = Intent()
            intent.component = android.content.ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
            android.util.Log.e("ImsakiaNative", "Failed to open Autostart: ${e.message}")
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
        try {
            val intent = Intent()
            intent.setAction("miui.intent.action.APP_PERMS_EDITOR")
            intent.setClassName("com.miui.securitycenter", "com.miui.permcenter.permissions.PermissionsEditorActivity")
            intent.putExtra("extra_pkgname", packageName)
            // ✅ هذا السطر هو مفتاح الحل في MIUI
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            startActivity(intent)
        } catch (e: Exception) {
            try {
                val intentFallback = Intent("interactive.intent.action.APP_PERMS_EDITOR")
                intentFallback.putExtra("extra_pkgname", packageName)
                intentFallback.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intentFallback)
            } catch (e2: Exception) {
                openAppSettings() // الملاذ الأخير
            }
        }
    }

    private fun openAutoStartSettings(result: MethodChannel.Result) {
        val manufacturer = android.os.Build.MANUFACTURER.lowercase()
        var moved = false

        try {
            when {
                manufacturer.contains("transsion") || manufacturer.contains("infinix") || manufacturer.contains("tecno") -> {
                    moved = tryStartIntent("com.transsion.phonemanager", "com.transsion.phonemanager.settings.container.ContainerActivity")
                }
                manufacturer.contains("huawei") -> {
                    // Huawei Path 1
                    moved = tryStartIntent("com.huawei.systemmanager", "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity")
                    if (!moved) {
                        // Huawei Path 2
                        moved = tryStartIntent("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity")
                    }
                    if (!moved) {
                        // Fallback Huawei
                        moved = tryStartIntent("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity")
                    }
                }
                manufacturer.contains("xiaomi") || manufacturer.contains("redmi") || manufacturer.contains("poco") -> {
                    // Try Action-based first as it's more reliable for some MIUI versions
                    try {
                        val intent = Intent("miui.intent.action.OP_AUTO_START")
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        moved = true
                    } catch (e: Exception) {
                        moved = tryStartIntent("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")
                    }
                    
                    if (!moved) {
                        moved = tryStartIntent("com.miui.securitycenter", "com.miui.permcenter.permissions.PermissionsEditorActivity")
                    }
                }
                manufacturer.contains("oppo") || manufacturer.contains("realme") -> {
                    moved = tryStartIntent("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")
                    if (!moved) {
                        moved = tryStartIntent("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity")
                    }
                }
                manufacturer.contains("samsung") -> {
                    try {
                        val intent = Intent(android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        moved = true
                    } catch (e: Exception) {}
                }
                manufacturer.contains("vivo") -> {
                    moved = tryStartIntent("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")
                }
            }

            if (!moved) {
                // Final generic fallback to app details
                try {
                    val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    intent.data = android.net.Uri.fromParts("package", packageName, null)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    moved = true
                } catch (e: Exception) {}
            }

            if (moved) {
                result.success("opened")
            } else {
                showFailSafeToast()
                result.success("unsupported")
            }
        } catch (e: Exception) {
            showFailSafeToast()
            result.success("unsupported")
        }
    }

    private fun tryStartIntent(packageName: String, className: String): Boolean {
        return try {
            val intent = Intent()
            intent.component = ComponentName(packageName, className)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun showFailSafeToast() {
        Handler(Looper.getMainLooper()).post {
            Toast.makeText(this, "يرجى تفعيل 'التشغيل التلقائي' من إعدادات الهاتف (مدير الهاتف)", Toast.LENGTH_LONG).show()
        }
    }

    private fun openComprehensivePermissions() {
        // Redirection to the new safe method if needed, but the channel now handles it
        // Keeping this for internal calls if any
        val fakeResult = object : MethodChannel.Result {
            override fun success(result: Any?) {}
            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
            override fun notImplemented() {}
        }
        openAutoStartSettings(fakeResult)
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
            for (id in 100..400) {
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

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        applyLockScreenFlags()
    }

    private fun applyLockScreenFlags() {
        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                setInheritShowWhenLocked(true)
            }

            // High Priority Dismiss
            keyguardManager.requestDismissKeyguard(this, null)
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
    }

    private fun isBatteryOptimizationGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
            powerManager.isIgnoringBatteryOptimizations(packageName)
        } else {
            true
        }
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(completionReceiver)
        } catch (e: Exception) {}
        super.onDestroy()
    }
}
