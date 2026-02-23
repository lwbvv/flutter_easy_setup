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

    test('parses optional fields when present', () {
      final config = FlavorConfig.fromYaml({
        'bundle_id': 'com.example.app.dev',
        'name': 'MyApp Dev',
        'version_code': 42,
        'version_name': '1.0.0-dev',
        'signing': {
          'keystore': 'keys/dev.keystore',
          'alias': 'dev-key',
        },
        'firebase': {
          'android': 'config/dev/google-services.json',
          'ios': 'config/dev/GoogleService-Info.plist',
        },
        'ios': {
          'team_id': 'ABCDEF1234',
          'provisioning_profile': 'Dev Profile',
          'code_sign_identity': 'Apple Development',
          'entitlements': 'ios/Runner/Dev.entitlements',
          'app_icon': 'AppIcon-Dev',
        },
      });
      expect(config.versionCode, 42);
      expect(config.versionName, '1.0.0-dev');
      expect(config.signing, isNotNull);
      expect(config.signing!.keystore, 'keys/dev.keystore');
      expect(config.signing!.alias, 'dev-key');
      expect(config.firebase, isNotNull);
      expect(config.firebase!.android, 'config/dev/google-services.json');
      expect(config.firebase!.ios, 'config/dev/GoogleService-Info.plist');
      expect(config.ios, isNotNull);
      expect(config.ios!.teamId, 'ABCDEF1234');
      expect(config.ios!.provisioningProfile, 'Dev Profile');
      expect(config.ios!.codeSignIdentity, 'Apple Development');
      expect(config.ios!.entitlements, 'ios/Runner/Dev.entitlements');
      expect(config.ios!.appIcon, 'AppIcon-Dev');
    });

    test('optional fields are null when not provided', () {
      final config = FlavorConfig.fromYaml({
        'bundle_id': 'com.example.app',
        'name': 'MyApp',
      });
      expect(config.versionCode, isNull);
      expect(config.versionName, isNull);
      expect(config.signing, isNull);
      expect(config.firebase, isNull);
      expect(config.ios, isNull);
    });
  });

  group('SigningConfig.fromYaml', () {
    test('parses valid map', () {
      final config = SigningConfig.fromYaml({
        'keystore': 'keys/release.keystore',
        'alias': 'release-key',
      });
      expect(config.keystore, 'keys/release.keystore');
      expect(config.alias, 'release-key');
    });

    test('throws when keystore is missing', () {
      expect(
        () => SigningConfig.fromYaml({'alias': 'key'}),
        throwsA(isA<TypeError>()),
      );
    });

    test('throws when alias is missing', () {
      expect(
        () => SigningConfig.fromYaml({'keystore': 'keys/k.keystore'}),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('FirebaseConfig.fromYaml', () {
    test('parses both android and ios paths', () {
      final config = FirebaseConfig.fromYaml({
        'android': 'config/dev/google-services.json',
        'ios': 'config/dev/GoogleService-Info.plist',
      });
      expect(config.android, 'config/dev/google-services.json');
      expect(config.ios, 'config/dev/GoogleService-Info.plist');
    });

    test('allows partial config (android only)', () {
      final config = FirebaseConfig.fromYaml({
        'android': 'config/dev/google-services.json',
      });
      expect(config.android, 'config/dev/google-services.json');
      expect(config.ios, isNull);
    });

    test('allows partial config (ios only)', () {
      final config = FirebaseConfig.fromYaml({
        'ios': 'config/dev/GoogleService-Info.plist',
      });
      expect(config.android, isNull);
      expect(config.ios, 'config/dev/GoogleService-Info.plist');
    });

    test('allows empty config', () {
      final config = FirebaseConfig.fromYaml({});
      expect(config.android, isNull);
      expect(config.ios, isNull);
    });
  });

  group('IosFlavorConfig.fromYaml', () {
    test('parses all fields', () {
      final config = IosFlavorConfig.fromYaml({
        'team_id': 'TEAM123',
        'provisioning_profile': 'My Profile',
        'code_sign_identity': 'Apple Distribution',
        'entitlements': 'Runner/Prod.entitlements',
        'app_icon': 'AppIcon-Prod',
      });
      expect(config.teamId, 'TEAM123');
      expect(config.provisioningProfile, 'My Profile');
      expect(config.codeSignIdentity, 'Apple Distribution');
      expect(config.entitlements, 'Runner/Prod.entitlements');
      expect(config.appIcon, 'AppIcon-Prod');
    });

    test('all fields are optional', () {
      final config = IosFlavorConfig.fromYaml({});
      expect(config.teamId, isNull);
      expect(config.provisioningProfile, isNull);
      expect(config.codeSignIdentity, isNull);
      expect(config.entitlements, isNull);
      expect(config.appIcon, isNull);
    });

    test('parses partial fields', () {
      final config = IosFlavorConfig.fromYaml({
        'team_id': 'TEAM123',
        'app_icon': 'AppIcon-Dev',
      });
      expect(config.teamId, 'TEAM123');
      expect(config.appIcon, 'AppIcon-Dev');
      expect(config.codeSignIdentity, isNull);
      expect(config.provisioningProfile, isNull);
      expect(config.entitlements, isNull);
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
easy_setup:
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

    test('throws SetupException when easy_setup key is missing', () {
      final yamlFile = File('${tempDir.path}/easy_setup.yaml');
      yamlFile.writeAsStringSync('something_else: true\n');

      expect(
        () => EasySetupConfig.fromFile(yamlFile.path),
        throwsA(
          isA<SetupException>().having(
            (e) => e.message,
            'message',
            contains('Missing "easy_setup" key'),
          ),
        ),
      );
    });

    test('throws SetupException when flavors key is missing', () {
      final yamlFile = File('${tempDir.path}/easy_setup.yaml');
      yamlFile.writeAsStringSync('easy_setup:\n  something_else: true\n');

      expect(
        () => EasySetupConfig.fromFile(yamlFile.path),
        throwsA(isA<SetupException>()),
      );
    });

    test('parses multiple flavors', () {
      final yamlFile = File('${tempDir.path}/easy_setup.yaml');
      yamlFile.writeAsStringSync('''
easy_setup:
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

    test('parses YAML with all optional fields', () {
      final yamlFile = File('${tempDir.path}/easy_setup.yaml');
      yamlFile.writeAsStringSync('''
easy_setup:
  flavors:
    dev:
      bundle_id: com.example.app.dev
      name: MyApp Dev
      version_code: 1
      version_name: "1.0.0-dev"
      signing:
        keystore: keys/dev.keystore
        alias: dev-key
      firebase:
        android: config/dev/google-services.json
        ios: config/dev/GoogleService-Info.plist
      ios:
        team_id: "ABCDEF1234"
        app_icon: AppIcon-Dev
''');

      final config = EasySetupConfig.fromFile(yamlFile.path);
      final dev = config.flavors['dev']!;
      expect(dev.versionCode, 1);
      expect(dev.versionName, '1.0.0-dev');
      expect(dev.signing!.keystore, 'keys/dev.keystore');
      expect(dev.firebase!.android, 'config/dev/google-services.json');
      expect(dev.ios!.teamId, 'ABCDEF1234');
      expect(dev.ios!.appIcon, 'AppIcon-Dev');
    });
  });
}
