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
    test('creates Matchfile with TODO placeholders and bundle IDs', () {
      MatchfileGenerator.generate(
        tempDir.path,
        ['com.app.dev', 'com.app'],
      );

      final file = File(p.join(tempDir.path, 'Matchfile'));
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('YOUR_CERTS_REPO_URL'));
      expect(content, contains('TODO'));
      expect(content, contains('storage_mode("git")'));
      expect(content, contains('type("appstore")'));
      expect(content, contains('"com.app.dev"'));
      expect(content, contains('"com.app"'));
      expect(content, contains('api_key_path("api_key.json")'));
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
