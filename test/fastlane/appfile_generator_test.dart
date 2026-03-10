import 'dart:io';

import 'package:easy_setup/src/fastlane/appfile_generator.dart';
import 'package:easy_setup/src/models/ci_cd_config.dart';
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

  group('AppfileGenerator', () {
    test('creates Appfile in output directory with correct content', () {
      AppfileGenerator.generate(tempDir.path, ios);

      final file = File(p.join(tempDir.path, 'Appfile'));
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('team_id("TEAM123")'));
      expect(content, contains('itc_team_id("ITC456")'));
    });

    test('overwrites existing file with correct content', () {
      AppfileGenerator.generate(tempDir.path, ios);
      final file = File(p.join(tempDir.path, 'Appfile'));
      final afterFirst = file.readAsStringSync();

      file.writeAsStringSync('CUSTOM');

      AppfileGenerator.generate(tempDir.path, ios);
      expect(file.readAsStringSync(), afterFirst);
    });

    test('does not create file in dry-run mode', () {
      AppfileGenerator.generate(tempDir.path, ios, dryRun: true);

      expect(
        File(p.join(tempDir.path, 'Appfile')).existsSync(),
        isFalse,
      );
    });
  });
}
