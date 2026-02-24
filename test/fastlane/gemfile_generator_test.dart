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
    test('creates Gemfile in output directory with correct content', () {
      GemfileGenerator.generate(tempDir.path);

      final file = File(p.join(tempDir.path, 'Gemfile'));
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('source "https://rubygems.org"'));
      expect(content, contains('gem "fastlane"'));
    });

    test('is idempotent — does not overwrite existing file', () {
      GemfileGenerator.generate(tempDir.path);

      final file = File(p.join(tempDir.path, 'Gemfile'));
      file.writeAsStringSync('CUSTOM');

      GemfileGenerator.generate(tempDir.path);
      expect(file.readAsStringSync(), 'CUSTOM');
    });

    test('does not create file in dry-run mode', () {
      GemfileGenerator.generate(tempDir.path, dryRun: true);

      expect(
        File(p.join(tempDir.path, 'Gemfile')).existsSync(),
        isFalse,
      );
    });

    test('creates parent directories if they do not exist', () {
      final nestedDir = p.join(tempDir.path, 'fastlane', 'ios');

      GemfileGenerator.generate(nestedDir);

      expect(File(p.join(nestedDir, 'Gemfile')).existsSync(), isTrue);
    });
  });
}
