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
        // 2. Only create the "release" config IF the key properties were loaded
        if (keystoreProperties["keyAlias"] != null) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                
                // --- FIX: Enable V1 & V2 Signing ---
                // This ensures the APK is valid on Android 11+ devices
                enableV1Signing = true
                enableV2Signing = true
            }
        }
    }

    defaultConfig {
        applicationId = "com.example.training"
        
        // 3. SAFE VERSION LOADING
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("debug") {
            // --- DEBUG CONFIGURATION ---
            applicationIdSuffix = ".debug"
            resValue("string", "app_name", "NAP Finder (Dev)")
            
            // Explicitly use the debug signing config (good practice)
            signingConfig = signingConfigs.getByName("debug")
        }

        getByName("release") {
            // --- RELEASE CONFIGURATION ---
            resValue("string", "app_name", "NAP Finder")

            // 4. Safe Signing Config Assignment
            // If the keys exist, sign it. If not (e.g. testing locally without keys), it remains unsigned.
            if (signingConfigs.findByName("release") != null) {
                signingConfig = signingConfigs.getByName("release")
            }
            
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}