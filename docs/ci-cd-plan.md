# CI/CD 자동화 설정 구현 계획

## 1. 개요

`easy_setup ci-cd` 명령을 추가하여, `easy_setup.yaml`의 `ci_cd` 섹션을 읽고 iOS CI/CD에 필요한 파일들을 자동 생성한다.

**핵심 원칙:**
- iOS 인증서 저장소: GitHub (git) only — Fastlane Match 방식
- 인증 방식: App Store Connect API Key only
- Android CI/CD는 이번 범위에 포함하지 않음 (향후 확장)

---

## 2. YAML 설정 구조

```yaml
easy_setup:
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

  ci_cd:
    # ── flavor override (optional) ──────────────────────────────
    # 생략 시 easy_setup.flavors의 bundle_id를 그대로 사용.
    # CI/CD에서 일부 flavor만 배포하거나, bundle_id를 다르게 쓸 때 지정.
    flavors:
      staging:
        bundle_id: com.example.app.staging
      prod:
        bundle_id: com.example.app

    # ── iOS 설정 (required) ─────────────────────────────────────
    ios:
      # required — Match 인증서/프로파일 저장 GitHub repo URL
      storage: https://github.com/user/app-certification.git

      # required — Apple Developer Team ID
      team_id: XXXXXXXXXX

      # required — App Store Connect Team ID
      itc_team_id: YYYYYYYYYY

      # required — App Store Connect API Key
      api_key:
        id: KEY_ID                          # required
        issuer_id: ISSUER_ID                # required
        key_path: fastlane/AuthKey.p8       # required — .p8 파일 경로
        duration: 1200                      # optional (기본 1200초)
        in_house: false                     # optional (기본 false, Enterprise가 아니면 false)

    # ── 프로비저닝 프로파일 (optional) ──────────────────────────
    # 생략 시 기본 네이밍 규칙 적용:
    #   debug   → "match Development {bundle_id}"
    #   profile → "match AdHoc {bundle_id}"
    #   release → "match AppStore {bundle_id}"
    provisioning_profile:
      debug:
        name: "match Development com.example.app"   # optional
      profile:
        name: "match AdHoc com.example.app"         # optional
      release:
        name: "match AppStore com.example.app"      # optional
```

### 2.1. 필드 상세

| 필드 | 필수 | 기본값 | 설명 |
|------|------|--------|------|
| `ci_cd.flavors` | × | `easy_setup.flavors` | CI/CD 대상 flavor와 bundle_id override |
| `ci_cd.ios.storage` | ○ | — | Match 인증서 저장 GitHub repo URL |
| `ci_cd.ios.team_id` | ○ | — | Apple Developer Team ID |
| `ci_cd.ios.itc_team_id` | ○ | — | App Store Connect Team ID |
| `ci_cd.ios.api_key.id` | ○ | — | API Key ID |
| `ci_cd.ios.api_key.issuer_id` | ○ | — | Issuer ID |
| `ci_cd.ios.api_key.key_path` | ○ | — | .p8 파일 경로 |
| `ci_cd.ios.api_key.duration` | × | `1200` | JWT 토큰 유효 시간(초) |
| `ci_cd.ios.api_key.in_house` | × | `false` | Enterprise 계정 여부 |
| `ci_cd.provisioning_profile.{type}.name` | × | `match {Type} {bundle_id}` | 프로파일 지정자 이름 |

### 2.2. Flavor 해석 로직

```
ci_cd에 사용할 flavors 결정:
  1. ci_cd.flavors가 있으면 → 해당 키만 대상
     - bundle_id가 명시되면 그 값 사용
     - bundle_id가 없으면 easy_setup.flavors.{flavor}.bundle_id 사용
  2. ci_cd.flavors가 없으면 → easy_setup.flavors 전체를 대상으로 사용
```

### 2.3. 프로비저닝 프로파일 이름 결정 로직

```
프로파일 이름 결정 (build type별, flavor별):
  1. ci_cd.provisioning_profile.{type}.name이 있으면 → 그 값 사용 (template)
     - "{bundle_id}" 플레이스홀더를 실제 bundle_id로 치환
  2. 없으면 기본값 사용:
     - debug   → "match Development {bundle_id}"
     - profile → "match AdHoc {bundle_id}"
     - release → "match AppStore {bundle_id}"
```

---

## 3. CLI 아키텍처 변경

### 3.1. 서브커맨드 도입

