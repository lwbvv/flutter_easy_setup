import 'dart:io';

import 'package:easy_setup/src/fastlane/matchfile_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('matchfile_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('MatchfileGenerator', () {
    test('creates Matchfile referencing ENV variables and bundle IDs', () {
      MatchfileGenerator.generate(
        tempDir.path,
        ['com.app.dev', 'com.app'],
      );

      final file = File(p.join(tempDir.path, 'Matchfile'));
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('ENV["CERTS_REPO_URL"]'));
      expect(content, contains('ENV["TEAM_ID"]'));
      expect(content, contains('ENV["APPLE_ID"]'));
      expect(content, contains('storage_mode("git")'));
      expect(content, contains('type("appstore")'));
      expect(content, contains('"com.app.dev"'));
      expect(content, contains('"com.app"'));
    });

    test('overwrites existing file with correct content', () {
      MatchfileGenerator.generate(tempDir.path, ['com.app']);
      final file = File(p.join(tempDir.path, 'Matchfile'));
      final afterFirst = file.readAsStringSync();

      file.writeAsStringSync('CUSTOM');

      MatchfileGenerator.generate(tempDir.path, ['com.app']);
      expect(file.readAsStringSync(), afterFirst);
    });

    test('does not create file in dry-run mode', () {
      MatchfileGenerator.generate(tempDir.path, ['com.app'], dryRun: true);

      expect(
        File(p.join(tempDir.path, 'Matchfile')).existsSync(),
        isFalse,
      );
    });
  });
}
