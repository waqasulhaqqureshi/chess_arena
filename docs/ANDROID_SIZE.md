# Android size strategy (target: as close to the ~5.7 MB floor as possible)

The Flutter engine alone costs ~5-6 MB per ABI. Everything else is budget.

## What we ship

- `google_mlkit_smart_reply` **standalone** (0.15.1) — Smart Reply model
  only. The monolithic `google_ml_kit` would add every vision/language
  binary (+100 MB) — never depend on it.
- `stockfish` — one native engine binary per ABI.

## build.gradle.kts levers (all applied)

1. **ABI filter** — `ndk { abiFilters += listOf("arm64-v8a", "armeabi-v7a") }`
   drops x86/x86_64 (emulator-only) halves of every native lib.
2. **Android App Bundle** — always release with
   `flutter build appbundle --release`; Play then serves a per-ABI,
   per-language split APK instead of the fat APK.
3. **R8 + resource shrinking** — `isMinifyEnabled`, `isShrinkResources`,
   `proguard-android-optimize.txt` + `proguard-rules.pro` (ML Kit and FFI
   keep rules included).
4. **Packaging excludes** — META-INF junk from ML Kit AARs removed.
5. **minSdk 21** — ML Kit floor; older minSdk would force legacy support
   libraries.

## Verify locally

```bash
flutter build appbundle --release
# then inspect:
bundletool build-apks --bundle=build/app/outputs/bundle/release/app-release.aab \
  --output=/tmp/apks --mode=universal  # worst case
# or use Android Studio's "Analyze APK" on the arm64 split for the real
# per-device download size.
```

## iOS note

ML Kit drops 32-bit: exclude `armv7` in Xcode (EXCLUDED_ARCHS) if iOS is
ever targeted; Android is unaffected.
