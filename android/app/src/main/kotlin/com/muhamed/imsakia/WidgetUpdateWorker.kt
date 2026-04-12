package com.muhamed.imsakia

import android.content.Context
import android.content.Intent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import androidx.work.Worker
import androidx.work.WorkerParameters

class WidgetUpdateWorker(context: Context, workerParams: WorkerParameters) :
    Worker(context, workerParams) {

    override fun doWork(): Result {
        val widgetIntent = Intent(applicationContext, PrayerWidget::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        }
        val ids = AppWidgetManager.getInstance(applicationContext)
            .getAppWidgetIds(ComponentName(applicationContext, PrayerWidget::class.java))
        widgetIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        applicationContext.sendBroadcast(widgetIntent)
        
        return Result.success()
    }
}
