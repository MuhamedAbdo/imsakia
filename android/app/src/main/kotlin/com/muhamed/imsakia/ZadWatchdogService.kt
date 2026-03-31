package com.muhamed.imsakia

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * ZadWatchdogService
 *
 * خدمة Foreground Service خفيفة الوزن مع START_STICKY.
 * مهمتها الوحيدة: البقاء حيّة وضمان استمرارية FlutterBackgroundService.
 *
 * عند استدعاء onTaskRemoved() (Clear All)، تُجدوِل إعادة تشغيل عبر
 * ServiceRestartReceiver بعد 1.5 ثانية — الوقت الكافي للنظام لإنهاء
 * عملية الإيقاف قبل محاولة الإحياء.
 *
 * foregroundServiceType: specialUse — مُبرَّر بـ:
 * "Ensuring prayer time (Athan) scheduling reliability for Muslim users"
 */
class ZadWatchdogService : Service() {

    companion object {
        const val TAG = "ZadWatchdogService"
        const val CHANNEL_ID = "zad_watchdog"
        const val NOTIFICATION_ID = 9002
        var isRunning = false
    }

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        Log.i(TAG, "[WATCHDOG] Service created.")
        startAsForeground()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "[WATCHDOG] onStartCommand — startId=$startId")
        // تأكّد أن الخدمة لا تزال في Foreground حتى بعد إعادة التشغيل
        startAsForeground()
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    /**
     * يُستدعى عند الضغط على "Clear All" في مدير المهام.
     * نُجدوِل إعادة التشغيل عبر AlarmManager بعد 1.5 ثانية.
     */
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.w(TAG, "[WATCHDOG] onTaskRemoved() fired — scheduling resurrection in 1500ms...")

        // 1.5 ثانية: "المنطقة الرمادية" التي ينتهي فيها النظام من إيقاف العملية
        // قبل أن يحاول الـ Receiver إحياء الخدمة من جديد
        ServiceRestartReceiver.schedule(applicationContext, delayMs = 1500L)
    }

    override fun onDestroy() {
        isRunning = false
        Log.w(TAG, "[WATCHDOG] Service destroyed.")
        super.onDestroy()
    }

    // ─────────────────────────────────────────────────────────────────────────

    private fun startAsForeground() {
        val notification = buildNotification()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            Log.e(TAG, "[WATCHDOG] startForeground failed: ${e.message}")
            // لا نوقف الخدمة — نكتفي بالـ Log لتجنب كسر التجربة
        }
    }

    private fun buildNotification(): Notification {
        createNotificationChannel()

        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            NOTIFICATION_ID,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("زاد - مراقب الصلوات")
            .setContentText("يراقب أوقات الصلاة لإعلامك في الوقت المحدد")
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setOngoing(true)
            .setSilent(true)
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (manager.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "زاد - مراقب الصلوات",
                    NotificationManager.IMPORTANCE_MIN // صامت تماماً — لا يُزعج المستخدم
                ).apply {
                    description = "Ensuring prayer time (Athan) scheduling reliability for Muslim users"
                    setSound(null, null)
                    enableVibration(false)
                    setShowBadge(false)
                }
                manager.createNotificationChannel(channel)
            }
        }
    }
}
