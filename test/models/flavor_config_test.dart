import 'dart:io';

import 'package:easy_setup/easy_setup.dart';
import 'package:test/test.dart';

void main() {
  group('FlavorConfig.fromYaml', () {
    test('parses valid map correctly', () {
      final config = FlavorConfig.fromYaml({
        'bundle_id': 'com.example.app.dev',
        'name': 'MyApp Dev',
      });
      expect(config.bundleId, 'com.example.app.dev');
      expect(config.name, 'MyApp Dev');
    });

    test('throws when bundle_id is missing', () {
      expect(
        () => FlavorConfig.fromYaml({'name': 'MyApp'}),
        throwsA(isA<TypeError>()),
      );
    });

    test('throws when name is missing', () {
      expect(
        () => FlavorConfig.fromYaml({'bundle_id': 'com.example.app'}),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('EasySetupConfig.fromFile', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('flavor_config_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('parses valid YAML file', () {
      final yamlFile = File('${tempDir.path}/easy_setup.yaml');
      yamlFile.writeAsStringSync('''
flavors:
  dev:
    bundle_id: com.example.app.dev
    name: MyApp Dev
  prod:
    bundle_id: com.example.app
    name: MyApp
''');

      final config = EasySetupConfig.fromFile(yamlFile.path);
      expect(config.flavors.length, 2);
      expect(config.flavors['dev']!.bundleId, 'com.example.app.dev');
      expect(config.flavors['dev']!.name, 'MyApp Dev');
      expect(config.flavors['prod']!.bundleId, 'com.example.app');
      expect(config.flavors['prod']!.name, 'MyApp');
    });

    test('throws SetupException when file does not exist', () {
      expect(
        () => EasySetupConfig.fromFile('${tempDir.path}/nonexistent.yaml'),
        throwsA(
          isA<SetupException>().having(
            (e) => e.message,
            'message',
            contains('easy_setup.yaml not found'),
          ),
        ),
      );
    });

    test('throws SetupException for invalid YAML', () {
      final yamlFile = File('${tempDir.path}/easy_setup.yaml');
      yamlFile.writeAsStringSync('not: valid: yaml: [[[');

      expect(
        () => EasySetupConfig.fromFile(yamlFile.path),
        throwsA(isA<SetupException>()),
      );
    });

    test('throws SetupException when flavors key is missing', () {
      final yamlFile = File('${tempDir.path}/easy_setup.yaml');
      yamlFile.writeAsStringSync('something_else: true\n');

      expect(
        () => EasySetupConfig.fromFile(yamlFile.path),
        throwsA(isA<SetupException>()),
      );
    });

    test('parses multiple flavors', () {
      final yamlFile = File('${tempDir.path}/easy_setup.yaml');
      yamlFile.writeAsStringSync('''
flavors:
  dev:
    bundle_id: com.example.dev
    name: Dev
  staging:
    bundle_id: com.example.staging
    name: Staging
  prod:
    bundle_id: com.example.prod
    name: Prod
''');

      final config = EasySetupConfig.fromFile(yamlFile.path);
      expect(config.flavors.length, 3);
      expect(config.flavors.keys, containsAll(['dev', 'staging', 'prod']));
    });
  });
}
