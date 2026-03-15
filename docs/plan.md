# easy_setup Future Work Plan

## Android

### Medium Priority
- [ ] `buildConfigField` — Build-time constants (API URL, feature flags, etc.)
- [ ] App icon — Per-flavor launcher icons (`mipmap-*` resources)
- [ ] `minSdkVersion` / `targetSdkVersion` — Per-flavor SDK versions
- [ ] `multiDexEnabled` — Per-flavor multidex configuration
- [ ] ProGuard / R8 rules — Per-flavor obfuscation settings (`proguardFiles`)

### Low Priority
- [ ] `dimension` — Multi-dimension support (e.g., `environment` x `store`)
- [ ] `ndk.abiFilters` — Per-flavor ABI filters
- [ ] `sourceSets` — Per-flavor source directory mapping
- [ ] `testInstrumentationRunner` — Per-flavor test runner

## iOS

### Medium Priority
- [ ] Additional Info.plist variables — Custom URL schemes, deep links, etc.
  - `CFBundleURLSchemes`
- [ ] ATS (App Transport Security) settings — Per-flavor network security policies

## CI/CD

- [ ] Android CI/CD — Add `ci_cd.android` section, Fastlane Supply or Gradle signing
- [ ] Firebase App Distribution — Fastlane firebase_app_distribution plugin lane
- [ ] Direct App Store deployment — Add `deliver` lane (screenshots, metadata included)
- [ ] Certificate storage type expansion — S3, Google Cloud Storage, etc. (Match support)
- [ ] Custom lanes — User-defined Fastlane lanes (code push, Slack notifications, etc.)

## pub.dev Release Preparation

- [ ] Improve `pubspec.yaml` description
- [ ] Add `pubspec.yaml` repository URL
- [ ] Add `pubspec.yaml` homepage / documentation URL
- [ ] Add `pubspec.yaml` topics
