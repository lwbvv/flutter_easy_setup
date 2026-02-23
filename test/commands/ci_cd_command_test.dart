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

  group('CiCdCommand', () {
    test('generates all CI/CD files', () {
      File(p.join(tempDir.path, 'easy_setup.yaml'))
          .writeAsStringSync(yamlWithCiCd);

      CiCdCommand.run(projectRoot: tempDir.path);

      expect(
        File(p.join(tempDir.path, 'ios', 'Gemfile')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(tempDir.path, 'ios', 'fastlane', 'Matchfile')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(tempDir.path, 'ios', 'fastlane', 'Appfile')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(tempDir.path, 'ios', 'fastlane', 'Fastfile')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(tempDir.path, '.github', 'workflows', 'ios-deploy.yml'))
            .existsSync(),
        isTrue,
      );
    });

    test('Matchfile contains correct bundle IDs', () {
      File(p.join(tempDir.path, 'easy_setup.yaml'))
          .writeAsStringSync(yamlWithCiCd);

      CiCdCommand.run(projectRoot: tempDir.path);

      final content = File(
        p.join(tempDir.path, 'ios', 'fastlane', 'Matchfile'),
      ).readAsStringSync();
      expect(content, contains('"com.example.app.dev"'));
      expect(content, contains('"com.example.app"'));
    });

    test('uses ci_cd.flavors override when specified', () {
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

      CiCdCommand.run(projectRoot: tempDir.path);

      final matchfile = File(
        p.join(tempDir.path, 'ios', 'fastlane', 'Matchfile'),
      ).readAsStringSync();
      // Only prod bundle_id should be present
      expect(matchfile, contains('"com.example.app"'));
      expect(matchfile, isNot(contains('com.example.app.dev')));
      expect(matchfile, isNot(contains('com.example.app.staging')));
    });

    test('ci_cd.flavors falls back to easy_setup.flavors bundle_id', () {
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

      CiCdCommand.run(projectRoot: tempDir.path);

      final matchfile = File(
        p.join(tempDir.path, 'ios', 'fastlane', 'Matchfile'),
      ).readAsStringSync();
      expect(matchfile, contains('"com.example.app"'));
    });

    test('dry-run does not create any files', () {
      File(p.join(tempDir.path, 'easy_setup.yaml'))
          .writeAsStringSync(yamlWithCiCd);

      CiCdCommand.run(projectRoot: tempDir.path, dryRun: true);

      expect(
        File(p.join(tempDir.path, 'ios', 'Gemfile')).existsSync(),
        isFalse,
      );
      expect(
        File(p.join(tempDir.path, 'ios', 'fastlane', 'Matchfile')).existsSync(),
        isFalse,
      );
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

    test('is idempotent — second run skips existing files', () {
      File(p.join(tempDir.path, 'easy_setup.yaml'))
          .writeAsStringSync(yamlWithCiCd);

      CiCdCommand.run(projectRoot: tempDir.path);

      // Overwrite one file
      final gemfile = File(p.join(tempDir.path, 'ios', 'Gemfile'));
      gemfile.writeAsStringSync('CUSTOM');

      // Second run should not overwrite
      CiCdCommand.run(projectRoot: tempDir.path);
      expect(gemfile.readAsStringSync(), 'CUSTOM');
    });
  });
}
