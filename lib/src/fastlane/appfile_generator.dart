import 'dart:io';

import 'package:path/path.dart' as p;

/// Appfile을 생성하는 클래스입니다.
class AppfileGenerator {
  /// [outputDir]에 Appfile을 생성합니다.
  static void generate(
    String outputDir, {
    bool dryRun = false,
  }) {
    final path = p.join(outputDir, 'Appfile');

    final content = 'team_id(ENV["TEAM_ID"])\n'
        'itc_team_id(ENV["ITC_TEAM_ID"])\n';

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
