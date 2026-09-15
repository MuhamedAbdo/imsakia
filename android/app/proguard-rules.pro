# ════════════════════════════════════════════════════════════════════════════
# إمساكية (زاد) — قواعد ProGuard / R8
# المبدأ: كل كلاس يُستدعى من نظام Android عبر اسمه (Manifest, AlarmManager,
# AppWidgetProvider) يجب أن يكون محمياً من الـ Obfuscation.
# ════════════════════════════════════════════════════════════════════════════

# ════════════════════════════════════════════════════════════════════════════
# 1. حماية شاملة للحزمة الأساسية — إعادة التسمية ممنوعة، الحذف مسموح
# ════════════════════════════════════════════════════════════════════════════
-keepnames class com.muhamed.imsakia.** { *; }

# ════════════════════════════════════════════════════════════════════════════
# 2. MainApplication — يُستدعى من النظام عند بدء العملية
#    يجب أن يكون اسمه مطابقاً لما في AndroidManifest.xml
# ════════════════════════════════════════════════════════════════════════════
-keep class com.muhamed.imsakia.MainApplication { *; }

# ════════════════════════════════════════════════════════════════════════════
# 3. MainActivity — نقطة الدخول الرئيسية
# ════════════════════════════════════════════════════════════════════════════
-keep class com.muhamed.imsakia.MainActivity { *; }

# ════════════════════════════════════════════════════════════════════════════
# 4. BroadcastReceivers — يُستدعيها النظام بالاسم من AlarmManager و Manifest
#    أي تغيير في الاسم = لا يُطلق الأذان أبداً
# ════════════════════════════════════════════════════════════════════════════
-keep class com.muhamed.imsakia.AthanReceiver { *; }
-keep class com.muhamed.imsakia.BootReceiver { *; }
-keep class com.muhamed.imsakia.MidnightReceiver { *; }
-keep class com.muhamed.imsakia.NotificationReceiver { *; }
-keep class com.muhamed.imsakia.PhoneStateReceiver { *; }
-keep class com.muhamed.imsakia.TimeChangeReceiver { *; }
-keep class com.muhamed.imsakia.ExactAlarmPermissionReceiver { *; }

# ════════════════════════════════════════════════════════════════════════════
# 5. Services — تُستدعى من النظام (startForegroundService / startService)
# ════════════════════════════════════════════════════════════════════════════
-keep class com.muhamed.imsakia.AthanService { *; }
-keep class com.muhamed.imsakia.SwipeDismissGuardService { *; }

# ════════════════════════════════════════════════════════════════════════════
# 6. AppWidgetProviders — يُستدعيها النظام لتحديث الويدجت
#    أي تغيير في الاسم = الويدجت يختفي أو لا يُحدَّث
# ════════════════════════════════════════════════════════════════════════════
-keep class com.muhamed.imsakia.PrayerWidget { *; }
-keep class com.muhamed.imsakia.NextPrayerWidget { *; }
-keep class com.muhamed.imsakia.DailyScheduleWidget { *; }

# ════════════════════════════════════════════════════════════════════════════
# 7. AlarmRescheduler — Kotlin object (singleton) يُستدعى داخلياً
#    يجب الحفاظ على اسمه + الـ companion object الداخلي
# ════════════════════════════════════════════════════════════════════════════
-keep class com.muhamed.imsakia.AlarmRescheduler { *; }
-keep class com.muhamed.imsakia.AlarmRescheduler$* { *; }

# ════════════════════════════════════════════════════════════════════════════
# 8. حماية كلاسات الأساس (Android Framework) — صافي وشامل
# ════════════════════════════════════════════════════════════════════════════
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.app.Service
-keep public class * extends android.app.Application
-keep public class * extends android.appwidget.AppWidgetProvider
-keep public class * extends android.app.Activity

# ════════════════════════════════════════════════════════════════════════════
# 9. Kotlin Coroutines و Metadata — تعتمد على reflection داخلياً
# ════════════════════════════════════════════════════════════════════════════
-keep class kotlin.coroutines.** { *; }
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**
-keepclassmembers class ** {
    @kotlin.jvm.JvmStatic *;
    @kotlin.jvm.JvmField *;
}

# ════════════════════════════════════════════════════════════════════════════
# 10. حماية الـ String constants (مفاتيح SharedPreferences)
# ════════════════════════════════════════════════════════════════════════════
-keepclassmembers class com.muhamed.imsakia.** {
    static final java.lang.String *;
    private static final java.lang.String *;
}

# ════════════════════════════════════════════════════════════════════════════
# 11. Flutter Engine — لا تمس كلاسات Flutter الأساسية
# ════════════════════════════════════════════════════════════════════════════
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-dontwarn io.flutter.**

# ════════════════════════════════════════════════════════════════════════════
# 12. audio_service plugin — يعتمد على reflection لإيجاد الـ handlers
# ════════════════════════════════════════════════════════════════════════════
-keep class com.ryanheise.audioservice.** { *; }
-dontwarn com.ryanheise.audioservice.**

# ════════════════════════════════════════════════════════════════════════════
# 13. home_widget plugin — يقرأ/يكتب SharedPreferences بأسماء ثابتة
# ════════════════════════════════════════════════════════════════════════════
-keep class es.antonborri.home_widget.** { *; }
-dontwarn es.antonborri.home_widget.**

# ════════════════════════════════════════════════════════════════════════════
# 14. WorkManager — لجدولة المهام الخلفية
# ════════════════════════════════════════════════════════════════════════════
-keep class androidx.work.** { *; }
-keep class * extends androidx.work.Worker
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
-dontwarn androidx.work.**

# ════════════════════════════════════════════════════════════════════════════
# 15. قواعد عامة للأمان
# ════════════════════════════════════════════════════════════════════════════
-keepclassmembers enum * { *; }

-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

-dontwarn org.slf4j.**
-dontwarn javax.annotation.**
-dontwarn sun.misc.Unsafe
