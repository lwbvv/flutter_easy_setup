import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/flavor_config.dart';

/// iOS locale별 InfoPlist.strings 파일을 생성하는 클래스입니다.
///
/// flavor별로 별도의 디렉터리에 InfoPlist.strings를 생성합니다:
///   ios/Flavors/{flavor}/{locale}.lproj/InfoPlist.strings
///
/// 빌드 시 build phase 스크립트가 현재 flavor의 strings를
/// Runner 디렉터리로 복사하여 Xcode가 인식하도록 합니다.
///
/// permission 문자열은 모든 flavor에서 공통이므로
/// Runner/{locale}.lproj/InfoPlist.strings에 직접 생성합니다.
class InfoPlistStringsGenerator {
  /// InfoPlist.strings 파일들을 생성합니다.
  ///
  /// [projectRoot]: Flutter 프로젝트 루트
  /// [flavors]: 전체 flavor 설정 맵
  /// [permission]: 기본 iOS 권한 설명 (en.lproj에 기록)
  /// [localizedPermission]: locale별 iOS 권한 설명
  static void generate(
    String projectRoot, {
    required Map<String, FlavorConfig> flavors,
    Map<String, String>? permission,
    Map<String, Map<String, String>>? localizedPermission,
    bool dryRun = false,
  }) {
    final hasBase = permission != null && permission.isNotEmpty;
    final hasLocalized =
        localizedPermission != null && localizedPermission.isNotEmpty;

    // flavor별 localized app_name이 있는지 확인
    final hasFlavorLocalized =
        flavors.values.any((f) => f.localized != null && f.localized!.isNotEmpty);

    if (!hasBase && !hasLocalized && !hasFlavorLocalized) return;

    print('\n--- iOS InfoPlist.strings ---');

    // 1. flavor별 InfoPlist.strings 생성 (ios/Flavors/{flavor}/{locale}.lproj/)
    if (hasFlavorLocalized) {
      _generateFlavorStrings(projectRoot, flavors, dryRun: dryRun);
    }

    // 2. permission strings 생성 (ios/Runner/{locale}.lproj/)
    _generatePermissionStrings(
      projectRoot,
      permission: permission,
      localizedPermission: localizedPermission,
      dryRun: dryRun,
    );
  }

  /// flavor별 InfoPlist.strings를 ios/Flavors/{flavor}/{locale}.lproj/에 생성합니다.
  static void _generateFlavorStrings(
    String projectRoot,
    Map<String, FlavorConfig> flavors, {
    required bool dryRun,
  }) {
    for (final entry in flavors.entries) {
      final flavor = entry.key;
      final config = entry.value;
      final localized = config.localized;
      if (localized == null || localized.isEmpty) continue;

      // 모든 locale + en (기본)
      final locales = <String>{...localized.keys, 'en'};

      for (final locale in locales) {
        final entries = <String, String>{};

        if (locale == 'en') {
          // en은 flavor의 기본 name 사용
          entries['CFBundleDisplayName'] = config.name;
        } else {
          final locConfig = localized[locale];
          if (locConfig?.appName != null) {
            entries['CFBundleDisplayName'] = locConfig!.appName!;
          }
        }

        if (entries.isEmpty) continue;

        _writeStringsFile(
          projectRoot,
          p.join('ios', 'Flavors', flavor, '$locale.lproj'),
          entries,
          dryRun: dryRun,
        );
      }
    }
  }

  /// permission strings를 ios/Runner/{locale}.lproj/에 생성합니다.
  static void _generatePermissionStrings(
    String projectRoot, {
    Map<String, String>? permission,
    Map<String, Map<String, String>>? localizedPermission,
    required bool dryRun,
  }) {
    final hasBase = permission != null && permission.isNotEmpty;
    final hasLocalized =
        localizedPermission != null && localizedPermission.isNotEmpty;

    if (!hasBase && !hasLocalized) return;

    // 모든 locale 수집
    final allLocales = <String>{};
    if (hasLocalized) allLocales.addAll(localizedPermission.keys);
    if (hasBase) allLocales.add('en');

    for (final locale in allLocales) {
      final entries = <String, String>{};

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
        p.join('ios', 'Runner', '$locale.lproj'),
        entries,
        dryRun: dryRun,
      );
    }
  }

  /// InfoPlist.strings 파일을 생성합니다.
  static void _writeStringsFile(
    String projectRoot,
    String relativeLprojDir,
    Map<String, String> entries, {
    required bool dryRun,
  }) {
    final lprojDir = p.join(projectRoot, relativeLprojDir);
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
