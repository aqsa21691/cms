# CMS Portal

A Flutter-based Course Management System with Teacher and Student portals.

## Build for Android (Optimized Size)

To generate the smallest possible APKs, run the following command in your terminal:

```powershell
flutter build apk --release --split-per-abi
```

This will generate three separate APKs in `build/app/outputs/flutter-apk/`:
- `app-armeabi-v7a-release.apk`
- `app-arm64-v8a-release.apk`
- `app-x86_64-release.apk`

**Tip**: Most modern Android phones use `arm64-v8a`. Installing just the specific APK for your phone will save significant space compared to the universal "fat" APK.

## Shrinking Config
The project is configured to use:
- `isMinifyEnabled = true` (Removes unused code)
- `isShrinkResources = true` (Removes unused images/assets)
- ProGuard Obfuscation
