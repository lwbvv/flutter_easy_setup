import 'package:easy_setup/src/exceptions.dart';
import 'package:easy_setup/src/models/ci_cd_config.dart';
import 'package:test/test.dart';

void main() {
  group('ApiKeyConfig.fromYaml', () {
    test('parses all fields', () {
      final config = ApiKeyConfig.fromYaml({
        'id': 'KEY_123',
        'issuer_id': 'ISSUER_456',
        'key_path': 'fastlane/AuthKey.p8',
        'duration': 900,
        'in_house': true,
      });
      expect(config.id, 'KEY_123');
      expect(config.issuerId, 'ISSUER_456');
      expect(config.keyPath, 'fastlane/AuthKey.p8');
      expect(config.duration, 900);
      expect(config.inHouse, isTrue);
    });

    test('uses defaults for optional fields', () {
      final config = ApiKeyConfig.fromYaml({
        'id': 'KEY_123',
        'issuer_id': 'ISSUER_456',
        'key_path': 'fastlane/AuthKey.p8',
      });
      expect(config.duration, 1200);
      expect(config.inHouse, isFalse);
    });

    test('throws SetupException when id is missing', () {
      expect(
        () => ApiKeyConfig.fromYaml({
          'issuer_id': 'ISSUER',
          'key_path': 'key.p8',
        }),
        throwsA(isA<SetupException>()),
      );
    });

    test('throws SetupException when issuer_id is missing', () {
      expect(
        () => ApiKeyConfig.fromYaml({
          'id': 'KEY',
          'key_path': 'key.p8',
        }),
        throwsA(isA<SetupException>()),
      );
    });

    test('throws SetupException when key_path is missing', () {
      expect(
        () => ApiKeyConfig.fromYaml({
          'id': 'KEY',
          'issuer_id': 'ISSUER',
        }),
        throwsA(isA<SetupException>()),
      );
    });
  });

  group('ProfileTypeConfig.fromYaml', () {
    test('parses name', () {
      final config = ProfileTypeConfig.fromYaml({'name': 'match Dev com.app'});
      expect(config.name, 'match Dev com.app');
    });

    test('name is null when not provided', () {
      final config = ProfileTypeConfig.fromYaml({});
      expect(config.name, isNull);
    });
  });

  group('ProvisioningProfileConfig.fromYaml', () {
    test('parses all types', () {
      final config = ProvisioningProfileConfig.fromYaml({
        'debug': {'name': 'match Development com.app'},
        'profile': {'name': 'match AdHoc com.app'},
        'release': {'name': 'match AppStore com.app'},
      });
      expect(config.debug!.name, 'match Development com.app');
      expect(config.profile!.name, 'match AdHoc com.app');
      expect(config.release!.name, 'match AppStore com.app');
    });

    test('all types are optional', () {
      final config = ProvisioningProfileConfig.fromYaml({});
      expect(config.debug, isNull);
      expect(config.profile, isNull);
      expect(config.release, isNull);
    });
  });

  group('CiCdIosConfig.fromYaml', () {
    test('parses valid config', () {
      final config = CiCdIosConfig.fromYaml({
        'storage': 'https://github.com/user/certs.git',
        'team_id': 'TEAM123',
        'itc_team_id': 'ITC456',
        'api_key': {
          'id': 'KEY',
          'issuer_id': 'ISSUER',
          'key_path': 'key.p8',
        },
      });
      expect(config.storage, 'https://github.com/user/certs.git');
      expect(config.teamId, 'TEAM123');
      expect(config.itcTeamId, 'ITC456');
      expect(config.apiKey.id, 'KEY');
    });

    test('throws SetupException when storage is missing', () {
      expect(
        () => CiCdIosConfig.fromYaml({
          'team_id': 'T',
          'itc_team_id': 'I',
          'api_key': {'id': 'K', 'issuer_id': 'I', 'key_path': 'p'},
        }),
        throwsA(isA<SetupException>()),
      );
    });

    test('throws SetupException when team_id is missing', () {
      expect(
        () => CiCdIosConfig.fromYaml({
          'storage': 'url',
          'itc_team_id': 'I',
          'api_key': {'id': 'K', 'issuer_id': 'I', 'key_path': 'p'},
        }),
        throwsA(isA<SetupException>()),
      );
    });

    test('throws SetupException when api_key is missing', () {
      expect(
        () => CiCdIosConfig.fromYaml({
          'storage': 'url',
          'team_id': 'T',
          'itc_team_id': 'I',
        }),
        throwsA(isA<SetupException>()),
      );
    });
  });

  group('CiCdFlavorConfig.fromYaml', () {
    test('parses bundle_id', () {
      final config = CiCdFlavorConfig.fromYaml({
        'bundle_id': 'com.example.app',
      });
      expect(config.bundleId, 'com.example.app');
    });

    test('bundle_id is null when not provided', () {
      final config = CiCdFlavorConfig.fromYaml({});
      expect(config.bundleId, isNull);
    });
  });

  group('CiCdConfig.fromYaml', () {
    final validIos = {
      'storage': 'https://github.com/user/certs.git',
      'team_id': 'TEAM123',
      'itc_team_id': 'ITC456',
      'api_key': {
        'id': 'KEY',
        'issuer_id': 'ISSUER',
        'key_path': 'fastlane/AuthKey.p8',
      },
    };

    test('parses full config', () {
      final config = CiCdConfig.fromYaml({
        'flavors': {
          'staging': {'bundle_id': 'com.app.staging'},
          'prod': {'bundle_id': 'com.app'},
        },
        'ios': validIos,
        'provisioning_profile': {
          'debug': {'name': 'match Development com.app'},
        },
      });
      expect(config.flavors, isNotNull);
      expect(config.flavors!.length, 2);
      expect(config.flavors!['staging']!.bundleId, 'com.app.staging');
      expect(config.ios.storage, 'https://github.com/user/certs.git');
      expect(config.provisioningProfile, isNotNull);
      expect(config.provisioningProfile!.debug!.name,
          'match Development com.app');
    });

    test('flavors and provisioning_profile are optional', () {
      final config = CiCdConfig.fromYaml({'ios': validIos});
      expect(config.flavors, isNull);
      expect(config.provisioningProfile, isNull);
    });

    test('throws SetupException when ios is missing', () {
      expect(
        () => CiCdConfig.fromYaml({}),
        throwsA(isA<SetupException>()),
      );
    });
  });
}
