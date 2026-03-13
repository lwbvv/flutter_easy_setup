import 'dart:io';

import 'package:easy_setup/src/commands/ci_cd_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  const yamlMinimal = '''
easy_setup:
  flavors:
    dev:
      bundle_id: com.example.app.dev
      name: MyApp Dev
    prod:
      bundle_id: com.example.app
      name: MyApp
''';

  const yamlWithMetadata = '''
easy_setup:
  flavors:
    prod:
      bundle_id: com.example.app
      name: MyApp

  metadata:
    ko:
      promotional_text: "앱 광고"
      description: "앱 설명"
      release_notes: "새로운 기능"
''';

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('register_test_');
    File(p.join(tempDir.path, 'pubspec.yaml'))
        .writeAsStringSync('name: test_app\nenvironment:\n  sdk: ">=3.0.0 <4.0.0"\n  flutter: ">=3.0.0"\ndependencies:\n  flutter:\n    sdk: flutter\n');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('CiCdCommand - Register Lane and Metadata', () {
    test('generates register lane in Fastfile with TODO placeholders', () async {
      File(p.join(tempDir.path, 'easy_setup.yaml'))
          .writeAsStringSync(yamlMinimal);

      await CiCdCommand.run(projectRoot: tempDir.path);

      final fastfile = File(p.join(tempDir.path, 'ci_cd', 'ios', 'fastlane', 'Fastfile'))
          .readAsStringSync();
      // Check for register lane
      expect(fastfile, contains('lane :register do'));
      // Check that app identifiers are filled in
      expect(fastfile, contains('app_identifier: "com.example.app.dev"'));
      expect(fastfile, contains('app_identifier: "com.example.app"'));
      expect(fastfile, contains('app_name: "MyApp Dev"'));
      expect(fastfile, contains('app_name: "MyApp"'));
      // Check for TODO placeholders instead of real values
      expect(fastfile, contains('team_id: "YOUR_TEAM_ID"'));
      expect(fastfile, contains('itc_team_id: "YOUR_ITC_TEAM_ID"'));
      expect(fastfile, contains('TODO'));
      // username should be commented out
      expect(fastfile, contains('# username: "your@email.com"'));
    });

    test('generates metadata files when metadata section is present', () async {
      File(p.join(tempDir.path, 'easy_setup.yaml'))
          .writeAsStringSync(yamlWithMetadata);

      await CiCdCommand.run(projectRoot: tempDir.path);

      // Check metadata files exist
      expect(
        File(p.join(tempDir.path, 'ci_cd', 'ios', 'fastlane', 'metadata', 'ko', 'promotional_text.txt'))
            .existsSync(),
        isTrue,
      );
      expect(
        File(p.join(tempDir.path, 'ci_cd', 'ios', 'fastlane', 'metadata', 'ko', 'description.txt'))
            .existsSync(),
        isTrue,
      );
      expect(
        File(p.join(tempDir.path, 'ci_cd', 'ios', 'fastlane', 'metadata', 'ko', 'release_notes.txt'))
            .existsSync(),
        isTrue,
      );

      // Check Fastfile has update_metadata lane
      final fastfile = File(p.join(tempDir.path, 'ci_cd', 'ios', 'fastlane', 'Fastfile'))
          .readAsStringSync();
      expect(fastfile, contains('lane :update_metadata do'));
      expect(fastfile, contains('deliver('));
    });

    test('no metadata section skips metadata generation', () async {
      File(p.join(tempDir.path, 'easy_setup.yaml'))
          .writeAsStringSync(yamlMinimal);

      await CiCdCommand.run(projectRoot: tempDir.path);

      // Metadata directory should not exist
      expect(
        Directory(p.join(tempDir.path, 'ci_cd', 'ios', 'fastlane', 'metadata'))
            .existsSync(),
        isFalse,
      );

      // Fastfile should not have update_metadata lane
      final fastfile = File(p.join(tempDir.path, 'ci_cd', 'ios', 'fastlane', 'Fastfile'))
          .readAsStringSync();
      expect(fastfile, isNot(contains('lane :update_metadata do')));
    });

    test('dry-run does not create register lane', () async {
      File(p.join(tempDir.path, 'easy_setup.yaml'))
          .writeAsStringSync(yamlMinimal);

      await CiCdCommand.run(projectRoot: tempDir.path, dryRun: true);

      // Fastfile should not exist in dry-run mode
      expect(
        File(p.join(tempDir.path, 'ci_cd', 'ios', 'fastlane', 'Fastfile'))
            .existsSync(),
        isFalse,
      );
    });
  });
}
