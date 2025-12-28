allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Change the build output directory
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

// Configure subprojects to use separate build directories
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Ensure app module is evaluated first
subprojects {
    project.evaluationDependsOn(":app")
}

// Force all subprojects (plugins included) to compile with JVM 1.8
tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
    kotlinOptions {
        jvmTarget = "17"
    }
}

tasks.withType<JavaCompile>().configureEach {
    sourceCompatibility = "17"
    targetCompatibility = "17"

}

// Clean task
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
