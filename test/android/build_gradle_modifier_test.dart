import 'dart:io';

import 'package:easy_setup/src/android/build_gradle_modifier.dart';
import 'package:easy_setup/easy_setup.dart';
import 'package:test/test.dart';

const _groovyGradle = '''
android {
    compileSdkVersion 33

    defaultConfig {
        applicationId "com.example.app"
        minSdkVersion 21
        targetSdkVersion 33
    }

    buildTypes {
        release {
            signingConfig signingConfigs.debug
        }
    }
}
''';

const _kotlinGradle = '''
android {
    compileSdk = 33

    defaultConfig {
        applicationId = "com.example.app"
        minSdk = 21
        targetSdk = 33
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}
''';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('gradle_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  final flavors = {
    'dev': const FlavorConfig(bundleId: 'com.example.app.dev', name: 'MyApp Dev'),
    'prod': const FlavorConfig(bundleId: 'com.example.app', name: 'MyApp'),
  };

  group('BuildGradleModifier', () {
    test('inserts flavorDimensions and productFlavors for Groovy DSL', () {
      final file = File('${tempDir.path}/build.gradle');
      file.writeAsStringSync(_groovyGradle);

      BuildGradleModifier.modify(file.path, flavors);

      final result = file.readAsStringSync();
      expect(result, contains('flavorDimensions "env"'));
      expect(result, contains('productFlavors {'));
      expect(result, contains('dev {'));
      expect(result, contains('prod {'));
      expect(result, contains('applicationId "com.example.app.dev"'));
      expect(result, contains('applicationId "com.example.app"'));
      expect(result, contains('resValue "string", "app_name", "MyApp Dev"'));
      expect(result, contains('resValue "string", "app_name", "MyApp"'));
      expect(result, contains('dimension "env"'));
    });

    test('uses Kotlin DSL syntax for .kts files', () {
      final file = File('${tempDir.path}/build.gradle.kts');
      file.writeAsStringSync(_kotlinGradle);

      BuildGradleModifier.modify(file.path, flavors);

      final result = file.readAsStringSync();
      expect(result, contains('flavorDimensions += listOf("env")'));
      expect(result, contains('create("dev")'));
      expect(result, contains('create("prod")'));
      expect(result, contains('applicationId = "com.example.app.dev"'));
      expect(result, contains('applicationId = "com.example.app"'));
      expect(result, contains('dimension = "env"'));
      expect(result, contains('resValue("string", "app_name", "MyApp Dev")'));
    });

    test('is idempotent — skips when flavorDimensions already present', () {
      final file = File('${tempDir.path}/build.gradle');
      file.writeAsStringSync(_groovyGradle);

      BuildGradleModifier.modify(file.path, flavors);
      final afterFirst = file.readAsStringSync();

      BuildGradleModifier.modify(file.path, flavors);
      final afterSecond = file.readAsStringSync();

      expect(afterSecond, afterFirst);
    });

    test('skips when file does not exist', () {
      // Should not throw
      BuildGradleModifier.modify('${tempDir.path}/nonexistent.gradle', flavors);
    });

    test('skips when buildTypes block is missing', () {
      final file = File('${tempDir.path}/build.gradle');
      file.writeAsStringSync('android {\n    compileSdkVersion 33\n}\n');

      BuildGradleModifier.modify(file.path, flavors);

      final result = file.readAsStringSync();
      expect(result, isNot(contains('flavorDimensions')));
    });

    test('does not modify file in dry-run mode', () {
      final file = File('${tempDir.path}/build.gradle');
      file.writeAsStringSync(_groovyGradle);

      BuildGradleModifier.modify(file.path, flavors, dryRun: true);

      final result = file.readAsStringSync();
      expect(result, _groovyGradle);
    });

    test('generates all flavors correctly', () {
      final threeFlavors = {
        'dev': const FlavorConfig(bundleId: 'com.example.dev', name: 'Dev'),
        'staging': const FlavorConfig(bundleId: 'com.example.staging', name: 'Staging'),
        'prod': const FlavorConfig(bundleId: 'com.example.prod', name: 'Prod'),
      };
      final file = File('${tempDir.path}/build.gradle');
      file.writeAsStringSync(_groovyGradle);

      BuildGradleModifier.modify(file.path, threeFlavors);

      final result = file.readAsStringSync();
      expect(result, contains('dev {'));
      expect(result, contains('staging {'));
      expect(result, contains('prod {'));
      expect(result, contains('applicationId "com.example.dev"'));
      expect(result, contains('applicationId "com.example.staging"'));
      expect(result, contains('applicationId "com.example.prod"'));
    });

    test('generates manifestPlaceholders for Groovy DSL', () {
      final file = File('${tempDir.path}/build.gradle');
      file.writeAsStringSync(_groovyGradle);

      BuildGradleModifier.modify(file.path, flavors);

      final result = file.readAsStringSync();
      expect(result, contains('manifestPlaceholders = [appName: "MyApp Dev"]'));
      expect(result, contains('manifestPlaceholders = [appName: "MyApp"]'));
    });

    test('generates manifestPlaceholders for Kotlin DSL', () {
      final file = File('${tempDir.path}/build.gradle.kts');
      file.writeAsStringSync(_kotlinGradle);

      BuildGradleModifier.modify(file.path, flavors);

      final result = file.readAsStringSync();
      expect(result, contains('manifestPlaceholders += mapOf("appName" to "MyApp Dev")'));
      expect(result, contains('manifestPlaceholders += mapOf("appName" to "MyApp")'));
    });

    test('generates versionCode and versionName when provided (Groovy)', () {
      final flavorsWithVersion = {
        'dev': const FlavorConfig(
          bundleId: 'com.example.dev',
          name: 'Dev',
          versionCode: 10,
          versionName: '1.0.0-dev',
        ),
      };
      final file = File('${tempDir.path}/build.gradle');
      file.writeAsStringSync(_groovyGradle);

      BuildGradleModifier.modify(file.path, flavorsWithVersion);

      final result = file.readAsStringSync();
      expect(result, contains('versionCode 10'));
      expect(result, contains('versionName "1.0.0-dev"'));
    });

    test('generates versionCode and versionName when provided (Kotlin)', () {
      final flavorsWithVersion = {
        'dev': const FlavorConfig(
          bundleId: 'com.example.dev',
          name: 'Dev',
          versionCode: 10,
          versionName: '1.0.0-dev',
        ),
      };
      final file = File('${tempDir.path}/build.gradle.kts');
      file.writeAsStringSync(_kotlinGradle);

      BuildGradleModifier.modify(file.path, flavorsWithVersion);

      final result = file.readAsStringSync();
      expect(result, contains('versionCode = 10'));
      expect(result, contains('versionName = "1.0.0-dev"'));
    });

    test('does not generate versionCode/versionName when not provided', () {
      final file = File('${tempDir.path}/build.gradle');
      file.writeAsStringSync(_groovyGradle);

      BuildGradleModifier.modify(file.path, flavors);

      final result = file.readAsStringSync();
      // versionCode and versionName should NOT appear as standalone lines
      // (they exist in the original defaultConfig but not in productFlavors)
      expect(result, isNot(contains(RegExp(r'productFlavors[\s\S]*versionCode \d'))));
    });

    test('generates signingConfigs block when signing is provided (Groovy)', () {
      final flavorsWithSigning = {
        'dev': const FlavorConfig(
          bundleId: 'com.example.dev',
          name: 'Dev',
          signing: SigningConfig(keystore: 'keys/dev.keystore', alias: 'dev-key'),
        ),
        'prod': const FlavorConfig(
          bundleId: 'com.example.prod',
          name: 'Prod',
        ),
      };
      final file = File('${tempDir.path}/build.gradle');
      file.writeAsStringSync(_groovyGradle);

      BuildGradleModifier.modify(file.path, flavorsWithSigning);

      final result = file.readAsStringSync();
      // signingConfigs block should be inserted
      expect(result, contains('signingConfigs {'));
      expect(result, contains('storeFile file("keys/dev.keystore")'));
      expect(result, contains('keyAlias "dev-key"'));
      // dev flavor should reference its signingConfig
      expect(result, contains('signingConfig signingConfigs.dev'));
      // prod flavor should NOT have signingConfig reference in productFlavors
      // (it has no signing config)
    });

    test('generates signingConfigs block when signing is provided (Kotlin)', () {
      final flavorsWithSigning = {
        'dev': const FlavorConfig(
          bundleId: 'com.example.dev',
          name: 'Dev',
          signing: SigningConfig(keystore: 'keys/dev.keystore', alias: 'dev-key'),
        ),
      };
      final file = File('${tempDir.path}/build.gradle.kts');
      file.writeAsStringSync(_kotlinGradle);

      BuildGradleModifier.modify(file.path, flavorsWithSigning);

      final result = file.readAsStringSync();
      expect(result, contains('signingConfigs {'));
      expect(result, contains('create("dev")'));
      expect(result, contains('storeFile = file("keys/dev.keystore")'));
      expect(result, contains('keyAlias = "dev-key"'));
      expect(result, contains('signingConfig = signingConfigs.getByName("dev")'));
    });

    test('does not generate signingConfigs block when no signing provided', () {
      final file = File('${tempDir.path}/build.gradle');
      file.writeAsStringSync(_groovyGradle);

      BuildGradleModifier.modify(file.path, flavors);

      final result = file.readAsStringSync();
      // The original content has "signingConfigs.debug" inside buildTypes,
      // but there should be no standalone "signingConfigs {" block
      expect(result, isNot(contains(RegExp(r'^\s+signingConfigs \{', multiLine: true))));
    });
  });
}
