import 'dart:io';

import 'package:easy_setup/src/fastlane/matchfile_generator.dart';
import 'package:easy_setup/src/models/ci_cd_config.dart';
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

  const ios = CiCdIosConfig(
    storage: 'https://github.com/user/certs.git',
    teamId: 'TEAM123',
    itcTeamId: 'ITC456',
    apiKey: ApiKeyConfig(
      id: 'KEY',
      issuerId: 'ISSUER',
      keyPath: 'fastlane/AuthKey.p8',
    ),
  );

  group('MatchfileGenerator', () {
    test('creates Matchfile in output directory with correct content', () {
      MatchfileGenerator.generate(
        tempDir.path,
        ios,
        ['com.app.dev', 'com.app'],
      );

      final file = File(p.join(tempDir.path, 'Matchfile'));
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('git_url("https://github.com/user/certs.git")'));
      expect(content, contains('storage_mode("git")'));
      expect(content, contains('type("appstore")'));
      expect(content, contains('"com.app.dev"'));
      expect(content, contains('"com.app"'));
      expect(content, contains('team_id("TEAM123")'));
      expect(content, contains('api_key_path("api_key.json")'));
    });

    test('is idempotent', () {
      MatchfileGenerator.generate(tempDir.path, ios, ['com.app']);

      final file = File(p.join(tempDir.path, 'Matchfile'));
      file.writeAsStringSync('CUSTOM');

      MatchfileGenerator.generate(tempDir.path, ios, ['com.app']);
      expect(file.readAsStringSync(), 'CUSTOM');
    });

    test('does not create file in dry-run mode', () {
      MatchfileGenerator.generate(tempDir.path, ios, ['com.app'], dryRun: true);

      expect(
        File(p.join(tempDir.path, 'Matchfile')).existsSync(),
        isFalse,
      );
    });
  });
}
