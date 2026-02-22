import 'dart:io';

import 'package:easy_setup/src/ios/xcconfig_generator.dart';
import 'package:easy_setup/easy_setup.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('xcconfig_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  const config = FlavorConfig(bundleId: 'com.example.app.dev', name: 'MyApp Dev');

  group('XcconfigGenerator', () {
    test('creates Debug, Release, and Profile xcconfig files', () {
      XcconfigGenerator.generate(tempDir.path, 'dev', config);

      expect(File(p.join(tempDir.path, 'Debug-dev.xcconfig')).existsSync(), isTrue);
      expect(File(p.join(tempDir.path, 'Release-dev.xcconfig')).existsSync(), isTrue);
      expect(File(p.join(tempDir.path, 'Profile-dev.xcconfig')).existsSync(), isTrue);
    });

    test('Debug xcconfig includes Debug.xcconfig', () {
      XcconfigGenerator.generate(tempDir.path, 'dev', config);

      final content = File(p.join(tempDir.path, 'Debug-dev.xcconfig')).readAsStringSync();
      expect(content, contains('#include "Debug.xcconfig"'));
      expect(content, contains('APP_DISPLAY_NAME=MyApp Dev'));
    });

    test('Release xcconfig includes Release.xcconfig', () {
      XcconfigGenerator.generate(tempDir.path, 'dev', config);

      final content = File(p.join(tempDir.path, 'Release-dev.xcconfig')).readAsStringSync();
      expect(content, contains('#include "Release.xcconfig"'));
      expect(content, contains('APP_DISPLAY_NAME=MyApp Dev'));
    });

    test('Profile xcconfig includes Release.xcconfig', () {
      XcconfigGenerator.generate(tempDir.path, 'dev', config);

      final content = File(p.join(tempDir.path, 'Profile-dev.xcconfig')).readAsStringSync();
      expect(content, contains('#include "Release.xcconfig"'));
      expect(content, contains('APP_DISPLAY_NAME=MyApp Dev'));
    });

    test('is idempotent — does not overwrite existing files', () {
      XcconfigGenerator.generate(tempDir.path, 'dev', config);

      // Overwrite with custom content to verify it's not replaced
      final debugFile = File(p.join(tempDir.path, 'Debug-dev.xcconfig'));
      debugFile.writeAsStringSync('CUSTOM CONTENT');

      XcconfigGenerator.generate(tempDir.path, 'dev', config);

      expect(debugFile.readAsStringSync(), 'CUSTOM CONTENT');
    });

    test('does not create files in dry-run mode', () {
      XcconfigGenerator.generate(tempDir.path, 'dev', config, dryRun: true);

      expect(File(p.join(tempDir.path, 'Debug-dev.xcconfig')).existsSync(), isFalse);
      expect(File(p.join(tempDir.path, 'Release-dev.xcconfig')).existsSync(), isFalse);
      expect(File(p.join(tempDir.path, 'Profile-dev.xcconfig')).existsSync(), isFalse);
    });

    test('creates parent directories if they do not exist', () {
      final nestedDir = p.join(tempDir.path, 'ios', 'Flutter');

      XcconfigGenerator.generate(nestedDir, 'dev', config);

      expect(File(p.join(nestedDir, 'Debug-dev.xcconfig')).existsSync(), isTrue);
    });
  });
}
