import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../exceptions.dart';

/// iOS 앱 아이콘을 1024x1024 소스 이미지로부터 자동 생성하는 클래스입니다.
///
/// 15개 고유 사이즈 PNG를 리사이즈하여 AppIcon-{flavor}.appiconset/ 에 저장하고,
/// Contents.json (19개 엔트리)을 생성합니다.
/// locale별 소스가 있으면 .lproj/ 서브디렉터리에 동일하게 생성합니다.
class AppIconGenerator {
  /// 앱 아이콘 사이즈 정의 (파일명, 픽셀 크기)
  static const List<_IconSize> _iconSizes = [
    _IconSize('Icon-App-20x20@1x.png', 20),
    _IconSize('Icon-App-20x20@2x.png', 40),
    _IconSize('Icon-App-20x20@3x.png', 60),
    _IconSize('Icon-App-29x29@1x.png', 29),
    _IconSize('Icon-App-29x29@2x.png', 58),
    _IconSize('Icon-App-29x29@3x.png', 87),
    _IconSize('Icon-App-40x40@1x.png', 40),
    _IconSize('Icon-App-40x40@2x.png', 80),
    _IconSize('Icon-App-40x40@3x.png', 120),
    _IconSize('Icon-App-60x60@2x.png', 120),
    _IconSize('Icon-App-60x60@3x.png', 180),
    _IconSize('Icon-App-76x76@1x.png', 76),
    _IconSize('Icon-App-76x76@2x.png', 152),
    _IconSize('Icon-App-83.5x83.5@2x.png', 167),
    _IconSize('Icon-App-1024x1024@1x.png', 1024),
  ];

  /// Contents.json 엔트리 정의 (19개)
  static const List<_ContentsEntry> _contentsEntries = [
    _ContentsEntry('Icon-App-20x20@2x.png', '20x20', '2x', 'iphone'),
    _ContentsEntry('Icon-App-20x20@3x.png', '20x20', '3x', 'iphone'),
    _ContentsEntry('Icon-App-29x29@2x.png', '29x29', '2x', 'iphone'),
    _ContentsEntry('Icon-App-29x29@3x.png', '29x29', '3x', 'iphone'),
    _ContentsEntry('Icon-App-40x40@2x.png', '40x40', '2x', 'iphone'),
    _ContentsEntry('Icon-App-40x40@3x.png', '40x40', '3x', 'iphone'),
    _ContentsEntry('Icon-App-60x60@2x.png', '60x60', '2x', 'iphone'),
    _ContentsEntry('Icon-App-60x60@3x.png', '60x60', '3x', 'iphone'),
    _ContentsEntry('Icon-App-20x20@1x.png', '20x20', '1x', 'ipad'),
    _ContentsEntry('Icon-App-20x20@2x.png', '20x20', '2x', 'ipad'),
    _ContentsEntry('Icon-App-29x29@1x.png', '29x29', '1x', 'ipad'),
    _ContentsEntry('Icon-App-29x29@2x.png', '29x29', '2x', 'ipad'),
    _ContentsEntry('Icon-App-40x40@1x.png', '40x40', '1x', 'ipad'),
    _ContentsEntry('Icon-App-40x40@2x.png', '40x40', '2x', 'ipad'),
    _ContentsEntry('Icon-App-76x76@1x.png', '76x76', '1x', 'ipad'),
    _ContentsEntry('Icon-App-76x76@2x.png', '76x76', '2x', 'ipad'),
    _ContentsEntry('Icon-App-83.5x83.5@2x.png', '83.5x83.5', '2x', 'ipad'),
    _ContentsEntry(
        'Icon-App-1024x1024@1x.png', '1024x1024', '1x', 'ios-marketing'),
  ];

