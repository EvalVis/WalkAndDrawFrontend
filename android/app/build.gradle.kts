plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.programmersdiary.walk_and_draw"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.programmersdiary.walk_and_draw"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        resValue("string", "google_maps_api_key", System.getenv("Google_maps_API") ?: "")
        resValue("string", "gemini_api_key", System.getenv("GEMINI_API") ?: "")
        resValue("string", "mongodb_atlas_username", System.getenv("MONGODB_ATLAS_USERNAME") ?: "")
        resValue("string", "mongodb_atlas_password", System.getenv("MONGODB_ATLAS_PASSWORD") ?: "")
        manifestPlaceholders["auth0Domain"] = "dev-nfxagfo4wp0f5ee7.us.auth0.com"
        manifestPlaceholders["auth0Scheme"] = "com.programmersdiary.walkanddraw"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
