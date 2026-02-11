// 1. Explicitly import the Delete task type to avoid "Unresolved reference" errors
import org.gradle.api.tasks.Delete 

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// 2. Define the build directory path safely
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    // 3. THIS IS THE CRITICAL FIX:
    // Only make other subprojects wait for :app. 
    // The :app module cannot wait for itself.
    if (project.name != "app") {
        project.evaluationDependsOn(":app")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}