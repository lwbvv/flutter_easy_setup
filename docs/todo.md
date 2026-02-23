# Flavor별 설정 가능 항목 정리

현재 `easy_setup`이 지원하는 항목과, 추가로 구현할 수 있는 항목을 정리합니다.

---

## Android (`productFlavors`)

### 현재 지원
- [x] `applicationId` (bundle_id)
- [x] `flavorDimensions` 자동 생성
- [x] `productFlavors` 블록 생성 (Groovy + Kotlin DSL)

### 추가 가능 항목

#### 우선순위 높음
- [x] `resValue` — flavor별 문자열 리소스 (앱 이름 등)
- [x] `versionCode` / `versionName` — flavor별 버전 관리
- [x] `signingConfig` — flavor별 서명 설정 (keystore 경로, alias 등)
- [x] `manifestPlaceholders` — AndroidManifest 변수 (앱 이름, 딥링크 스킴 등)
- [x] Firebase `google-services.json` — flavor별 파일 복사 (`app/src/{flavor}/`)

#### 우선순위 중간
- [ ] `buildConfigField` — 빌드 타임 상수 (API URL, 기능 플래그 등)
- [ ] App icon — flavor별 런처 아이콘 (`mipmap-*` 리소스)
- [ ] `minSdkVersion` / `targetSdkVersion` — flavor별 SDK 버전
- [ ] `multiDexEnabled` — flavor별 멀티덱스 설정
- [ ] ProGuard / R8 규칙 — flavor별 난독화 설정 (`proguardFiles`)

#### 우선순위 낮음 (기능 개발 요청이 들어오면 개발)
- [ ] `dimension` — 다중 dimension 지원 (예: `environment` × `store`)
- [ ] `ndk.abiFilters` — flavor별 ABI 필터
- [ ] `sourceSets` — flavor별 소스 디렉터리 매핑
- [ ] `testInstrumentationRunner` — flavor별 테스트 러너

---

## iOS

### 현재 지원
- [x] `PRODUCT_BUNDLE_IDENTIFIER` (xcconfig → pbxproj) V
- [x] `APP_DISPLAY_NAME` (xcconfig → Info.plist) V
- [x] Build configurations (Debug/Release/Profile per flavor) V
- [x] `.xcscheme` 파일 생성 V
- [x] Podfile 빌드 모드 매핑 V
- [x] xcconfig 파일 생성 (`#include` 체인) V

### 추가 가능 항목

#### 우선순위 높음
- [x] Firebase `GoogleService-Info.plist` — flavor별 파일 복사 및 Build Phase 스크립트
- [x] Code signing — flavor별 Provisioning Profile, Team ID, Code Sign Identity
  - `CODE_SIGN_IDENTITY`
  - `DEVELOPMENT_TEAM`
  - `PROVISIONING_PROFILE_SPECIFIER`
- [x] App icon — flavor별 `AppIcon` 에셋 카탈로그 (`ASSETCATALOG_COMPILER_APPICON_NAME`)
- [x] Entitlements — flavor별 `.entitlements` 파일 (`CODE_SIGN_ENTITLEMENTS`)

#### 우선순위 중간
- [ ] Info.plist 추가 변수 — 커스텀 URL 스킴, 딥링크 등
  - `CFBundleURLSchemes`
  - `CFBundleShortVersionString` / `CFBundleVersion`
- [ ] Launch screen — flavor별 LaunchScreen.storyboard 또는 이미지
- [ ] 커스텀 xcconfig 변수 — 사용자 정의 빌드 설정 (API URL 등)
  - `GCC_PREPROCESSOR_DEFINITIONS` (Obj-C 매크로)
  - 커스텀 `USER_DEFINED` 변수
- [ ] ATS (App Transport Security) 설정 — flavor별 네트워크 보안 정책

#### 우선순위 낮음 (기능 개발 요청이 들어오면 개발)
- [ ] `TARGETED_DEVICE_FAMILY` — flavor별 디바이스 지원 (iPhone/iPad)
- [ ] `IPHONEOS_DEPLOYMENT_TARGET` — flavor별 최소 iOS 버전
- [ ] `SWIFT_ACTIVE_COMPILATION_CONDITIONS` — Swift 컴파일 조건
- [ ] `OTHER_LDFLAGS` — flavor별 링커 플래그

---

## Flutter 레벨

### 추가 가능 항목
- [ ] `--flavor` + `--dart-define` 자동 조합 — 빌드 커맨드 생성
- [ ] `lib/` flavor별 진입점 — `main_dev.dart`, `main_prod.dart` 자동 생성
- [ ] `.env` 파일 — flavor별 환경 변수 파일 생성 (`flutter_dotenv` 연동)
- [ ] `launch.json` / `tasks.json` — VS Code flavor별 디버그 설정 자동 생성

---

## easy_setup.yaml 확장 구조 (안)

```yaml
flavors:
  dev:
    bundle_id: com.example.app.dev
    name: MyApp Dev
    # --- 추가 가능 항목 ---
    version_code: 1
    version_name: "1.0.0-dev"
    signing:
      keystore: keys/dev.keystore
      alias: dev
    firebase:
      android: config/dev/google-services.json
      ios: config/dev/GoogleService-Info.plist
    variables:
      API_BASE_URL: "https://dev-api.example.com"
      ENABLE_LOGGING: "true"
    ios:
      team_id: "XXXXXXXXXX"
      provisioning_profile: "Dev Profile"
      entitlements: config/dev/Runner.entitlements
      app_icon: AppIcon-Dev
    android:
      app_icon: "@mipmap/ic_launcher_dev"
      proguard: config/dev/proguard-rules.pro
  prod:
    bundle_id: com.example.app
    name: MyApp
    # ...
```

---

## 구현 우선순위 로드맵

### Phase 1 — 핵심 (현재 구현 완료)
- Android: applicationId, productFlavors
- iOS: bundle ID, display name, build configs, schemes, Podfile, xcconfig

### Phase 2 — Firebase + 서명
- Firebase 설정 파일 복사 (Android + iOS)
- Android signing config
- iOS code signing (Team ID, provisioning profile)

### Phase 3 — 앱 리소스
- Flavor별 앱 아이콘 (Android + iOS)
- Flavor별 launch screen
- Android resValue / manifestPlaceholders

### Phase 4 — 개발 편의
- 커스텀 변수 (buildConfigField / xcconfig)
- Flutter launch.json 생성
- main_{flavor}.dart 진입점 생성

### Phase 5 — 고급
- 다중 dimension 지원
- Entitlements
- ProGuard 규칙
- .env 파일 연동
