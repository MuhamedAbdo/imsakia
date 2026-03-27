package com.muhamed.imsakia

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import android.app.AlarmManager

class AthanTriggerReceiver : BroadcastReceiver() {
    companion object {
        const val TAG = "AthanTriggerReceiver"
        const val CHANNEL_ID = "adhan_athan"
        const val NOTIFICATION_ID = 5001
        const val ACTION_STOP_ATHAN = "com.muhamed.imsakia.STOP_ATHAN"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.d(TAG, "onReceive: Action = $action")

        if (action == Intent.ACTION_BOOT_COMPLETED || 
            action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            action == "android.intent.action.QUICKBOOT_POWERON") {
            handleBootReschedule(context)
            return
        }

        Log.d(TAG, "⏰ Exact Athan OS-Level Alarm Triggered!")

        // 1. Acquire WakeLock (Keep device awake for max 4 minutes while Athan plays)
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
            "Imsakia::AthanWakeLock"
        )
        wakeLock.acquire(4 * 60 * 1000L)

        // 2. Extract Data
        val prayerAr = intent.getStringExtra("prayer_ar") ?: "الصلاة"
        val prayerEn = intent.getStringExtra("prayer_en") ?: "Prayer"
        val assetPath = intent.getStringExtra("asset_path") ?: "assets/audio/athan_egypt_ab.mp3"
        val prayerImage = intent.getStringExtra("image") ?: ""
        // 3. Early detection fallback (Task 1 & 7 Refinement)
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val isPlaying = prefs.getBoolean("flutter.athan_is_playing", false)
            if (!isPlaying) {
                prefs.edit()
                    .putBoolean("flutter.athan_is_playing", true)
                    .putLong("flutter.athan_start_time", System.currentTimeMillis())
                    .apply()
                Log.d(TAG, "Early fallback start state saved")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to write early fallback state: ${e.message}")
        }

        val serviceIntent = Intent(context, NativeAthanService::class.java).apply {
            putExtras(intent)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }

        // 4. Try explicit startActivity failure fallback
        try {
            val fullScreenIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("open_athan_screen", true)
                putExtra("prayer_ar", prayerAr)
                putExtra("prayer_en", prayerEn)
                putExtra("image", prayerImage)
            }
            context.startActivity(fullScreenIntent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to startActivity from receiver fallback: ${e.message}")
        }
    }

    private fun handleBootReschedule(context: Context) {
        Log.d(TAG, "🔄 Handling Boot/Update: Rescheduling Alarms Natively...")
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val alarmsJson = prefs.getString("flutter.native_scheduled_alarms", "[]")
        
        try {
            val array = JSONArray(alarmsJson)
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val now = System.currentTimeMillis()
            var rescheduledCount = 0

            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                val id = obj.getInt("id")
                val timeMs = obj.getLong("timeMs")
                
                if (timeMs > now) {
                    val prayerAr = obj.getString("prayerAr")
                    val prayerEn = obj.getString("prayerEn")
                    val assetPath = obj.getString("assetPath")
                    val image = obj.getString("image")

                    val alarmIntent = Intent(context, AthanTriggerReceiver::class.java).apply {
                        putExtra("prayer_ar", prayerAr)
                        putExtra("prayer_en", prayerEn)
                        putExtra("asset_path", assetPath)
                        putExtra("image", image)
                        putExtra("notification_id", id)
                    }
                    val pendingIntent = PendingIntent.getBroadcast(
                        context,
                        id,
                        alarmIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
                        alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMs, pendingIntent)
                    } else {
                        alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMs, pendingIntent)
                    }
                    rescheduledCount++
                }
            }
            Log.d(TAG, "Success: Rescheduled $rescheduledCount future alarms.")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to reschedule alarms natively: ${e.message}")
        }
    }
}
