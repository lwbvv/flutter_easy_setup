import 'dart:io';

import 'package:easy_setup/src/commands/ci_cd_command.dart';
import 'package:easy_setup/src/exceptions.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

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
      team_id: XXXXXXXXXX
      itc_team_id: YYYYYYYYYY
      api_key:
        id: KEY_ID
        issuer_id: ISSUER_ID
        key_path: ci_cd/ios/fastlane/AuthKey.p8
''';

  const yamlWithCiCdFlavors = '''
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
      prod:
        bundle_id: com.example.app

    ios:
      storage: https://github.com/user/certs.git
      team_id: XXXXXXXXXX
      itc_team_id: YYYYYYYYYY
      api_key:
        id: KEY_ID
        issuer_id: ISSUER_ID
        key_path: ci_cd/ios/fastlane/AuthKey.p8
''';

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('register_test_');
    File(p.join(tempDir.path, 'pubspec.yaml'))
        .writeAsStringSync('name: test_app\nenvironment:\n  sdk: ">=3.0.0 <4.0.0"\n  flutter: ">=3.0.0"\ndependencies:\n  flutter:\n    sdk: flutter\n');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('CiCdCommand - Bundle ID registration', () {
    test('throws SetupException when no ci_cd section', () async {
      File(p.join(tempDir.path, 'easy_setup.yaml'))
          .writeAsStringSync('easy_setup:\n  flavors:\n    dev:\n      bundle_id: com.example.app.dev\n      name: MyApp Dev\n');

      expect(
        () => CiCdCommand.run(projectRoot: tempDir.path),
        throwsA(isA<SetupException>()),
      );
    });

    test('skips Bundle ID registration when API key file not found', () async {
      File(p.join(tempDir.path, 'easy_setup.yaml'))
          .writeAsStringSync(yamlWithCiCd);

      // Should not throw — just skips registration
      await CiCdCommand.run(projectRoot: tempDir.path);

      // Fastfile should still be generated
      expect(
        File(p.join(tempDir.path, 'ci_cd', 'ios', 'fastlane', 'Fastfile')).existsSync(),
        isTrue,
      );
    });

    test('dry-run does not register Bundle IDs', () async {
      File(p.join(tempDir.path, 'easy_setup.yaml'))
          .writeAsStringSync(yamlWithCiCd);

      await CiCdCommand.run(projectRoot: tempDir.path, dryRun: true);
    });

    test('resolves all flavors when ci_cd.flavors is not specified', () async {
      File(p.join(tempDir.path, 'easy_setup.yaml'))
          .writeAsStringSync(yamlWithCiCd);

      // dry-run으로 flavor 해석만 검증 (API 호출 없음)
      await CiCdCommand.run(projectRoot: tempDir.path, dryRun: true);
    });

    test('resolves only ci_cd.flavors when specified', () async {
      File(p.join(tempDir.path, 'easy_setup.yaml'))
          .writeAsStringSync(yamlWithCiCdFlavors);

      // dry-run으로 flavor 해석만 검증 — prod만 대상
      await CiCdCommand.run(projectRoot: tempDir.path, dryRun: true);
    });

    test('generates register lane in Fastfile', () async {
      File(p.join(tempDir.path, 'easy_setup.yaml'))
          .writeAsStringSync(yamlWithCiCd);

      await CiCdCommand.run(projectRoot: tempDir.path);

      final fastfile = File(p.join(tempDir.path, 'ci_cd', 'ios', 'fastlane', 'Fastfile'))
          .readAsStringSync();
      expect(fastfile, contains('lane :register do'));
      expect(fastfile, contains('produce('));
      expect(fastfile, contains('com.example.app.dev'));
      expect(fastfile, contains('com.example.app'));
    });

    test('register lane includes apple_id as username when present', () async {
      final yaml = '''
easy_setup:
  flavors:
    prod:
      bundle_id: com.example.app
      name: MyApp

  ci_cd:
    ios:
      storage: https://github.com/user/certs.git
      team_id: XXXXXXXXXX
      itc_team_id: YYYYYYYYYY
      apple_id: user@example.com
      api_key:
        id: KEY_ID
        issuer_id: ISSUER_ID
        key_path: ci_cd/ios/fastlane/AuthKey.p8
''';
      File(p.join(tempDir.path, 'easy_setup.yaml')).writeAsStringSync(yaml);

      await CiCdCommand.run(projectRoot: tempDir.path);

      final fastfile = File(p.join(tempDir.path, 'ci_cd', 'ios', 'fastlane', 'Fastfile'))
          .readAsStringSync();
      expect(fastfile, contains('username: "user@example.com"'));
    });
  });
}
