import 'dart:io';

import 'package:path/path.dart' as p;

import '../exceptions.dart';

/// xcodegen CLI를 실행하는 유틸리티 클래스입니다.
///
/// `xcodegen generate` 명령을 호출하여 project.yml로부터
/// Xcode 프로젝트(project.pbxproj, schemes 등)를 생성합니다.
class XcodeGenRunner {
  /// xcodegen generate를 실행합니다.
  ///
  /// [projectRoot]: Flutter 프로젝트 루트
  /// project.yml이 있는 ios/ 디렉터리에서 실행됩니다.
  static void run(String projectRoot, {bool dryRun = false}) {
    final iosDir = p.join(projectRoot, 'ios');
    final projectYmlPath = p.join(iosDir, 'project.yml');

    if (dryRun) {
      print('  [dry-run] Would run: xcodegen generate (in $iosDir)');
      return;
    }

    if (!File(projectYmlPath).existsSync()) {
      throw SetupException(
        'project.yml not found at $projectYmlPath\n'
        'Run the flavor setup first to generate project.yml.',
      );
    }

    // xcodegen 설치 확인
    final which = Process.runSync('which', ['xcodegen']);
    if (which.exitCode != 0) {
      print('  WARNING: xcodegen is not installed.');
      print('  Install it with: brew install xcodegen');
      print('  Then run: cd ios && xcodegen generate');
      print('  See: https://github.com/yonaskolb/XcodeGen');
      return;
    }

    print('  Running: xcodegen generate');
    final result = Process.runSync(
      'xcodegen',
      ['generate'],
      workingDirectory: iosDir,
    );

    if (result.exitCode != 0) {
      final stderr = (result.stderr as String).trim();
      throw SetupException(
        'xcodegen generate failed (exit code ${result.exitCode}):\n$stderr',
      );
    }

    final stdout = (result.stdout as String).trim();
    if (stdout.isNotEmpty) {
      print('  $stdout');
    }
    print('  Xcode project generated successfully.');
  }
}
