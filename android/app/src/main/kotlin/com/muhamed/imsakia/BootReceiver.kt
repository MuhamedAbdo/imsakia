package com.muhamed.imsakia

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class BootReceiver : BroadcastReceiver() {
    private val PREFS_NAME = "athan_schedules"

    override fun onReceive(context: Context, intent: Intent) {
        System.err.println("!!! ATHAN DEBUG: BootReceiver onReceive [${intent.action}] !!!")
        val action = intent.action
        if (action == Intent.ACTION_BOOT_COMPLETED || 
            action == Intent.ACTION_TIME_CHANGED || 
            action == Intent.ACTION_TIMEZONE_CHANGED) {
            
            rescheduleAlarms(context)
        }
    }

    private fun rescheduleAlarms(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val allSchedules = prefs.all
        val currentTime = System.currentTimeMillis()

        for ((idStr, timeObj) in allSchedules) {
            val id = idStr.toIntOrNull() ?: continue
            val timeInMillis = timeObj as? Long ?: continue
            System.err.println("!!! ATHAN DEBUG: Rescheduling ID=$id at $timeInMillis !!!")

            // Only reschedule future alarms
            if (timeInMillis > currentTime) {
                val alarmIntent = Intent(context, AthanReceiver::class.java).apply {
                    putExtra("id", id)
                    putExtra("timeInMillis", timeInMillis)
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context, 
                    id, 
                    alarmIntent, 
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    val clockInfo = AlarmManager.AlarmClockInfo(timeInMillis, pendingIntent)
                    alarmManager.setAlarmClock(clockInfo, pendingIntent)
                } else {
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, timeInMillis, pendingIntent)
                }
            } else {
                // Cleanup past alarms from prefs
                prefs.edit().remove(idStr).apply()
            }
        }
    }
}
