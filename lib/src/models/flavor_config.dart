import 'dart:io';

import 'package:yaml/yaml.dart';

import '../exceptions.dart';
import 'ci_cd_config.dart' show LocaleMetadataConfig;

/// Android signing 설정을 담는 모델 클래스입니다.
class SigningConfig {
  final String keystore;
  final String alias;

  const SigningConfig({required this.keystore, required this.alias});

  factory SigningConfig.fromYaml(Map yaml) {
    return SigningConfig(
      keystore: yaml['keystore'] as String,
      alias: yaml['alias'] as String,
    );
  }
}

/// Firebase 설정 파일 경로를 담는 모델 클래스입니다.
class FirebaseConfig {
  final String? android;
  final String? ios;

  const FirebaseConfig({this.android, this.ios});

  factory FirebaseConfig.fromYaml(Map yaml) {
    return FirebaseConfig(
      android: yaml['android'] as String?,
      ios: yaml['ios'] as String?,
    );
  }
}

/// iOS flavor별 추가 설정을 담는 모델 클래스입니다.
class IosFlavorConfig {
  final String? teamId;
  final String? provisioningProfile;
  final String? codeSignIdentity;
  final String? entitlements;

  const IosFlavorConfig({
    this.teamId,
    this.provisioningProfile,
    this.codeSignIdentity,
    this.entitlements,
  });

  factory IosFlavorConfig.fromYaml(Map yaml) {
    return IosFlavorConfig(
      teamId: yaml['team_id'] as String?,
      provisioningProfile: yaml['provisioning_profile'] as String?,
      codeSignIdentity: yaml['code_sign_identity'] as String?,
      entitlements: yaml['entitlements'] as String?,
    );
  }
}

/// Flavor별 locale 설정을 담는 모델 클래스입니다.
///
/// [appIcon]: locale별 앱 아이콘 소스 이미지 경로 (1024x1024 PNG)
/// [appName]: locale별 앱 표시 이름
class FlavorLocalizedConfig {
  final String? appIcon;
  final String? appName;

  const FlavorLocalizedConfig({this.appIcon, this.appName});

  factory FlavorLocalizedConfig.fromYaml(Map yaml) {
    return FlavorLocalizedConfig(
      appIcon: yaml['app_icon'] as String?,
      appName: yaml['app_name'] as String?,
    );
  }
}

/// 전역 locale 설정을 담는 모델 클래스입니다.
///
/// [permission]: iOS 권한 설명 문자열 맵 (NSCameraUsageDescription 등)
class GlobalLocalizedConfig {
  final Map<String, String>? permission;

  const GlobalLocalizedConfig({this.permission});

  factory GlobalLocalizedConfig.fromYaml(Map yaml) {
    Map<String, String>? permission;
    final permMap = yaml['permission'];
    if (permMap != null) {
      permission = <String, String>{};
      for (final entry in (permMap as Map).entries) {
        permission[entry.key as String] = entry.value as String;
      }
    }
    return GlobalLocalizedConfig(permission: permission);
  }
}

/// 단일 flavor의 설정값을 담는 모델 클래스입니다.
///
/// [bundleId]: 앱의 고유 식별자 (예: com.example.app.dev)
/// [name]: 사용자에게 보이는 앱 이름 (예: MyApp Dev)
class FlavorConfig {
  final String bundleId;
  final String name;
  final int? versionCode;
  final String? versionName;
  final SigningConfig? signing;
  final FirebaseConfig? firebase;
  final IosFlavorConfig? ios;
  final String? appIcon;
  final Map<String, FlavorLocalizedConfig>? localized;

  const FlavorConfig({
    required this.bundleId,
    required this.name,
    this.versionCode,
    this.versionName,
    this.signing,
    this.firebase,
    this.ios,
    this.appIcon,
    this.localized,
  });

