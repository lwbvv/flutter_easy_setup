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
    // Debug용 xcconfig — Debug.xcconfig를 상속
    _writeXcconfig(
      p.join(xcconfigDir, 'Debug-$flavor.xcconfig'),
      '#include "Debug.xcconfig"\n'
      'APP_DISPLAY_NAME=${config.name}\n',
      dryRun: dryRun,
    );
    // Release용 xcconfig — Release.xcconfig를 상속
    _writeXcconfig(
      p.join(xcconfigDir, 'Release-$flavor.xcconfig'),
      '#include "Release.xcconfig"\n'
      'APP_DISPLAY_NAME=${config.name}\n',
      dryRun: dryRun,
    );
    // Profile용 xcconfig — Release.xcconfig를 상속 (프로파일은 릴리스 기반)
    _writeXcconfig(
      p.join(xcconfigDir, 'Profile-$flavor.xcconfig'),
      '#include "Release.xcconfig"\n'
      'APP_DISPLAY_NAME=${config.name}\n',
      dryRun: dryRun,
    );
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
