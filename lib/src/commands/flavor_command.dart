import 'dart:io';

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

    // 4단계: iOS — flavor별 xcconfig 파일 생성 (Debug/Release/Profile)
    print('\n--- iOS xcconfig ---');
    final xcconfigDir = ProjectFinder.iosXcconfigDir(root);

    // 사용하지 않는 xcconfig 파일 정리 (flavor 변경 시 이전 xcconfig 제거)
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

    // 5단계: iOS — XcodeGen project.yml 생성
    print('\n--- iOS project.yml (XcodeGen) ---');
    XcodeGenGenerator.generate(
      root,
      config.flavors,
      localizations: config.localizations,
      dryRun: dryRun,
    );

    // 5.5단계: iOS — XcodeGen 빌드 스크립트 생성
    print('\n--- iOS build scripts ---');
    XcodeGenScriptsGenerator.generate(root, dryRun: dryRun);

    // 6단계: iOS — xcodegen generate 실행
    print('\n--- iOS xcodegen generate ---');
    XcodeGenRunner.run(root, dryRun: dryRun);

    // 7단계: iOS — Info.plist 수정
    //        CFBundleDisplayName → $(APP_DISPLAY_NAME) + permission 키 추가
    print('\n--- iOS Info.plist ---');
    final plistPath = ProjectFinder.iosInfoPlistPath(root);
    InfoPlistModifier.modify(
      plistPath,
      permission: config.permission,
      dryRun: dryRun,
    );

    // 7.5단계: iOS — localized 설정으로 InfoPlist.strings 생성
    //          각 flavor의 localized 앱 이름은 해당 flavor의 xcconfig에서
    //          APP_DISPLAY_NAME_{locale} 변수로 정의되고,
    //          InfoPlist.strings에서 $(...) 형식으로 참조됨
    //          따라서 모든 flavor의 localized를 병합하여 .strings 템플릿 생성
    {
      final mergedFlavorLocalized = <String, FlavorLocalizedConfig>{};
      for (final entry in config.flavors.entries) {
        final flavorLoc = entry.value.localized;
        if (flavorLoc != null) {
          for (final locEntry in flavorLoc.entries) {
            if (!mergedFlavorLocalized.containsKey(locEntry.key)) {
              mergedFlavorLocalized[locEntry.key] = locEntry.value;
            }
          }
        }
      }

      if (mergedFlavorLocalized.isNotEmpty ||
          config.permission != null ||
          config.localizedPermission != null) {
        InfoPlistStringsGenerator.generate(
          root,
          flavorLocalized:
              mergedFlavorLocalized.isNotEmpty ? mergedFlavorLocalized : null,
          permission: config.permission,
          localizedPermission: config.localizedPermission,
          dryRun: dryRun,
        );
      }
    }

    // 8단계: iOS — Podfile에 flavor별 빌드 모드 매핑 추가
    print('\n--- iOS Podfile ---');
    final podfilePath = ProjectFinder.iosPodfilePath(root);
    PodfileModifier.modify(podfilePath, config.flavors, dryRun: dryRun);

    // 완료 메시지 출력
    _printSummary(dryRun: dryRun);
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
