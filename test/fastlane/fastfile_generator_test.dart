import 'dart:io';

import 'package:easy_setup/src/fastlane/fastfile_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fastfile_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('FastfileGenerator', () {
    test('creates Fastfile with TODO placeholders', () {
      FastfileGenerator.generate(tempDir.path, ['dev', 'prod']);

      final file = File(p.join(tempDir.path, 'Fastfile'));
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('default_platform(:ios)'));
      expect(content, contains('YOUR_KEY_ID'));
      expect(content, contains('YOUR_ISSUER_ID'));
      expect(content, contains('AuthKey.p8'));
      expect(content, contains('TODO'));
      expect(content, contains('lane :certificates'));
      expect(content, contains('lane :beta'));
      expect(content, contains('upload_to_testflight'));
    });

    test('defaults to prod flavor when available', () {
      FastfileGenerator.generate(tempDir.path, ['dev', 'prod']);

      final content = File(p.join(tempDir.path, 'Fastfile'))
          .readAsStringSync();
      expect(content, contains('options[:flavor] || "prod"'));
    });

    test('defaults to first flavor when prod is not available', () {
      FastfileGenerator.generate(tempDir.path, ['staging', 'dev']);

      final content = File(p.join(tempDir.path, 'Fastfile'))
          .readAsStringSync();
      expect(content, contains('options[:flavor] || "staging"'));
    });

    test('overwrites existing file with correct content', () {
      FastfileGenerator.generate(tempDir.path, ['prod']);
      final file = File(p.join(tempDir.path, 'Fastfile'));
      final afterFirst = file.readAsStringSync();

      file.writeAsStringSync('CUSTOM');

      FastfileGenerator.generate(tempDir.path, ['prod']);
      expect(file.readAsStringSync(), afterFirst);
    });

    test('does not create file in dry-run mode', () {
      FastfileGenerator.generate(tempDir.path, ['prod'], dryRun: true);

      expect(
        File(p.join(tempDir.path, 'Fastfile')).existsSync(),
        isFalse,
      );
    });
  });
}
