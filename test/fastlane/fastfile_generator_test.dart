import 'dart:io';

import 'package:easy_setup/src/fastlane/fastfile_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fastfile_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('FastfileGenerator', () {
    test('creates Fastfile referencing ENV variables', () {
      FastfileGenerator.generate(tempDir.path, {'dev': 'com.app.dev', 'prod': 'com.app'});

      final file = File(p.join(tempDir.path, 'Fastfile'));
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('default_platform(:ios)'));
      expect(content, contains('ENV["API_KEY_ID"]'));
      expect(content, contains('ENV["API_KEY_ISSUER_ID"]'));
      expect(content, contains('AuthKey.p8'));
      expect(content, contains('lane :sync_certs'));
      expect(content, contains('lane :refresh_profiles'));
      expect(content, contains('lane :beta'));
      expect(content, contains('upload_to_testflight'));
    });

    test('defaults to prod flavor when available', () {
      FastfileGenerator.generate(tempDir.path, {'dev': 'com.app.dev', 'prod': 'com.app'});

      final content = File(p.join(tempDir.path, 'Fastfile'))
          .readAsStringSync();
      expect(content, contains('options[:flavor] || "prod"'));
    });

    test('defaults to first flavor when prod is not available', () {
      FastfileGenerator.generate(tempDir.path, {'staging': 'com.app.staging', 'dev': 'com.app.dev'});

      final content = File(p.join(tempDir.path, 'Fastfile'))
          .readAsStringSync();
      expect(content, contains('options[:flavor] || "staging"'));
    });

    test('overwrites existing file with correct content', () {
      FastfileGenerator.generate(tempDir.path, {'prod': 'com.app'});
      final file = File(p.join(tempDir.path, 'Fastfile'));
      final afterFirst = file.readAsStringSync();

      file.writeAsStringSync('CUSTOM');

      FastfileGenerator.generate(tempDir.path, {'prod': 'com.app'});
      expect(file.readAsStringSync(), afterFirst);
    });

    test('beta lane includes increment_build_number_in_pubspec', () {
      FastfileGenerator.generate(tempDir.path, {'prod': 'com.app'});

      final content = File(p.join(tempDir.path, 'Fastfile'))
          .readAsStringSync();
      expect(content, contains('def increment_build_number_in_pubspec'));
      expect(content, contains('increment_build_number_in_pubspec'));
      // Verify it's called before flutter build
      final incrementIndex = content.indexOf('    increment_build_number_in_pubspec');
      final buildIndex = content.indexOf('flutter build ipa');
      expect(incrementIndex, lessThan(buildIndex));
    });

    test('generates per-flavor build configuration signing settings', () {
      FastfileGenerator.generate(tempDir.path, {
        'dev': 'com.app.dev',
        'prod': 'com.app',
      });

      final content = File(p.join(tempDir.path, 'Fastfile'))
          .readAsStringSync();

      // Debug-{flavor} configurations
      expect(content, contains('build_configurations: "Debug-dev"'));
      expect(content, contains('build_configurations: "Debug-prod"'));
      // Release-{flavor} configurations
      expect(content, contains('build_configurations: "Release-dev"'));
      expect(content, contains('build_configurations: "Release-prod"'));
      // Profile-{flavor} configurations
      expect(content, contains('build_configurations: "Profile-dev"'));
      expect(content, contains('build_configurations: "Profile-prod"'));

      // Bundle IDs are used directly (not Ruby variables)
      expect(content, contains('bundle_identifier: "com.app.dev"'));
      expect(content, contains('bundle_identifier: "com.app"'));

      // Profile name mappings
      expect(content, contains('profile_name: "match Development com.app.dev"'));
      expect(content, contains('profile_name: "match AppStore com.app"'));

      // Release/Profile use Apple Distribution identity
      expect(content, contains('code_sign_identity: "Apple Distribution"'));
    });

    test('does not create file in dry-run mode', () {
      FastfileGenerator.generate(tempDir.path, {'prod': 'com.app'}, dryRun: true);

      expect(
        File(p.join(tempDir.path, 'Fastfile')).existsSync(),
        isFalse,
      );
    });
  });
}
