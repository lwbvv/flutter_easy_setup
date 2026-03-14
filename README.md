# easy_setup

Flutter 프로젝트의 flavor(빌드 변형) 환경과 CI/CD 파이프라인을 **한 번의 명령**으로 자동 설정하는 Dart CLI 도구입니다.

`easy_setup.yaml` 설정 파일 하나만 작성하면, Android와 iOS의 복잡한 빌드 설정과 CI/CD 파이프라인(Fastlane + GitHub Actions)을 모두 자동으로 구성합니다.

---

## 목차

- [주요 기능](#주요-기능)
- [설치](#설치)
- [사용법](#사용법)
- [설정 파일 (easy_setup.yaml)](#설정-파일-easy_setupyaml)
- [Localization](#localization)
- [앱 아이콘 자동 생성](#앱-아이콘-자동-생성)
- [CI/CD 설정 (ci-cd 커맨드)](#cicd-설정-ci-cd-커맨드)
- [자동으로 수정되는 파일](#자동으로-수정되는-파일)
- [프로젝트 구조](#프로젝트-구조)
- [모듈별 설명](#모듈별-설명)
- [설계 원칙](#설계-원칙)
- [문제 해결](#문제-해결)

---

## 주요 기능

| 플랫폼 | 자동 설정 항목 |
|---------|---------------|
| **Android** | `build.gradle`에 `flavorDimensions` + `productFlavors` 블록 추가 (Groovy/Kotlin DSL 모두 지원) |
| **iOS** | xcconfig 파일 생성 (Debug/Release/Profile per flavor) |
| **iOS** | `project.pbxproj`에 빌드 구성(XCBuildConfiguration) 추가 |
| **iOS** | flavor별 `.xcscheme` 파일 생성 |
| **iOS** | `Info.plist`의 앱 이름을 xcconfig 변수로 교체 |
| **iOS** | `Podfile`에 빌드 모드 매핑 추가 |
| **iOS** | 1024x1024 소스 이미지로 앱 아이콘 자동 생성 (flavor별 지원) |
| **iOS** | locale별 `InfoPlist.strings` 자동 생성 (앱 이름 + 권한 설명 localization) |
| **Firebase** | `google-services.json` / `GoogleService-Info.plist` flavor별 자동 복사 |
| **CI/CD** | Fastlane 파일 자동 생성 (Gemfile, Matchfile, Appfile, Fastfile + register lane) |
| **CI/CD** | GitHub Actions 워크플로우 자동 생성 (ios-deploy.yml) |
| **CI/CD** | Apple Developer Bundle ID 자동 등록 (API Key) |
| **CI/CD** | App Store Connect 앱 생성을 위한 `register` lane 자동 생성 (`fastlane produce`) |
| **CI/CD** | App Store Connect 메타데이터 관리 (프로모션 텍스트, 설명, 릴리스 노트 등) + `update_metadata` lane 자동 생성 |

---

## 설치

### 방법 1: dart pub global (권장)

```bash
dart pub global activate --source path .
```

이후 어디서든 `easy_setup` 명령으로 실행할 수 있습니다.

### 방법 2: 직접 실행

```bash
dart run bin/easy_setup.dart [옵션]
```

### 방법 3: 네이티브 바이너리로 컴파일

```bash
dart compile exe bin/easy_setup.dart -o easy_setup
./easy_setup [옵션]
```

---

## 사용법

### 기본 사용

Flutter 프로젝트 루트에 `easy_setup.yaml`을 만든 뒤 실행합니다:

```bash
# flavor 설정 (기본 커맨드)
easy_setup
easy_setup flavor

# CI/CD 파이프라인 설정 + Bundle ID 등록 + register lane 생성
easy_setup ci-cd
```

### CLI 옵션

```
Usage: easy_setup <command> [options]

Commands:
  flavor    Flutter flavor 환경 설정 (Android + iOS)  [default]
  ci-cd     CI/CD 파이프라인 설정 생성, Bundle ID 등록,
            register lane 생성 (Fastlane + GitHub Actions)

Options:
  -h, --help            도움말 표시
  -n, --dry-run         파일을 변경하지 않고 미리보기만 수행
  -p, --project-root    Flutter 프로젝트 루트 경로 지정 (기본: 자동 탐지)
```

### 예시

```bash
# flavor dry-run으로 미리보기
easy_setup --dry-run

# CI/CD 설정 미리보기
easy_setup ci-cd --dry-run

# 특정 프로젝트 경로 지정
easy_setup -p /path/to/flutter/project
easy_setup ci-cd -p /path/to/flutter/project
```

### 실행 후 다음 단계

**flavor 커맨드 후:**

```bash
flutter pub get
cd ios && pod install
flutter run --flavor dev -t lib/main.dart
```

**ci-cd 커맨드 후:**

```bash
cd ci_cd/ios/fastlane && bundle install
bundle exec fastlane match init  # 최초 1회
bundle exec fastlane register    # App Store Connect 앱 생성 (2FA 필요)
bundle exec fastlane update_metadata  # 메타데이터 업로드 (metadata 설정 시)
# GitHub Secrets 설정 (아래 CI/CD 섹션 참조)
```

---

## 설정 파일 (easy_setup.yaml)

Flutter 프로젝트 루트에 `easy_setup.yaml` 파일을 생성합니다:

```yaml
easy_setup:
  flavors:
    dev:
      bundle_id: com.example.app.dev
      name: MyApp Dev
      app_icon: assets/icons/dev_icon.png       # 선택사항: 1024x1024 소스 이미지
      localized:                                 # 선택사항: flavor별 localization
        ko:
          app_name: 마이앱 Dev
        ja:
          app_name: マイアプリ Dev
    staging:
      bundle_id: com.example.app.staging
      name: MyApp Staging
    prod:
      bundle_id: com.example.app
      name: MyApp
      app_icon: assets/icons/prod_icon.png
      localized:
        ko:
          app_name: 마이앱

  localizations: [ko, en, zh-HK]                          # 선택사항: Xcode knownRegions 설정
  permission:                                              # 선택사항: 기본 iOS 권한 설명 (Base.lproj)
    NSCameraUsageDescription: "Camera access is required"
    NSPhotoLibraryUsageDescription: "Photo library access is required"
  localized_permission:                                    # 선택사항: locale별 iOS 권한 설명
    ko:
      NSCameraUsageDescription: "카메라 접근이 필요합니다"
    en:
      NSCameraUsageDescription: "Camera access is required"
      NSPhotoLibraryUsageDescription: "Photo library access is required"
```

### Flavor 필드 설명

| 필드 | 필수 | 설명 | 예시 |
|------|------|------|------|
| `bundle_id` | O | 앱의 고유 식별자 (Android applicationId / iOS PRODUCT_BUNDLE_IDENTIFIER) | `com.example.app.dev` |
| `name` | O | 사용자에게 표시되는 앱 이름 (Android app_name / iOS APP_DISPLAY_NAME) | `MyApp Dev` |
| `version_code` | | 앱 버전 코드 (정수) | `42` |
| `version_name` | | 앱 버전 이름 (문자열) | `1.0.0-dev` |
| `app_icon` | | 1024x1024 소스 이미지 경로 (프로젝트 루트 기준 상대경로) | `assets/icons/dev_icon.png` |
| `localized` | | flavor별 locale 설정 (아래 [Localization](#localization) 참조) | |
| `signing` | | Android signing 설정 (`keystore`, `alias`) | |
| `firebase` | | Firebase 설정 파일 경로 (`android`, `ios`) | |
| `ios` | | iOS 전용 설정 (`team_id`, `provisioning_profile`, `code_sign_identity`, `entitlements`) | |

---

## Localization

Localization 설정은 세 부분으로 나뉩니다:

### 1. `localizations` — Xcode knownRegions

`localizations` 목록을 설정하면 Xcode의 `knownRegions`에 해당 언어가 등록됩니다:

```yaml
easy_setup:
  localizations: [ko, en, zh-HK]
```

### 2. Flavor별 `localized` — 앱 이름

각 flavor 아래에 `localized` 섹션을 추가하여 locale별 앱 이름을 설정합니다:

```yaml
easy_setup:
  flavors:
    dev:
      bundle_id: com.example.app.dev
      name: MyApp Dev
      app_icon: assets/icons/dev_icon.png
      localized:
        ko:
          app_name: 마이앱 Dev                      # locale별 앱 이름
        ja:
          app_name: マイアプリ Dev
```

| 필드 | 설명 |
|------|------|
| `app_name` | locale별 앱 표시 이름. `InfoPlist.strings`의 `CFBundleDisplayName`으로 생성됨 |

### 3. `permission` / `localized_permission` — iOS 권한 설명

`easy_setup` 레벨에 권한 설명을 설정합니다. `permission`은 기본값(`Base.lproj`), `localized_permission`은 locale별 값입니다:

```yaml
easy_setup:
  permission:
    NSCameraUsageDescription: "Camera access is required"
    NSPhotoLibraryUsageDescription: "Photo library access is required"
  localized_permission:
    ko:
      NSCameraUsageDescription: "카메라 접근이 필요합니다"
      NSPhotoLibraryUsageDescription: "사진 접근이 필요합니다"
    en:
      NSCameraUsageDescription: "Camera access is required"
      NSPhotoLibraryUsageDescription: "Photo library access is required"
```

| 필드 | 설명 |
|------|------|
| `permission` | 기본 iOS 권한 설명. `Base.lproj/InfoPlist.strings`에 생성됨 |
| `localized_permission` | locale별 iOS 권한 설명. 각 `{locale}.lproj/InfoPlist.strings`에 생성됨 |

### ⚠️ 중요: Flavor별 Localized App Name의 제약

iOS의 구조상 제약으로 **모든 flavor가 같은 locale에서 동일한 app_name을 가져야 합니다**.

❌ **잘못된 예시** (같은 locale에 다른 app_name):
```yaml
flavors:
  dev:
    name: MyApp Dev
    localized:
      ko: app_name: "마이앱 Dev"
  prod:
    name: MyApp
    localized:
      ko: app_name: "마이앱"  # ← 같은 locale에 다른 값 = 충돌!
```

이 경우 경고 메시지가 표시되고, **첫 번째 flavor의 값만 사용**됩니다.

✅ **올바른 예시**:
```yaml
flavors:
  dev:
    name: MyApp Dev
    localized:
      ko: app_name: "마이앱 Dev"
      ja: app_name: "マイアプリ Dev"
  prod:
    name: MyApp
    localized:
      ko: app_name: "마이앱 Dev"        # ← dev와 동일
      ja: app_name: "マイアプリ Dev"    # ← dev와 동일
```

또는 **한 flavor만 localized를 정의**:
```yaml
flavors:
  dev:
    name: MyApp Dev
    localized:
      ko: app_name: "마이앱 Dev"
  prod:
    name: MyApp
    # localized 정의 안 함 → ko.lproj에서 dev의 값 사용
```

### 생성되는 파일

flavor별 `app_name`과 `localized_permission`이 병합되어 locale별 `InfoPlist.strings` 파일이 생성됩니다:

```
ios/Runner/ko.lproj/InfoPlist.strings
ios/Runner/ja.lproj/InfoPlist.strings
ios/Runner/en.lproj/InfoPlist.strings
```

파일 내용 예시 (`ko.lproj/InfoPlist.strings`):

```
"CFBundleDisplayName" = "마이앱 Dev";
"NSCameraUsageDescription" = "카메라 접근이 필요합니다";
"NSPhotoLibraryUsageDescription" = "사진 접근이 필요합니다";
```

---

## 앱 아이콘 자동 생성

`app_icon` 필드에 1024x1024 PNG 소스 이미지 경로를 지정하면, `easy_setup flavor` 실행 시 iOS 앱 아이콘을 자동으로 생성합니다.

### 동작 방식

1. 소스 이미지(1024x1024)를 로드하고 크기를 검증합니다.
2. 15개 고유 사이즈로 리사이즈하여 PNG 파일을 생성합니다.
3. `Contents.json` (19개 엔트리)을 생성합니다.
4. xcconfig에 `ASSETCATALOG_COMPILER_APPICON_NAME=AppIcon-{flavor}`를 자동 설정합니다.

### 생성 경로

```
ios/Runner/Assets.xcassets/AppIcon-{flavor}.appiconset/
  Contents.json
  Icon-App-20x20@1x.png      (20px)
  Icon-App-20x20@2x.png      (40px)
  Icon-App-20x20@3x.png      (60px)
  Icon-App-29x29@1x.png      (29px)
  Icon-App-29x29@2x.png      (58px)
  Icon-App-29x29@3x.png      (87px)
  Icon-App-40x40@1x.png      (40px)
  Icon-App-40x40@2x.png      (80px)
  Icon-App-40x40@3x.png      (120px)
  Icon-App-60x60@2x.png      (120px)
  Icon-App-60x60@3x.png      (180px)
  Icon-App-76x76@1x.png      (76px)
  Icon-App-76x76@2x.png      (152px)
  Icon-App-83.5x83.5@2x.png  (167px)
  Icon-App-1024x1024@1x.png  (1024px)
```

---

## CI/CD 설정 (ci-cd 커맨드)

`easy_setup ci-cd` 명령으로 iOS CI/CD에 필요한 모든 설정을 자동으로 수행합니다:

1. Fastlane 파일 생성 (Gemfile, Matchfile, Appfile, Fastfile)
2. API Key로 Bundle ID 자동 등록 (.p8 파일이 있을 경우)
3. Fastfile에 `register` lane 추가 (App Store Connect 앱 생성용)
4. 메타데이터 파일 생성 + `update_metadata` lane 추가 (설정 시)
5. GitHub Actions 워크플로우 생성

### YAML 설정 (`ci_cd` 섹션)

```yaml
easy_setup:
  flavors:
    dev:
      bundle_id: com.example.app.dev
      name: MyApp Dev
    prod:
      bundle_id: com.example.app
      name: MyApp

  ci_cd:
    # CI/CD 대상 flavor (생략 시 위의 flavors 전체 사용)
    flavors:
      prod:
        bundle_id: com.example.app

    ios:
      storage: https://github.com/user/app-certification.git
      team_id: XXXXXXXXXX
      itc_team_id: YYYYYYYYYY
      # 선택사항: Apple ID (register lane에서 사용)
      apple_id: user@example.com
      api_key:
        id: KEY_ID
        issuer_id: ISSUER_ID
        key_path: ci_cd/ios/fastlane/AuthKey.p8
        duration: 1200        # optional (기본 1200)
        in_house: false        # optional (기본 false)

    # 선택사항: App Store Connect 메타데이터
    metadata:
      ko:
        promotional_text: "한국어 프로모션 텍스트"
        description: "앱 설명입니다"
        release_notes: "버그 수정 및 개선"
        keywords: "키워드1, 키워드2"
        name: "마이앱"
        subtitle: "서브타이틀"
        privacy_url: "https://example.com/privacy"
        support_url: "https://example.com/support"
        marketing_url: "https://example.com"
      en-US:
        promotional_text: "English promotional text"
        description: "App description"
```

### 생성되는 파일

| 파일 | 설명 |
|------|------|
| `Gemfile` (프로젝트 루트) | Fastlane Ruby 의존성 |
| `ci_cd/ios/fastlane/Gemfile` | Fastlane Ruby 의존성 |
| `ci_cd/ios/fastlane/Matchfile` | Match 인증서/프로파일 설정 |
| `ci_cd/ios/fastlane/Appfile` | 앱 식별 정보 (team_id, itc_team_id) |
| `ci_cd/ios/fastlane/Fastfile` | 빌드 + TestFlight 배포 + register + update_metadata 레인 |
| `ci_cd/ios/fastlane/metadata/{locale}/*.txt` | App Store Connect 메타데이터 (metadata 설정 시) |
| `.github/workflows/ios-deploy.yml` | GitHub Actions 워크플로우 |

### Bundle ID 자동 등록

- API Key 파일(.p8)이 `key_path`에 존재하면 App Store Connect API를 통해 Bundle ID를 자동으로 등록합니다.
- 이미 존재하는 Bundle ID는 건너뜁니다.
- .p8 파일이 없으면 Bundle ID 등록을 건너뛰고 나머지 설정만 진행합니다.

### App Store Connect 앱 생성 (register lane)

Fastfile에 자동 생성되는 `register` lane을 통해 App Store Connect에 앱을 생성할 수 있습니다.
앱 생성은 Apple ID 인증(2FA)이 필요하므로 사용자가 직접 실행해야 합니다:

```bash
cd ci_cd/ios/fastlane && bundle exec fastlane register
```

### App Store Connect 메타데이터 관리

`ci_cd.metadata` 섹션이 설정되어 있으면, locale별 메타데이터 파일을 자동 생성하고 Fastfile에 `update_metadata` lane을 추가합니다.

**생성되는 디렉터리 구조:**

```
ci_cd/ios/fastlane/metadata/
  ko/
    promotional_text.txt
    description.txt
    release_notes.txt
    keywords.txt
    name.txt
    subtitle.txt
    privacy_url.txt
    support_url.txt
    marketing_url.txt
  en-US/
    promotional_text.txt
    description.txt
```

**지원되는 메타데이터 필드:**

| 필드 | 파일명 | 설명 |
|------|--------|------|
| `promotional_text` | `promotional_text.txt` | 프로모션 텍스트 |
| `description` | `description.txt` | 앱 설명 |
| `release_notes` | `release_notes.txt` | 릴리스 노트 (새로운 기능) |
| `keywords` | `keywords.txt` | 검색 키워드 (쉼표 구분) |
| `name` | `name.txt` | 앱 이름 |
| `subtitle` | `subtitle.txt` | 앱 부제목 |
| `privacy_url` | `privacy_url.txt` | 개인정보 처리방침 URL |
| `support_url` | `support_url.txt` | 지원 URL |
| `marketing_url` | `marketing_url.txt` | 마케팅 URL |

모든 필드는 선택사항이며, 설정된 필드만 파일로 생성됩니다.

**메타데이터 업로드:**

Fastlane `deliver`를 사용하여 App Store Connect에 메타데이터를 업로드합니다:

```bash
cd ci_cd/ios/fastlane && bundle exec fastlane update_metadata
```

### 대상 flavor 결정

- `ci_cd.flavors`가 정의되어 있으면 해당 flavor만 대상으로 합니다.
- `ci_cd.flavors`가 없으면 `easy_setup.flavors` 전체를 대상으로 합니다.

### 필요한 GitHub Secrets

| Secret 이름 | 설명 |
|-------------|------|
| `MATCH_PASSWORD` | Match 인증서 저장소 암호화 비밀번호 |
| `MATCH_GIT_BASIC_AUTHORIZATION` | GitHub 인증서 repo 접근 토큰 (`echo -n "username:PAT" \| base64`) |
| `APP_STORE_CONNECT_API_KEY_BASE64` | .p8 키 파일 내용 (`base64 -i AuthKey.p8`) |

---

## 자동으로 수정되는 파일

### Android

**`android/app/build.gradle(.kts)`**

`buildTypes` 블록 뒤에 다음이 추가됩니다:

```groovy
// Groovy DSL
flavorDimensions "env"
productFlavors {
    dev {
        dimension "env"
        applicationId "com.example.app.dev"
        resValue "string", "app_name", "MyApp Dev"
    }
    prod {
        dimension "env"
        applicationId "com.example.app"
        resValue "string", "app_name", "MyApp"
    }
}
```

Kotlin DSL(`.kts`)도 자동으로 인식하여 올바른 문법으로 생성합니다.

### iOS

1. **xcconfig 파일** (`ios/Flutter/`)
   - `Debug-{flavor}.xcconfig` — Debug.xcconfig를 include하고 `APP_DISPLAY_NAME` 설정
   - `Release-{flavor}.xcconfig` — Release.xcconfig를 include
   - `Profile-{flavor}.xcconfig` — Release.xcconfig를 include
   - `app_icon`이 설정된 경우 `ASSETCATALOG_COMPILER_APPICON_NAME=AppIcon-{flavor}` 자동 추가

2. **앱 아이콘** (`ios/Runner/Assets.xcassets/`) — `app_icon` 설정 시
   - `AppIcon-{flavor}.appiconset/` 디렉터리에 15개 사이즈 PNG + Contents.json 생성

3. **project.pbxproj** (`ios/Runner.xcodeproj/`)
   - 기존 Debug/Release/Profile 빌드 구성을 복제하여 flavor별 구성 생성
   - PBXFileReference, PBXGroup, XCBuildConfiguration, XCConfigurationList 모두 수정

4. **xcscheme** (`ios/Runner.xcodeproj/xcshareddata/xcschemes/`)
   - flavor별 Xcode 빌드 스키마 생성
   - Build/Launch → Debug-{flavor}, Profile → Profile-{flavor}, Archive → Release-{flavor}

5. **Info.plist** (`ios/Runner/`)
   - `CFBundleDisplayName` 값을 `$(APP_DISPLAY_NAME)`으로 교체

6. **InfoPlist.strings** (`ios/Runner/{locale}.lproj/`) — `localized` 설정 시
   - flavor별 `app_name` → `CFBundleDisplayName` 키로 생성
   - 전역 `permission` → 해당 권한 키로 생성
   - 같은 locale에 대해 flavor의 app_name과 전역 permission이 병합됨

7. **Podfile** (`ios/`)
   - `Debug-{flavor} => :debug`, `Release-{flavor} => :release` 등 매핑 추가

---

## 프로젝트 구조

```
easy_setup/
├── bin/
│   └── easy_setup.dart                    # CLI 진입점 (서브커맨드 라우팅)
├── lib/
│   ├── easy_setup.dart                    # 라이브러리 공개 API (re-export)
│   └── src/
│       ├── exceptions.dart                # SetupException 정의
│       ├── models/
│       │   ├── flavor_config.dart         # FlavorConfig, EasySetupConfig, FlavorLocalizedConfig
│       │   └── ci_cd_config.dart          # CiCdConfig, CiCdIosConfig 등
│       ├── utils/
│       │   ├── project_finder.dart        # Flutter 프로젝트 경로 탐색
│       │   ├── uuid_generator.dart        # Xcode UUID 생성 (24자리 hex)
│       │   └── fastlane_runner.dart       # Gemfile 관리 + fastlane 실행
│       ├── commands/
│       │   ├── flavor_command.dart        # flavor 파이프라인 오케스트레이션
│       │   └── ci_cd_command.dart         # CI/CD 파이프라인 (파일 생성 + Bundle ID 등록 + register lane)
│       ├── app_store/
│       │   ├── app_store_connect_client.dart  # App Store Connect REST API 클라이언트
│       │   └── jwt_generator.dart             # ES256 JWT 토큰 생성
│       ├── android/
│       │   └── build_gradle_modifier.dart # build.gradle flavor 설정
│       ├── ios/
│       │   ├── app_icon_generator.dart    # 앱 아이콘 자동 생성 (리사이즈 + Contents.json)
│       │   ├── xcconfig_generator.dart    # xcconfig 파일 생성
│       │   ├── pbxproj_modifier.dart      # project.pbxproj 수정 (가장 복잡)
│       │   ├── scheme_generator.dart      # .xcscheme 생성
│       │   ├── info_plist_modifier.dart   # Info.plist 수정
│       │   ├── info_plist_strings_generator.dart  # {locale}.lproj/InfoPlist.strings 생성
│       │   └── podfile_modifier.dart      # Podfile 수정
│       ├── firebase/
│       │   └── firebase_copier.dart       # google-services.json / GoogleService-Info.plist 복사
│       ├── fastlane/
│       │   ├── gemfile_generator.dart     # Gemfile 생성
│       │   ├── matchfile_generator.dart   # Matchfile 생성
│       │   ├── appfile_generator.dart     # Appfile 생성
│       │   ├── fastfile_generator.dart    # Fastfile 생성 + lane 관리 (addLane, addRegisterLane, addMetadataLane)
│       │   └── metadata_generator.dart    # App Store Connect 메타데이터 파일 생성
│       └── github/
│           └── workflow_generator.dart    # .github/workflows/*.yml 생성
└── pubspec.yaml
```

---

## 모듈별 설명

### `bin/easy_setup.dart` — CLI 진입점
- `args` 패키지를 사용하여 `--help`, `--dry-run`, `--project-root` 옵션을 파싱합니다.
- 서브커맨드 라우팅: `flavor` (기본), `ci-cd`.
- 서브커맨드 생략 시 `flavor`로 동작하여 하위 호환성을 보장합니다.

### `FlavorCommand` — flavor 오케스트레이터
- flavor 설정 과정을 순차적으로 실행합니다.
- 프로젝트 루트 자동 탐지 → YAML 로드 → Android → iOS (xcconfig → Firebase → 앱 아이콘 → pbxproj → scheme → plist → InfoPlist.strings → Podfile).
- `app_icon`이 설정된 flavor에 대해 `AppIconGenerator`를 호출하여 flavor별 아이콘을 자동 생성합니다.
- flavor별 `localized` (app_name)과 전역 `localized_permission` (권한)을 병합하여 `InfoPlistStringsGenerator`로 `.strings` 파일을 생성합니다.

### `CiCdCommand` — CI/CD 오케스트레이터
- CI/CD 파이프라인 설정을 순차적으로 실행합니다.
- YAML 로드 → flavor 해석 → Gemfile 준비 → Fastlane 4파일 → Bundle ID 등록 → register lane 추가 → 메타데이터 생성 → GitHub Actions 워크플로우 → 안내 출력.
- API Key 파일(.p8)이 있으면 Bundle ID를 자동 등록하고, 없으면 건너뜁니다.
- `FastfileGenerator.addRegisterLane()`으로 Fastfile에 register lane을 추가합니다.
- `ci_cd.metadata` 설정이 있으면 메타데이터 파일을 생성하고 `update_metadata` lane을 추가합니다.

### `AppIconGenerator` — iOS 앱 아이콘 생성
- flavor별로 1024x1024 소스 PNG를 15개 고유 사이즈로 리사이즈합니다 (`image` 패키지 사용).
- `Contents.json` (19개 엔트리)을 생성하여 iPhone/iPad/App Store용 아이콘을 매핑합니다.
- 덮어쓰기 방식으로 재실행 시에도 안전합니다 (idempotent).

### `InfoPlistStringsGenerator` — iOS InfoPlist.strings 생성
- flavor별 `localized` (app_name)과 전역 `localized_permission` (권한)을 병합합니다.
- locale별로 `ios/Runner/{locale}.lproj/InfoPlist.strings` 파일을 생성합니다.
- `app_name` → `CFBundleDisplayName`, permission 키 → 해당 권한 키로 매핑됩니다.

### `FastfileGenerator` — Fastfile 생성 + lane 관리
- `generate()`: 기본 Fastfile 골격 생성 (api_key, certificates, beta lane).
- `addLane()`: 범용 lane 삽입 (마커 기반 idempotent strip-and-replace).
- `addRegisterLane()`: register lane 생성 (`produce` 호출 코드).
- `addMetadataLane()`: update_metadata lane 생성 (`deliver` 호출 코드).

### `MetadataGenerator` — App Store Connect 메타데이터
- locale별 메타데이터 파일을 `ci_cd/ios/fastlane/metadata/{locale}/` 하위에 생성합니다.
- `LocaleMetadataConfig.toFileMap()`으로 설정된 필드만 파일로 변환합니다.

### `FlavorConfig` / `EasySetupConfig` — 설정 모델
- `easy_setup.yaml`을 파싱하여 `Map<String, FlavorConfig>`로 변환합니다.
- `FlavorConfig.localized`: flavor별 locale 설정 (`FlavorLocalizedConfig` — app_name).
- `EasySetupConfig.localizations`: Xcode knownRegions에 등록할 언어 목록.
- `EasySetupConfig.permission`: 기본 iOS 권한 설명 (Base.lproj용).
- `EasySetupConfig.localizedPermission`: locale별 iOS 권한 설명.
- 파일 부재나 파싱 오류 시 친절한 에러 메시지를 제공합니다.

### `ProjectFinder` — 경로 유틸리티
- 현재 디렉터리에서 위로 올라가며 `pubspec.yaml`에 Flutter SDK 참조가 있는지 확인합니다.
- Android, iOS 각 설정 파일의 표준 경로를 반환합니다 (`iosAssetCatalogDir` 포함).

### `BuildGradleModifier` — Android 설정
- `buildTypes` 블록을 찾아 그 뒤에 `flavorDimensions` + `productFlavors`를 삽입합니다.
- 중괄호 깊이(brace-counting)로 블록 끝을 정확히 탐지합니다.

### `FirebaseCopier` — Firebase 설정 파일 복사
- `firebase.android` 경로의 `google-services.json`을 flavor별 Android 디렉터리에 복사합니다.
- `firebase.ios` 경로의 `GoogleService-Info.plist`를 flavor별 iOS 디렉터리에 복사합니다.

### `PbxprojModifier` — iOS 프로젝트 설정 (가장 복잡)
- Xcode `project.pbxproj` 파일의 6개 섹션을 수정합니다.
- 기존 빌드 구성 블록을 "복제(clone)" 방식으로 생성하여 Xcode 버전 차이에 대응합니다.
- Runner 타겟과 Project 레벨 양쪽 모두 설정합니다.

### `XcconfigGenerator` — iOS xcconfig 생성
- 각 flavor에 대해 Debug/Release/Profile 3개의 xcconfig 파일을 생성합니다.
- 기존 Debug.xcconfig, Release.xcconfig를 `#include`로 상속합니다.
- `appIcon`이 설정된 경우 `ASSETCATALOG_COMPILER_APPICON_NAME=AppIcon-{flavor}`를 자동 추가합니다.

### `SchemeGenerator` — iOS 빌드 스키마 생성
- Xcode의 Build/Test/Launch/Profile/Analyze/Archive 액션에 올바른 빌드 구성을 매핑합니다.
- Runner 타겟의 UUID를 `BuildableReference`에 포함합니다.

### `InfoPlistModifier` — iOS Info.plist 수정
- 앱 표시 이름(`CFBundleDisplayName`)을 xcconfig 변수(`$(APP_DISPLAY_NAME)`)로 교체합니다.
- 키가 없으면 자동으로 추가합니다.

### `PodfileModifier` — iOS Podfile 수정
- CocoaPods의 빌드 구성-모드 매핑에 flavor 항목을 추가합니다.
- `Debug-{flavor} → :debug`, `Profile-{flavor} → :release`, `Release-{flavor} → :release`.

---

## 설계 원칙

### 멱등성 (Idempotency)
모든 Modifier/Generator에 멱등성 가드가 적용되어 있습니다. 같은 명령을 여러 번 실행해도 중복 설정이 발생하지 않습니다.

### 복제(Clone) 기반 접근
`pbxproj_modifier`는 하드코딩된 템플릿 대신 기존 빌드 구성 블록을 복제합니다. 이를 통해 Xcode 버전에 따라 달라지는 빌드 설정 키를 자동으로 계승합니다.

### Brace-Counting 파서
정규식만으로는 중첩된 중괄호 구조를 안전하게 파싱할 수 없으므로, 깊이(depth)를 추적하는 전용 파서(`_findBlockEnd`)를 사용합니다.

### 2단계 Localization
- **Flavor별 `localized`**: 앱 아이콘, 앱 이름 등 flavor에 따라 달라질 수 있는 설정
- **전역 `localized`**: iOS 권한 설명 등 모든 flavor에 공통으로 적용되는 설정

### Dry-Run 모드
`--dry-run` 플래그로 실제 파일을 변경하지 않고 어떤 작업이 수행될지 미리 확인할 수 있습니다.

---

## 문제 해결

### "Could not find a Flutter project root"
- Flutter 프로젝트 디렉터리 안에서 실행하거나, `-p` 옵션으로 경로를 지정하세요.
- `pubspec.yaml`에 `sdk: flutter`가 있는지 확인하세요.

### "easy_setup.yaml not found"
- 프로젝트 루트에 `easy_setup.yaml` 파일을 생성하세요. (위의 설정 파일 섹션 참조)

### "buildTypes block not found"
- `android/app/build.gradle(.kts)`에 `buildTypes` 블록이 있는지 확인하세요.
- Flutter 프로젝트를 `flutter create`로 생성했다면 기본적으로 존재합니다.

### iOS 설정이 건너뛰어지는 경우
- `ios/` 디렉터리가 있는지 확인하세요 (`flutter create`로 iOS 지원이 활성화되어 있어야 합니다).
- `ios/Runner.xcodeproj/project.pbxproj` 파일이 존재하는지 확인하세요.

### "App icon source must be 1024x1024"
- `app_icon` 경로의 PNG 이미지가 정확히 1024x1024 픽셀이어야 합니다.
- JPEG 등 다른 포맷이 아닌 PNG 파일을 사용하세요.

### "App icon source image not found"
- `app_icon` 경로가 프로젝트 루트 기준 상대경로인지 확인하세요.
- 파일이 해당 경로에 존재하는지 확인하세요.

### 이미 설정된 경우
- `flavor` / `ci-cd`: 덮어쓰기 방식 — 기존 설정을 제거하고 새로 생성합니다.
- Bundle ID 등록: 이미 존재하는 Bundle ID는 자동으로 건너뜁니다.

### CI/CD 관련

**"API Key file not found"**
- `easy_setup.yaml`의 `ci_cd.ios.api_key.key_path`에 지정된 경로에 .p8 파일이 있는지 확인하세요.
- .p8 파일이 없어도 CI/CD 파일 생성은 정상적으로 진행됩니다 (Bundle ID 등록만 건너뜀).

**App Store Connect 앱 생성 실패**
- `bundle exec fastlane register` 실행 시 Apple ID 2FA 인증이 필요합니다.
- `ci_cd.ios.apple_id`에 Apple ID를 설정하거나, 환경변수 `FASTLANE_USER`를 사용하세요.
