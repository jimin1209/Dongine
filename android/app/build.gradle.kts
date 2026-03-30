plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.dongine.dongine"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.dongine.dongine"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // gradle.properties (또는 local.properties) 에서 값을 읽어 manifest에 주입
        manifestPlaceholders["NAVER_MAP_CLIENT_ID"] =
            project.findProperty("NAVER_MAP_CLIENT_ID") ?: "YOUR_NAVER_MAP_CLIENT_ID"
    }

    buildTypes {
        release {
            // Release 빌드 시 서명 설정이 필요합니다.
            // 1. android/key.properties 파일을 생성하고 keystore 경로/비밀번호를 입력하세요.
            // 2. 아래 signingConfig을 release용으로 교체하세요.
            // 참고: https://docs.flutter.dev/deployment/android#signing-the-app
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
