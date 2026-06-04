allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    
    if (project.name == "home_widget") {
        project.plugins.apply("org.jetbrains.kotlin.android")
    }
    
    // Register afterEvaluate HERE (before evaluationDependsOn below triggers early
    // evaluation of other subprojects). This ensures the callback is already in place
    // when each subproject finishes its own build.gradle, so it can override compileSdk.
    afterEvaluate {
        extensions.findByName("android")?.let { android ->
            try {
                val method = android.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                method.invoke(android, 37)
            } catch (e: Exception) {
                // Ignore
            }
        }

        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            val javaCompileName = name.replace("Kotlin", "JavaWithJavac")
            val javaCompile = project.tasks.withType<JavaCompile>().findByName(javaCompileName)
            val javaTarget = javaCompile?.targetCompatibility ?: "1.8"
            
            val jvmTargetStr = when (javaTarget) {
                "1.8", "VERSION_1_8", "8" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8
                "11", "VERSION_11" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
                "17", "VERSION_17" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
                "21", "VERSION_21" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21
                else -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8
            }
            
            compilerOptions {
                jvmTarget.set(jvmTargetStr)
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