현재 단일 명령 구조를 서브커맨드 체계로 전환한다.

```
easy_setup <command> [options]

Commands:
  flavor    Flutter flavor 환경 설정 (Android + iOS)
  ci-cd     CI/CD 파이프라인 설정 생성 (Fastlane + GitHub Actions)

Global Options:
  -h, --help          도움말 표시
  -n, --dry-run       파일 변경 없이 미리보기
  -p, --project-root  Flutter 프로젝트 루트 경로 지정
```

**하위 호환성:** 서브커맨드 없이 `easy_setup`만 실행하면 `easy_setup flavor`와 동일하게 동작.

### 3.2. bin/easy_setup.dart 변경

```dart
void main(List<String> arguments) {
  // 서브커맨드가 없거나 옵션만 있으면 → flavor (하위 호환)
  // 'flavor' → FlavorCommand.run()
  // 'ci-cd'  → CiCdCommand.run()
}
```

`args` 패키지의 `CommandRunner` 또는 수동 서브커맨드 라우팅 사용.

---

## 4. 생성 파일 목록

`easy_setup ci-cd` 명령 실행 시 아래 파일들이 생성된다.

### 4.1. Fastlane 파일 (ios/ 하위)

| 파일 | 설명 |
|------|------|
| `ios/Gemfile` | Fastlane Ruby 의존성 |
| `ios/fastlane/Matchfile` | Match 설정 (storage, team, bundle IDs) |
| `ios/fastlane/Appfile` | 앱 식별 정보 (team_id, itc_team_id) |
| `ios/fastlane/Fastfile` | 빌드/배포 레인 정의 |

### 4.2. GitHub Actions 워크플로우

| 파일 | 설명 |
|------|------|
| `.github/workflows/ios-deploy.yml` | iOS 빌드 + TestFlight 배포 워크플로우 |

### 4.3. 각 파일의 생성 내용

#### `ios/Gemfile`

```ruby
source "https://rubygems.org"

gem "fastlane"
```

#### `ios/fastlane/Matchfile`

```ruby
git_url("https://github.com/user/app-certification.git")
storage_mode("git")

type("appstore")

app_identifier([
  "com.example.app.dev",
  "com.example.app.staging",
  "com.example.app",
])

team_id("XXXXXXXXXX")

api_key_path("fastlane/api_key.json")
```

#### `ios/fastlane/Appfile`

```ruby
team_id("XXXXXXXXXX")
itc_team_id("YYYYYYYYYY")
```

#### `ios/fastlane/Fastfile`

```ruby
default_platform(:ios)

platform :ios do
  # ── API Key 설정 ──────────────────────────────────
  def api_key
    app_store_connect_api_key(
      key_id: "KEY_ID",
      issuer_id: "ISSUER_ID",
      key_filepath: "fastlane/AuthKey.p8",
      duration: 1200,
      in_house: false,
    )
  end

  # ── 인증서 동기화 ─────────────────────────────────
  desc "Sync all certificates and provisioning profiles"
  lane :certificates do
    ["development", "adhoc", "appstore"].each do |type|
      match(
        type: type,
        api_key: api_key,
        readonly: is_ci,
      )
    end
  end

  # ── flavor별 빌드 + TestFlight 배포 ───────────────
  desc "Build and upload to TestFlight"
  lane :beta do |options|
    flavor = options[:flavor] || "prod"

    certificates

    sh("cd ../.. && flutter build ipa --flavor #{flavor} --release")

    upload_to_testflight(
      api_key: api_key,
      skip_waiting_for_build_processing: true,
    )
  end
end
```

#### `.github/workflows/ios-deploy.yml`

```yaml
name: iOS Deploy

on:
  workflow_dispatch:
    inputs:
      flavor:
        description: "Flavor to build and deploy"
        required: true
        default: "prod"
        type: choice
        options:
          - dev
          - staging
          - prod

jobs:
  deploy:
    runs-on: macos-latest
    timeout-minutes: 30

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: "3.2"
          bundler-cache: true
          working-directory: ios

      - name: Flutter dependencies
        run: flutter pub get

      - name: Decode API Key
        env:
          API_KEY_BASE64: ${{ secrets.APP_STORE_CONNECT_API_KEY_BASE64 }}
        run: echo "$API_KEY_BASE64" | base64 --decode > ios/fastlane/AuthKey.p8

      - name: Match — sync certificates
        env:
          MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
          MATCH_GIT_BASIC_AUTHORIZATION: ${{ secrets.MATCH_GIT_BASIC_AUTHORIZATION }}
        run: |
          cd ios
          bundle exec fastlane certificates

      - name: Build & Deploy to TestFlight
        env:
          MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
          MATCH_GIT_BASIC_AUTHORIZATION: ${{ secrets.MATCH_GIT_BASIC_AUTHORIZATION }}
        run: |
          cd ios
          bundle exec fastlane beta flavor:${{ inputs.flavor }}
```

