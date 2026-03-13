import 'dart:io';

import '../exceptions.dart';

/// Fastlane 실행 환경을 준비하고 명령을 실행하는 유틸리티입니다.
///
/// fastlane 디렉터리에서 `bundle install`을 실행하고
/// `bundle exec fastlane` 으로 명령을 실행합니다.
class FastlaneRunner {
  /// [fastlaneDir]에서 `bundle install`을 실행합니다.
  static Future<void> bundleInstall(String fastlaneDir,
      {bool dryRun = false}) async {
    if (dryRun) {
      print('  [dry-run] Would run: bundle install');
      return;
    }

    print('  Running: bundle install...');
    final result = await Process.run(
      'bundle',
      ['install'],
      workingDirectory: fastlaneDir,
    );

    if (result.exitCode != 0) {
      final stderr = (result.stderr as String).trim();
      throw SetupException(
        'bundle install failed:\n'
        '${stderr.isNotEmpty ? stderr : (result.stdout as String).trim()}',
      );
    }
    print('  bundle install complete');
  }

  /// `bundle exec fastlane`으로 명령을 실행합니다.
  ///
  /// [environment]로 추가 환경변수를 전달할 수 있습니다.
  static Future<ProcessResult> run(
    String fastlaneDir,
    List<String> args, {
    Map<String, String>? environment,
  }) async {
    return Process.run(
      'bundle',
      ['exec', 'fastlane', ...args],
      workingDirectory: fastlaneDir,
      environment: environment,
      includeParentEnvironment: true,
    );
  }
}
