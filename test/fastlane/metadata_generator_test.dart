import 'dart:io';

import 'package:easy_setup/src/fastlane/metadata_generator.dart';
import 'package:easy_setup/src/models/ci_cd_config.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('metadata_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('MetadataGenerator', () {
    test('generates metadata files for single locale', () {
      final metadata = {
        'ko': LocaleMetadataConfig(
          promotionalText: '프로모션 텍스트입니다',
          description: '앱 설명입니다',
          name: '마이앱',
        ),
      };

      MetadataGenerator.generate(tempDir.path, metadata);

      final promoFile =
          File(p.join(tempDir.path, 'metadata', 'ko', 'promotional_text.txt'));
      expect(promoFile.existsSync(), isTrue);
      expect(promoFile.readAsStringSync(), '프로모션 텍스트입니다\n');

      final descFile =
          File(p.join(tempDir.path, 'metadata', 'ko', 'description.txt'));
      expect(descFile.existsSync(), isTrue);
      expect(descFile.readAsStringSync(), '앱 설명입니다\n');

      final nameFile =
          File(p.join(tempDir.path, 'metadata', 'ko', 'name.txt'));
      expect(nameFile.existsSync(), isTrue);
      expect(nameFile.readAsStringSync(), '마이앱\n');
    });

    test('generates metadata files for multiple locales', () {
      final metadata = {
        'ko': LocaleMetadataConfig(
          promotionalText: '한국어 프로모션',
        ),
        'en-US': LocaleMetadataConfig(
          promotionalText: 'English promo',
        ),
      };

      MetadataGenerator.generate(tempDir.path, metadata);

      expect(
        File(p.join(tempDir.path, 'metadata', 'ko', 'promotional_text.txt'))
            .readAsStringSync(),
        '한국어 프로모션\n',
      );
      expect(
        File(p.join(tempDir.path, 'metadata', 'en-US', 'promotional_text.txt'))
            .readAsStringSync(),
        'English promo\n',
      );
    });

    test('generates all supported file types', () {
      final metadata = {
        'ko': LocaleMetadataConfig(
          promotionalText: 'promo',
          description: 'desc',
          releaseNotes: 'notes',
          keywords: 'key1, key2',
          name: 'name',
          subtitle: 'sub',
          privacyUrl: 'https://privacy.url',
          supportUrl: 'https://support.url',
          marketingUrl: 'https://marketing.url',
        ),
      };

      MetadataGenerator.generate(tempDir.path, metadata);

      final localeDir = p.join(tempDir.path, 'metadata', 'ko');
      expect(File(p.join(localeDir, 'promotional_text.txt')).existsSync(),
          isTrue);
      expect(File(p.join(localeDir, 'description.txt')).existsSync(), isTrue);
      expect(
          File(p.join(localeDir, 'release_notes.txt')).existsSync(), isTrue);
      expect(File(p.join(localeDir, 'keywords.txt')).existsSync(), isTrue);
      expect(File(p.join(localeDir, 'name.txt')).existsSync(), isTrue);
      expect(File(p.join(localeDir, 'subtitle.txt')).existsSync(), isTrue);
      expect(File(p.join(localeDir, 'privacy_url.txt')).existsSync(), isTrue);
      expect(File(p.join(localeDir, 'support_url.txt')).existsSync(), isTrue);
      expect(
          File(p.join(localeDir, 'marketing_url.txt')).existsSync(), isTrue);
    });

    test('skips locale with no fields set', () {
      final metadata = {
        'ko': const LocaleMetadataConfig(),
      };

      MetadataGenerator.generate(tempDir.path, metadata);

      expect(
          Directory(p.join(tempDir.path, 'metadata', 'ko')).existsSync(),
          isFalse);
    });

    test('dry-run does not create files', () {
      final metadata = {
        'ko': LocaleMetadataConfig(promotionalText: 'test'),
      };

      MetadataGenerator.generate(tempDir.path, metadata, dryRun: true);

      expect(
          Directory(p.join(tempDir.path, 'metadata')).existsSync(), isFalse);
    });

    test('overwrites existing files', () {
      final metadata = {
        'ko': LocaleMetadataConfig(promotionalText: 'v1'),
      };

      MetadataGenerator.generate(tempDir.path, metadata);

      final updated = {
        'ko': LocaleMetadataConfig(promotionalText: 'v2'),
      };

      MetadataGenerator.generate(tempDir.path, updated);

      expect(
        File(p.join(tempDir.path, 'metadata', 'ko', 'promotional_text.txt'))
            .readAsStringSync(),
        'v2\n',
      );
    });
  });

  group('LocaleMetadataConfig.fromYaml', () {
    test('parses all fields', () {
      final config = LocaleMetadataConfig.fromYaml({
        'promotional_text': 'promo',
        'description': 'desc',
        'release_notes': 'notes',
        'keywords': 'key1, key2',
        'name': 'name',
        'subtitle': 'sub',
        'privacy_url': 'https://privacy',
        'support_url': 'https://support',
        'marketing_url': 'https://marketing',
      });
      expect(config.promotionalText, 'promo');
      expect(config.description, 'desc');
      expect(config.releaseNotes, 'notes');
      expect(config.keywords, 'key1, key2');
      expect(config.name, 'name');
      expect(config.subtitle, 'sub');
      expect(config.privacyUrl, 'https://privacy');
      expect(config.supportUrl, 'https://support');
      expect(config.marketingUrl, 'https://marketing');
    });

    test('all fields are optional', () {
      final config = LocaleMetadataConfig.fromYaml({});
      expect(config.promotionalText, isNull);
      expect(config.description, isNull);
    });
  });
}
