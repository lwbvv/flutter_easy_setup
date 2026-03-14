import 'dart:io';

import 'package:path/path.dart' as p;

/// Matchfile을 생성하는 클래스입니다.
class MatchfileGenerator {
  /// [outputDir]에 Matchfile을 생성합니다.
  ///
  /// [bundleIds]: Match에 등록할 bundle ID 목록
  static void generate(
    String outputDir,
    List<String> bundleIds, {
    bool dryRun = false,
  }) {
    final path = p.join(outputDir, 'Matchfile');

    final ids = bundleIds.map((id) => '  "$id",').join('\n');
    final content = 'git_url(ENV["CERTS_REPO_URL"])\n'
        'storage_mode("git")\n'
        '\n'
        'type("appstore")\n'
        '\n'
        'app_identifier([\n'
        '$ids\n'
        '])\n'
        '\n'
        'team_id(ENV["TEAM_ID"])\n'
        'username(ENV["APPLE_ID"])\n';

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
