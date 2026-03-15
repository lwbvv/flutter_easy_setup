import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/flavor_config.dart';

/// iOS locale별 InfoPlist.strings 파일을 생성하는 클래스입니다.
///
/// 기본 permission은 en.lproj에 포함되고, locale별 permission은 각 locale.lproj에,
/// flavor별 app_name은 xcconfig 변수를 참조하는 CFBundleDisplayName으로 생성합니다.
class InfoPlistStringsGenerator {
  /// InfoPlist.strings 파일들을 생성합니다.
  ///
  /// [projectRoot]: Flutter 프로젝트 루트
  /// [flavorLocalized]: flavor별 locale 설정 (app_name 등)
  /// [permission]: 기본 iOS 권한 설명 (en.lproj에 기록)
  /// [localizedPermission]: locale별 iOS 권한 설명
  static void generate(
    String projectRoot, {
    Map<String, FlavorLocalizedConfig>? flavorLocalized,
    Map<String, String>? permission,
    Map<String, Map<String, String>>? localizedPermission,
    bool dryRun = false,
  }) {
    final hasBase = permission != null && permission.isNotEmpty;
    final hasLocalized = localizedPermission != null && localizedPermission.isNotEmpty;
    final hasFlavor = flavorLocalized != null && flavorLocalized.isNotEmpty;

    if (!hasBase && !hasLocalized && !hasFlavor) return;

    print('\n--- iOS InfoPlist.strings ---');

    // 모든 locale 키를 수집
    final allLocales = <String>{};
    if (hasFlavor) allLocales.addAll(flavorLocalized.keys);
    if (hasLocalized) allLocales.addAll(localizedPermission.keys);
    // 기본 permission이 있으면 en locale에 포함
    if (hasBase) allLocales.add('en');

    for (final locale in allLocales) {
      final entries = <String, String>{};

      // flavor별 app_name → CFBundleDisplayName
      // en: xcconfig의 APP_DISPLAY_NAME 변수를 참조 (flavor별로 다름)
      // 그 외 locale: easy_setup.yaml의 값을 그대로 사용
      final flavorConfig = flavorLocalized?[locale];
      if (flavorConfig?.appName != null) {
        if (locale == 'en') {
          entries['CFBundleDisplayName'] = '(\$APP_DISPLAY_NAME)';
        } else {
          entries['CFBundleDisplayName'] = flavorConfig!.appName!;
        }
      }

      // 기본 permission을 en locale에 포함
      if (locale == 'en' && hasBase) {
        entries.addAll(permission);
      }

      // locale별 permission
      final localePerms = localizedPermission?[locale];
      if (localePerms != null) {
        entries.addAll(localePerms);
      }

      if (entries.isEmpty) continue;

      _writeStringsFile(
        projectRoot,
        locale,
        entries,
        dryRun: dryRun,
      );
    }
  }

  /// 단일 locale의 InfoPlist.strings 파일을 생성합니다.
  static void _writeStringsFile(
    String projectRoot,
    String locale,
    Map<String, String> entries, {
    required bool dryRun,
  }) {
    final lprojDir = p.join(projectRoot, 'ios', 'Runner', '$locale.lproj');
    final stringsPath = p.join(lprojDir, 'InfoPlist.strings');

    if (dryRun) {
      print('  [dry-run] Would write: $stringsPath');
      return;
    }

    Directory(lprojDir).createSync(recursive: true);

    final sb = StringBuffer();
    for (final entry in entries.entries) {
      sb.writeln('"${entry.key}" = "${entry.value}";');
    }

    File(stringsPath).writeAsStringSync(sb.toString());
    print('  Wrote: $stringsPath');
  }
}
