import 'dart:io';

import 'package:easy_setup/src/fastlane/appfile_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('appfile_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('AppfileGenerator', () {
    test('creates Appfile referencing ENV variables', () {
      AppfileGenerator.generate(tempDir.path);

      final file = File(p.join(tempDir.path, 'Appfile'));
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('ENV["TEAM_ID"]'));
      expect(content, contains('ENV["ITC_TEAM_ID"]'));
    });

    test('overwrites existing file with correct content', () {
      AppfileGenerator.generate(tempDir.path);
      final file = File(p.join(tempDir.path, 'Appfile'));
      final afterFirst = file.readAsStringSync();

      file.writeAsStringSync('CUSTOM');

      AppfileGenerator.generate(tempDir.path);
      expect(file.readAsStringSync(), afterFirst);
    });

    test('does not create file in dry-run mode', () {
      AppfileGenerator.generate(tempDir.path, dryRun: true);

      expect(
        File(p.join(tempDir.path, 'Appfile')).existsSync(),
        isFalse,
      );
    });
  });
}
