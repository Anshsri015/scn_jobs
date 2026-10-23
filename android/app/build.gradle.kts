plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

val flutterVersionCode = localProperties.getProperty("flutter.versionCode") ?: "1"
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "0.1.0"

// Release signing (B2/B3) — loaded from key.properties, which is NOT
// committed to git (see the note below on .gitignore + backing this
// keystore up). If key.properties or the keystore file is missing —
// e.g. a fresh clone, or CI before secrets are wired — this falls
// back to the debug keystore with a printed warning instead of
// failing the build outright, so `flutter run` / debug builds still
// work. A *release* build made this way is NOT a real release build
// (Play Store will reject a debug-signed upload) — the warning is
// there so that's never silently shipped.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
} else {
    println(
        "WARNING: android/key.properties not found — release builds " +
                "will fall back to the debug keystore. See B2/B3 in the " +
                "Play Store readiness tracker before shipping."
    )
}

android {
    namespace = "in.scnjobs.worker"

    // Updated from 35 -> 36
    compileSdk = 36

    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8

        isCoreLibraryDesugaringEnabled = true
    }
    kotlinOptions {
        jvmTarget = "1.8"
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    defaultConfig {
        applicationId = "in.scnjobs.worker"

        minSdk = flutter.minSdkVersion
        targetSdk = 36

        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName

        multiDexEnabled = true
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }

        debug {
            isMinifyEnabled = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