  /// YAML 맵으로부터 FlavorConfig 인스턴스를 생성합니다.
  factory FlavorConfig.fromYaml(Map yaml) {
    Map<String, FlavorLocalizedConfig>? localized;
    final localizedMap = yaml['localized'];
    if (localizedMap != null) {
      localized = <String, FlavorLocalizedConfig>{};
      for (final entry in (localizedMap as Map).entries) {
        localized[entry.key as String] =
            FlavorLocalizedConfig.fromYaml(entry.value as Map);
      }
    }

    return FlavorConfig(
      bundleId: yaml['bundle_id'] as String,
      name: yaml['name'] as String,
      versionCode: yaml['version_code'] as int?,
      versionName: yaml['version_name'] as String?,
      signing: yaml['signing'] != null
          ? SigningConfig.fromYaml(yaml['signing'] as Map)
          : null,
      firebase: yaml['firebase'] != null
          ? FirebaseConfig.fromYaml(yaml['firebase'] as Map)
          : null,
      ios: yaml['ios'] != null
          ? IosFlavorConfig.fromYaml(yaml['ios'] as Map)
          : null,
      appIcon: yaml['app_icon'] as String?,
      localized: localized,
    );
  }
}

/// easy_setup.yaml 파일 전체를 파싱한 결과를 담는 클래스입니다.
///
/// [flavors]: flavor 이름(dev, prod 등)을 키로, [FlavorConfig]를 값으로 하는 맵
/// [localized]: 선택사항 — 전역 locale 설정 (permission 등)
/// [metadata]: 선택사항 — App Store Connect 메타데이터 (locale별)
class EasySetupConfig {
  final Map<String, FlavorConfig> flavors;
  final Map<String, GlobalLocalizedConfig>? localized;
  final Map<String, LocaleMetadataConfig>? metadata;

  const EasySetupConfig({
    required this.flavors,
    this.localized,
    this.metadata,
  });

  /// [path]에 위치한 easy_setup.yaml 파일을 읽고 파싱합니다.
  ///
  /// 파일이 없으면 사용 예시와 함께 [SetupException]을 throw합니다.
  /// YAML 구문 오류 시에도 [SetupException]을 throw합니다.
  factory EasySetupConfig.fromFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw SetupException(
        'easy_setup.yaml not found at $path\n'
        'Create it with:\n'
        'easy_setup:\n'
        '  flavors:\n'
        '    dev:\n'
        '      bundle_id: com.example.app.dev\n'
        '      name: MyApp Dev',
      );
    }
    try {
      final doc = loadYaml(file.readAsStringSync()) as Map;
      final easySetup = doc['easy_setup'];
      if (easySetup == null || easySetup is! Map) {
        throw SetupException(
          'Missing "easy_setup" key in easy_setup.yaml.\n'
          'Expected structure:\n'
          'easy_setup:\n'
          '  flavors:\n'
          '    dev:\n'
          '      bundle_id: com.example.app.dev\n'
          '      name: MyApp Dev',
        );
      }
      final flavorsMap = easySetup['flavors'] as Map;
      final flavors = <String, FlavorConfig>{};
      for (final entry in flavorsMap.entries) {
        flavors[entry.key as String] = FlavorConfig.fromYaml(entry.value as Map);
      }

      Map<String, GlobalLocalizedConfig>? localized;
      final localizedMap = easySetup['localized'];
      if (localizedMap != null) {
        localized = <String, GlobalLocalizedConfig>{};
        for (final entry in (localizedMap as Map).entries) {
          localized[entry.key as String] =
              GlobalLocalizedConfig.fromYaml(entry.value as Map);
        }
      }

      Map<String, LocaleMetadataConfig>? metadata;
      final metadataMap = easySetup['metadata'];
      if (metadataMap != null) {
        metadata = <String, LocaleMetadataConfig>{};
        for (final entry in (metadataMap as Map).entries) {
          metadata[entry.key as String] =
              LocaleMetadataConfig.fromYaml(entry.value as Map);
        }
      }

      return EasySetupConfig(
        flavors: flavors,
        localized: localized,
        metadata: metadata,
      );
    } catch (e) {
      if (e is SetupException) rethrow;
      throw SetupException('Failed to parse easy_setup.yaml: $e');
    }
  }
}
