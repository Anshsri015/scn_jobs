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
}

// [D6 patch] isar_flutter_libs (3.1.0+1, unmaintained) doesn't declare a
// namespace in its own build.gradle, which AGP 8+ requires for every
// Android library module. This must be registered BEFORE the
// `evaluationDependsOn(":app")` block below — that line forces :app
// (and, via Flutter's plugin loader, isar_flutter_libs) to evaluate
// immediately, and afterEvaluate can't be registered on a project
// that's already evaluated.
subprojects {
    afterEvaluate {
        if (plugins.hasPlugin("com.android.library")) {
            extensions.findByType<com.android.build.gradle.LibraryExtension>()?.let { android ->
                if (android.namespace == null) {
                    android.namespace = "dev.isar.${project.name}"
                }
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
