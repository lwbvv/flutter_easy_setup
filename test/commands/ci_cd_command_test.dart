import 'dart:io';

import 'package:easy_setup/src/commands/ci_cd_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('ci_cd_cmd_test_');
    // 최소한의 Flutter 프로젝트 구조 생성
    File(p.join(tempDir.path, 'pubspec.yaml'))
        .writeAsStringSync('name: test_app\ndependencies:\n  flutter:\n    sdk: flutter\n');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  const yamlWithoutCiCd = '''
easy_setup:
  flavors:
    dev:
      bundle_id: com.example.app.dev
      name: MyApp Dev
    prod:
      bundle_id: com.example.app
      name: MyApp
''';

  /// ci_cd/ios/fastlane/ 디렉터리 아래 파일 경로를 반환하는 헬퍼
  String fastlanePath(String filename) =>
      p.join(tempDir.path, 'ci_cd', 'ios', 'fastlane', filename);

  group('CiCdCommand', () {
    test('generates all CI/CD files', () async {
      File(p.join(tempDir.path, 'easy_setup.yaml'))
          .writeAsStringSync(yamlWithoutCiCd);

      await CiCdCommand.run(projectRoot: tempDir.path);

      expect(File(fastlanePath('.env')).existsSync(), isTrue);
      expect(File(fastlanePath('Gemfile')).existsSync(), isTrue);
      expect(File(fastlanePath('Matchfile')).existsSync(), isTrue);
      expect(File(fastlanePath('Appfile')).existsSync(), isTrue);
      expect(File(fastlanePath('Fastfile')).existsSync(), isTrue);
      expect(
        File(p.join(tempDir.path, '.github', 'workflows', 'ios-deploy.yml'))
            .existsSync(),
        isTrue,
      );
    });

    test('Matchfile contains correct bundle IDs', () async {
      File(p.join(tempDir.path, 'easy_setup.yaml'))
          .writeAsStringSync(yamlWithoutCiCd);

      await CiCdCommand.run(projectRoot: tempDir.path);

      final content = File(fastlanePath('Matchfile')).readAsStringSync();
      expect(content, contains('"com.example.app.dev"'));
      expect(content, contains('"com.example.app"'));
    });

    test('dry-run does not create any files', () async {
      File(p.join(tempDir.path, 'easy_setup.yaml'))
          .writeAsStringSync(yamlWithoutCiCd);

      await CiCdCommand.run(projectRoot: tempDir.path, dryRun: true);

      expect(File(fastlanePath('Gemfile')).existsSync(), isFalse);
      expect(File(fastlanePath('Matchfile')).existsSync(), isFalse);
    });

    test('overwrites existing files on second run', () async {
      File(p.join(tempDir.path, 'easy_setup.yaml'))
          .writeAsStringSync(yamlWithoutCiCd);

      await CiCdCommand.run(projectRoot: tempDir.path);
      final gemfile = File(fastlanePath('Gemfile'));
      final afterFirst = gemfile.readAsStringSync();

      // Overwrite one file
      gemfile.writeAsStringSync('CUSTOM');

      // Second run should overwrite with correct content
      await CiCdCommand.run(projectRoot: tempDir.path);
      expect(gemfile.readAsStringSync(), afterFirst);
    });
  });
}
