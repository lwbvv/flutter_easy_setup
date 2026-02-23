import '../exceptions.dart';
import '../fastlane/appfile_generator.dart';
import '../fastlane/fastfile_generator.dart';
import '../fastlane/gemfile_generator.dart';
import '../fastlane/matchfile_generator.dart';
import '../github/workflow_generator.dart';
import '../models/flavor_config.dart';
import '../utils/project_finder.dart';

/// CI/CD 파이프라인 설정의 전체 파이프라인을 오케스트레이션하는 명령 클래스입니다.
///
/// 아래 순서대로 Fastlane 파일과 GitHub Actions 워크플로우를 생성합니다:
///   1. Flutter 프로젝트 루트 탐지
///   2. easy_setup.yaml 로드 및 ci_cd 섹션 파싱
///   3. CI/CD 대상 flavor 및 bundle_id 해석
///   4. ios/Gemfile 생성
///   5. ios/fastlane/Matchfile 생성
///   6. ios/fastlane/Appfile 생성
///   7. ios/fastlane/Fastfile 생성
///   8. .github/workflows/ios-deploy.yml 생성
class CiCdCommand {
  /// CI/CD 설정 파이프라인을 실행합니다.
  static void run({bool dryRun = false, String? projectRoot}) {
    // 1. Flutter 프로젝트 루트 확인
    final root = projectRoot ?? ProjectFinder.findFlutterRoot();
    if (root == null) {
      throw SetupException(
        'Could not find a Flutter project root.\n'
        'Run this command from inside a Flutter project directory.',
      );
    }
    print('Flutter project root: $root');

    // 2. easy_setup.yaml 로드
    final configPath = ProjectFinder.configPath(root);
    print('Loading config from: $configPath');
    final config = EasySetupConfig.fromFile(configPath);

    // 3. ci_cd 섹션 존재 확인
    final ciCd = config.ciCd;
    if (ciCd == null) {
      throw SetupException(
        'No "ci_cd" section found in easy_setup.yaml.\n'
        'Add a ci_cd section with iOS configuration.\n'
        'Example:\n'
        'easy_setup:\n'
        '  ci_cd:\n'
        '    ios:\n'
        '      storage: https://github.com/user/certs.git\n'
        '      team_id: XXXXXXXXXX\n'
        '      itc_team_id: YYYYYYYYYY\n'
        '      api_key:\n'
        '        id: KEY_ID\n'
        '        issuer_id: ISSUER_ID\n'
        '        key_path: fastlane/AuthKey.p8',
      );
    }

    // 4. CI/CD 대상 flavor & bundle_id 해석
    final Map<String, String> resolvedFlavors;
    if (ciCd.flavors != null && ciCd.flavors!.isNotEmpty) {
      // ci_cd.flavors가 명시된 경우: 해당 키만 대상
      resolvedFlavors = {};
      for (final entry in ciCd.flavors!.entries) {
        final flavorName = entry.key;
        final ciCdFlavor = entry.value;
        if (ciCdFlavor.bundleId != null) {
          resolvedFlavors[flavorName] = ciCdFlavor.bundleId!;
        } else if (config.flavors.containsKey(flavorName)) {
          resolvedFlavors[flavorName] = config.flavors[flavorName]!.bundleId;
        } else {
          throw SetupException(
            'Flavor "$flavorName" in ci_cd.flavors not found in easy_setup.flavors '
            'and no bundle_id override provided.',
          );
        }
      }
    } else {
      // ci_cd.flavors 미지정: easy_setup.flavors 전체 사용
      if (config.flavors.isEmpty) {
        throw SetupException('No flavors defined in easy_setup.yaml');
      }
      resolvedFlavors = {
        for (final entry in config.flavors.entries)
          entry.key: entry.value.bundleId,
      };
    }

    final flavorNames = resolvedFlavors.keys.toList();
    final bundleIds = resolvedFlavors.values.toList();

    print('CI/CD flavors: ${flavorNames.join(', ')}');
    if (dryRun) print('\n[dry-run mode] No files will be written.');

    // 5. Fastlane 파일 생성
    print('\n--- Fastlane ---');
    GemfileGenerator.generate(root, dryRun: dryRun);
    MatchfileGenerator.generate(root, ciCd.ios, bundleIds, dryRun: dryRun);
    AppfileGenerator.generate(root, ciCd.ios, dryRun: dryRun);
    FastfileGenerator.generate(root, ciCd.ios, flavorNames, dryRun: dryRun);

    // 6. GitHub Actions 워크플로우 생성
    print('\n--- GitHub Actions ---');
    WorkflowGenerator.generate(root, flavorNames, dryRun: dryRun);

    // 7. 완료 안내
    _printSummary(dryRun: dryRun);
  }

  static void _printSummary({required bool dryRun}) {
    print('\n${dryRun ? "Preview" : "CI/CD setup"} complete!');
    if (!dryRun) {
      print('\nGenerated files:');
      print('  - ios/Gemfile');
      print('  - ios/fastlane/Matchfile');
      print('  - ios/fastlane/Appfile');
      print('  - ios/fastlane/Fastfile');
      print('  - .github/workflows/ios-deploy.yml');
      print('\nRequired GitHub Secrets:');
      print('  MATCH_PASSWORD              — Match encryption password');
      print('  MATCH_GIT_BASIC_AUTHORIZATION — base64(username:PAT)');
      print('  APP_STORE_CONNECT_API_KEY_BASE64 — base64 of .p8 key file');
      print('\nNext steps:');
      print('  1. cd ios && bundle install');
      print('  2. bundle exec fastlane match init  (first time only)');
      print('  3. Configure GitHub Secrets in your repository settings');
    }
  }
}
