import 'dart:io';

import 'package:easy_setup/src/fastlane/gemfile_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('gemfile_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('GemfileGenerator', () {
    test('creates ios/Gemfile with correct content', () {
      GemfileGenerator.generate(tempDir.path);

      final file = File(p.join(tempDir.path, 'ios', 'Gemfile'));
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('source "https://rubygems.org"'));
      expect(content, contains('gem "fastlane"'));
    });

    test('is idempotent — does not overwrite existing file', () {
      GemfileGenerator.generate(tempDir.path);

      final file = File(p.join(tempDir.path, 'ios', 'Gemfile'));
      file.writeAsStringSync('CUSTOM');

      GemfileGenerator.generate(tempDir.path);
      expect(file.readAsStringSync(), 'CUSTOM');
    });

    test('does not create file in dry-run mode', () {
      GemfileGenerator.generate(tempDir.path, dryRun: true);

      expect(
        File(p.join(tempDir.path, 'ios', 'Gemfile')).existsSync(),
        isFalse,
      );
    });
  });
}
