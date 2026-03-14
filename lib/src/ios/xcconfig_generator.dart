import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/flavor_config.dart';

/// iOS flavor별 xcconfig 파일을 생성하는 클래스입니다.
///
/// 각 flavor에 대해 3개의 xcconfig 파일을 생성합니다:
///   - Debug-{flavor}.xcconfig   → Debug.xcconfig를 include
///   - Release-{flavor}.xcconfig → Release.xcconfig를 include
///   - Profile-{flavor}.xcconfig → Release.xcconfig를 include (프로파일 빌드용)
///
/// 각 파일에는 APP_DISPLAY_NAME 변수가 설정되어,
/// Info.plist에서 $(APP_DISPLAY_NAME)으로 참조할 수 있습니다.
class XcconfigGenerator {
  /// 지정된 [xcconfigDir] 디렉터리에 flavor별 xcconfig 파일을 생성합니다.
  static void generate(
    String xcconfigDir,
    String flavor,
    FlavorConfig config, {
    bool dryRun = false,
  }) {
    final vars = _buildXcconfigVars(config, flavor: flavor);

    // Debug용 xcconfig — Debug.xcconfig를 상속
    _writeXcconfig(
      p.join(xcconfigDir, 'Debug-$flavor.xcconfig'),
      '#include "Debug.xcconfig"\n$vars',
      dryRun: dryRun,
    );
    // Release용 xcconfig — Release.xcconfig를 상속
    _writeXcconfig(
      p.join(xcconfigDir, 'Release-$flavor.xcconfig'),
      '#include "Release.xcconfig"\n$vars',
      dryRun: dryRun,
    );
    // Profile용 xcconfig — Release.xcconfig를 상속 (프로파일은 릴리스 기반)
    _writeXcconfig(
      p.join(xcconfigDir, 'Profile-$flavor.xcconfig'),
      '#include "Release.xcconfig"\n$vars',
      dryRun: dryRun,
    );
  }

  /// FlavorConfig로부터 xcconfig 변수 문자열을 조합합니다.
  ///
  /// [flavor]가 전달되고 [config.appIcon]이 설정되어 있으면
  /// ASSETCATALOG_COMPILER_APPICON_NAME을 AppIcon-{flavor}로 자동 설정합니다.
  static String _buildXcconfigVars(FlavorConfig config, {String? flavor}) {
    final sb = StringBuffer();
    sb.writeln('APP_DISPLAY_NAME=${config.name}');
    final ios = config.ios;
    if (ios != null) {
      if (ios.teamId != null) {
        sb.writeln('DEVELOPMENT_TEAM=${ios.teamId}');
      }
      if (ios.codeSignIdentity != null) {
        sb.writeln('CODE_SIGN_IDENTITY=${ios.codeSignIdentity}');
      }
      if (ios.provisioningProfile != null) {
        sb.writeln('PROVISIONING_PROFILE_SPECIFIER=${ios.provisioningProfile}');
      }
      if (ios.entitlements != null) {
        sb.writeln('CODE_SIGN_ENTITLEMENTS=${ios.entitlements}');
      }
    }
    if (config.appIcon != null && flavor != null) {
      sb.writeln('ASSETCATALOG_COMPILER_APPICON_NAME=AppIcon-$flavor');
    }
    return sb.toString();
  }

  /// [xcconfigDir]에서 사용하지 않는 flavor별 xcconfig 파일을 삭제합니다.
  ///
  /// [activeFlavors]: 현재 활성 flavor 목록 (이들의 xcconfig만 보존)
  /// Debug-{flavor}, Release-{flavor}, Profile-{flavor} 패턴의 파일만 대상으로 합니다.
  static void cleanupUnusedXcconfigs(
    String xcconfigDir,
    Set<String> activeFlavors, {
    bool dryRun = false,
  }) {
    final dir = Directory(xcconfigDir);
    if (!dir.existsSync()) return;

    final prefixes = ['Debug-', 'Release-', 'Profile-'];

    try {
      for (final entity in dir.listSync()) {
        if (entity is! File) continue;
        final fileName = p.basename(entity.path);
        if (!fileName.endsWith('.xcconfig')) continue;

        for (final prefix in prefixes) {
          if (fileName.startsWith(prefix)) {
            final flavor =
                fileName.replaceFirst(prefix, '').replaceFirst('.xcconfig', '');
            if (!activeFlavors.contains(flavor)) {
              if (dryRun) {
                print('  [dry-run] Would delete: ${entity.path}');
              } else {
                entity.deleteSync();
                print('  Deleted unused xcconfig: ${entity.path}');
              }
            }
            break;
          }
        }
      }
    } catch (e) {
      print('  Warning: Failed to cleanup xcconfigs: $e');
    }
  }

  /// 개별 xcconfig 파일을 작성합니다 (기존 파일이 있으면 덮어씁니다).
  static void _writeXcconfig(
    String path,
    String content, {
    required bool dryRun,
  }) {
    if (dryRun) {
      print('  [dry-run] Would write: $path');
      return;
    }
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    print('  Wrote: $path');
  }
}
