# Keep Flutter classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }

# Keep Media Kit JNI/Native classes
-keep class com.alexmercerind.mediakit.** { *; }
-keep class com.alexmercerind.mediakit_video.** { *; }

# Keep Better Player / ExoPlayer native classes
-keep class com.jhomlala.better_player.** { *; }
-keep class com.google.android.exoplayer2.** { *; }

# Keep Wakelock Plus classes
-keep class dev.fluttercommunity.plus.wakelock.** { *; }

# Keep LibTorrent4J / Torrent engine classes
-keep class org.libtorrent4j.** { *; }
-keep class org.libtorrent4j.swig.** { *; }

# Keep Firebase classes
-keep class com.google.firebase.** { *; }

# Don't warn about missing dependencies in compiled libraries
-dontwarn org.libtorrent4j.**
-dontwarn com.google.android.exoplayer2.**
