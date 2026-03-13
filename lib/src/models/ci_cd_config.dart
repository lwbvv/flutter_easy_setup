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
  final String? appleId;
  final String? appleIdPassword;

  const CiCdIosConfig({
    required this.storage,
    required this.teamId,
    required this.itcTeamId,
    required this.apiKey,
    this.appleId,
    this.appleIdPassword,
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
    final apiKeyYaml = apiKeyMap as Map;
    return CiCdIosConfig(
      storage: storage as String,
      teamId: teamId as String,
      itcTeamId: itcTeamId as String,
      apiKey: ApiKeyConfig.fromYaml(apiKeyYaml),
      appleId: (yaml['apple_id'] ?? apiKeyYaml['apple_id']) as String?,
      appleIdPassword: (yaml['apple_id_password'] ?? apiKeyYaml['apple_id_password']) as String?,
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

/// 단일 locale의 메타데이터 설정
class LocaleMetadataConfig {
  final String? promotionalText;
  final String? description;
  final String? releaseNotes;
  final String? keywords;
  final String? name;
  final String? subtitle;
  final String? privacyUrl;
  final String? supportUrl;
  final String? marketingUrl;

  const LocaleMetadataConfig({
    this.promotionalText,
    this.description,
    this.releaseNotes,
    this.keywords,
    this.name,
    this.subtitle,
    this.privacyUrl,
    this.supportUrl,
    this.marketingUrl,
  });

  factory LocaleMetadataConfig.fromYaml(Map yaml) {
    return LocaleMetadataConfig(
      promotionalText: yaml['promotional_text'] as String?,
      description: yaml['description'] as String?,
      releaseNotes: yaml['release_notes'] as String?,
      keywords: yaml['keywords'] as String?,
      name: yaml['name'] as String?,
      subtitle: yaml['subtitle'] as String?,
      privacyUrl: yaml['privacy_url'] as String?,
      supportUrl: yaml['support_url'] as String?,
      marketingUrl: yaml['marketing_url'] as String?,
    );
  }

  /// 설정된 필드를 파일명 → 값 맵으로 반환합니다.
  Map<String, String> toFileMap() {
    final map = <String, String>{};
    if (promotionalText != null) {
      map['promotional_text.txt'] = promotionalText!;
    }
    if (description != null) map['description.txt'] = description!;
    if (releaseNotes != null) map['release_notes.txt'] = releaseNotes!;
    if (keywords != null) map['keywords.txt'] = keywords!;
    if (name != null) map['name.txt'] = name!;
    if (subtitle != null) map['subtitle.txt'] = subtitle!;
    if (privacyUrl != null) map['privacy_url.txt'] = privacyUrl!;
    if (supportUrl != null) map['support_url.txt'] = supportUrl!;
    if (marketingUrl != null) map['marketing_url.txt'] = marketingUrl!;
    return map;
  }
}

/// CI/CD 최상위 설정
class CiCdConfig {
  final Map<String, CiCdFlavorConfig>? flavors;
  final CiCdIosConfig ios;
  final ProvisioningProfileConfig? provisioningProfile;
  final Map<String, LocaleMetadataConfig>? metadata;

  const CiCdConfig({
    this.flavors,
    required this.ios,
    this.provisioningProfile,
    this.metadata,
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

    Map<String, LocaleMetadataConfig>? metadata;
    final metadataMap = yaml['metadata'];
    if (metadataMap != null) {
      metadata = <String, LocaleMetadataConfig>{};
      for (final entry in (metadataMap as Map).entries) {
        metadata[entry.key as String] =
            LocaleMetadataConfig.fromYaml(entry.value as Map);
      }
    }

    return CiCdConfig(
      flavors: flavors,
      ios: CiCdIosConfig.fromYaml(iosMap as Map),
      provisioningProfile: yaml['provisioning_profile'] != null
          ? ProvisioningProfileConfig.fromYaml(
              yaml['provisioning_profile'] as Map)
          : null,
      metadata: metadata,
    );
  }
}
