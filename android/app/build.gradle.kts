import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// 서명 열쇠 — 어제 TWA APK를 서명한 것과 같은 열쇠라야 그 위에 업데이트로 설치된다
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

android {
    namespace = "com.taejinsoft.woorimoim"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // 알림 패키지가 옛 안드로이드에서도 최신 날짜 기능을 쓰려고 이걸 요구한다 (없으면 빌드가 멈춤)
        isCoreLibraryDesugaringEnabled = true
    }

    /* 앱 두 가지를 하나의 코드로 만든다.
       · woori = 판매용 「우리 모임」
       · apsan = 앞산 배드민턴 동호회 전용 (회원들에게 보낼 것)
       기능은 같고 이름·아이콘·꾸러미 이름만 다르다 → 버그를 한 번만 고치면 양쪽에 다 적용된다. */
    /* ⚠️ AGP 9 부터 «갈래마다 다른 문자열(resValue)» 기능이 **꺼진 채로 온다.**
       안 켜면 빌드가 `Product Flavor woori contains custom resource values, but the feature is disabled`
       한 줄로 멈춘다 — 앱 이름(우리 모임 / 앞산 배드민턴)을 갈래로 나누는 자리가 바로 이것이다. */
    buildFeatures {
        resValues = true
    }

    flavorDimensions += "brand"
    /* ⚠️ **기본 갈래는 apsan 이다.**
       지금은 앞산 배드민턴 동호회로만 쓴다. 갈래를 안 적고 `flutter run`/`flutter build` 를 치면
       예전에는 판매용 「우리 모임」이 나와, 회원에게 엉뚱한 이름의 앱이 갈 뻔했다.
       판매용 갈래는 **지우지 않고 남겨 둔다** — 나중에 팔 때 `--flavor woori` 로 그대로 쓴다. */
    productFlavors {
        create("woori") {
            dimension = "brand"
            applicationId = "com.taejinsoft.woorimoim"
            resValue("string", "app_name", "우리 모임")
        }
        create("apsan") {
            dimension = "brand"
            isDefault = true            // 갈래를 안 적으면 이것 — 지금 쓰는 앱
            applicationId = "com.taejinsoft.apsanclub"
            resValue("string", "app_name", "앞산 배드민턴")
        }
    }

    defaultConfig {
        applicationId = "com.taejinsoft.apsanclub"
        minSdk = flutter.minSdkVersion                       // Firebase 인증이 요구하는 최소 (안드로이드 6.0)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keyProps.getProperty("storeFile") != null) {
                storeFile = rootProject.file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
