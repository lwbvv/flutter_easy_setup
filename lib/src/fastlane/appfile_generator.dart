import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/ci_cd_config.dart';

/// ios/fastlane/Appfile을 생성하는 클래스입니다.
class AppfileGenerator {
  /// [projectRoot]의 ios/fastlane/Appfile을 생성합니다.
  ///
  /// [ios]: CI/CD iOS 설정 (team_id, itc_team_id)
  static void generate(
    String projectRoot,
    CiCdIosConfig ios, {
    bool dryRun = false,
  }) {
    final path = p.join(projectRoot, 'ios', 'fastlane', 'Appfile');

    final content = 'team_id("${ios.teamId}")\n'
        'itc_team_id("${ios.itcTeamId}")\n';

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