---

## 5. 필요한 GitHub Secrets

`ci-cd` 명령 실행 후, 사용자에게 다음 시크릿 설정을 안내한다.

| Secret 이름 | 설명 | 생성 방법 |
|-------------|------|----------|
| `MATCH_PASSWORD` | Match 인증서 저장소 암호화 비밀번호 | 임의 문자열, `match` 최초 실행 시 설정 |
| `MATCH_GIT_BASIC_AUTHORIZATION` | GitHub 인증서 repo 접근 토큰 | `echo -n "username:PAT" \| base64` |
| `APP_STORE_CONNECT_API_KEY_BASE64` | .p8 키 파일 내용 (base64) | `base64 -i AuthKey.p8` |

---

## 6. 모델 클래스

### 6.1. 새로 추가할 모델

```
lib/src/models/
├── flavor_config.dart          # 기존 (EasySetupConfig 수정)
└── ci_cd_config.dart           # 신규
```

#### `ci_cd_config.dart`

```dart
/// CI/CD 최상위 설정
class CiCdConfig {
  final Map<String, String>? flavors;     // flavor → bundle_id override
  final CiCdIosConfig ios;
  final ProvisioningProfileConfig? provisioningProfile;
}

/// iOS CI/CD 설정
class CiCdIosConfig {
  final String storage;       // GitHub repo URL
  final String teamId;
  final String itcTeamId;
  final ApiKeyConfig apiKey;
}

/// App Store Connect API Key 설정
class ApiKeyConfig {
  final String id;
  final String issuerId;
  final String keyPath;
  final int duration;         // default 1200
  final bool inHouse;         // default false
}

/// 프로비저닝 프로파일 설정 (build type별)
class ProvisioningProfileConfig {
  final ProfileTypeConfig? debug;
  final ProfileTypeConfig? profile;
  final ProfileTypeConfig? release;
}

class ProfileTypeConfig {
  final String? name;
}
```

### 6.2. EasySetupConfig 수정

```dart
class EasySetupConfig {
  final Map<String, FlavorConfig> flavors;
  final CiCdConfig? ciCd;                   // 신규 추가

  factory EasySetupConfig.fromFile(String path) {
    // ...기존 flavors 파싱...
    final ciCdMap = easySetup['ci_cd'];
    final ciCd = ciCdMap != null ? CiCdConfig.fromYaml(ciCdMap) : null;
    return EasySetupConfig(flavors: flavors, ciCd: ciCd);
  }
}
```

---

## 7. 새 파일 구조

```
lib/src/
├── commands/
│   ├── flavor_command.dart       # 기존
│   └── ci_cd_command.dart        # 신규 — CI/CD 오케스트레이터
├── models/
│   ├── flavor_config.dart        # 수정 — ciCd 필드 추가
│   └── ci_cd_config.dart         # 신규 — CI/CD 모델
├── fastlane/
│   ├── gemfile_generator.dart    # 신규 — ios/Gemfile 생성
│   ├── matchfile_generator.dart  # 신규 — ios/fastlane/Matchfile 생성
│   ├── appfile_generator.dart    # 신규 — ios/fastlane/Appfile 생성
│   └── fastfile_generator.dart   # 신규 — ios/fastlane/Fastfile 생성
├── github/
│   └── workflow_generator.dart   # 신규 — .github/workflows/*.yml 생성
└── ...기존 파일들...
```

---

## 8. CiCdCommand 실행 흐름

