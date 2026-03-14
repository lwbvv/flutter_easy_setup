import 'dart:io';

import 'package:path/path.dart' as p;

/// Flutter 프로젝트의 각종 파일 경로를 탐색하고 반환하는 유틸리티 클래스입니다.
///
/// 프로젝트 루트 자동 탐지, 설정 파일 경로, Android/iOS 관련 파일 경로를 제공합니다.
class ProjectFinder {
  /// [startDir]로부터 상위 디렉터리를 순회하며 Flutter 프로젝트 루트를 찾습니다.
  ///
  /// pubspec.yaml에 'sdk: flutter' 또는 'flutter:' 키워드가 포함되어 있으면
  /// Flutter 프로젝트로 판단합니다.
  /// 루트 디렉터리('/')까지 올라가도 찾지 못하면 null을 반환합니다.
  static String? findFlutterRoot([String? startDir]) {
    var dir = Directory(startDir ?? Directory.current.path);
    while (true) {
      final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
      if (pubspec.existsSync()) {
        final content = pubspec.readAsStringSync();
        // Flutter 프로젝트는 pubspec.yaml에서 flutter SDK를 참조함
        if (content.contains('sdk: flutter') || content.contains('  flutter:')) {
          return dir.path;
        }
      }
      final parent = dir.parent;
      // 최상위 디렉터리에 도달하면 탐색 종료
      if (parent.path == dir.path) return null;
      dir = parent;
    }
  }

  /// easy_setup.yaml 설정 파일의 전체 경로를 반환합니다.
  static String configPath([String? projectRoot]) =>
      p.join(projectRoot ?? Directory.current.path, 'easy_setup.yaml');

  /// Android app 모듈의 build.gradle(.kts) 경로를 반환합니다.
  ///
  /// Kotlin DSL(.kts) 파일이 존재하면 우선 반환하고,
  /// 없으면 Groovy DSL(.gradle) 경로를 반환합니다.
  static String androidBuildGradlePath(String projectRoot) {
    final kts = p.join(projectRoot, 'android', 'app', 'build.gradle.kts');
    return File(kts).existsSync()
        ? kts
        : p.join(projectRoot, 'android', 'app', 'build.gradle');
  }

  /// iOS xcconfig 파일들이 위치하는 디렉터리 경로 (ios/Flutter/)를 반환합니다.
  static String iosXcconfigDir(String projectRoot) =>
      p.join(projectRoot, 'ios', 'Flutter');

  /// iOS project.pbxproj 파일 경로를 반환합니다.
  static String iosPbxprojPath(String projectRoot) =>
      p.join(projectRoot, 'ios', 'Runner.xcodeproj', 'project.pbxproj');

  /// iOS xcscheme 파일들이 위치하는 디렉터리 경로를 반환합니다.
  static String iosSchemesDir(String projectRoot) => p.join(
        projectRoot,
        'ios',
        'Runner.xcodeproj',
        'xcshareddata',
        'xcschemes',
      );

  /// iOS Info.plist 파일 경로를 반환합니다.
  static String iosInfoPlistPath(String projectRoot) =>
      p.join(projectRoot, 'ios', 'Runner', 'Info.plist');

  /// iOS Podfile 경로를 반환합니다.
  static String iosPodfilePath(String projectRoot) =>
      p.join(projectRoot, 'ios', 'Podfile');

  /// iOS Assets.xcassets 디렉터리 경로를 반환합니다.
  static String iosAssetCatalogDir(String projectRoot) =>
      p.join(projectRoot, 'ios', 'Runner', 'Assets.xcassets');
}
