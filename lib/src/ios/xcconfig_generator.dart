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
    final vars = _buildXcconfigVars(config);

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
  static String _buildXcconfigVars(FlavorConfig config) {
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
      if (ios.appIcon != null) {
        sb.writeln('ASSETCATALOG_COMPILER_APPICON_NAME=${ios.appIcon}');
      }
    }
    return sb.toString();
  }

  /// 개별 xcconfig 파일을 작성합니다.
  ///
  /// 이미 파일이 존재하면 덮어쓰지 않고 건너뜁니다 (멱등성 보장).
  static void _writeXcconfig(
    String path,
    String content, {
    required bool dryRun,
  }) {
    if (dryRun) {
      print('  [dry-run] Would create: $path');
      return;
    }
    final file = File(path);
    if (file.existsSync()) {
      print('  Already exists: $path, skipping.');
      return;
    }
    // 디렉터리가 없으면 재귀적으로 생성
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    print('  Created: $path');
  }
}
