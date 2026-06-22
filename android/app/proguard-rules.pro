# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Dio / OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# Keep Hive models
-keep class ** extends com.google.protobuf.GeneratedMessageLite { *; }

# Camera
-keep class androidx.camera.** { *; }

# Prevent R8 from removing needed classes
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# For stack traces
-renamesourcefileattribute SourceFile

# Google ML Kit - keep all text recognizer options
-dontwarn com.google.mlkit.vision.text.**
-keep class com.google.mlkit.vision.text.** { *; }