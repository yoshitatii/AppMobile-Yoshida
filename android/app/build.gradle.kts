plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.aplikasi_kasir"
    compileSdk = 35

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "com.example.aplikasi_kasir"
        
        // OPTIMASI LOW-END: minSdk 21 (Android 5.0) untuk dukungan perangkat lama
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
        
        // OPTIMASI: Multi-dex untuk perangkat low-end
        multiDexEnabled = true
        
        // OPTIMASI: Vector drawable support untuk mengurangi ukuran APK
        vectorDrawables.useSupportLibrary = true
    }

    buildTypes {
        release {
            // OPTIMASI: Aktifkan minify & shrink untuk mengurangi ukuran APK
            isMinifyEnabled = true
            isShrinkResources = true
            
            // OPTIMASI: ProGuard rules untuk code obfuscation dan size reduction
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            
            // Signing config (gunakan debug untuk testing)
            signingConfig = signingConfigs.getByName("debug")
        }
        
        debug {
            // Debug config tetap default untuk development
            applicationIdSuffix = ".debug"
        }
    }

    // OPTIMASI LOW-END: Split APK per ABI untuk ukuran lebih kecil
    splits {
        abi {
            isEnable = true
            reset()
            include("armeabi-v7a", "arm64-v8a", "x86_64")
            isUniversalApk = true
        }
    }

    // OPTIMASI: Packaging options untuk mengurangi ukuran
    packaging {
        resources {
            excludes += listOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/license.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/notice.txt",
                "META-INF/ASL2.0",
                "META-INF/*.kotlin_module"
            )
        }
    }

    // OPTIMASI: Lint options
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    // OPTIMASI: Build features yang tidak digunakan dinonaktifkan
    buildFeatures {
        viewBinding = false
        buildConfig = false
    }
}

flutter {
    source = "../.."
}

// OPTIMASI: Dependencies yang diperlukan
dependencies {
    // Multi-dex support untuk low-end devices
    implementation("androidx.multidex:multidex:2.0.1")
}