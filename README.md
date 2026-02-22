# easy_setup

Flutter 프로젝트의 flavor(빌드 변형) 환경을 **한 번의 명령**으로 자동 설정하는 Dart CLI 도구입니다.

`easy_setup.yaml` 설정 파일 하나만 작성하면, Android와 iOS의 복잡한 빌드 설정을 모두 자동으로 구성합니다.

---

## 목차

- [주요 기능](#주요-기능)
- [설치](#설치)
- [사용법](#사용법)
- [설정 파일 (easy_setup.yaml)](#설정-파일-easy_setupyaml)
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
easy_setup
```

### CLI 옵션

```
옵션:
  -h, --help            도움말 표시
  -n, --dry-run         파일을 변경하지 않고 미리보기만 수행
  -p, --project-root    Flutter 프로젝트 루트 경로 지정 (기본: 자동 탐지)
```

### 예시

```bash
# dry-run으로 미리보기
easy_setup --dry-run

# 특정 프로젝트 경로 지정
easy_setup -p /path/to/flutter/project

# 두 옵션 함께 사용
easy_setup -n -p /path/to/flutter/project
```

### 실행 후 다음 단계

`easy_setup` 실행이 완료되면 아래 명령을 순서대로 실행하세요:

```bash
flutter pub get
cd ios && pod install
flutter run --flavor dev -t lib/main.dart
```

---

## 설정 파일 (easy_setup.yaml)

Flutter 프로젝트 루트에 `easy_setup.yaml` 파일을 생성합니다:

```yaml
flavors:
  dev:
    bundle_id: com.example.app.dev
    name: MyApp Dev
  staging:
    bundle_id: com.example.app.staging
    name: MyApp Staging
  prod:
    bundle_id: com.example.app
    name: MyApp
```

### 필드 설명

| 필드 | 설명 | 예시 |
|------|------|------|
| `bundle_id` | 앱의 고유 식별자 (Android applicationId / iOS PRODUCT_BUNDLE_IDENTIFIER) | `com.example.app.dev` |
| `name` | 사용자에게 표시되는 앱 이름 (Android app_name / iOS APP_DISPLAY_NAME) | `MyApp Dev` |

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

2. **project.pbxproj** (`ios/Runner.xcodeproj/`)
   - 기존 Debug/Release/Profile 빌드 구성을 복제하여 flavor별 구성 생성
   - PBXFileReference, PBXGroup, XCBuildConfiguration, XCConfigurationList 모두 수정

3. **xcscheme** (`ios/Runner.xcodeproj/xcshareddata/xcschemes/`)
   - flavor별 Xcode 빌드 스키마 생성
   - Build/Launch → Debug-{flavor}, Profile → Profile-{flavor}, Archive → Release-{flavor}

4. **Info.plist** (`ios/Runner/`)
   - `CFBundleDisplayName` 값을 `$(APP_DISPLAY_NAME)`으로 교체

5. **Podfile** (`ios/`)
   - `Debug-{flavor} => :debug`, `Release-{flavor} => :release` 등 매핑 추가

---

## 프로젝트 구조

```
easy_setup/
├── bin/
│   └── easy_setup.dart                    # CLI 진입점 (실행 파일)
├── lib/
│   ├── easy_setup.dart                    # 라이브러리 공개 API (re-export)
│   └── src/
│       ├── exceptions.dart                # SetupException 정의
│       ├── models/
│       │   └── flavor_config.dart         # FlavorConfig, EasySetupConfig 모델
│       ├── utils/
│       │   ├── project_finder.dart        # Flutter 프로젝트 경로 탐색
│       │   └── uuid_generator.dart        # Xcode UUID 생성 (24자리 hex)
│       ├── commands/
│       │   └── flavor_command.dart        # 전체 파이프라인 오케스트레이션
│       ├── android/
│       │   └── build_gradle_modifier.dart # build.gradle flavor 설정
│       └── ios/
│           ├── xcconfig_generator.dart    # xcconfig 파일 생성
│           ├── pbxproj_modifier.dart      # project.pbxproj 수정 (가장 복잡)
│           ├── scheme_generator.dart      # .xcscheme 생성
│           ├── info_plist_modifier.dart   # Info.plist 수정
│           └── podfile_modifier.dart      # Podfile 수정
└── pubspec.yaml
```

---

## 모듈별 설명

### `bin/easy_setup.dart` — CLI 진입점
- `args` 패키지를 사용하여 `--help`, `--dry-run`, `--project-root` 옵션을 파싱합니다.
- 파싱 결과를 `FlavorCommand.run()`에 전달하여 전체 설정 파이프라인을 시작합니다.

### `FlavorCommand` — 오케스트레이터
- 전체 설정 과정을 8단계로 나누어 순차적으로 실행합니다.
- 프로젝트 루트 자동 탐지 → YAML 로드 → Android → iOS (xcconfig → pbxproj → scheme → plist → Podfile).

### `FlavorConfig` / `EasySetupConfig` — 설정 모델
- `easy_setup.yaml`을 파싱하여 `Map<String, FlavorConfig>`로 변환합니다.
- 파일 부재나 파싱 오류 시 친절한 에러 메시지를 제공합니다.

### `ProjectFinder` — 경로 유틸리티
- 현재 디렉터리에서 위로 올라가며 `pubspec.yaml`에 Flutter SDK 참조가 있는지 확인합니다.
- Android, iOS 각 설정 파일의 표준 경로를 반환합니다.

### `BuildGradleModifier` — Android 설정
- `buildTypes` 블록을 찾아 그 뒤에 `flavorDimensions` + `productFlavors`를 삽입합니다.
- 중괄호 깊이(brace-counting)로 블록 끝을 정확히 탐지합니다.

### `PbxprojModifier` — iOS 프로젝트 설정 (가장 복잡)
- Xcode `project.pbxproj` 파일의 6개 섹션을 수정합니다.
- 기존 빌드 구성 블록을 "복제(clone)" 방식으로 생성하여 Xcode 버전 차이에 대응합니다.
- Runner 타겟과 Project 레벨 양쪽 모두 설정합니다.

### `XcconfigGenerator` — iOS xcconfig 생성
- 각 flavor에 대해 Debug/Release/Profile 3개의 xcconfig 파일을 생성합니다.
- 기존 Debug.xcconfig, Release.xcconfig를 `#include`로 상속합니다.

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

### 이미 설정된 경우
- 멱등성 가드에 의해 이미 설정된 항목은 자동으로 건너뜁니다.
- 처음부터 다시 설정하려면, git으로 변경 사항을 되돌린 후 다시 실행하세요.
