import 'dart:io';

import 'package:path/path.dart' as p;

import '../app_store/app_store_connect_client.dart';
import '../app_store/jwt_generator.dart';
import '../exceptions.dart';
import '../models/flavor_config.dart';
import '../utils/project_finder.dart';

/// Apple Developer Bundle ID 등록 및 App Store Connect 앱 생성을 자동화하는 명령 클래스입니다.
///
/// App Store Connect REST API를 직접 호출하여:
///   1. Apple Developer에 Bundle ID가 없으면 생성
///   2. App Store Connect에 앱이 없으면 생성
///   3. 이미 존재하면 건너뜀
///
/// App Store Connect API Key (.p8 파일)가 필요합니다.
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

    // 5. API Key 파일 검증 (dry-run에서도 실행)
    final ios = ciCd.ios;
    final apiKey = ios.apiKey;
    final keyFilepath = p.join(root, apiKey.keyPath);
    if (!File(keyFilepath).existsSync()) {
      throw SetupException(
        'API Key file not found: $keyFilepath\n'
        'Place your App Store Connect .p8 key file at this path.',
      );
    }

    if (dryRun) {
      print('\n[dry-run mode] No API calls will be made.\n');
      print('  API Key: $keyFilepath');
      print('');
      for (final entry in resolvedFlavors.entries) {
        final info = entry.value;
        print('  Would check/create Bundle ID: ${info.bundleId}');
        print('  Would check/create App: ${info.name} (${info.bundleId})');
      }
      return;
    }

    // 6. API Key로 JWT 생성
    print('\nGenerating JWT token...');
    final jwt = JwtGenerator.generate(
      keyId: apiKey.id,
      issuerId: apiKey.issuerId,
      privateKeyPath: keyFilepath,
      duration: apiKey.duration,
    );

    // 7. API 클라이언트 생성
    final client = AppStoreConnectClient(jwt);

    // 8. 각 flavor에 대해 Bundle ID + App 등록
    print('\n--- Bundle ID & App Registration ---');
    for (final entry in resolvedFlavors.entries) {
      final flavor = entry.key;
      final info = entry.value;

      print('\n[$flavor]');

      // 8.1 Bundle ID 확인/생성
      var bundleIdResourceId = await client.findBundleId(info.bundleId);
      if (bundleIdResourceId != null) {
        print('  Bundle ID already exists: ${info.bundleId}, skipping.');
      } else {
        print('  Creating Bundle ID: ${info.bundleId}');
        bundleIdResourceId = await client.createBundleId(
          info.bundleId,
          info.name,
        );
        print('  Created Bundle ID: ${info.bundleId}');
      }

      // 8.2 App 확인/생성
      final exists = await client.appExists(info.bundleId);
      if (exists) {
        print('  App already exists for: ${info.bundleId}, skipping.');
      } else {
        print('  Creating App: ${info.name}');
        await client.createApp(
          bundleIdResourceId: bundleIdResourceId,
          name: info.name,
          sku: info.bundleId,
        );
        print('  Created App: ${info.name}');
      }
    }

    print('\nRegistration complete!');
  }

  /// CI/CD 대상 flavor의 bundleId + name을 해석합니다.
  ///
  /// 해석 우선순위:
  ///   1. ci_cd.flavors가 있으면 해당 키만 대상
  ///      - bundleId: ci_cd.flavors.{f}.bundle_id → easy_setup.flavors.{f}.bundle_id
  ///      - name: easy_setup.flavors.{f}.name
  ///   2. ci_cd.flavors가 없으면 easy_setup.flavors 전체
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
