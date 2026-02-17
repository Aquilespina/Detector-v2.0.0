plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// --- ¡SOLUCIÓN DEFINITIVA! Forzar versiones estables de AndroidX ---
configurations.all {
    resolutionStrategy {
        force("androidx.core:core:1.9.0")
        force("androidx.core:core-ktx:1.9.0")
        force("androidx.appcompat:appcompat:1.6.1")
        force("androidx.activity:activity:1.8.0")
    }
}

android {
    namespace = "com.example.detectorapp"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.detectorapp"
        minSdk = flutter.minSdkVersion
        targetSdk = 34 
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