  /// [assetCatalogDir]에 AppIcon-{flavor}.appiconset/을 생성합니다.
  ///
  /// [projectRoot]: Flutter 프로젝트 루트 (소스 이미지 경로 해석용)
  /// [assetCatalogDir]: ios/Runner/Assets.xcassets 경로
  /// [flavor]: flavor 이름
  /// [appIconPath]: 1024x1024 소스 이미지 경로 (프로젝트 루트 기준 상대경로)
  /// [appIconLocalized]: locale별 소스 이미지 경로 맵 (선택사항)
  static void generate(
    String projectRoot,
    String assetCatalogDir,
    String flavor,
    String appIconPath, {
    Map<String, String>? appIconLocalized,
    bool dryRun = false,
  }) {
    final appiconsetDir = p.join(assetCatalogDir, 'AppIcon-$flavor.appiconset');

    // 기본 아이콘 생성
    final sourcePath = p.join(projectRoot, appIconPath);
    _generateIconSet(sourcePath, appiconsetDir, dryRun: dryRun);

    // locale별 아이콘 생성
    if (appIconLocalized != null) {
      for (final entry in appIconLocalized.entries) {
        final locale = entry.key;
        final localePath = p.join(projectRoot, entry.value);
        final localeDir = p.join(appiconsetDir, '$locale.lproj');
        _generateIconSet(localePath, localeDir, dryRun: dryRun);
      }
    }
  }

  /// 소스 이미지를 로드하고 15개 사이즈 PNG + Contents.json을 생성합니다.
  static void _generateIconSet(
    String sourcePath,
    String outputDir, {
    required bool dryRun,
  }) {
    final sourceFile = File(sourcePath);
    if (!sourceFile.existsSync()) {
      throw SetupException('App icon source image not found: $sourcePath');
    }

    final sourceImage = img.decodePng(sourceFile.readAsBytesSync());
    if (sourceImage == null) {
      throw SetupException('Failed to decode PNG image: $sourcePath');
    }
    if (sourceImage.width != 1024 || sourceImage.height != 1024) {
      throw SetupException(
        'App icon source must be 1024x1024, '
        'got ${sourceImage.width}x${sourceImage.height}: $sourcePath',
      );
    }

    if (dryRun) {
      print('  [dry-run] Would generate app icons in: $outputDir');
      return;
    }

    Directory(outputDir).createSync(recursive: true);

    // 리사이즈된 아이콘 PNG 생성
    final generatedSizes = <int>{};
    for (final iconSize in _iconSizes) {
      final outputPath = p.join(outputDir, iconSize.filename);
      if (generatedSizes.contains(iconSize.pixels)) {
        // 동일 픽셀 사이즈는 이미 생성됨 — 복사
        final existingFile = _iconSizes
            .firstWhere((s) =>
                s.pixels == iconSize.pixels &&
                generatedSizes.contains(s.pixels) &&
                s.filename != iconSize.filename)
            .filename;
        File(p.join(outputDir, existingFile)).copySync(outputPath);
      } else {
        final resized = img.copyResize(
          sourceImage,
          width: iconSize.pixels,
          height: iconSize.pixels,
          interpolation: img.Interpolation.average,
        );
        File(outputPath).writeAsBytesSync(img.encodePng(resized));
        generatedSizes.add(iconSize.pixels);
      }
    }

    // Contents.json 생성
    final contentsJson = _buildContentsJson();
    File(p.join(outputDir, 'Contents.json'))
        .writeAsStringSync(contentsJson);

    print('  Generated app icons: $outputDir');
  }

  /// Contents.json 문자열을 생성합니다.
  static String _buildContentsJson() {
    final images = <Map<String, dynamic>>[];
    for (final entry in _contentsEntries) {
      final map = <String, dynamic>{
        'size': entry.size,
        'idiom': entry.idiom,
        'filename': entry.filename,
        'scale': entry.scale,
      };
      if (entry.subtype != null) {
        map['appearances'] = [
          {
            'appearance': 'luminosity',
            'value': entry.subtype,
          }
        ];
      }
      images.add(map);
    }

    final contents = {
      'images': images,
      'info': {
        'version': 1,
        'author': 'easy_setup',
      },
    };

    return const JsonEncoder.withIndent('  ').convert(contents);
  }
}

/// 아이콘 사이즈 정의 (파일명 + 픽셀 크기)
class _IconSize {
  final String filename;
  final int pixels;
  const _IconSize(this.filename, this.pixels);
}

/// Contents.json 엔트리 정의
class _ContentsEntry {
  final String filename;
  final String size;
  final String scale;
  final String idiom;
  final String? subtype;
  const _ContentsEntry(this.filename, this.size, this.scale, this.idiom,
      {this.subtype});
}
