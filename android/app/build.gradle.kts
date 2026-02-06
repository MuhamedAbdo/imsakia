plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.muhamed.imsakia"
    compileSdk = flutter.compileSdkVersion
    
    // تم تعطيل هذا السطر لمنع Gradle من محاولة تحميل نسخة NDK 28 الضخمة والمعلقة
    // ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    dependencies {
        coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.muhamed.imsakia"
        
        // استخدام النسخة المحددة من فلاتر
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Widget configuration - تثبيت النسخة لضمان عمل home_widget
        minSdk = flutter.minSdkVersion 
    }

    buildTypes {
        release {
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    
    // Fix for workmanager duplicate classes
    configurations.all {
        resolutionStrategy {
            eachDependency {
                if ((requested.group == "androidx.work") && (requested.name.startsWith("work-runtime"))) {
                    useVersion("2.8.1")
                }
            }
        }
    }
}

flutter {
    source = "../.."
}
