# --- Chess Arena release shrinking rules ---

# ML Kit Smart Reply bridge (native plugin classes must survive R8).
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Flutter engine / embedding.
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Stockfish FFI plugin.
-keep class com.example.stockfish.** { *; }
-dontwarn com.example.stockfish.**

# Keep native method signatures (FFI lookups).
-keepclasseswithmembernames class * {
    native <methods>;
}
