# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Just Audio, Audio Service, Audio Session
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.ryanheise.audio_session.** { *; }
-keep class androidx.media.** { *; }
-keep class androidx.media.filterfw.** { *; }
-keep class androidx.core.app.NotificationCompat** { *; }

# Sqflite
-keep class com.tekartik.sqflite.** { *; }

# AndroidX Core & FileProvider
-keep class androidx.core.content.FileProvider { *; }
