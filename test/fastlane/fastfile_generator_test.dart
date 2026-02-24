import 'dart:io';

import 'package:easy_setup/src/fastlane/fastfile_generator.dart';
import 'package:easy_setup/src/models/ci_cd_config.dart';
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

  const ios = CiCdIosConfig(
    storage: 'https://github.com/user/certs.git',
    teamId: 'TEAM123',
    itcTeamId: 'ITC456',
    apiKey: ApiKeyConfig(
      id: 'KEY_ID',
      issuerId: 'ISSUER_ID',
      keyPath: 'fastlane/AuthKey.p8',
      duration: 1200,
      inHouse: false,
    ),
  );

  group('FastfileGenerator', () {
    test('creates Fastfile in output directory with correct content', () {
      FastfileGenerator.generate(tempDir.path, ios, ['dev', 'prod']);

      final file = File(p.join(tempDir.path, 'Fastfile'));
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('default_platform(:ios)'));
      expect(content, contains('key_id: "KEY_ID"'));
      expect(content, contains('issuer_id: "ISSUER_ID"'));
      expect(content, contains('key_filepath: "fastlane/AuthKey.p8"'));
      expect(content, contains('duration: 1200'));
      expect(content, contains('in_house: false'));
      expect(content, contains('lane :certificates'));
      expect(content, contains('lane :beta'));
      expect(content, contains('upload_to_testflight'));
    });

    test('defaults to prod flavor when available', () {
      FastfileGenerator.generate(tempDir.path, ios, ['dev', 'prod']);

      final content = File(p.join(tempDir.path, 'Fastfile'))
          .readAsStringSync();
      expect(content, contains('options[:flavor] || "prod"'));
    });

    test('defaults to first flavor when prod is not available', () {
      FastfileGenerator.generate(tempDir.path, ios, ['staging', 'dev']);

      final content = File(p.join(tempDir.path, 'Fastfile'))
          .readAsStringSync();
      expect(content, contains('options[:flavor] || "staging"'));
    });

    test('is idempotent', () {
      FastfileGenerator.generate(tempDir.path, ios, ['prod']);

      final file = File(p.join(tempDir.path, 'Fastfile'));
      file.writeAsStringSync('CUSTOM');

      FastfileGenerator.generate(tempDir.path, ios, ['prod']);
      expect(file.readAsStringSync(), 'CUSTOM');
    });

    test('does not create file in dry-run mode', () {
      FastfileGenerator.generate(tempDir.path, ios, ['prod'], dryRun: true);

      expect(
        File(p.join(tempDir.path, 'Fastfile')).existsSync(),
        isFalse,
      );
    });
  });
}
