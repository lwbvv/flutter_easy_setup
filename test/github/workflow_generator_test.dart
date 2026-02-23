import 'dart:io';

import 'package:easy_setup/src/github/workflow_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('workflow_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('WorkflowGenerator', () {
    test('creates .github/workflows/ios-deploy.yml', () {
      WorkflowGenerator.generate(tempDir.path, ['dev', 'staging', 'prod']);

      final file = File(
          p.join(tempDir.path, '.github', 'workflows', 'ios-deploy.yml'));
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('name: iOS Deploy'));
      expect(content, contains('workflow_dispatch'));
      expect(content, contains('- dev'));
      expect(content, contains('- staging'));
      expect(content, contains('- prod'));
      expect(content, contains('default: "prod"'));
      expect(content, contains('actions/checkout@v4'));
      expect(content, contains('subosito/flutter-action@v2'));
      expect(content, contains('ruby/setup-ruby@v1'));
      expect(content, contains('flutter pub get'));
      expect(content, contains('APP_STORE_CONNECT_API_KEY_BASE64'));
      expect(content, contains('MATCH_PASSWORD'));
      expect(content, contains('MATCH_GIT_BASIC_AUTHORIZATION'));
      expect(content, contains('bundle exec fastlane certificates'));
      expect(content, contains('bundle exec fastlane beta'));
    });

    test('defaults to first flavor when prod is absent', () {
      WorkflowGenerator.generate(tempDir.path, ['staging', 'dev']);

      final content = File(
        p.join(tempDir.path, '.github', 'workflows', 'ios-deploy.yml'),
      ).readAsStringSync();
      expect(content, contains('default: "staging"'));
    });

    test('is idempotent', () {
      WorkflowGenerator.generate(tempDir.path, ['prod']);

      final file = File(
          p.join(tempDir.path, '.github', 'workflows', 'ios-deploy.yml'));
      file.writeAsStringSync('CUSTOM');

      WorkflowGenerator.generate(tempDir.path, ['prod']);
      expect(file.readAsStringSync(), 'CUSTOM');
    });

    test('does not create file in dry-run mode', () {
      WorkflowGenerator.generate(tempDir.path, ['prod'], dryRun: true);

      expect(
        File(p.join(tempDir.path, '.github', 'workflows', 'ios-deploy.yml'))
            .existsSync(),
        isFalse,
      );
    });
  });
}