```
CiCdCommand.run(dryRun, projectRoot)
│
├── 1. Flutter 프로젝트 루트 확인
├── 2. easy_setup.yaml 로드 → EasySetupConfig (ci_cd 포함)
├── 3. ci_cd 섹션 존재 확인 (없으면 SetupException)
├── 4. CI/CD 대상 flavors & bundle_id 목록 해석
│
├── 5. Fastlane 파일 생성
│   ├── 5.1 ios/Gemfile
│   ├── 5.2 ios/fastlane/Matchfile
│   ├── 5.3 ios/fastlane/Appfile
│   └── 5.4 ios/fastlane/Fastfile
│
├── 6. GitHub Actions 워크플로우 생성
│   └── 6.1 .github/workflows/ios-deploy.yml
│
└── 7. 완료 안내 출력
    ├── 생성된 파일 목록
    ├── 설정해야 할 GitHub Secrets
    └── 다음 단계 (bundle install, match 초기화 등)
```

---

## 9. 멱등성 가드

기존 flavor 파이프라인과 동일하게, 이미 존재하는 파일은 덮어쓰지 않는다.

- 각 Generator에서 파일 존재 여부 확인
- 이미 존재하면 `[skip] ios/Gemfile already exists` 출력
- `--force` 플래그 추가 고려 (덮어쓰기 허용) — 향후 확장

---

## 10. 구현 순서

### Phase 1: 모델 & 설정 파싱
1. `ci_cd_config.dart` — 모델 클래스 정의 + `fromYaml` 파싱
2. `EasySetupConfig` 수정 — `ciCd` 필드 추가
3. 모델 유닛 테스트

### Phase 2: CLI 서브커맨드
4. `bin/easy_setup.dart` — 서브커맨드 라우팅 (`flavor`, `ci-cd`)
5. 하위 호환성 보장 (서브커맨드 생략 시 = `flavor`)

### Phase 3: Fastlane 생성기
6. `GemfileGenerator` — ios/Gemfile 생성
7. `MatchfileGenerator` — ios/fastlane/Matchfile 생성
8. `AppfileGenerator` — ios/fastlane/Appfile 생성
9. `FastfileGenerator` — ios/fastlane/Fastfile 생성
10. 각 Generator 유닛 테스트

### Phase 4: GitHub Actions 생성기
11. `WorkflowGenerator` — .github/workflows/ios-deploy.yml 생성
12. 유닛 테스트

### Phase 5: 오케스트레이터 & 통합 테스트
13. `CiCdCommand` — 전체 파이프라인 오케스트레이션
14. 통합 테스트 (임시 디렉터리에서 전체 실행 검증)

### Phase 6: 문서화
15. README.md 업데이트
16. `_printUsage()` 업데이트

---

## 11. 테스트 계획

```
test/
├── models/
│   ├── flavor_config_test.dart       # 수정 — ciCd 파싱 테스트 추가
│   └── ci_cd_config_test.dart        # 신규
├── fastlane/
│   ├── gemfile_generator_test.dart   # 신규
│   ├── matchfile_generator_test.dart # 신규
│   ├── appfile_generator_test.dart   # 신규
│   └── fastfile_generator_test.dart  # 신규
├── github/
│   └── workflow_generator_test.dart  # 신규
└── commands/
    ├── flavor_command_test.dart       # 기존
    └── ci_cd_command_test.dart        # 신규 — 통합 테스트
```

**테스트 케이스 주요 항목:**
- ci_cd 섹션 파싱 (정상 / 필수 필드 누락 / 옵션 필드 기본값)
- flavor 해석 (ci_cd.flavors 있을 때 / 없을 때)
- 프로비저닝 프로파일 이름 결정 (커스텀 / 기본값)
- 각 Generator의 출력 내용 검증
- 멱등성 (동일 명령 2회 실행 시 skip)
- dry-run 모드에서 파일 미생성

---

## 12. 향후 확장 고려사항

이번 구현 범위에 포함하지 않지만 구조적으로 확장 가능한 항목:

| 항목 | 설명 |
|------|------|
| Android CI/CD | `ci_cd.android` 섹션 추가, Fastlane Supply 또는 Gradle 서명 |
| Firebase App Distribution | Fastlane firebase_app_distribution 플러그인 레인 |
| App Store 직접 배포 | `deliver` 레인 추가 (스크린샷, 메타데이터 포함) |
| 인증서 저장소 타입 확장 | S3, Google Cloud Storage 등 (Match 지원) |
| 인증 방식 확장 | Apple ID + password, Apple ID + 2FA 지원 |
| 커스텀 레인 | 사용자 정의 Fastlane 레인 (코드 푸시, 슬랙 알림 등) |
| Provisioning Profile path | 프로파일 파일 경로 관리 (수동 프로파일 사용 시) |
| `--force` 플래그 | 기존 파일 덮어쓰기 허용 |
