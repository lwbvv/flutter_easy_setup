import 'dart:io';

import 'package:path/path.dart' as p;

/// ios/Gemfile을 생성하는 클래스입니다.
class GemfileGenerator {
  /// [projectRoot]의 ios/Gemfile을 생성합니다.
  ///
  /// 이미 파일이 존재하면 덮어쓰지 않습니다 (멱등성).
  static void generate(String projectRoot, {bool dryRun = false}) {
    final path = p.join(projectRoot, 'ios', 'Gemfile');

    const content = 'source "https://rubygems.org"\n'
        '\n'
        'gem "fastlane"\n';

    _writeFile(path, content, dryRun: dryRun);
  }

  static void _writeFile(String path, String content, {required bool dryRun}) {
    if (dryRun) {
      print('  [dry-run] Would create: $path');
      return;
    }
    final file = File(path);
    if (file.existsSync()) {
      print('  Already exists: $path, skipping.');
      return;
    }
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    print('  Created: $path');
  }
}
