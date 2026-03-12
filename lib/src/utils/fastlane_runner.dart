import 'dart:io';

import 'package:path/path.dart' as p;

import '../exceptions.dart';

/// Fastlane 실행 환경을 준비하고 명령을 실행하는 유틸리티입니다.
///
/// 프로젝트 루트에 Gemfile이 없으면 생성하고 `bundle install`을 실행합니다.
/// 이후 `bundle exec fastlane` 으로 명령을 실행합니다.
class FastlaneRunner {
  /// 프로젝트 루트에 Gemfile이 없으면 생성하고, fastlane gem이 없으면 추가합니다.
  ///
  /// [dryRun]이 true이면 파일을 생성하지 않고 상태만 출력합니다.
  /// Gemfile 생성/수정 여부를 반환합니다.
  static bool ensureGemfile(String projectRoot, {bool dryRun = false}) {
    final gemfilePath = p.join(projectRoot, 'Gemfile');
    final gemfile = File(gemfilePath);

    if (gemfile.existsSync()) {
      final content = gemfile.readAsStringSync();
      if (RegExp(r'''gem\s+['"]fastlane['"]''').hasMatch(content)) {
        print('  Gemfile: fastlane already present');
        return false;
      }

      // Gemfile은 있지만 fastlane이 없는 경우
      if (dryRun) {
        print('  [dry-run] Would add fastlane to: $gemfilePath');
        return true;
      }
      final updated = '${content.trimRight()}\n\ngem "fastlane"\n';
      gemfile.writeAsStringSync(updated);
      print('  Added fastlane to: $gemfilePath');
      return true;
    }

    // Gemfile이 없는 경우
    if (dryRun) {
      print('  [dry-run] Would create: $gemfilePath');
      return true;
    }

    gemfile.writeAsStringSync(
      'source "https://rubygems.org"\n'
      '\n'
      'gem "fastlane"\n',
    );
    print('  Created: $gemfilePath');
    return true;
  }

  /// `bundle install`을 실행합니다.
  static Future<void> bundleInstall(String projectRoot,
      {bool dryRun = false}) async {
    if (dryRun) {
      print('  [dry-run] Would run: bundle install');
      return;
    }

    print('  Running: bundle install...');
    final result = await Process.run(
      'bundle',
      ['install'],
      workingDirectory: projectRoot,
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

  /// Gemfile을 준비하고 `bundle install`까지 실행합니다.
  ///
  /// Gemfile이 새로 생성되거나 fastlane이 추가된 경우에만 `bundle install`을 실행합니다.
  static Future<void> setup(String projectRoot, {bool dryRun = false}) async {
    print('\n--- Gemfile ---');
    final changed = ensureGemfile(projectRoot, dryRun: dryRun);
    if (changed) {
      await bundleInstall(projectRoot, dryRun: dryRun);
    }
  }

  /// `bundle exec fastlane`으로 명령을 실행합니다.
  static Future<ProcessResult> run(
    String projectRoot,
    List<String> args,
  ) async {
    return Process.run(
      'bundle',
      ['exec', 'fastlane', ...args],
      workingDirectory: projectRoot,
    );
  }
}
