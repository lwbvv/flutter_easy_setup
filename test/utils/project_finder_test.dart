import 'dart:io';

import 'package:easy_setup/easy_setup.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('ProjectFinder', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('project_finder_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    group('configPath', () {
      test('joins project root with easy_setup.yaml', () {
        final result = ProjectFinder.configPath('/my/project');
        expect(result, p.join('/my/project', 'easy_setup.yaml'));
      });
    });

    group('androidBuildGradlePath', () {
      test('returns .kts path when .kts file exists', () {
        final ktsDir = Directory(p.join(tempDir.path, 'android', 'app'));
        ktsDir.createSync(recursive: true);
        File(p.join(ktsDir.path, 'build.gradle.kts')).writeAsStringSync('');

        final result = ProjectFinder.androidBuildGradlePath(tempDir.path);
        expect(result, p.join(tempDir.path, 'android', 'app', 'build.gradle.kts'));
      });

      test('returns .gradle path when .kts does not exist', () {
        final result = ProjectFinder.androidBuildGradlePath(tempDir.path);
        expect(result, p.join(tempDir.path, 'android', 'app', 'build.gradle'));
      });
    });

    group('iOS path helpers', () {
      test('iosXcconfigDir returns ios/Flutter/', () {
        expect(
          ProjectFinder.iosXcconfigDir('/root'),
          p.join('/root', 'ios', 'Flutter'),
        );
      });

      test('iosPbxprojPath returns correct path', () {
        expect(
          ProjectFinder.iosPbxprojPath('/root'),
          p.join('/root', 'ios', 'Runner.xcodeproj', 'project.pbxproj'),
        );
      });

      test('iosSchemesDir returns correct path', () {
        expect(
          ProjectFinder.iosSchemesDir('/root'),
          p.join('/root', 'ios', 'Runner.xcodeproj', 'xcshareddata', 'xcschemes'),
        );
      });

      test('iosInfoPlistPath returns correct path', () {
        expect(
          ProjectFinder.iosInfoPlistPath('/root'),
          p.join('/root', 'ios', 'Runner', 'Info.plist'),
        );
      });

      test('iosPodfilePath returns correct path', () {
        expect(
          ProjectFinder.iosPodfilePath('/root'),
          p.join('/root', 'ios', 'Podfile'),
        );
      });
    });

    group('findFlutterRoot', () {
      test('finds Flutter project root with sdk: flutter', () {
        File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_app
dependencies:
  flutter:
    sdk: flutter
''');

        final result = ProjectFinder.findFlutterRoot(tempDir.path);
        expect(result, tempDir.path);
      });

      test('finds Flutter project root with flutter: key', () {
        File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_app
dependencies:
  something: ^1.0.0

  flutter:
    uses-material-design: true
''');

        final result = ProjectFinder.findFlutterRoot(tempDir.path);
        expect(result, tempDir.path);
      });

      test('searches parent directories', () {
        File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_app
dependencies:
  flutter:
    sdk: flutter
''');
        final subDir = Directory(p.join(tempDir.path, 'lib', 'src'));
        subDir.createSync(recursive: true);

        final result = ProjectFinder.findFlutterRoot(subDir.path);
        expect(result, tempDir.path);
      });

      test('returns null when no Flutter project found', () {
        // No pubspec.yaml at all
        final result = ProjectFinder.findFlutterRoot(tempDir.path);
        expect(result, isNull);
      });

      test('returns null for non-Flutter Dart project', () {
        File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_dart_package
environment:
  sdk: ^3.0.0
''');

        final result = ProjectFinder.findFlutterRoot(tempDir.path);
        expect(result, isNull);
      });
    });
  });
}
