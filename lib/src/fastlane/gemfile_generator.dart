import 'dart:io';

import 'package:path/path.dart' as p;

/// Gemfile을 생성하는 클래스입니다.
class GemfileGenerator {
  /// [outputDir]에 Gemfile을 생성합니다.
  ///
  /// 이미 파일이 존재하면 덮어쓰지 않습니다 (멱등성).
  static void generate(String outputDir, {bool dryRun = false}) {
    final path = p.join(outputDir, 'Gemfile');

    const content = 'source "https://rubygems.org"\n'
        '\n'
        'gem "fastlane"\n';

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
