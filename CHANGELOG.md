## 0.0.1

### Flavor Command (default)

- **Android**: Auto-configure `build.gradle` / `build.gradle.kts` with `flavorDimensions` and `productFlavors` (brace-counting parser for nested Groovy/Kotlin DSL)
- **iOS (XcodeGen-based)**: Generate `project.yml` and run `xcodegen generate` to configure Xcode project
  - Generate per-flavor xcconfig files (Debug/Release/Profile)
  - Modify `Info.plist` for flavor-aware display names
  - Generate/modify `Podfile` with flavor build mode mappings and `ios_version` support
  - Auto-add `permission_handler` GCC macros to Podfile
- **App Icon**: Auto-generate all required icon sizes from a single 1024x1024 source image per flavor, with automatic cleanup of unused icons
- **Localization**: Flavor-specific localized app names via `InfoPlist.strings` and xcconfig variables
- **Firebase**: Copy `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) per flavor
- **Idempotency**: All modifiers/generators are idempotent — safe to run multiple times
- **Auto-cleanup**: Unused xcconfig files, schemes, and app icons are removed when flavors change

### CI/CD Command

- **Fastlane**: Generate `Gemfile`, `Matchfile`, `Appfile`, and `Fastfile` with `sync_certs`, `build`, and `deploy` lanes
- **GitHub Actions**: Generate `.github/workflows/ios-deploy.yml` workflow
- **Bundle ID Registration**: Auto-register Bundle IDs via App Store Connect API
- **App Store Metadata**: Generate metadata directory structure for App Store Connect

### General

- `--dry-run` / `-n` flag to preview changes without writing files
- `--project-root` / `-p` flag to specify Flutter project root
- Subcommand omission defaults to `flavor` for backward compatibility
- User-friendly error messages via `SetupException`
