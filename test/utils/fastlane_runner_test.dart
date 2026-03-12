import 'dart:io';

import 'package:easy_setup/easy_setup.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fastlane_runner_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('FastlaneRunner.ensureGemfile', () {
    test('creates Gemfile when none exists', () {
      FastlaneRunner.ensureGemfile(tempDir.path);

      final gemfile = File(p.join(tempDir.path, 'Gemfile'));
      expect(gemfile.existsSync(), isTrue);

      final content = gemfile.readAsStringSync();
      expect(content, contains('source "https://rubygems.org"'));
      expect(content, contains('gem "fastlane"'));
    });

    test('dry-run does not create Gemfile', () {
      FastlaneRunner.ensureGemfile(tempDir.path, dryRun: true);

      final gemfile = File(p.join(tempDir.path, 'Gemfile'));
      expect(gemfile.existsSync(), isFalse);
    });

    test('adds fastlane to existing Gemfile without it', () {
      final gemfile = File(p.join(tempDir.path, 'Gemfile'));
      gemfile.writeAsStringSync('source "https://rubygems.org"\n\ngem "cocoapods"\n');

      FastlaneRunner.ensureGemfile(tempDir.path);

      final content = gemfile.readAsStringSync();
      expect(content, contains('gem "cocoapods"'));
      expect(content, contains('gem "fastlane"'));
    });

    test('skips when Gemfile already has fastlane', () {
      final gemfile = File(p.join(tempDir.path, 'Gemfile'));
      final original = 'source "https://rubygems.org"\n\ngem "fastlane"\n';
      gemfile.writeAsStringSync(original);

      final changed = FastlaneRunner.ensureGemfile(tempDir.path);

      expect(changed, isFalse);
      expect(gemfile.readAsStringSync(), equals(original));
    });

    test('detects fastlane with single quotes', () {
      final gemfile = File(p.join(tempDir.path, 'Gemfile'));
      gemfile.writeAsStringSync("source 'https://rubygems.org'\n\ngem 'fastlane'\n");

      final changed = FastlaneRunner.ensureGemfile(tempDir.path);

      expect(changed, isFalse);
    });

    test('returns true when Gemfile is created', () {
      final changed = FastlaneRunner.ensureGemfile(tempDir.path);
      expect(changed, isTrue);
    });

    test('returns true when fastlane is added', () {
      File(p.join(tempDir.path, 'Gemfile'))
          .writeAsStringSync('source "https://rubygems.org"\n');

      final changed = FastlaneRunner.ensureGemfile(tempDir.path);
      expect(changed, isTrue);
    });
  });
}
