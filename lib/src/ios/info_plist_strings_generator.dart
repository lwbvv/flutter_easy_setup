import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/flavor_config.dart';

/// iOS locale별 InfoPlist.strings 파일을 생성하는 클래스입니다.
///
/// flavor별 localized 설정(앱 이름)과 전역 localized 설정(권한)을 병합하여
/// `ios/Runner/{locale}.lproj/InfoPlist.strings` 파일을 생성합니다.
class InfoPlistStringsGenerator {
  /// flavor별 + 전역 localized 설정을 병합하여 InfoPlist.strings를 생성합니다.
  ///
  /// [projectRoot]: Flutter 프로젝트 루트
  /// [flavorLocalized]: flavor별 locale 설정 (app_name, app_icon 등)
  /// [globalLocalized]: 전역 locale 설정 (permission 등)
  static void generate(
    String projectRoot, {
    Map<String, FlavorLocalizedConfig>? flavorLocalized,
    Map<String, GlobalLocalizedConfig>? globalLocalized,
    bool dryRun = false,
  }) {
    // 모든 locale 키를 수집
    final allLocales = <String>{};
    if (flavorLocalized != null) allLocales.addAll(flavorLocalized.keys);
    if (globalLocalized != null) allLocales.addAll(globalLocalized.keys);

    if (allLocales.isEmpty) return;

    print('\n--- iOS InfoPlist.strings ---');

    for (final locale in allLocales) {
      final entries = <String, String>{};

      // flavor별 app_name → CFBundleDisplayName
      final flavorConfig = flavorLocalized?[locale];
      if (flavorConfig?.appName != null) {
        entries['CFBundleDisplayName'] = flavorConfig!.appName!;
      }

      // 전역 permission 키들
      final globalConfig = globalLocalized?[locale];
      if (globalConfig?.permission != null) {
        entries.addAll(globalConfig!.permission!);
      }

      if (entries.isEmpty) continue;

      final lprojDir = p.join(projectRoot, 'ios', 'Runner', '$locale.lproj');
      final stringsPath = p.join(lprojDir, 'InfoPlist.strings');

      if (dryRun) {
        print('  [dry-run] Would write: $stringsPath');
        continue;
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
}
