# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# build.gradle.kts buildTypes configuration.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# Vosk native model classes
-keep class com.alphacephei.vosk.** { *; }
-keep class org.vosk.** { *; }

# Keep ASR service classes
-keep public class com.example.voskasr.audio.VoskRecognizer { public *; }
-keep public class com.example.voskasr.audio.OpusDecoder { public *; }

# OkHttp / Okio (WebSocket client for Baidu realtime ASR)
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-keep class okhttp3.internal.ws.** { *; }

# Keep audio engine abstraction (Reflective access by EngineManager)
-keep class com.example.voskasr.audio.** { *; }

# Keep BuildConfig (Baidu credentials injected via BuildConfig.BAIDU_*)
-keep class com.example.voskasr.BuildConfig { *; }
