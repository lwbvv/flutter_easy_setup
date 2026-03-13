import 'package:path/path.dart' as p;

import '../exceptions.dart';
import '../fastlane/appfile_generator.dart';
import '../fastlane/dotenv_generator.dart';
import '../fastlane/fastfile_generator.dart';
import '../fastlane/gemfile_generator.dart';
import '../fastlane/matchfile_generator.dart';
import '../fastlane/metadata_generator.dart';
import '../github/workflow_generator.dart';
import '../models/flavor_config.dart';
import '../utils/fastlane_runner.dart';
import '../utils/project_finder.dart';

/// CI/CD 파이프라인 설정의 전체 파이프라인을 오케스트레이션하는 명령 클래스입니다.
///
/// 아래 순서대로 Fastlane 파일과 GitHub Actions 워크플로우를 생성합니다:
///   1. Flutter 프로젝트 루트 탐지
///   2. easy_setup.yaml 로드
///   3. CI/CD 대상 flavor 및 bundle_id 해석 (easy_setup.flavors에서)
///   4. ci_cd/ios/fastlane/ Fastlane 파일 생성 (.env, Gemfile, Matchfile, Appfile, Fastfile)
///   5. bundle install (fastlane 디렉터리)
///   6. Fastfile에 register lane 추가
///   7. metadata 파일 생성 + update_metadata lane 추가 (선택사항)
///   8. .github/workflows/ios-deploy.yml 생성
class CiCdCommand {
  /// CI/CD 설정 파이프라인을 실행합니다.
  static Future<void> run({bool dryRun = false, String? projectRoot}) async {
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

    // 3. CI/CD 대상 flavor & bundle_id & name 해석
    final resolvedFlavors = _resolveFlavors(config);
    final flavorNames = resolvedFlavors.keys.toList();
    final bundleIds =
        resolvedFlavors.values.map((f) => f.bundleId).toList();

    print('CI/CD flavors: ${flavorNames.join(', ')}');
    if (dryRun) print('\n[dry-run mode] No files will be written.');

    // 4. Fastlane 파일 생성 — ci_cd/ios/fastlane/ 디렉터리에 모든 파일 생성
    print('\n--- Fastlane ---');
    final fastlaneDir = p.join(root, 'ci_cd', 'ios', 'fastlane');
    DotenvGenerator.generate(fastlaneDir, dryRun: dryRun);
    GemfileGenerator.generate(fastlaneDir, dryRun: dryRun);
    MatchfileGenerator.generate(fastlaneDir, bundleIds, dryRun: dryRun);
    AppfileGenerator.generate(fastlaneDir, dryRun: dryRun);
    FastfileGenerator.generate(fastlaneDir, flavorNames, dryRun: dryRun);

    // 5. bundle install (fastlane 디렉터리)
    await FastlaneRunner.bundleInstall(fastlaneDir, dryRun: dryRun);

    // 6. Fastfile에 register lane 추가
    if (!dryRun) {
      print('\n--- Register Lane ---');
      final fastfilePath = p.join(fastlaneDir, 'Fastfile');
      final flavorRecords = resolvedFlavors.map(
        (key, info) => MapEntry(
          key,
          (bundleId: info.bundleId, name: info.name),
        ),
      );
      FastfileGenerator.addRegisterLane(
        fastfilePath: fastfilePath,
        flavors: flavorRecords,
      );
    }

    // 7. metadata 파일 생성 + update_metadata lane 추가 (선택사항)
    if (config.metadata != null && config.metadata!.isNotEmpty) {
      print('\n--- Metadata ---');
      MetadataGenerator.generate(fastlaneDir, config.metadata!, dryRun: dryRun);

      if (!dryRun) {
        final fastfilePath = p.join(fastlaneDir, 'Fastfile');
        FastfileGenerator.addMetadataLane(
          fastfilePath: fastfilePath,
        );
      }
    }

    // 8. GitHub Actions 워크플로우 생성
    print('\n--- GitHub Actions ---');
    WorkflowGenerator.generate(root, flavorNames, dryRun: dryRun);

    // 9. 완료 안내
    final hasMetadata = config.metadata != null && config.metadata!.isNotEmpty;
    _printSummary(dryRun: dryRun, hasMetadata: hasMetadata);
  }

  /// CI/CD 대상 flavor의 bundleId + name을 해석합니다 (easy_setup.flavors에서).
  static Map<String, _FlavorInfo> _resolveFlavors(EasySetupConfig config) {
    if (config.flavors.isEmpty) {
      throw SetupException('No flavors defined in easy_setup.yaml');
    }

    final result = <String, _FlavorInfo>{};
    for (final entry in config.flavors.entries) {
      result[entry.key] = _FlavorInfo(
        bundleId: entry.value.bundleId,
        name: entry.value.name,
      );
    }
    return result;
  }

  static void _printSummary({
    required bool dryRun,
    required bool hasMetadata,
  }) {
    print('\n${dryRun ? "Preview" : "CI/CD setup"} complete!');
    if (!dryRun) {
      print('\nGenerated files:');
      print('  - ci_cd/ios/fastlane/.env');
      print('  - ci_cd/ios/fastlane/Gemfile');
      print('  - ci_cd/ios/fastlane/Matchfile');
      print('  - ci_cd/ios/fastlane/Appfile');
      print('  - ci_cd/ios/fastlane/Fastfile (with register lane)');
      if (hasMetadata) {
        print('  - ci_cd/ios/fastlane/metadata/{locale}/*.txt');
      }
      print('  - .github/workflows/ios-deploy.yml');
      print('\nConfiguration needed:');
      print('  1. Edit ci_cd/ios/fastlane/.env');
      print('     - TEAM_ID, ITC_TEAM_ID, API_KEY_ID, API_KEY_ISSUER_ID, CERTS_REPO_URL');
      print('\nRequired GitHub Secrets:');
      print('  MATCH_PASSWORD              — Match encryption password');
      print('  MATCH_GIT_BASIC_AUTHORIZATION — base64(username:PAT)');
      print('  APP_STORE_CONNECT_API_KEY_BASE64 — base64 of .p8 key file');
      print('\nNext steps:');
      print('  1. Complete the configuration above');
      print('  2. cd ci_cd/ios/fastlane && bundle install');
      print('  3. bundle exec fastlane match init  (first time only)');
      print('  4. Configure GitHub Secrets in your repository settings');
      var step = 5;
      print('  $step. cd ci_cd/ios/fastlane && bundle exec fastlane register');
      print('     (to create apps on App Store Connect — requires 2FA)');
      step++;
      if (hasMetadata) {
        print('  $step. cd ci_cd/ios/fastlane && bundle exec fastlane update_metadata');
        print('     (to upload metadata to App Store Connect)');
      }
    }
  }
}

/// 단일 flavor의 bundleId + name을 담는 내부 클래스입니다.
class _FlavorInfo {
  final String bundleId;
  final String name;

  const _FlavorInfo({required this.bundleId, required this.name});
}
