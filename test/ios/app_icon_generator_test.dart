import 'dart:convert';
import 'dart:io';

import 'package:easy_setup/easy_setup.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String projectRoot;
  late String assetCatalogDir;
  late String sourceIconPath;

  /// Creates a 1024x1024 PNG image for testing.
  void createSourceIcon(String path, {int width = 1024, int height = 1024}) {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(255, 0, 0));
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(img.encodePng(image));
  }

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('app_icon_test_');
    projectRoot = tempDir.path;
    assetCatalogDir =
        p.join(projectRoot, 'ios', 'Runner', 'Assets.xcassets');
    sourceIconPath = p.join(projectRoot, 'assets', 'icons', 'icon.png');
    createSourceIcon(sourceIconPath);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('AppIconGenerator', () {
    test('generates 15 PNG files and Contents.json', () {
      AppIconGenerator.generate(
        projectRoot,
        assetCatalogDir,
        'dev',
        'assets/icons/icon.png',
      );

      final outputDir =
          p.join(assetCatalogDir, 'AppIcon-dev.appiconset');
      expect(Directory(outputDir).existsSync(), isTrue);

      // 15 unique filename PNGs
      final expectedFiles = [
        'Icon-App-20x20@1x.png',
        'Icon-App-20x20@2x.png',
        'Icon-App-20x20@3x.png',
        'Icon-App-29x29@1x.png',
        'Icon-App-29x29@2x.png',
        'Icon-App-29x29@3x.png',
        'Icon-App-40x40@1x.png',
        'Icon-App-40x40@2x.png',
        'Icon-App-40x40@3x.png',
        'Icon-App-60x60@2x.png',
        'Icon-App-60x60@3x.png',
        'Icon-App-76x76@1x.png',
        'Icon-App-76x76@2x.png',
        'Icon-App-83.5x83.5@2x.png',
        'Icon-App-1024x1024@1x.png',
      ];

      for (final filename in expectedFiles) {
        expect(
          File(p.join(outputDir, filename)).existsSync(),
          isTrue,
          reason: '$filename should exist',
        );
      }

      expect(
        File(p.join(outputDir, 'Contents.json')).existsSync(),
        isTrue,
      );
    });

    test('generated PNGs have correct pixel sizes', () {
      AppIconGenerator.generate(
        projectRoot,
        assetCatalogDir,
        'dev',
        'assets/icons/icon.png',
      );

      final outputDir =
          p.join(assetCatalogDir, 'AppIcon-dev.appiconset');

      final expectedSizes = {
        'Icon-App-20x20@1x.png': 20,
        'Icon-App-20x20@2x.png': 40,
        'Icon-App-20x20@3x.png': 60,
        'Icon-App-29x29@1x.png': 29,
        'Icon-App-29x29@2x.png': 58,
        'Icon-App-29x29@3x.png': 87,
        'Icon-App-40x40@1x.png': 40,
        'Icon-App-40x40@2x.png': 80,
        'Icon-App-40x40@3x.png': 120,
        'Icon-App-60x60@2x.png': 120,
        'Icon-App-60x60@3x.png': 180,
        'Icon-App-76x76@1x.png': 76,
        'Icon-App-76x76@2x.png': 152,
        'Icon-App-83.5x83.5@2x.png': 167,
        'Icon-App-1024x1024@1x.png': 1024,
      };

      for (final entry in expectedSizes.entries) {
        final file = File(p.join(outputDir, entry.key));
        final decoded = img.decodePng(file.readAsBytesSync())!;
        expect(decoded.width, entry.value,
            reason: '${entry.key} width should be ${entry.value}');
        expect(decoded.height, entry.value,
            reason: '${entry.key} height should be ${entry.value}');
      }
    });

    test('Contents.json has 18 entries', () {
      AppIconGenerator.generate(
        projectRoot,
        assetCatalogDir,
        'dev',
        'assets/icons/icon.png',
      );

      final outputDir =
          p.join(assetCatalogDir, 'AppIcon-dev.appiconset');
      final contentsFile = File(p.join(outputDir, 'Contents.json'));
      final contents =
          jsonDecode(contentsFile.readAsStringSync()) as Map<String, dynamic>;

      final images = contents['images'] as List;
      expect(images.length, 18);

      // Verify each entry has required fields
      for (final image in images) {
        final map = image as Map<String, dynamic>;
        expect(map.containsKey('size'), isTrue);
        expect(map.containsKey('idiom'), isTrue);
        expect(map.containsKey('filename'), isTrue);
        expect(map.containsKey('scale'), isTrue);
      }

      // Verify info block
      final info = contents['info'] as Map<String, dynamic>;
      expect(info['version'], 1);
      expect(info['author'], 'easy_setup');
    });

    test('throws SetupException for non-1024x1024 source', () {
      final smallIconPath =
          p.join(projectRoot, 'assets', 'icons', 'small.png');
      createSourceIcon(smallIconPath, width: 512, height: 512);

      expect(
        () => AppIconGenerator.generate(
          projectRoot,
          assetCatalogDir,
          'dev',
          'assets/icons/small.png',
        ),
        throwsA(
          isA<SetupException>().having(
            (e) => e.message,
            'message',
            contains('1024x1024'),
          ),
        ),
      );
    });

    test('throws SetupException when source file not found', () {
      expect(
        () => AppIconGenerator.generate(
          projectRoot,
          assetCatalogDir,
          'dev',
          'assets/icons/nonexistent.png',
        ),
        throwsA(
          isA<SetupException>().having(
            (e) => e.message,
            'message',
            contains('not found'),
          ),
        ),
      );
    });

    test('does not create files in dry-run mode', () {
      AppIconGenerator.generate(
        projectRoot,
        assetCatalogDir,
        'dev',
        'assets/icons/icon.png',
        dryRun: true,
      );

      final outputDir =
          p.join(assetCatalogDir, 'AppIcon-dev.appiconset');
      expect(Directory(outputDir).existsSync(), isFalse);
    });

    test('overwrites existing files on re-run (idempotent)', () {
      AppIconGenerator.generate(
        projectRoot,
        assetCatalogDir,
        'dev',
        'assets/icons/icon.png',
      );

      final outputDir =
          p.join(assetCatalogDir, 'AppIcon-dev.appiconset');
      final firstRunContents =
          File(p.join(outputDir, 'Contents.json')).readAsStringSync();

      // Re-run
      AppIconGenerator.generate(
        projectRoot,
        assetCatalogDir,
        'dev',
        'assets/icons/icon.png',
      );

      final secondRunContents =
          File(p.join(outputDir, 'Contents.json')).readAsStringSync();
      expect(secondRunContents, firstRunContents);
    });

  });
}
