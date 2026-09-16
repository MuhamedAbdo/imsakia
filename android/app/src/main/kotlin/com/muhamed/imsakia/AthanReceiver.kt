package com.muhamed.imsakia

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class AthanReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ZadAthan"
        // الحد الأقصى لتأخر النظام المقبول: 30 دقيقة
        private const val MAX_ACCEPTABLE_DELAY_MS = 30 * 60 * 1000L

        // Ringtone fallback — يُحتفظ به static لإمكانية الإيقاف لاحقاً
        @Volatile private var emergencyRingtone: Ringtone? = null
    }

    override fun onReceive(context: Context, intent: Intent) {
        val pendingResult = goAsync()
        CoroutineScope(Dispatchers.Default).launch {
            try {
                handleAlarmAsync(context, intent)
            } catch (e: Exception) {
                android.util.Log.e(TAG, "Error handling athan alarm", e)
            } finally {
                pendingResult.finish()
            }
        }
    }

    private fun handleAlarmAsync(context: Context, intent: Intent) {
        val now = System.currentTimeMillis()
        val scheduledTime = intent.getLongExtra("scheduled_time", 0L)
        val delayMs = now - scheduledTime
        val rawPrayerName = intent.getStringExtra("prayer_name") ?: "الصلاة"
        val prayerName = rawPrayerName.replace("صلاة الشروق", "شروق الشمس")
        val alarmId = intent.getIntExtra("alarm_id", -1)
        android.util.Log.e("AZAN_TRACE", "RECEIVER FIRED\nprayerName=$prayerName\nid=$alarmId\nscheduledTime=$scheduledTime\nnow=$now\ndelayMs=$delayMs")
        android.util.Log.d(TAG, "Receiver Awake - ID: $alarmId")

        // ════════════════════════════════════════════════════════════════════
        // 🛡️ GUARD: إسقاط الأذان المتأخر (Drop Stale Alarms)
        // إذا أخّر النظام المنبه لأكثر من 30 دقيقة، نلغي الأذان ونعرض إشعاراً صامتاً.
        // ════════════════════════════════════════════════════════════════════
        if (scheduledTime > 0L && delayMs > MAX_ACCEPTABLE_DELAY_MS) {
            android.util.Log.w(
                TAG,
                "!!! STALE ALARM DROPPED: $delayMs ms late (${delayMs / 1000}s) for alarm ID=$alarmId. " +
                "Showing silent notification instead."
            )
            showSilentNotification(context, prayerName, alarmId)
            return
        }

        if (scheduledTime > 0L) {
            android.util.Log.d(TAG, "--- Timing OK: delay=${delayMs}ms for $alarmId ---")
        }

        val prayerKey = intent.getStringExtra("prayer_key") ?: "dhuhr"
        val isSilent = intent.getBooleanExtra("is_silent", false)

        // ════════════════════════════════════════════════════════════════════
        // 1. إزالة هذه الصلاة من athan_schedules فوراً بعد انطلاقها (BUG #3 FIX)
        // نحذف المنبه المُطلَق فوراً + أي منبه منتهٍ، بدلاً من انتظار 30 دقيقة.
        // بدون هذا، يقرأ الويدجت الـ timestamp المنتهي ويعرض عداداً سالباً.
        // ════════════════════════════════════════════════════════════════════
        cleanupExpiredAlarms(context, firedAlarmId = alarmId)

        // ════════════════════════════════════════════════════════════════════
        // 1b. BUG #8 FIX: تحديث HomeWidgetPreferences مباشرة من الـ Native
        // يقطع الاعتماد على Flutter لتحديث الـ timestamp في الخلفية.
        // الـ home_widget plugin يقرأ من "HomeWidgetPreferences" — نكتب إليه مباشرة.
        // ════════════════════════════════════════════════════════════════════
        updateHomeWidgetTimestampFromNative(context)

        // ════════════════════════════════════════════════════════════════════
        // 2. إلغاء إشعار الأذان القديم (السابق)
        // ════════════════════════════════════════════════════════════════════
        try {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            notificationManager.cancel(1001)
        } catch (e: Exception) {}

        // ════════════════════════════════════════════════════════════════════
        // 3. تحديث فوري للويدجت
        // ════════════════════════════════════════════════════════════════════
        try {
            val widgetIntent = Intent(context, PrayerWidget::class.java).apply {
                action = "com.muhamed.imsakia.UPDATE_COUNTDOWN"
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, PrayerWidget::class.java))
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                putExtra("triggered_prayer_name", prayerName)
            }
            context.sendBroadcast(widgetIntent)
            android.util.Log.i(TAG, "--- Immediate Direct Widget Sync Broadcast Sent ($prayerName) ---")

        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to broadcast widget update: ${e.message}")
        }

        // تحديث NextPrayerWidget أيضاً
        try {
            val nextWidgetIntent = Intent(context, NextPrayerWidget::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, NextPrayerWidget::class.java))
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(nextWidgetIntent)
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to broadcast NextPrayerWidget update: ${e.message}")
        }

        if (isSilent) {
            showSilentNotification(context, prayerName, alarmId)
            return
        }

        android.util.Log.i(TAG, "!!! Athan Alert Triggered: $prayerName !!!")

        // ════════════════════════════════════════════════════════════════════
        // Layer 2: إخبار AlarmWatchdogService بتحديث الإشعار الدائم
        // يحدث الآن (بعد cleanup) فتكون الصلاة التالية هي الصحيحة
        // ════════════════════════════════════════════════════════════════════
        try {
            val watchdogIntent = Intent(context, AlarmWatchdogService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(watchdogIntent)
            } else {
                context.startService(watchdogIntent)
            }
        } catch (e: Exception) {
            android.util.Log.w(TAG, "Could not ping watchdog to refresh notification: ${e.message}")
        }

        // --- Audible Branch: Start AthanService ---
        val serviceIntent = Intent(context, AthanService::class.java).apply {
            putExtra("prayer_name", prayerName)
            putExtra("prayer_key", prayerKey)
            putExtra("alarm_id", alarmId)
        }

        // ════════════════════════════════════════════════════════════════════
        // Layer 1: محاولة startForegroundService — مع Fallback للطوارئ
        //
        // سيناريو الفشل: MIUI جمّد العملية بعد Swipe Kill، فيُلقي النظام
        // ForegroundServiceStartNotAllowedException (API 31+) أو يصمت (API قديم)
        //
        // الـ Fallback: تشغيل الصوت مباشرة عبر Ringtone API بدون Service.
        // هذا ممكن من BroadcastReceiver ولا يتطلب Foreground permission.
        // ════════════════════════════════════════════════════════════════════
        var serviceStarted = false
        try {
            android.util.Log.e("AZAN_TRACE", "SERVICE REQUESTED")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            serviceStarted = true
        } catch (e: Exception) {
            android.util.Log.e(TAG, "!!! startForegroundService FAILED (likely post-Swipe freeze): ${e.message} — activating Ringtone fallback !!!")
        }

        if (!serviceStarted) {
            playEmergencyRingtone(context, prayerName, alarmId)
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // Layer 1 Fallback: Ringtone Emergency Playback
    //
    // يُستخدم عند فشل startForegroundService بعد Swipe Kill على MIUI.
    // Ringtone API مسموح به من BroadcastReceiver بدون Foreground permission.
    // يُشغّل صوت النظام الافتراضي للتنبيه (alarm) كـ fallback صوتي.
    // ════════════════════════════════════════════════════════════════════
    private fun playEmergencyRingtone(context: Context, prayerName: String, alarmId: Int) {
        try {
            android.util.Log.w(TAG, "!!! EMERGENCY RINGTONE FALLBACK for $prayerName !!!")

            // إيقاف أي رنين سابق
            emergencyRingtone?.stop()
            emergencyRingtone = null

            // استخدم صوت التنبيه الافتراضي للنظام
            val alarmUri: Uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

            val ringtone = RingtoneManager.getRingtone(context, alarmUri)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                ringtone.isLooping = false
            }

            // ضبط الـ AudioAttributes على USAGE_ALARM لأقصى صوت
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                ringtone.audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            }

            ringtone.play()
            emergencyRingtone = ringtone

            // إظهار إشعار طارئ بالإضافة للصوت
            showSilentNotification(context, prayerName, alarmId)

            android.util.Log.w(TAG, "!!! EMERGENCY RINGTONE playing for $prayerName !!!")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Emergency ringtone failed: ${e.message}")
            // Last resort: notification only
            showSilentNotification(context, prayerName, alarmId)
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // BUG #3 FIX: حذف المنبه المُطلَق فوراً + كل المنبهات المنتهية.
    // السلوك القديم كان يحتفظ بالمنبه لـ 30 دقيقة — نافذة للعد السالب.
    // ════════════════════════════════════════════════════════════════════
    private fun cleanupExpiredAlarms(context: Context, firedAlarmId: Int) {
        try {
            val schedulePrefs = context.getSharedPreferences("athan_schedules", Context.MODE_PRIVATE)
            val now = System.currentTimeMillis()
            val editor = schedulePrefs.edit()

            // 1. احذف المنبه المُطلَق فوراً (بصرف النظر عن وقته)
            if (firedAlarmId >= 0) {
                editor.remove(firedAlarmId.toString()).remove("${firedAlarmId}_data")
                android.util.Log.d(TAG, "✅ Fired alarm ID=$firedAlarmId removed immediately")
            }

            // 2. احذف أي منبه منتهٍ آخر
            for (entry in schedulePrefs.all.toMap()) {
                if (entry.key.endsWith("_data")) continue
                val id = entry.key.toIntOrNull() ?: continue
                if (id == firedAlarmId) continue // تم حذفه أعلاه
                val timestamp = (entry.value as? Number)?.toLong() ?: continue
                if (timestamp <= now) {
                    editor.remove(entry.key).remove("${entry.key}_data")
                    android.util.Log.d(TAG, "🗑️ Cleaned expired alarm ID=$id")
                }
            }
            editor.apply()
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to clean prefs: ${e.message}")
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // BUG #8 FIX: كتابة الـ timestamp للصلاة القادمة مباشرة في
    // HomeWidgetPreferences — نفس الـ SharedPreferences التي تكتب إليها
    // مكتبة home_widget في Flutter. هذا يقطع اعتماد الويدجت على Flutter
    // في الخلفية ويضمن عدم العد السالب حتى مع موت عملية Flutter.
    // ════════════════════════════════════════════════════════════════════
    private fun updateHomeWidgetTimestampFromNative(context: Context) {
        try {
            val schedules = context.getSharedPreferences("athan_schedules", Context.MODE_PRIVATE)
            val now = System.currentTimeMillis()

            var nextTimestamp = Long.MAX_VALUE
            var nextName = ""
            var nextKey = ""

            // البحث عن أقرب منبه مستقبلي في athan_schedules
            for (entry in schedules.all) {
                if (entry.key.endsWith("_data")) continue
                val id = entry.key.toIntOrNull() ?: continue
                val timestamp = (entry.value as? Number)?.toLong() ?: continue
                if (timestamp > now && timestamp < nextTimestamp) {
                    nextTimestamp = timestamp
                    val data = schedules.getString("${entry.key}_data", "") ?: ""
                    val parts = data.split("|")
                    nextName = parts.getOrElse(0) { "الصلاة" }
                    nextKey  = parts.getOrElse(1) { "dhuhr" }
                }
            }

            if (nextTimestamp == Long.MAX_VALUE) {
                android.util.Log.w(TAG, "updateHomeWidgetTimestamp: no future alarms found in schedules")
                return
            }

            // تنسيق وقت العرض (12h عربي) — مثل ما يفعل Flutter
            val sdf = SimpleDateFormat("h:mm a", Locale("ar"))
            val timeStr = sdf.format(Date(nextTimestamp))
            val displayStr = "$nextName $timeStr"

            // الكتابة في نفس مفاتيح home_widget plugin
            val widgetPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            widgetPrefs.edit()
                .putLong("flutter.next_prayer_timestamp", nextTimestamp)
                .putString("flutter.next_prayer_name", nextName)
                .putString("flutter.next_prayer_display", displayStr)
                .apply()

            android.util.Log.i(
                TAG,
                "✅ BUG#8 FIX: HomeWidgetPreferences updated natively → $nextName at $timeStr (ts=$nextTimestamp)"
            )
        } catch (e: Exception) {
            android.util.Log.e(TAG, "updateHomeWidgetTimestampFromNative failed: ${e.message}")
        }
    }

    private fun showSilentNotification(context: Context, prayerName: String, alarmId: Int) {
        val channelId = "zad_silent_v3"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val importance = android.app.NotificationManager.IMPORTANCE_HIGH
            val channel = android.app.NotificationChannel(channelId, "Athan Service (Silent)", importance).apply {
                setSound(null, null)
                setShowBadge(false)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 200, 100, 200)
            }
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            manager.createNotificationChannel(channel)
        }

        val isShorooq = prayerName.contains("شروق") || prayerName == "الشروق"
        val titleText = if (isShorooq) "شروق الشمس الآن" else "صلاة $prayerName الآن"
        val bodyText = if (isShorooq) "حان الآن وقت الشروق" else ""

        val builder = NotificationCompat.Builder(context, channelId)
            .setContentTitle(titleText)
            .setContentText(bodyText)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(NotificationCompat.CATEGORY_EVENT)
            .setAutoCancel(true)
            .setVibrate(longArrayOf(0, 200, 100, 200))

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        notificationManager.notify(1001, builder.build())
    }
}