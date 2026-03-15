import 'dart:io';

import 'package:path/path.dart' as p;

import '../android/build_gradle_modifier.dart';
import '../exceptions.dart';
import '../firebase/firebase_copier.dart';
import '../ios/app_icon_generator.dart';
import '../ios/info_plist_modifier.dart';
import '../ios/info_plist_strings_generator.dart';
import '../ios/podfile_modifier.dart';
import '../ios/xcconfig_generator.dart';
import '../ios/xcodegen_generator.dart';
import '../ios/xcodegen_scripts_generator.dart';
import '../models/flavor_config.dart';
import '../utils/project_finder.dart';
import '../utils/xcodegen_runner.dart';

/// flavor 설정의 전체 파이프라인을 오케스트레이션하는 명령 클래스입니다.
///
/// 아래 순서대로 Android와 iOS 설정을 자동으로 수행합니다:
///   1. Flutter 프로젝트 루트 탐지
///   2. easy_setup.yaml 로드 및 파싱
///   3. Android build.gradle — productFlavors 블록 추가 (signingConfigs 포함)
///   3.5. Android Firebase — google-services.json 복사
///   4. iOS xcconfig — flavor별 Debug/Release/Profile 설정 파일 생성
///   4.5. iOS Firebase — GoogleService-Info.plist 복사
///   4.6. iOS App Icon — flavor별 앱 아이콘 자동 생성
///   5. iOS project.yml — XcodeGen 설정 파일 생성
///   5.5. iOS scripts — XcodeGen 빌드 스크립트 생성
///   6. iOS xcodegen — xcodegen generate 실행 (project.pbxproj + schemes 생성)
///   7. iOS Info.plist — CFBundleDisplayName을 변수로 교체
///   7.5. iOS InfoPlist.strings — locale별 앱 이름 + 권한 설명
///   8. iOS Podfile — flavor별 빌드 모드 매핑 추가
class FlavorCommand {
  /// flavor 설정 파이프라인을 실행합니다.
  ///
  /// [projectRoot]를 지정하면 자동 탐지를 건너뛰고 해당 경로를 사용합니다.
  /// [dryRun]이 true이면 파일을 변경하지 않고 미리보기만 출력합니다.
  static void run({bool dryRun = false, String? projectRoot}) {
    // 1단계: Flutter 프로젝트 루트 경로 확인
    final root = projectRoot ?? ProjectFinder.findFlutterRoot();
    if (root == null) {
      throw SetupException(
        'Could not find a Flutter project root.\n'
        'Run this command from inside a Flutter project directory.',
      );
    }
    print('Flutter project root: $root');

    // 2단계: easy_setup.yaml 설정 파일 로드
    final configPath = ProjectFinder.configPath(root);
    print('Loading config from: $configPath');
    final config = EasySetupConfig.fromFile(configPath);
    if (config.flavors.isEmpty) {
      throw SetupException('No flavors defined in easy_setup.yaml');
    }
    print('Flavors: ${config.flavors.keys.join(', ')}');
    if (dryRun) print('\n[dry-run mode] No files will be written.');

    // 3단계: Android — build.gradle에 flavorDimensions + productFlavors 삽입
    print('\n--- Android ---');
    final gradlePath = ProjectFinder.androidBuildGradlePath(root);
    BuildGradleModifier.modify(gradlePath, config.flavors, dryRun: dryRun);

    // 3.5단계: Android Firebase — google-services.json 복사
    for (final entry in config.flavors.entries) {
      final firebase = entry.value.firebase;
      if (firebase?.android != null) {
        FirebaseCopier.copyAndroidConfig(
          root,
          entry.key,
          firebase!.android!,
          dryRun: dryRun,
        );
      }
    }

    // 4단계: iOS — xcconfig 파일 생성
    print('\n--- iOS xcconfig ---');
    final xcconfigDir = ProjectFinder.iosXcconfigDir(root);

    // Flutter 기본 xcconfig 파일이 없으면 생성
    XcconfigGenerator.ensureBaseXcconfigs(xcconfigDir, dryRun: dryRun);

    // 사용하지 않는 flavor xcconfig 파일 정리
    XcconfigGenerator.cleanupUnusedXcconfigs(
      xcconfigDir,
      config.flavors.keys.toSet(),
      dryRun: dryRun,
    );

    for (final entry in config.flavors.entries) {
      XcconfigGenerator.generate(
        xcconfigDir,
        entry.key,
        entry.value,
        dryRun: dryRun,
      );
    }

    // 4.5단계: iOS Firebase — GoogleService-Info.plist 복사
    for (final entry in config.flavors.entries) {
      final firebase = entry.value.firebase;
      if (firebase?.ios != null) {
        FirebaseCopier.copyIosConfig(
          root,
          entry.key,
          firebase!.ios!,
          dryRun: dryRun,
        );
      }
    }

    // 4.6단계: iOS — app_icon이 있는 flavor에 대해 앱 아이콘 자동 생성
    final assetCatalogDir = ProjectFinder.iosAssetCatalogDir(root);

    // 현재 설정된 flavor 목록 추출 (앱 아이콘이 있는 flavor)
    final activeFlavorsWithIcon = <String>{};
    for (final entry in config.flavors.entries) {
      if (entry.value.appIcon != null) {
        activeFlavorsWithIcon.add(entry.key);
      }
    }

    // 사용하지 않는 앱 아이콘 정리 (flavor 변경 시 이전 아이콘 제거)
    if (activeFlavorsWithIcon.isNotEmpty ||
        Directory(assetCatalogDir).existsSync()) {
      AppIconGenerator.cleanupUnusedAppIcons(
        assetCatalogDir,
        activeFlavorsWithIcon,
        dryRun: dryRun,
      );
    }

    // 각 flavor의 앱 아이콘 생성 (flavor별로만)
    for (final entry in config.flavors.entries) {
      if (entry.value.appIcon != null) {
        print('\n--- iOS App Icon (${entry.key}) ---');
        AppIconGenerator.generate(
          root,
          assetCatalogDir,
          entry.key,
          entry.value.appIcon!,
          dryRun: dryRun,
        );
      }
    }

    // 5단계: iOS — Info.plist 수정
    //        CFBundleDisplayName → $(APP_DISPLAY_NAME) + permission 키 추가
    print('\n--- iOS Info.plist ---');
    final plistPath = ProjectFinder.iosInfoPlistPath(root);
    InfoPlistModifier.modify(
      plistPath,
      permission: config.permission,
      dryRun: dryRun,
    );

    // 5.5단계: iOS — InfoPlist.strings 생성
    //          flavor별 strings: ios/Flavors/{flavor}/{locale}.lproj/
    //          permission strings: ios/Runner/{locale}.lproj/
    //          xcodegen generate 이전에 실행해야 .lproj 파일이 프로젝트에 포함됨
    InfoPlistStringsGenerator.generate(
      root,
      flavors: config.flavors,
      permission: config.permission,
      localizedPermission: config.localizedPermission,
      dryRun: dryRun,
    );

    // 6단계: iOS — XcodeGen project.yml 생성
    print('\n--- iOS project.yml (XcodeGen) ---');
    XcodeGenGenerator.generate(
      root,
      config.flavors,
      localizations: config.localizations,
      iosVersion: config.iosVersion,
      dryRun: dryRun,
    );

    // 6.5단계: iOS — XcodeGen 빌드 스크립트 생성
    print('\n--- iOS build scripts ---');
    final hasFlavorLocalized =
        config.flavors.values.any((f) => f.localized != null && f.localized!.isNotEmpty);
    XcodeGenScriptsGenerator.generate(
      root,
      hasFlavors: hasFlavorLocalized,
      dryRun: dryRun,
    );

    // 7단계: iOS — xcodegen generate 실행
    //        .lproj, xcconfig 등 모든 파일이 생성된 후에 실행해야
    //        Xcode 프로젝트에 정확히 반영됨
    print('\n--- iOS xcodegen generate ---');
    XcodeGenRunner.run(root, dryRun: dryRun);

    // 8단계: iOS — Podfile에 flavor별 빌드 모드 매핑 + permission 매크로 추가
    print('\n--- iOS Podfile ---');
    final podfilePath = ProjectFinder.iosPodfilePath(root);
    PodfileModifier.modify(
      podfilePath,
      config.flavors,
      permission: config.permission,
      iosVersion: config.iosVersion,
      dryRun: dryRun,
    );

    // 9단계: iOS — .gitignore에 easy_setup이 생성/관리하는 파일 추가
    _updateGitignore(
      root,
      hasFlavorLocalized: hasFlavorLocalized,
      dryRun: dryRun,
    );

    // 완료 메시지 출력
    _printSummary(dryRun: dryRun);
  }

