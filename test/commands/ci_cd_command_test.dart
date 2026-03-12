import 'dart:io';

import 'package:easy_setup/src/commands/ci_cd_command.dart';
import 'package:easy_setup/src/exceptions.dart';
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

  const yamlWithCiCd = '''
easy_setup:
  flavors:
    dev:
      bundle_id: com.example.app.dev
      name: MyApp Dev
    prod:
      bundle_id: com.example.app
      name: MyApp

  ci_cd:
    ios:
      storage: https://github.com/user/certs.git
      team_id: TEAM123
      itc_team_id: ITC456
      api_key:
        id: KEY_ID
        issuer_id: ISSUER_ID
        key_path: fastlane/AuthKey.p8
''';

  /// fastlane/ios/ 디렉터리 아래 파일 경로를 반환하는 헬퍼
  String fastlanePath(String filename) =>
      p.join(tempDir.path, 'fastlane', 'ios', filename);

  group('CiCdCommand', () {
    test('generates all CI/CD files', () async {
      File(p.join(tempDir.path, 'easy_setup.yaml'))
          .writeAsStringSync(yamlWithCiCd);

      await CiCdCommand.run(projectRoot: tempDir.path);

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
          .writeAsStringSync(yamlWithCiCd);

      await CiCdCommand.run(projectRoot: tempDir.path);

      final content = File(fastlanePath('Matchfile')).readAsStringSync();
      expect(content, contains('"com.example.app.dev"'));
      expect(content, contains('"com.example.app"'));
    });

    test('uses ci_cd.flavors override when specified', () async {
      final yaml = '''
easy_setup:
  flavors:
    dev:
      bundle_id: com.example.app.dev
      name: MyApp Dev
    staging:
      bundle_id: com.example.app.staging
      name: MyApp Staging
    prod:
      bundle_id: com.example.app
      name: MyApp

  ci_cd:
    flavors:
      prod:
        bundle_id: com.example.app
    ios:
      storage: https://github.com/user/certs.git
      team_id: TEAM123
      itc_team_id: ITC456
      api_key:
        id: KEY_ID
        issuer_id: ISSUER_ID
        key_path: fastlane/AuthKey.p8
''';
      File(p.join(tempDir.path, 'easy_setup.yaml')).writeAsStringSync(yaml);

      await CiCdCommand.run(projectRoot: tempDir.path);

      final matchfile = File(fastlanePath('Matchfile')).readAsStringSync();
      // Only prod bundle_id should be present
      expect(matchfile, contains('"com.example.app"'));
      expect(matchfile, isNot(contains('com.example.app.dev')));
      expect(matchfile, isNot(contains('com.example.app.staging')));
    });

    test('ci_cd.flavors falls back to easy_setup.flavors bundle_id', () async {
      final yaml = '''
easy_setup:
  flavors:
    dev:
      bundle_id: com.example.app.dev
      name: MyApp Dev
    prod:
      bundle_id: com.example.app
      name: MyApp

  ci_cd:
    flavors:
      prod: {}
    ios:
      storage: https://github.com/user/certs.git
      team_id: TEAM123
      itc_team_id: ITC456
      api_key:
        id: KEY_ID
        issuer_id: ISSUER_ID
        key_path: fastlane/AuthKey.p8
''';
      File(p.join(tempDir.path, 'easy_setup.yaml')).writeAsStringSync(yaml);

      await CiCdCommand.run(projectRoot: tempDir.path);

      final matchfile = File(fastlanePath('Matchfile')).readAsStringSync();
      expect(matchfile, contains('"com.example.app"'));
    });

    test('dry-run does not create any files', () async {
      File(p.join(tempDir.path, 'easy_setup.yaml'))
          .writeAsStringSync(yamlWithCiCd);

      await CiCdCommand.run(projectRoot: tempDir.path, dryRun: true);

      expect(File(fastlanePath('Gemfile')).existsSync(), isFalse);
      expect(File(fastlanePath('Matchfile')).existsSync(), isFalse);
    });

    test('throws SetupException when ci_cd section is missing', () {
      File(p.join(tempDir.path, 'easy_setup.yaml')).writeAsStringSync('''
easy_setup:
  flavors:
    dev:
      bundle_id: com.example.app.dev
      name: MyApp Dev
''');

      expect(
        () => CiCdCommand.run(projectRoot: tempDir.path),
        throwsA(
          isA<SetupException>().having(
            (e) => e.message,
            'message',
            contains('No "ci_cd" section'),
          ),
        ),
      );
    });

    test('overwrites existing files on second run', () async {
      File(p.join(tempDir.path, 'easy_setup.yaml'))
          .writeAsStringSync(yamlWithCiCd);

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
