plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.muhamed.imsakia"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storePassword = keystoreProperties["storePassword"] as String?
            val stFile = keystoreProperties["storeFile"] as String?
            if (stFile != null) {
                // Look in android/app/ or android/ root
                val fileObj = file(stFile)
                storeFile = if (fileObj.exists()) {
                    fileObj
                } else {
                    val rootFileObj = rootProject.file(stFile)
                    if (rootFileObj.exists()) {
                        rootFileObj
                    } else {
                        null
                    }
                }
            }
            enableV1Signing = true
            enableV2Signing = true
        }
    }

    defaultConfig {
        applicationId = "com.muhamed.imsakia"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // ربط التوقيع الرسمي
            signingConfig = signingConfigs.getByName("release")
            
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.work:work-runtime-ktx:2.9.0")
    // Note: home_widget (and all other Flutter plugins) are registered automatically
    // by the flutter-plugin-loader Gradle plugin via .flutter-plugins-dependencies.
    // Do NOT add them manually with implementation(project(":home_widget")).
}

flutter {
    source = "../.."
}
