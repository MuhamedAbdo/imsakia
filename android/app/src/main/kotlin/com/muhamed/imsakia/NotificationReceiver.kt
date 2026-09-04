package com.muhamed.imsakia

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class NotificationReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val title = intent.getStringExtra(EXTRA_TITLE) ?: "تنبيه"
        val body = intent.getStringExtra(EXTRA_BODY) ?: ""
        val payload = intent.getStringExtra(EXTRA_PAYLOAD) ?: ""
        val channelId = intent.getStringExtra(EXTRA_CHANNEL_ID) ?: CHANNEL_AZKAR
        val notificationId = intent.getIntExtra(EXTRA_ID, 0)

        Log.d(TAG, "onReceive: Fired notification ID=$notificationId, Channel=$channelId, Payload=$payload")

        // Intent لفتح التطبيق عند النقر
        val clickIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_PAYLOAD, payload)
        }

        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val clickPendingIntent = PendingIntent.getActivity(
            context,
            notificationId, // استخدام الـ ID لضمان تفرد הـ PendingIntent
            clickIntent,
            pendingIntentFlags
        )

        // بناء الإشعار
        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.mipmap.ic_launcher) // يجب التأكد من وجود الأيقونة، يفضل استخدام أيقونة شفافة (مثلاً ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(if (channelId == CHANNEL_AZKAR) NotificationCompat.PRIORITY_HIGH else NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setContentIntent(clickPendingIntent)

        // إضافة أسلوب النص المتعدد (BigText) إذا كان النص طويلاً
        if (body.length > 40) {
            builder.setStyle(NotificationCompat.BigTextStyle().bigText(body))
        }

        // عرض الإشعار
        try {
            val notificationManager = NotificationManagerCompat.from(context)
            notificationManager.notify(notificationId, builder.build())
            Log.d(TAG, "onReceive: Notification displayed successfully.")
        } catch (e: SecurityException) {
            Log.e(TAG, "onReceive: SecurityException - Permission POST_NOTIFICATIONS might be missing. ${e.message}")
        } catch (e: Exception) {
            Log.e(TAG, "onReceive: Failed to show notification. ${e.message}")
        }
    }

    companion object {
        private const val TAG = "NotificationReceiver"
        
        // ثوابت المفاتيح
        const val EXTRA_ID = "extra_id"
        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_BODY = "extra_body"
        const val EXTRA_PAYLOAD = "extra_payload"
        const val EXTRA_CHANNEL_ID = "extra_channel_id"

        // القنوات
        const val CHANNEL_AZKAR = "azkar_notifications_v1"
        const val CHANNEL_OCCASION = "occasion_notifications_v1"
        const val CHANNEL_FASTING = "fasting_notifications_v1"

        fun createNotificationChannels(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

                // قناة الأذكار (أولوية عالية، صوت واهتزاز)
                val azkarChannel = NotificationChannel(
                    CHANNEL_AZKAR,
                    "أذكار الصباح والمساء",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "تنبيهات أذكار الصباح والمساء"
                    enableVibration(true)
                }

                // قناة المناسبات (أولوية عادية)
                val occasionChannel = NotificationChannel(
                    CHANNEL_OCCASION,
                    "المناسبات الإسلامية",
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply {
                    description = "تنبيهات المناسبات الإسلامية وتاريخ اليوم"
                }

                // قناة الصيام (أولوية عادية)
                val fastingChannel = NotificationChannel(
                    CHANNEL_FASTING,
                    "تذكيرات الصيام",
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply {
                    description = "تذكيرات ببدء الصيام للمناسبات"
                }

                notificationManager.createNotificationChannels(listOf(azkarChannel, occasionChannel, fastingChannel))
                Log.d(TAG, "createNotificationChannels: Channels created.")
            }
        }

        fun scheduleNotification(
            context: Context,
            id: Int,
            timeInMillis: Long,
            title: String,
            body: String,
            payload: String,
            channelId: String
        ): Boolean {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            if (alarmManager == null) {
                Log.e(TAG, "scheduleNotification: AlarmManager is null")
                return false
            }

            // فحص الصلاحية في أندرويد 12+
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
                Log.w(TAG, "scheduleNotification: Exact alarm permission not granted")
                return false
            }

            val intent = Intent(context, NotificationReceiver::class.java).apply {
                putExtra(EXTRA_ID, id)
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_BODY, body)
                putExtra(EXTRA_PAYLOAD, payload)
                putExtra(EXTRA_CHANNEL_ID, channelId)
            }

            val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                id,
                intent,
                pendingIntentFlags
            )

            return try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeInMillis, pendingIntent)
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, timeInMillis, pendingIntent)
                } else {
                    alarmManager.set(AlarmManager.RTC_WAKEUP, timeInMillis, pendingIntent)
                }
                Log.d(TAG, "scheduleNotification: Scheduled ID=$id successfully for $timeInMillis.")
                true
            } catch (e: SecurityException) {
                Log.e(TAG, "scheduleNotification: SecurityException: ${e.message}")
                false
            }
        }

        fun cancelNotification(context: Context, id: Int) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            val intent = Intent(context, NotificationReceiver::class.java)
            
            val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                id,
                intent,
                pendingIntentFlags
            )

            alarmManager?.cancel(pendingIntent)
            pendingIntent.cancel()
            Log.d(TAG, "cancelNotification: Cancelled ID=$id")
        }

        fun cancelNotificationsInRange(context: Context, fromId: Int, toId: Int) {
            Log.d(TAG, "cancelNotificationsInRange: Background cancelling from $fromId to $toId")
            Thread {
                for (id in fromId..toId) {
                    cancelNotification(context, id)
                }
            }.start()
        }
    }
}
