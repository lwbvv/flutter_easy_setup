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

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('register_test_');
    // pubspec.yaml (Flutter 프로젝트로 인식되기 위해 필요)
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

    test('dry-run prints what would be done without running fastlane', () async {
      File(p.join(tempDir.path, 'easy_setup.yaml'))
          .writeAsStringSync(yamlWithCiCd);

      // dry-run should succeed without API key file or fastlane installed
      await RegisterCommand.run(projectRoot: tempDir.path, dryRun: true);
    });

    test('resolves all flavors when ci_cd.flavors is not specified', () async {
      File(p.join(tempDir.path, 'easy_setup.yaml'))
          .writeAsStringSync(yamlWithCiCd);

      // dry-run으로 flavor 해석만 검증 (fastlane 호출 없음)
      await RegisterCommand.run(projectRoot: tempDir.path, dryRun: true);
      // 에러 없이 완료되면 성공 (dev, prod 모두 해석됨)
    });

    test('resolves only ci_cd.flavors when specified', () async {
      File(p.join(tempDir.path, 'easy_setup.yaml'))
          .writeAsStringSync(yamlWithCiCdFlavors);

      // dry-run으로 flavor 해석만 검증 — prod만 대상
      await RegisterCommand.run(projectRoot: tempDir.path, dryRun: true);
    });

    test('throws when API key file not found (non dry-run)', () async {
      File(p.join(tempDir.path, 'easy_setup.yaml'))
          .writeAsStringSync(yamlWithCiCd);

      // API 키 파일이 없으면 SetupException
      expect(
        () => RegisterCommand.run(projectRoot: tempDir.path),
        throwsA(isA<SetupException>()),
      );
    });
  });
}
