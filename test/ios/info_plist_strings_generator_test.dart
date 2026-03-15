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
    Directory(p.join(projectRoot, 'ios', 'Runner')).createSync(recursive: true);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('InfoPlistStringsGenerator', () {
    test('generates flavor-specific strings in Flavors directory', () {
      InfoPlistStringsGenerator.generate(
        projectRoot,
        flavors: {
          'dev': const FlavorConfig(
            bundleId: 'com.example.dev',
            name: 'MyApp Dev',
            localized: {'ko': FlavorLocalizedConfig(appName: '마이앱 Dev')},
          ),
          'prod': const FlavorConfig(
            bundleId: 'com.example.prod',
            name: 'MyApp',
            localized: {'ko': FlavorLocalizedConfig(appName: '마이앱')},
          ),
        },
      );

      // dev/ko
      final devKo = File(p.join(projectRoot, 'ios', 'Flavors', 'dev',
              'ko.lproj', 'InfoPlist.strings'))
          .readAsStringSync();
      expect(devKo, contains('"CFBundleDisplayName" = "마이앱 Dev";'));

      // dev/en (uses flavor name)
      final devEn = File(p.join(projectRoot, 'ios', 'Flavors', 'dev',
              'en.lproj', 'InfoPlist.strings'))
          .readAsStringSync();
      expect(devEn, contains('"CFBundleDisplayName" = "MyApp Dev";'));

      // prod/ko
      final prodKo = File(p.join(projectRoot, 'ios', 'Flavors', 'prod',
              'ko.lproj', 'InfoPlist.strings'))
          .readAsStringSync();
      expect(prodKo, contains('"CFBundleDisplayName" = "마이앱";'));

      // prod/en
      final prodEn = File(p.join(projectRoot, 'ios', 'Flavors', 'prod',
              'en.lproj', 'InfoPlist.strings'))
          .readAsStringSync();
      expect(prodEn, contains('"CFBundleDisplayName" = "MyApp";'));
    });

    test('generates permission strings in Runner directory', () {
      InfoPlistStringsGenerator.generate(
        projectRoot,
        flavors: {
          'dev': const FlavorConfig(bundleId: 'x', name: 'X'),
        },
        permission: {
          'NSCameraUsageDescription': 'Camera access is required',
        },
        localizedPermission: {
          'ko': {
            'NSCameraUsageDescription': '카메라 접근이 필요합니다',
          },
        },
      );

      // en permission in Runner
      final enContent = File(p.join(
              projectRoot, 'ios', 'Runner', 'en.lproj', 'InfoPlist.strings'))
          .readAsStringSync();
      expect(enContent,
          contains('"NSCameraUsageDescription" = "Camera access is required";'));

      // ko permission in Runner
      final koContent = File(p.join(
              projectRoot, 'ios', 'Runner', 'ko.lproj', 'InfoPlist.strings'))
          .readAsStringSync();
      expect(koContent,
          contains('"NSCameraUsageDescription" = "카메라 접근이 필요합니다";'));
    });

    test('does not generate flavor strings when no localized config', () {
      InfoPlistStringsGenerator.generate(
        projectRoot,
        flavors: {
          'dev': const FlavorConfig(bundleId: 'x', name: 'X'),
        },
      );

      final flavorsDir = Directory(p.join(projectRoot, 'ios', 'Flavors'));
      expect(flavorsDir.existsSync(), isFalse);
    });

    test('does not create files in dry-run mode', () {
      InfoPlistStringsGenerator.generate(
        projectRoot,
        flavors: {
          'dev': const FlavorConfig(
            bundleId: 'x',
            name: 'X',
            localized: {'ko': FlavorLocalizedConfig(appName: '테스트')},
          ),
        },
        dryRun: true,
      );

      final flavorsDir = Directory(p.join(projectRoot, 'ios', 'Flavors'));
      expect(flavorsDir.existsSync(), isFalse);
    });

    test('is idempotent', () {
      final flavors = {
        'dev': const FlavorConfig(
          bundleId: 'x',
          name: 'X',
          localized: {'ko': FlavorLocalizedConfig(appName: '테스트')},
        ),
      };

      InfoPlistStringsGenerator.generate(projectRoot, flavors: flavors);
      final first = File(p.join(projectRoot, 'ios', 'Flavors', 'dev',
              'ko.lproj', 'InfoPlist.strings'))
          .readAsStringSync();

      InfoPlistStringsGenerator.generate(projectRoot, flavors: flavors);
      final second = File(p.join(projectRoot, 'ios', 'Flavors', 'dev',
              'ko.lproj', 'InfoPlist.strings'))
          .readAsStringSync();

      expect(second, first);
    });

    test('does nothing when no permission and no localized', () {
      InfoPlistStringsGenerator.generate(
        projectRoot,
        flavors: {
          'dev': const FlavorConfig(bundleId: 'x', name: 'X'),
        },
      );

      final runnerDir = Directory(p.join(projectRoot, 'ios', 'Runner'));
      final lprojDirs = runnerDir
          .listSync()
          .whereType<Directory>()
          .where((d) => d.path.endsWith('.lproj'));
      expect(lprojDirs, isEmpty);
    });

    test('generates multiple locales per flavor', () {
      InfoPlistStringsGenerator.generate(
        projectRoot,
        flavors: {
          'dev': const FlavorConfig(
            bundleId: 'x',
            name: 'X Dev',
            localized: {
              'ko': FlavorLocalizedConfig(appName: '테스트'),
              'ja': FlavorLocalizedConfig(appName: 'テスト'),
            },
          ),
        },
      );

      expect(
        File(p.join(projectRoot, 'ios', 'Flavors', 'dev', 'ko.lproj',
                'InfoPlist.strings'))
            .existsSync(),
        isTrue,
      );
      expect(
        File(p.join(projectRoot, 'ios', 'Flavors', 'dev', 'ja.lproj',
                'InfoPlist.strings'))
            .existsSync(),
        isTrue,
      );
      expect(
        File(p.join(projectRoot, 'ios', 'Flavors', 'dev', 'en.lproj',
                'InfoPlist.strings'))
            .existsSync(),
        isTrue,
      );
    });
  });
}
