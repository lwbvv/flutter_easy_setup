import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/ci_cd_config.dart';

/// A class that generates the metadata directory structure for Fastlane `deliver`.
///
/// Generated structure:
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
  /// Generates metadata files under [outputDir] (the fastlane directory).
  ///
  /// [metadata]: map of per-locale metadata configuration
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
