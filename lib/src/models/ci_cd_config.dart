/// Metadata configuration for a single locale
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

  /// Returns the configured fields as a filename-to-value map.
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
