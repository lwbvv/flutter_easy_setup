import 'dart:io';

import 'package:easy_setup/easy_setup.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String projectRoot;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('info_plist_strings_test_');
    projectRoot = tempDir.path;
    // ios/Runner 디렉터리 생성
    Directory(p.join(projectRoot, 'ios', 'Runner')).createSync(recursive: true);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('InfoPlistStringsGenerator', () {
    test('generates InfoPlist.strings with flavor app_name (non-en uses raw value)', () {
      InfoPlistStringsGenerator.generate(
        projectRoot,
        flavorLocalized: {
          'ko': const FlavorLocalizedConfig(appName: '테스트 앱'),
        },
      );

      final stringsPath =
          p.join(projectRoot, 'ios', 'Runner', 'ko.lproj', 'InfoPlist.strings');
      expect(File(stringsPath).existsSync(), isTrue);

      final content = File(stringsPath).readAsStringSync();
      // non-en locale은 yaml 값을 그대로 사용
      expect(content, contains('"CFBundleDisplayName" = "테스트 앱";'));
    });

    test('en locale uses xcconfig variable for CFBundleDisplayName', () {
      InfoPlistStringsGenerator.generate(
        projectRoot,
        flavorLocalized: {
          'en': const FlavorLocalizedConfig(appName: 'Test App'),
        },
      );

      final stringsPath =
          p.join(projectRoot, 'ios', 'Runner', 'en.lproj', 'InfoPlist.strings');
      expect(File(stringsPath).existsSync(), isTrue);

      final content = File(stringsPath).readAsStringSync();
      // en은 xcconfig 변수 참조
      expect(content, contains('"CFBundleDisplayName" = "(\$APP_DISPLAY_NAME)";'));
    });

    test('generates en.lproj with base permission', () {
      InfoPlistStringsGenerator.generate(
        projectRoot,
        permission: {
          'NSCameraUsageDescription': 'Camera access is required',
          'NSPhotoLibraryUsageDescription': 'Photo library access is required',
        },
      );

      final stringsPath = p.join(
          projectRoot, 'ios', 'Runner', 'en.lproj', 'InfoPlist.strings');
      expect(File(stringsPath).existsSync(), isTrue);

      final content = File(stringsPath).readAsStringSync();
      expect(content,
          contains('"NSCameraUsageDescription" = "Camera access is required";'));
      expect(
          content,
          contains(
              '"NSPhotoLibraryUsageDescription" = "Photo library access is required";'));

      // Base.lproj는 생성되지 않아야 함
      final basePath = p.join(
          projectRoot, 'ios', 'Runner', 'Base.lproj', 'InfoPlist.strings');
      expect(File(basePath).existsSync(), isFalse);
    });

    test('generates locale-specific permission files', () {
      InfoPlistStringsGenerator.generate(
        projectRoot,
        localizedPermission: {
          'ko': {
            'NSCameraUsageDescription': '카메라 접근이 필요합니다',
          },
          'en': {
            'NSCameraUsageDescription': 'Camera access is required',
          },
        },
      );

      final koContent = File(p.join(
              projectRoot, 'ios', 'Runner', 'ko.lproj', 'InfoPlist.strings'))
          .readAsStringSync();
      expect(koContent,
          contains('"NSCameraUsageDescription" = "카메라 접근이 필요합니다";'));

      final enContent = File(p.join(
              projectRoot, 'ios', 'Runner', 'en.lproj', 'InfoPlist.strings'))
          .readAsStringSync();
      expect(enContent,
          contains('"NSCameraUsageDescription" = "Camera access is required";'));
    });

    test('merges flavor app_name and localized permission for same locale', () {
      InfoPlistStringsGenerator.generate(
        projectRoot,
        flavorLocalized: {
          'ko': const FlavorLocalizedConfig(appName: '테스트'),
        },
        localizedPermission: {
          'ko': {
            'NSCameraUsageDescription': '카메라 접근이 필요합니다',
          },
        },
      );

      final stringsPath =
          p.join(projectRoot, 'ios', 'Runner', 'ko.lproj', 'InfoPlist.strings');
      final content = File(stringsPath).readAsStringSync();
      // non-en locale은 yaml 값 그대로
      expect(content, contains('"CFBundleDisplayName" = "테스트";'));
      expect(content,
          contains('"NSCameraUsageDescription" = "카메라 접근이 필요합니다";'));
    });

    test('generates multiple locale directories', () {
      InfoPlistStringsGenerator.generate(
        projectRoot,
        flavorLocalized: {
          'ko': const FlavorLocalizedConfig(appName: '테스트'),
          'ja': const FlavorLocalizedConfig(appName: 'テスト'),
        },
      );

      expect(
        File(p.join(projectRoot, 'ios', 'Runner', 'ko.lproj',
                'InfoPlist.strings'))
            .existsSync(),
        isTrue,
      );
      expect(
        File(p.join(projectRoot, 'ios', 'Runner', 'ja.lproj',
                'InfoPlist.strings'))
            .existsSync(),
        isTrue,
      );
    });

    test('does not create files in dry-run mode', () {
      InfoPlistStringsGenerator.generate(
        projectRoot,
        flavorLocalized: {
          'ko': const FlavorLocalizedConfig(appName: '테스트'),
        },
        dryRun: true,
      );

      final lprojDir = p.join(projectRoot, 'ios', 'Runner', 'ko.lproj');
      expect(Directory(lprojDir).existsSync(), isFalse);
    });

    test('overwrites existing files on re-run (idempotent)', () {
      InfoPlistStringsGenerator.generate(
        projectRoot,
        flavorLocalized: {
          'ko': const FlavorLocalizedConfig(appName: '테스트'),
        },
      );

      final stringsPath =
          p.join(projectRoot, 'ios', 'Runner', 'ko.lproj', 'InfoPlist.strings');
      final firstContent = File(stringsPath).readAsStringSync();

      InfoPlistStringsGenerator.generate(
        projectRoot,
        flavorLocalized: {
          'ko': const FlavorLocalizedConfig(appName: '테스트'),
        },
      );

      final secondContent = File(stringsPath).readAsStringSync();
      expect(secondContent, firstContent);
    });

    test('skips locale with no effective entries', () {
      InfoPlistStringsGenerator.generate(
        projectRoot,
        flavorLocalized: {
          'ko': const FlavorLocalizedConfig(),
        },
      );

      // 비어있는 locale 설정 → no InfoPlist.strings entry needed
      final lprojDir = p.join(projectRoot, 'ios', 'Runner', 'ko.lproj');
      expect(Directory(lprojDir).existsSync(), isFalse);
    });

    test('does nothing when all parameters are null', () {
      InfoPlistStringsGenerator.generate(projectRoot);

      // 아무 .lproj 디렉터리도 생성되지 않아야 함
      final runnerDir = Directory(p.join(projectRoot, 'ios', 'Runner'));
      final lprojDirs = runnerDir
          .listSync()
          .whereType<Directory>()
          .where((d) => d.path.endsWith('.lproj'));
      expect(lprojDirs, isEmpty);
    });

    test('merges base permission into en.lproj with localized permission', () {
      InfoPlistStringsGenerator.generate(
        projectRoot,
        permission: {
          'NSCameraUsageDescription': 'Camera access needed',
        },
        localizedPermission: {
          'ko': {
            'NSCameraUsageDescription': '카메라 접근 필요',
          },
        },
      );

      // en.lproj에 기본 permission 포함
      final enContent = File(p.join(
              projectRoot, 'ios', 'Runner', 'en.lproj', 'InfoPlist.strings'))
          .readAsStringSync();
      expect(enContent,
          contains('"NSCameraUsageDescription" = "Camera access needed";'));

      // ko.lproj
      final koContent = File(p.join(
              projectRoot, 'ios', 'Runner', 'ko.lproj', 'InfoPlist.strings'))
          .readAsStringSync();
      expect(koContent,
          contains('"NSCameraUsageDescription" = "카메라 접근 필요";'));

      // Base.lproj는 생성되지 않아야 함
      final basePath = p.join(
          projectRoot, 'ios', 'Runner', 'Base.lproj', 'InfoPlist.strings');
      expect(File(basePath).existsSync(), isFalse);
    });

    test('merges base permission and en localized permission into en.lproj', () {
      InfoPlistStringsGenerator.generate(
        projectRoot,
        permission: {
          'NSCameraUsageDescription': 'Camera access needed',
          'NSPhotoLibraryUsageDescription': 'Photo library access needed',
        },
        localizedPermission: {
          'en': {
            'NSCameraUsageDescription': 'Camera access is required',
          },
        },
      );

      // en의 localized_permission이 base permission을 덮어씀
      final enContent = File(p.join(
              projectRoot, 'ios', 'Runner', 'en.lproj', 'InfoPlist.strings'))
          .readAsStringSync();
      expect(enContent,
          contains('"NSCameraUsageDescription" = "Camera access is required";'));
      expect(enContent,
          contains('"NSPhotoLibraryUsageDescription" = "Photo library access needed";'));
    });
  });
}