  /// ios/.gitignore에 easy_setup이 생성/관리하는 파일을 추가합니다.
  ///
  /// xcodegen generate로 생성되는 xcodeproj, easy_setup이 생성하는
  /// xcconfig/스크립트/flavor strings, CocoaPods 산출물 등을 gitignore합니다.
  static void _updateGitignore(
    String projectRoot, {
    required bool hasFlavorLocalized,
    required bool dryRun,
  }) {
    final gitignorePath = p.join(projectRoot, 'ios', '.gitignore');
    final file = File(gitignorePath);
    String content = file.existsSync() ? file.readAsStringSync() : '';

    // easy_setup 마커가 이미 있으면 블록 전체를 교체
    const marker = '# === easy_setup generated ===';
    const endMarker = '# === end easy_setup ===';

    final entries = <String>[
      '# Xcode project (generated by xcodegen)',
      'Runner.xcodeproj/',
      '',
      '# Xcode workspace + CocoaPods',
      'Runner.xcworkspace/',
      'Pods/',
      'Podfile.lock',
      '',
      '# easy_setup generated files',
      'project.yml',
      'xcodegen/',
      'Flavors/',
      'Flutter/Debug-*.xcconfig',
      'Flutter/Release-*.xcconfig',
      'Flutter/Profile-*.xcconfig',
      'Runner/Assets.xcassets/AppIcon-*/',
    ];

    if (hasFlavorLocalized) {
      entries.addAll([
        '',
        '# Modified by build script (flavor-specific display names)',
        'Runner/*.lproj/InfoPlist.strings',
      ]);
    }

    final block = '$marker\n${entries.join('\n')}\n$endMarker\n';

    // 기존 블록이 있으면 교체
    final blockPattern = RegExp(
      '${RegExp.escape(marker)}[\\s\\S]*?${RegExp.escape(endMarker)}\\n?',
    );

    if (blockPattern.hasMatch(content)) {
      final newContent = content.replaceFirst(blockPattern, block);
      if (newContent == content) return; // 변경 없음

      if (dryRun) {
        print('  [dry-run] Would update ios/.gitignore');
        return;
      }

      file.writeAsStringSync(newContent);
      print('  Updated ios/.gitignore');
      return;
    }

    // 기존 블록이 없으면 추가
    if (dryRun) {
      print('  [dry-run] Would update ios/.gitignore');
      return;
    }

    if (content.isNotEmpty && !content.endsWith('\n')) {
      content += '\n';
    }
    content += '\n$block';

    file.writeAsStringSync(content);
    print('  Updated ios/.gitignore');
  }

  /// 설정 완료 후 요약 메시지와 다음 단계를 안내합니다.
  static void _printSummary({required bool dryRun}) {
    print('\n${dryRun ? "Preview" : "Setup"} complete!');
    if (!dryRun) {
      print('\nNext steps:');
      print('  1. flutter pub get');
      print('  2. cd ios && pod install');
      print('  3. flutter run --flavor <flavor> -t lib/main.dart');
    }
  }
}
