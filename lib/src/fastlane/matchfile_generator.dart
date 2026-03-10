import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/ci_cd_config.dart';

/// Matchfile을 생성하는 클래스입니다.
class MatchfileGenerator {
  /// [outputDir]에 Matchfile을 생성합니다.
  ///
  /// [ios]: CI/CD iOS 설정 (storage, team_id)
  /// [bundleIds]: Match에 등록할 bundle ID 목록
  static void generate(
    String outputDir,
    CiCdIosConfig ios,
    List<String> bundleIds, {
    bool dryRun = false,
  }) {
    final path = p.join(outputDir, 'Matchfile');

    final ids = bundleIds.map((id) => '  "$id",').join('\n');
    final content = 'git_url("${ios.storage}")\n'
        'storage_mode("git")\n'
        '\n'
        'type("appstore")\n'
        '\n'
        'app_identifier([\n'
        '$ids\n'
        '])\n'
        '\n'
        'team_id("${ios.teamId}")\n'
        '\n'
        'api_key_path("api_key.json")\n';

    _writeFile(path, content, dryRun: dryRun);
  }

  static void _writeFile(String path, String content, {required bool dryRun}) {
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
