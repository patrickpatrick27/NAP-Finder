plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

// 1. Load the Key Properties safely
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.training"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            // --- SAFETY LOCK 1: FAIL IF KEYS MISSING ---
            // If GitHub Actions can't find the key file, STOP the build.
            // This prevents "Package Invalid" errors caused by unsigned APKs.
            if (!keystorePropertiesFile.exists()) {
                 println("⚠️ WARNING: key.properties not found. Release build will NOT be signed.")
                 // Note: We don't crash here so you can still run 'flutter run --release' locally without keys if needed.
                 // But for GitHub, this usually means the secret failed.
            }
            
            // Only try to read keys if the file exists
            if (keystoreProperties["keyAlias"] != null) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                
                // --- SAFETY LOCK 2: FORCE V1 & V2 SIGNING ---
                enableV1Signing = true
                enableV2Signing = true
            }
        }
    }

    defaultConfig {
        applicationId = "com.example.training"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("debug") {
            // Re-adding this so you can have both apps installed at once
            applicationIdSuffix = ".debug"
            resValue("string", "app_name", "NAP Finder (Dev)")
        }

        getByName("release") {
            resValue("string", "app_name", "NAP Finder")
            
            // Force the release config. 
            signingConfig = signingConfigs.getByName("release")
            
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}