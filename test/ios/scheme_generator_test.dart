import 'dart:io';

import 'package:easy_setup/src/ios/scheme_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  const runnerUuid = 'AABBCCDD11223344EEFF0011';

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('scheme_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('SchemeGenerator', () {
    test('creates .xcscheme file for given flavor', () {
      SchemeGenerator.generate(tempDir.path, 'dev', runnerUuid);

      final file = File(p.join(tempDir.path, 'dev.xcscheme'));
      expect(file.existsSync(), isTrue);
    });

    test('scheme XML uses correct buildConfiguration names', () {
      SchemeGenerator.generate(tempDir.path, 'dev', runnerUuid);

      final content = File(p.join(tempDir.path, 'dev.xcscheme')).readAsStringSync();
      expect(content, contains('buildConfiguration = "Debug-dev"'));
      expect(content, contains('buildConfiguration = "Profile-dev"'));
      expect(content, contains('buildConfiguration = "Release-dev"'));
    });

    test('scheme XML contains Runner target UUID in BuildableReference', () {
      SchemeGenerator.generate(tempDir.path, 'dev', runnerUuid);

      final content = File(p.join(tempDir.path, 'dev.xcscheme')).readAsStringSync();
      expect(content, contains('BlueprintIdentifier = "$runnerUuid"'));
      expect(content, contains('BuildableName = "Runner.app"'));
      expect(content, contains('BlueprintName = "Runner"'));
    });

    test('scheme XML is valid XML with version declaration', () {
      SchemeGenerator.generate(tempDir.path, 'dev', runnerUuid);

      final content = File(p.join(tempDir.path, 'dev.xcscheme')).readAsStringSync();
      expect(content, startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(content, contains('<Scheme'));
      expect(content, contains('</Scheme>'));
    });

    test('overwrites existing scheme with correct content', () {
      SchemeGenerator.generate(tempDir.path, 'dev', runnerUuid);
      final afterFirst = File(p.join(tempDir.path, 'dev.xcscheme')).readAsStringSync();

      File(p.join(tempDir.path, 'dev.xcscheme')).writeAsStringSync('CUSTOM');

      SchemeGenerator.generate(tempDir.path, 'dev', runnerUuid);
      final afterSecond = File(p.join(tempDir.path, 'dev.xcscheme')).readAsStringSync();

      expect(afterSecond, afterFirst);
    });

    test('does not create file in dry-run mode', () {
      SchemeGenerator.generate(tempDir.path, 'dev', runnerUuid, dryRun: true);

      expect(File(p.join(tempDir.path, 'dev.xcscheme')).existsSync(), isFalse);
    });

    test('creates directory recursively if it does not exist', () {
      final nestedDir = p.join(tempDir.path, 'xcshareddata', 'xcschemes');

      SchemeGenerator.generate(nestedDir, 'prod', runnerUuid);

      expect(File(p.join(nestedDir, 'prod.xcscheme')).existsSync(), isTrue);
    });
  });
}
