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

class AthanTriggerReceiver : BroadcastReceiver() {
    companion object {
        const val TAG = "AthanTriggerReceiver"
        const val CHANNEL_ID = "adhan_athan"
        const val NOTIFICATION_ID = 5001
        const val ACTION_STOP_ATHAN = "com.muhamed.imsakia.STOP_ATHAN"
    }

    override fun onReceive(context: Context, intent: Intent) {
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
}
