import '../exceptions.dart';

/// App Store Connect API Key 설정
class ApiKeyConfig {
  final String id;
  final String issuerId;
  final String keyPath;
  final int duration;
  final bool inHouse;

  const ApiKeyConfig({
    required this.id,
    required this.issuerId,
    required this.keyPath,
    this.duration = 1200,
    this.inHouse = false,
  });

  factory ApiKeyConfig.fromYaml(Map yaml) {
    final id = yaml['id'];
    final issuerId = yaml['issuer_id'];
    final keyPath = yaml['key_path'];
    if (id == null || issuerId == null || keyPath == null) {
      throw SetupException(
        'api_key requires "id", "issuer_id", and "key_path" fields.',
      );
    }
    return ApiKeyConfig(
      id: id as String,
      issuerId: issuerId as String,
      keyPath: keyPath as String,
      duration: (yaml['duration'] as int?) ?? 1200,
      inHouse: (yaml['in_house'] as bool?) ?? false,
    );
  }
}

/// 프로비저닝 프로파일 타입별 설정
class ProfileTypeConfig {
  final String? name;

  const ProfileTypeConfig({this.name});

  factory ProfileTypeConfig.fromYaml(Map yaml) {
    return ProfileTypeConfig(name: yaml['name'] as String?);
  }
}

/// 프로비저닝 프로파일 설정 (build type별)
class ProvisioningProfileConfig {
  final ProfileTypeConfig? debug;
  final ProfileTypeConfig? profile;
  final ProfileTypeConfig? release;

  const ProvisioningProfileConfig({this.debug, this.profile, this.release});

  factory ProvisioningProfileConfig.fromYaml(Map yaml) {
    return ProvisioningProfileConfig(
      debug: yaml['debug'] != null
          ? ProfileTypeConfig.fromYaml(yaml['debug'] as Map)
          : null,
      profile: yaml['profile'] != null
          ? ProfileTypeConfig.fromYaml(yaml['profile'] as Map)
          : null,
      release: yaml['release'] != null
          ? ProfileTypeConfig.fromYaml(yaml['release'] as Map)
          : null,
    );
  }
}

/// iOS CI/CD 설정
class CiCdIosConfig {
  final String storage;
  final String teamId;
  final String itcTeamId;
  final ApiKeyConfig apiKey;

  const CiCdIosConfig({
    required this.storage,
    required this.teamId,
    required this.itcTeamId,
    required this.apiKey,
  });

  factory CiCdIosConfig.fromYaml(Map yaml) {
    final storage = yaml['storage'];
    final teamId = yaml['team_id'];
    final itcTeamId = yaml['itc_team_id'];
    final apiKeyMap = yaml['api_key'];
    if (storage == null || teamId == null || itcTeamId == null || apiKeyMap == null) {
      throw SetupException(
        'ci_cd.ios requires "storage", "team_id", "itc_team_id", and "api_key" fields.',
      );
    }
    return CiCdIosConfig(
      storage: storage as String,
      teamId: teamId as String,
      itcTeamId: itcTeamId as String,
      apiKey: ApiKeyConfig.fromYaml(apiKeyMap as Map),
    );
  }
}

/// CI/CD flavor 설정 (bundle_id override)
class CiCdFlavorConfig {
  final String? bundleId;

  const CiCdFlavorConfig({this.bundleId});

  factory CiCdFlavorConfig.fromYaml(Map yaml) {
    return CiCdFlavorConfig(bundleId: yaml['bundle_id'] as String?);
  }
}

/// CI/CD 최상위 설정
class CiCdConfig {
  final Map<String, CiCdFlavorConfig>? flavors;
  final CiCdIosConfig ios;
  final ProvisioningProfileConfig? provisioningProfile;

  const CiCdConfig({
    this.flavors,
    required this.ios,
    this.provisioningProfile,
  });

  factory CiCdConfig.fromYaml(Map yaml) {
    final iosMap = yaml['ios'];
    if (iosMap == null) {
      throw SetupException('ci_cd requires "ios" section.');
    }

    Map<String, CiCdFlavorConfig>? flavors;
    final flavorsMap = yaml['flavors'];
    if (flavorsMap != null) {
      flavors = <String, CiCdFlavorConfig>{};
      for (final entry in (flavorsMap as Map).entries) {
        flavors[entry.key as String] =
            CiCdFlavorConfig.fromYaml(entry.value as Map);
      }
    }

    return CiCdConfig(
      flavors: flavors,
      ios: CiCdIosConfig.fromYaml(iosMap as Map),
      provisioningProfile: yaml['provisioning_profile'] != null
          ? ProvisioningProfileConfig.fromYaml(
              yaml['provisioning_profile'] as Map)
          : null,
    );
  }
}
