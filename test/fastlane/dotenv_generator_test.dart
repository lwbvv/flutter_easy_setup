import 'dart:io';

import 'package:easy_setup/src/fastlane/dotenv_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('dotenv_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('DotenvGenerator', () {
    test('creates .env with all required variables', () {
      DotenvGenerator.generate(tempDir.path);

      final file = File(p.join(tempDir.path, '.env'));
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('TEAM_ID='));
      expect(content, contains('ITC_TEAM_ID='));
      expect(content, contains('API_KEY_ID='));
      expect(content, contains('API_KEY_ISSUER_ID='));
      expect(content, contains('CERTS_REPO_URL='));
      expect(content, contains('APPLE_ID='));
    });

    test('does not overwrite existing .env', () {
      final file = File(p.join(tempDir.path, '.env'));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('TEAM_ID=REAL_VALUE');

      DotenvGenerator.generate(tempDir.path);

      expect(file.readAsStringSync(), 'TEAM_ID=REAL_VALUE');
    });

    test('does not create file in dry-run mode', () {
      DotenvGenerator.generate(tempDir.path, dryRun: true);

      expect(
        File(p.join(tempDir.path, '.env')).existsSync(),
        isFalse,
      );
    });
  });
}
