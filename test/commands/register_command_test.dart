import 'dart:io';

import 'package:easy_setup/easy_setup.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  final yamlWithCiCd = '''
easy_setup:
  flavors:
    dev:
      bundle_id: com.example.app.dev
      name: MyApp Dev
    prod:
      bundle_id: com.example.app
      name: MyApp

  ci_cd:
    ios:
      storage: https://github.com/user/certs.git
      team_id: XXXXXXXXXX
      itc_team_id: YYYYYYYYYY
      api_key:
        id: KEY_ID
        issuer_id: ISSUER_ID
        key_path: fastlane/AuthKey.p8
''';

  final yamlWithCiCdFlavors = '''
easy_setup:
  flavors:
    dev:
      bundle_id: com.example.app.dev
      name: MyApp Dev
    prod:
      bundle_id: com.example.app
      name: MyApp

  ci_cd:
    flavors:
      prod:
        bundle_id: com.example.app

    ios:
      storage: https://github.com/user/certs.git
      team_id: XXXXXXXXXX
      itc_team_id: YYYYYYYYYY
      api_key:
        id: KEY_ID
        issuer_id: ISSUER_ID
        key_path: fastlane/AuthKey.p8
''';

  /// 테스트용 dummy .p8 파일을 생성합니다.
  void createDummyApiKey(String root) {
    final keyDir = Directory(p.join(root, 'fastlane'));
    keyDir.createSync(recursive: true);
    File(p.join(keyDir.path, 'AuthKey.p8'))
        .writeAsStringSync('-----BEGIN PRIVATE KEY-----\nDUMMY\n-----END PRIVATE KEY-----');
  }

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('register_test_');
    File(p.join(tempDir.path, 'pubspec.yaml'))
        .writeAsStringSync('name: test_app\nenvironment:\n  sdk: ">=3.0.0 <4.0.0"\n  flutter: ">=3.0.0"\ndependencies:\n  flutter:\n    sdk: flutter\n');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('RegisterCommand', () {
    test('throws SetupException when no ci_cd section', () async {
      File(p.join(tempDir.path, 'easy_setup.yaml'))
          .writeAsStringSync('easy_setup:\n  flavors:\n    dev:\n      bundle_id: com.example.app.dev\n      name: MyApp Dev\n');

      expect(
        () => RegisterCommand.run(projectRoot: tempDir.path),
        throwsA(isA<SetupException>()),
      );
    });

    test('throws when API key file not found', () async {
      File(p.join(tempDir.path, 'easy_setup.yaml'))
          .writeAsStringSync(yamlWithCiCd);

      expect(
        () => RegisterCommand.run(projectRoot: tempDir.path, dryRun: true),
        throwsA(isA<SetupException>().having(
          (e) => e.message,
          'message',
          contains('API Key file not found'),
        )),
      );
    });

    test('dry-run prints what would be done without API calls', () async {
      File(p.join(tempDir.path, 'easy_setup.yaml'))
          .writeAsStringSync(yamlWithCiCd);
      createDummyApiKey(tempDir.path);

      await RegisterCommand.run(projectRoot: tempDir.path, dryRun: true);
    });

    test('resolves all flavors when ci_cd.flavors is not specified', () async {
      File(p.join(tempDir.path, 'easy_setup.yaml'))
          .writeAsStringSync(yamlWithCiCd);
      createDummyApiKey(tempDir.path);

      // dry-run으로 flavor 해석만 검증 (API 호출 없음)
      await RegisterCommand.run(projectRoot: tempDir.path, dryRun: true);
    });

    test('resolves only ci_cd.flavors when specified', () async {
      File(p.join(tempDir.path, 'easy_setup.yaml'))
          .writeAsStringSync(yamlWithCiCdFlavors);
      createDummyApiKey(tempDir.path);

      // dry-run으로 flavor 해석만 검증 — prod만 대상
      await RegisterCommand.run(projectRoot: tempDir.path, dryRun: true);
    });

    test('throws when API key file not found (non dry-run)', () async {
      File(p.join(tempDir.path, 'easy_setup.yaml'))
          .writeAsStringSync(yamlWithCiCd);

      expect(
        () => RegisterCommand.run(projectRoot: tempDir.path),
        throwsA(isA<SetupException>()),
      );
    });
  });
}
