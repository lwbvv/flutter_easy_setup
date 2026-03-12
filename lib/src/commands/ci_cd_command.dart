import 'dart:io';

import 'package:path/path.dart' as p;

import '../app_store/app_store_connect_client.dart';
import '../app_store/jwt_generator.dart';
import '../exceptions.dart';
import '../fastlane/appfile_generator.dart';
import '../fastlane/fastfile_generator.dart';
import '../fastlane/gemfile_generator.dart';
import '../fastlane/matchfile_generator.dart';
import '../github/workflow_generator.dart';
import '../models/flavor_config.dart';
import '../utils/fastlane_runner.dart';
import '../utils/project_finder.dart';

/// CI/CD 파이프라인 설정의 전체 파이프라인을 오케스트레이션하는 명령 클래스입니다.
///
/// 아래 순서대로 Fastlane 파일과 GitHub Actions 워크플로우를 생성합니다:
///   1. Flutter 프로젝트 루트 탐지
///   2. easy_setup.yaml 로드 및 ci_cd 섹션 파싱
///   3. CI/CD 대상 flavor 및 bundle_id 해석
///   4. 프로젝트 루트 Gemfile 확인/생성 + bundle install
///   5. fastlane/ios/ Fastlane 파일 생성 (Gemfile, Matchfile, Appfile, Fastfile)
///   6. API Key로 Bundle ID 등록
///   7. Fastfile에 register lane 추가
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

    // 4. CI/CD 대상 flavor & bundle_id & name 해석
    final resolvedFlavors = _resolveFlavors(config);
    final flavorNames = resolvedFlavors.keys.toList();
    final bundleIds =
        resolvedFlavors.values.map((f) => f.bundleId).toList();

    print('CI/CD flavors: ${flavorNames.join(', ')}');
    if (dryRun) print('\n[dry-run mode] No files will be written.');

    // 5. 프로젝트 루트 Gemfile 확인/생성 + bundle install
    await FastlaneRunner.setup(root, dryRun: dryRun);

    // 6. Fastlane 파일 생성 — fastlane/ios/ 디렉터리에 모든 파일 생성
    print('\n--- Fastlane ---');
    final fastlaneDir = p.join(root, 'fastlane', 'ios');
    GemfileGenerator.generate(fastlaneDir, dryRun: dryRun);
    MatchfileGenerator.generate(fastlaneDir, ciCd.ios, bundleIds,
        dryRun: dryRun);
    AppfileGenerator.generate(fastlaneDir, ciCd.ios, dryRun: dryRun);
    FastfileGenerator.generate(fastlaneDir, ciCd.ios, flavorNames,
        dryRun: dryRun);

    // 7. Bundle ID 등록 + register lane 추가
    final ios = ciCd.ios;
    final apiKey = ios.apiKey;
    final keyFilepath = p.join(root, apiKey.keyPath);
    final hasApiKey = File(keyFilepath).existsSync();

    if (hasApiKey && !dryRun) {
      // API Key로 Bundle ID 자동 등록
      print('\n--- Bundle ID Registration ---');
      print('Generating JWT token...');
      final jwt = JwtGenerator.generate(
        keyId: apiKey.id,
        issuerId: apiKey.issuerId,
        privateKeyPath: keyFilepath,
        duration: apiKey.duration,
      );

      final client = AppStoreConnectClient(jwt);

      for (final entry in resolvedFlavors.entries) {
        final flavor = entry.key;
        final info = entry.value;

        print('\n[$flavor]');
        final existing = await client.findBundleId(info.bundleId);
        if (existing != null) {
          print('  Bundle ID already exists: ${info.bundleId}');
        } else {
          print('  Registering Bundle ID: ${info.bundleId}');
          await client.createBundleId(info.bundleId, info.name);
          print('  Registered Bundle ID: ${info.bundleId}');
        }
      }
    } else if (!hasApiKey) {
      print('\n--- Bundle ID Registration ---');
      print('  Skipped: API Key file not found at $keyFilepath');
      print('  Place your .p8 key file there to enable auto-registration.');
    }

    // 8. Fastfile에 register lane 추가
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
        ios: ios,
        flavors: flavorRecords,
      );
    }

    // 9. GitHub Actions 워크플로우 생성
    print('\n--- GitHub Actions ---');
    WorkflowGenerator.generate(root, flavorNames, dryRun: dryRun);

    // 10. 완료 안내
    _printSummary(dryRun: dryRun, hasApiKey: hasApiKey);
  }

  /// CI/CD 대상 flavor의 bundleId + name을 해석합니다.
  static Map<String, _FlavorInfo> _resolveFlavors(EasySetupConfig config) {
    final ciCd = config.ciCd!;
    final result = <String, _FlavorInfo>{};

    if (ciCd.flavors != null && ciCd.flavors!.isNotEmpty) {
      for (final entry in ciCd.flavors!.entries) {
        final flavorName = entry.key;
        final ciCdFlavor = entry.value;

        final bundleId = ciCdFlavor.bundleId ??
            config.flavors[flavorName]?.bundleId;
        final name = config.flavors[flavorName]?.name;

        if (bundleId == null) {
          throw SetupException(
            'Flavor "$flavorName" in ci_cd.flavors not found in easy_setup.flavors '
            'and no bundle_id override provided.',
          );
        }
        if (name == null) {
          throw SetupException(
            'Flavor "$flavorName": could not resolve app name.\n'
            'Ensure the flavor is defined in easy_setup.flavors with a name.',
          );
        }

        result[flavorName] = _FlavorInfo(bundleId: bundleId, name: name);
      }
    } else {
      if (config.flavors.isEmpty) {
        throw SetupException('No flavors defined in easy_setup.yaml');
      }
      for (final entry in config.flavors.entries) {
        result[entry.key] = _FlavorInfo(
          bundleId: entry.value.bundleId,
          name: entry.value.name,
        );
      }
    }

    return result;
  }

  static void _printSummary({required bool dryRun, required bool hasApiKey}) {
    print('\n${dryRun ? "Preview" : "CI/CD setup"} complete!');
    if (!dryRun) {
      print('\nGenerated files:');
      print('  - Gemfile (project root)');
      print('  - fastlane/ios/Gemfile');
      print('  - fastlane/ios/Matchfile');
      print('  - fastlane/ios/Appfile');
      print('  - fastlane/ios/Fastfile (with register lane)');
      print('  - .github/workflows/ios-deploy.yml');
      print('\nRequired GitHub Secrets:');
      print('  MATCH_PASSWORD              — Match encryption password');
      print('  MATCH_GIT_BASIC_AUTHORIZATION — base64(username:PAT)');
      print('  APP_STORE_CONNECT_API_KEY_BASE64 — base64 of .p8 key file');
      print('\nNext steps:');
      print('  1. cd fastlane/ios && bundle install');
      print('  2. bundle exec fastlane match init  (first time only)');
      print('  3. Configure GitHub Secrets in your repository settings');
      if (hasApiKey) {
        print('  4. cd fastlane/ios && bundle exec fastlane register');
        print('     (to create apps on App Store Connect — requires 2FA)');
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
