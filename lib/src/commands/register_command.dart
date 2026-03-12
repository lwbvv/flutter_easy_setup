import 'dart:io';

import 'package:path/path.dart' as p;

import '../app_store/app_store_connect_client.dart';
import '../app_store/jwt_generator.dart';
import '../exceptions.dart';
import '../models/flavor_config.dart';
import '../utils/fastlane_runner.dart';
import '../utils/project_finder.dart';

/// Apple Developer Bundle ID 등록 및 App Store Connect 앱 생성을 자동화하는 명령 클래스입니다.
///
/// 동작 방식:
///   1. API Key로 Bundle ID를 App Store Connect에 등록합니다.
///   2. Bundle ID 등록 후 fastlane produce를 호출하여 앱을 생성합니다.
///   3. 이미 존재하는 Bundle ID/앱은 건너뜁니다.
///
/// Apple ID와 비밀번호가 필요합니다 (환경변수로 전달 가능).
class RegisterCommand {
  /// register 파이프라인을 실행합니다.
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

    // 3. ci_cd 섹션 확인
    final ciCd = config.ciCd;
    if (ciCd == null) {
      throw SetupException(
        'No "ci_cd" section found in easy_setup.yaml.\n'
        'The register command requires ci_cd.ios configuration.',
      );
    }

    // 4. CI/CD 대상 flavor 해석
    final resolvedFlavors = _resolveFlavors(config);
    print('Target flavors: ${resolvedFlavors.keys.join(', ')}');

    // 5. 의존성 검증
    final ios = ciCd.ios;
    final apiKey = ios.apiKey;
    final keyFilepath = p.join(root, apiKey.keyPath);
    if (!File(keyFilepath).existsSync()) {
      throw SetupException(
        'API Key file not found: $keyFilepath\n'
        'Place your App Store Connect .p8 key file at this path.',
      );
    }

    // Apple ID 정보 확인
    final appleId = ios.appleId ?? Platform.environment['FASTLANE_USER'];
    final appleIdPassword = ios.appleIdPassword ?? Platform.environment['FASTLANE_PASSWORD'];

    if (dryRun) {
      print('\n[dry-run mode] No actions will be taken.\n');
      print('  API Key:  $keyFilepath');
      if (appleId != null) {
        print('  Apple ID: $appleId');
      } else {
        print('  Apple ID: (from FASTLANE_USER env var)');
      }
      print('');
      for (final entry in resolvedFlavors.entries) {
        final info = entry.value;
        print('  1. Register Bundle ID: ${info.bundleId}');
        print('  2. Create App via fastlane produce: ${info.name}');
      }
      return;
    }

    // 6. Gemfile 준비
    await FastlaneRunner.setup(root, dryRun: false);

    // 7. API Key로 JWT 생성
    print('\nGenerating JWT token...');
    final jwt = JwtGenerator.generate(
      keyId: apiKey.id,
      issuerId: apiKey.issuerId,
      privateKeyPath: keyFilepath,
      duration: apiKey.duration,
    );

    // 8. API 클라이언트 생성
    final client = AppStoreConnectClient(jwt);

    // 9. 각 flavor에 대해 Bundle ID 등록 후 fastlane produce 실행
    print('\n--- Bundle ID Registration & App Creation ---');
    for (final entry in resolvedFlavors.entries) {
      final flavor = entry.key;
      final info = entry.value;

      print('\n[$flavor]');

      // 9.1 Bundle ID 등록
      final bundleIdResourceId = await client.findBundleId(info.bundleId);
      if (bundleIdResourceId != null) {
        print('  Bundle ID already exists: ${info.bundleId}');
      } else {
        print('  Registering Bundle ID: ${info.bundleId}');
        await client.createBundleId(
          info.bundleId,
          info.name,
        );
        print('  Registered Bundle ID: ${info.bundleId}');
      }

      // 9.2 fastlane produce로 앱 생성
      print('  Creating App via fastlane produce: ${info.name}');
      await _runProduce(
        root: root,
        bundleId: info.bundleId,
        appName: info.name,
        sku: info.bundleId,
        teamId: ios.teamId,
        itcTeamId: ios.itcTeamId,
        appleId: appleId,
        appleIdPassword: appleIdPassword,
      );
      print('  Done: ${info.bundleId}');
    }

    print('\nRegistration complete!');
  }

  /// `bundle exec fastlane produce`를 실행하여 앱을 생성합니다.
  static Future<void> _runProduce({
    required String root,
    required String bundleId,
    required String appName,
    required String sku,
    required String teamId,
    required String itcTeamId,
    required String? appleId,
    required String? appleIdPassword,
  }) async {
    final args = [
      'produce',
      '--app_identifier', bundleId,
      '--app_name', appName,
      '--sku', sku,
      '--team_id', teamId,
      '--itc_team_id', itcTeamId,
    ];

    // Apple ID 지정
    if (appleId != null) {
      args.addAll(['--username', appleId]);
    }

    final result = await FastlaneRunner.run(root, args);

    if (result.exitCode != 0) {
      final stderr = (result.stderr as String).trim();
      final stdout = (result.stdout as String).trim();
      throw SetupException(
        'fastlane produce failed for "$bundleId":\n'
        '${stderr.isNotEmpty ? stderr : stdout}',
      );
    }

    // produce 출력 표시
    final stdout = (result.stdout as String).trim();
    if (stdout.isNotEmpty) {
      for (final line in stdout.split('\n')) {
        if (line.isNotEmpty) {
          print('    $line');
        }
      }
    }
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
            'Flavor "$flavorName" in ci_cd.flavors: '
            'could not resolve bundle_id.',
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
}

/// 단일 flavor의 등록에 필요한 정보를 담는 내부 클래스입니다.
class _FlavorInfo {
  final String bundleId;
  final String name;

  const _FlavorInfo({required this.bundleId, required this.name});
}
