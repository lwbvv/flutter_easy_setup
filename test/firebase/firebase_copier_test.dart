import 'dart:io';

import 'package:easy_setup/easy_setup.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('firebase_copier_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('FirebaseCopier.copyAndroidConfig', () {
    test('copies google-services.json to android/app/src/{flavor}/', () {
      // Create source file
      final sourceDir = Directory(p.join(tempDir.path, 'config', 'dev'));
      sourceDir.createSync(recursive: true);
      final sourceFile = File(p.join(sourceDir.path, 'google-services.json'));
      sourceFile.writeAsStringSync('{"project_id":"dev"}');

      FirebaseCopier.copyAndroidConfig(
        tempDir.path,
        'dev',
        'config/dev/google-services.json',
      );

      final dest = File(p.join(tempDir.path, 'android', 'app', 'src', 'dev', 'google-services.json'));
      expect(dest.existsSync(), isTrue);
      expect(dest.readAsStringSync(), '{"project_id":"dev"}');
    });

    test('skips when source file does not exist', () {
      // Should not throw
      FirebaseCopier.copyAndroidConfig(
        tempDir.path,
        'dev',
        'config/dev/google-services.json',
      );

      final dest = File(p.join(tempDir.path, 'android', 'app', 'src', 'dev', 'google-services.json'));
      expect(dest.existsSync(), isFalse);
    });

    test('overwrites when destination already exists', () {
      // Create source file
      final sourceDir = Directory(p.join(tempDir.path, 'config', 'dev'));
      sourceDir.createSync(recursive: true);
      File(p.join(sourceDir.path, 'google-services.json'))
          .writeAsStringSync('{"project_id":"dev"}');

      FirebaseCopier.copyAndroidConfig(tempDir.path, 'dev', 'config/dev/google-services.json');

      // Modify dest
      final dest = File(p.join(tempDir.path, 'android', 'app', 'src', 'dev', 'google-services.json'));
      dest.writeAsStringSync('MODIFIED');

      // Second run should overwrite with source content
      FirebaseCopier.copyAndroidConfig(tempDir.path, 'dev', 'config/dev/google-services.json');

      expect(dest.readAsStringSync(), '{"project_id":"dev"}');
    });

    test('does not copy in dry-run mode', () {
      final sourceDir = Directory(p.join(tempDir.path, 'config', 'dev'));
      sourceDir.createSync(recursive: true);
      File(p.join(sourceDir.path, 'google-services.json'))
          .writeAsStringSync('{"project_id":"dev"}');

      FirebaseCopier.copyAndroidConfig(
        tempDir.path,
        'dev',
        'config/dev/google-services.json',
        dryRun: true,
      );

      final dest = File(p.join(tempDir.path, 'android', 'app', 'src', 'dev', 'google-services.json'));
      expect(dest.existsSync(), isFalse);
    });

    test('creates destination directories recursively', () {
      final sourceDir = Directory(p.join(tempDir.path, 'config', 'prod'));
      sourceDir.createSync(recursive: true);
      File(p.join(sourceDir.path, 'google-services.json'))
          .writeAsStringSync('{"project_id":"prod"}');

      // android/app/src/prod/ does not exist yet
      FirebaseCopier.copyAndroidConfig(
        tempDir.path,
        'prod',
        'config/prod/google-services.json',
      );

      final dest = File(p.join(tempDir.path, 'android', 'app', 'src', 'prod', 'google-services.json'));
      expect(dest.existsSync(), isTrue);
    });
  });

  group('FirebaseCopier.copyIosConfig', () {
    test('copies GoogleService-Info.plist to ios/Runner/Firebase/{flavor}/', () {
      final sourceDir = Directory(p.join(tempDir.path, 'config', 'dev'));
      sourceDir.createSync(recursive: true);
      final sourceFile = File(p.join(sourceDir.path, 'GoogleService-Info.plist'));
      sourceFile.writeAsStringSync('<plist>dev</plist>');

      FirebaseCopier.copyIosConfig(
        tempDir.path,
        'dev',
        'config/dev/GoogleService-Info.plist',
      );

      final dest = File(p.join(
        tempDir.path, 'ios', 'Runner', 'Firebase', 'dev', 'GoogleService-Info.plist',
      ));
      expect(dest.existsSync(), isTrue);
      expect(dest.readAsStringSync(), '<plist>dev</plist>');
    });

    test('skips when source file does not exist', () {
      FirebaseCopier.copyIosConfig(
        tempDir.path,
        'dev',
        'config/dev/GoogleService-Info.plist',
      );

      final dest = File(p.join(
        tempDir.path, 'ios', 'Runner', 'Firebase', 'dev', 'GoogleService-Info.plist',
      ));
      expect(dest.existsSync(), isFalse);
    });

    test('overwrites when destination already exists', () {
      final sourceDir = Directory(p.join(tempDir.path, 'config', 'dev'));
      sourceDir.createSync(recursive: true);
      File(p.join(sourceDir.path, 'GoogleService-Info.plist'))
          .writeAsStringSync('<plist>dev</plist>');

      FirebaseCopier.copyIosConfig(tempDir.path, 'dev', 'config/dev/GoogleService-Info.plist');

      final dest = File(p.join(
        tempDir.path, 'ios', 'Runner', 'Firebase', 'dev', 'GoogleService-Info.plist',
      ));
      dest.writeAsStringSync('MODIFIED');

      // Second run should overwrite with source content
      FirebaseCopier.copyIosConfig(tempDir.path, 'dev', 'config/dev/GoogleService-Info.plist');

      expect(dest.readAsStringSync(), '<plist>dev</plist>');
    });

    test('does not copy in dry-run mode', () {
      final sourceDir = Directory(p.join(tempDir.path, 'config', 'dev'));
      sourceDir.createSync(recursive: true);
      File(p.join(sourceDir.path, 'GoogleService-Info.plist'))
          .writeAsStringSync('<plist>dev</plist>');

      FirebaseCopier.copyIosConfig(
        tempDir.path,
        'dev',
        'config/dev/GoogleService-Info.plist',
        dryRun: true,
      );

      final dest = File(p.join(
        tempDir.path, 'ios', 'Runner', 'Firebase', 'dev', 'GoogleService-Info.plist',
      ));
      expect(dest.existsSync(), isFalse);
    });

    test('creates destination directories recursively', () {
      final sourceDir = Directory(p.join(tempDir.path, 'config', 'prod'));
      sourceDir.createSync(recursive: true);
      File(p.join(sourceDir.path, 'GoogleService-Info.plist'))
          .writeAsStringSync('<plist>prod</plist>');

      FirebaseCopier.copyIosConfig(
        tempDir.path,
        'prod',
        'config/prod/GoogleService-Info.plist',
      );

      final dest = File(p.join(
        tempDir.path, 'ios', 'Runner', 'Firebase', 'prod', 'GoogleService-Info.plist',
      ));
      expect(dest.existsSync(), isTrue);
    });
  });
}
