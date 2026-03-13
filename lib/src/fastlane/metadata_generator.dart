import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/ci_cd_config.dart';

/// Fastlane `deliver`용 metadata 디렉터리 구조를 생성하는 클래스입니다.
///
/// 생성되는 구조:
/// ```
/// ci_cd/ios/fastlane/metadata/
///   ko/
///     promotional_text.txt
///     description.txt
///     ...
///   en-US/
///     promotional_text.txt
///     ...
/// ```
class MetadataGenerator {
  /// [outputDir] (fastlane 디렉터리) 하위에 metadata 파일을 생성합니다.
  ///
  /// [metadata]: locale별 메타데이터 설정 맵
  static void generate(
    String outputDir,
    Map<String, LocaleMetadataConfig> metadata, {
    bool dryRun = false,
  }) {
    final metadataDir = p.join(outputDir, 'metadata');

    for (final entry in metadata.entries) {
      final locale = entry.key;
      final config = entry.value;
      final localeDir = p.join(metadataDir, locale);
      final fileMap = config.toFileMap();

      if (fileMap.isEmpty) continue;

      for (final fileEntry in fileMap.entries) {
        final filePath = p.join(localeDir, fileEntry.key);
        _writeFile(filePath, '${fileEntry.value}\n', dryRun: dryRun);
      }
    }
  }

  static void _writeFile(String path, String content,
      {required bool dryRun}) {
    if (dryRun) {
      print('  [dry-run] Would write: $path');
      return;
    }
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    print('  Wrote: $path');
  }
}
