import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.example.voskasr"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.example.voskasr"
        minSdk = 26
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        ndk {
            abiFilters += setOf("arm64-v8a", "armeabi-v7a")
        }

        val localProps = Properties().also { props ->
            rootProject.file("local.properties").takeIf { it.exists() }?.inputStream()?.use { props.load(it) }
        }
        buildConfigField("int", "BAIDU_APP_ID", localProps.getProperty("BAIDU_APP_ID", "0"))
        buildConfigField("String", "BAIDU_API_KEY", "\"${localProps.getProperty("BAIDU_API_KEY", "")}\"")
        buildConfigField("String", "BAIDU_SECRET_KEY", "\"${localProps.getProperty("BAIDU_SECRET_KEY", "")}\"")
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.11"
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2024.02.00")
    implementation(composeBom)

    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("androidx.activity:activity-compose:1.8.2")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.7.0")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.7.0")

    // Compose
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")
    implementation("androidx.compose.material3:material3")

    // Vosk Android ASR
    implementation("com.alphacephei:vosk-android:0.3.47")

    // Coroutines
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.0")

    // OkHttp WebSocket for Baidu realtime ASR
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
}
