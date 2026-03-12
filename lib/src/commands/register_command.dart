import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../exceptions.dart';
import '../models/flavor_config.dart';
import '../utils/project_finder.dart';

/// Apple Developer Bundle ID 등록 및 App Store Connect 앱 생성을 자동화하는 명령 클래스입니다.
///
/// Fastlane의 `produce` 명령을 사용하여:
///   1. Apple Developer에 Bundle ID가 없으면 생성
///   2. App Store Connect에 앱이 없으면 생성
///   3. 이미 존재하면 건너뜀 (produce 내장 기능)
///
/// Fastlane이 설치되어 있어야 하며, App Store Connect API Key (.p8 파일)가 필요합니다.
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

    // 3. ci_cd 섹션 확인 (API Key 필요)
    final ciCd = config.ciCd;
    if (ciCd == null) {
      throw SetupException(
        'No "ci_cd" section found in easy_setup.yaml.\n'
        'The register command requires ci_cd.ios.api_key configuration.',
      );
    }

    // 4. CI/CD 대상 flavor 해석 (bundleId + name 모두 필요)
    final resolvedFlavors = _resolveFlavors(config);
    print('Target flavors: ${resolvedFlavors.keys.join(', ')}');

    if (dryRun) {
      print('\n[dry-run mode] No actions will be taken.\n');
      for (final entry in resolvedFlavors.entries) {
        final info = entry.value;
        print('  Would run: fastlane produce '
            '--app_identifier ${info.bundleId} '
            '--app_name "${info.name}"');
      }
      return;
    }

    // 5. Fastlane 설치 확인
    await _ensureFastlaneInstalled();

    // 6. API Key JSON 파일 생성 (Fastlane 인증용)
    final ios = ciCd.ios;
    final apiKey = ios.apiKey;
    final apiKeyJsonFile = await _createApiKeyJson(
      keyId: apiKey.id,
      issuerId: apiKey.issuerId,
      keyFilepath: p.join(root, apiKey.keyPath),
      duration: apiKey.duration,
      inHouse: apiKey.inHouse,
    );

    try {
      // 7. 각 flavor에 대해 fastlane produce 실행
      print('\n--- Bundle ID & App Registration via fastlane produce ---');
      for (final entry in resolvedFlavors.entries) {
        final flavor = entry.key;
        final info = entry.value;

        print('\n[$flavor]');
        print('  Running: fastlane produce '
            '--app_identifier ${info.bundleId} '
            '--app_name "${info.name}"');

        await _runProduce(
          appIdentifier: info.bundleId,
          appName: info.name,
          sku: info.bundleId,
          teamId: ios.teamId,
          itcTeamId: ios.itcTeamId,
          apiKeyPath: apiKeyJsonFile.path,
        );

        print('  Done: ${info.bundleId}');
      }

      print('\nRegistration complete!');
    } finally {
      // 8. 임시 API Key JSON 파일 정리
      if (apiKeyJsonFile.existsSync()) {
        apiKeyJsonFile.deleteSync();
      }
    }
  }

  /// Fastlane이 설치되어 있는지 확인합니다.
  static Future<void> _ensureFastlaneInstalled() async {
    final result = await Process.run('which', ['fastlane']);
    if (result.exitCode != 0) {
      throw SetupException(
        'Fastlane is not installed.\n'
        'Install it with: brew install fastlane\n'
        'Or: gem install fastlane',
      );
    }
  }

  /// Fastlane API Key 인증용 임시 JSON 파일을 생성합니다.
  static Future<File> _createApiKeyJson({
    required String keyId,
    required String issuerId,
    required String keyFilepath,
    required int duration,
    required bool inHouse,
  }) async {
    if (!File(keyFilepath).existsSync()) {
      throw SetupException(
        'API Key file not found: $keyFilepath\n'
        'Place your App Store Connect .p8 key file at this path.',
      );
    }

    final json = {
      'key_id': keyId,
      'issuer_id': issuerId,
      'key_filepath': keyFilepath,
      'duration': duration,
      'in_house': inHouse,
    };

    final tempFile = File(p.join(
      Directory.systemTemp.path,
      'easy_setup_api_key_${DateTime.now().millisecondsSinceEpoch}.json',
    ));
    await tempFile.writeAsString(jsonEncode(json));
    return tempFile;
  }

  /// `fastlane produce`를 실행합니다.
  static Future<void> _runProduce({
    required String appIdentifier,
    required String appName,
    required String sku,
    required String teamId,
    required String itcTeamId,
    required String apiKeyPath,
  }) async {
    final result = await Process.run('fastlane', [
      'produce',
      '--app_identifier', appIdentifier,
      '--app_name', appName,
      '--sku', sku,
      '--team_id', teamId,
      '--itc_team_id', itcTeamId,
      '--api_key_path', apiKeyPath,
    ]);

    if (result.exitCode != 0) {
      final stderr = (result.stderr as String).trim();
      final stdout = (result.stdout as String).trim();
      throw SetupException(
        'fastlane produce failed for "$appIdentifier":\n'
        '${stderr.isNotEmpty ? stderr : stdout}',
      );
    }

    // produce 출력 표시 (이미 존재/새로 생성 등의 메시지 포함)
    final stdout = (result.stdout as String).trim();
    if (stdout.isNotEmpty) {
      for (final line in stdout.split('\n')) {
        print('  $line');
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
