package com.muhamed.imsakia;

import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.widget.RemoteViews;
import android.app.PendingIntent;
import android.content.Intent;
import android.content.ComponentName;
import android.content.SharedPreferences;
import android.util.Log;

public class PrayerWidgetProvider extends AppWidgetProvider {
    
    private static final String TAG = "PrayerWidgetProvider";
    
    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        Log.d(TAG, "onUpdate called");
        for (int appWidgetId : appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId);
        }
    }

    @Override
    public void onEnabled(Context context) {
        Log.d(TAG, "onEnabled called");
        // Called when the first widget is created
    }

    @Override
    public void onDisabled(Context context) {
        Log.d(TAG, "onDisabled called");
        // Called when the last widget is removed
    }

    static void updateAppWidget(Context context, AppWidgetManager appWidgetManager, int appWidgetId) {
        Log.d(TAG, "updateAppWidget called for widget: " + appWidgetId);
        
        // Get widget data from SharedPreferences
        SharedPreferences prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE);
        
        // Create RemoteViews for the widget layout
        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.prayer_widget_layout);
        
        // Set prayer data with proper keys and logging
        String nextPrayer = prefs.getString("flutter.nextPrayer", "الظهر");
        String timeUntil = prefs.getString("flutter.timeUntil", "2 ساعة 30 دقيقة");
        String hijriDate = prefs.getString("flutter.hijriDate", "15 رمضان 1445 هـ");
        
        Log.d(TAG, "Reading data: nextPrayer=" + nextPrayer + ", timeUntil=" + timeUntil + ", hijriDate=" + hijriDate);
        
        // Check if data exists and is not empty
        if (timeUntil == null || timeUntil.isEmpty() || timeUntil.equals("---")) {
            timeUntil = "جاري التحديث...";
            Log.w(TAG, "timeUntil was empty, using default");
        }
        
        if (nextPrayer == null || nextPrayer.isEmpty()) {
            nextPrayer = "الظهر";
            Log.w(TAG, "nextPrayer was empty, using default");
        }
        
        if (hijriDate == null || hijriDate.isEmpty()) {
            hijriDate = "15 رمضان 1445 هـ";
            Log.w(TAG, "hijriDate was empty, using default");
        }
        
        views.setTextViewText(R.id.next_prayer_name, nextPrayer);
        views.setTextViewText(R.id.time_until_prayer, timeUntil);
        views.setTextViewText(R.id.hijri_date, hijriDate);
        
        // Set click intent to open the app
        Intent intent = new Intent(context, MainActivity.class);
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
        PendingIntent pendingIntent = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_IMMUTABLE);
        views.setOnClickPendingIntent(R.id.widget_layout, pendingIntent);
        
        // Update the widget
        appWidgetManager.updateAppWidget(appWidgetId, views);
        Log.d(TAG, "Widget updated successfully");
    }
    
    public static void updateAllWidgets(Context context) {
        Log.d(TAG, "updateAllWidgets called");
        AppWidgetManager appWidgetManager = AppWidgetManager.getInstance(context);
        ComponentName widgetProvider = new ComponentName(context, PrayerWidgetProvider.class);
        int[] appWidgetIds = appWidgetManager.getAppWidgetIds(widgetProvider);
        
        for (int appWidgetId : appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId);
        }
    }
}
