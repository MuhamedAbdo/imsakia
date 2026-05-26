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
    // Register afterEvaluate HERE (before evaluationDependsOn below triggers early
    // evaluation of other subprojects). This ensures the callback is already in place
    // when each subproject finishes its own build.gradle, so it can override compileSdk.
    afterEvaluate {
        extensions.findByType<com.android.build.gradle.BaseExtension>()?.compileSdkVersion(37)
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
