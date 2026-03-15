import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/flavor_config.dart';

/// XcodeGen의 project.yml 파일을 생성하는 클래스입니다.
///
/// easy_setup.yaml의 flavor 설정을 XcodeGen 형식의 project.yml로 변환하고,
/// xcodegen generate 명령으로 Xcode 프로젝트 전체를 생성합니다.
///
/// 기존의 pbxproj_modifier, scheme_generator를 대체합니다.
class XcodeGenGenerator {
  /// project.yml 파일을 생성합니다.
  ///
  /// [projectRoot]: Flutter 프로젝트 루트
  /// [flavors]: flavor 설정 맵
  /// [localizations]: knownRegions에 등록할 언어 목록
  static void generate(
    String projectRoot,
    Map<String, FlavorConfig> flavors, {
    List<String>? localizations,
    String? iosVersion,
    bool dryRun = false,
  }) {
    final iosDir = p.join(projectRoot, 'ios');
    final projectYmlPath = p.join(iosDir, 'project.yml');

    final content = _buildProjectYml(flavors,
        localizations: localizations, iosVersion: iosVersion);

    if (dryRun) {
      print('  [dry-run] Would write: $projectYmlPath');
      return;
    }

    Directory(iosDir).createSync(recursive: true);
    File(projectYmlPath).writeAsStringSync(content);
    print('  Wrote: $projectYmlPath');
  }

  /// project.yml 내용을 생성합니다.
  static String _buildProjectYml(
    Map<String, FlavorConfig> flavors, {
    List<String>? localizations,
    String? iosVersion,
  }) {
    final version = iosVersion ?? '13.0';
    final sb = StringBuffer();

    // name
    sb.writeln('name: Runner');
    sb.writeln();

    // options
    _writeOptions(sb, localizations: localizations, iosVersion: version);

    // configs
    _writeConfigs(sb, flavors);

    // settings (project-level)
    _writeProjectSettings(sb, iosVersion: version);

    // targets
    _writeTargets(sb, flavors);

    // schemes
    _writeSchemes(sb, flavors);

    return sb.toString();
  }

  /// options 섹션을 생성합니다.
  static void _writeOptions(StringBuffer sb,
      {List<String>? localizations, required String iosVersion}) {
    sb.writeln('options:');
    sb.writeln('  bundleIdPrefix: ""');
    sb.writeln('  deploymentTarget:');
    sb.writeln('    iOS: "$iosVersion"');

    if (localizations != null && localizations.isNotEmpty) {
      sb.writeln('  developmentLanguage: en');
      sb.writeln('  knownRegions:');
      sb.writeln('    - Base');
      for (final locale in localizations) {
        sb.writeln('    - $locale');
      }
    }

    sb.writeln();
  }

  /// configs 섹션을 생성합니다.
  ///
  /// Flutter 기본 3개(Debug, Release, Profile) + flavor별 3개씩 생성합니다.
  /// Profile은 none 타입으로 설정하여 XcodeGen의 기본 설정을 방지합니다.
  static void _writeConfigs(StringBuffer sb, Map<String, FlavorConfig> flavors) {
    sb.writeln('configs:');
    sb.writeln('  Debug: debug');
    sb.writeln('  Profile: none');
    sb.writeln('  Release: release');
    for (final flavor in flavors.keys) {
      sb.writeln('  Debug-$flavor: debug');
      sb.writeln('  Profile-$flavor: none');
      sb.writeln('  Release-$flavor: release');
    }
    sb.writeln();
  }

  /// project-level settings 섹션을 생성합니다.
  static void _writeProjectSettings(StringBuffer sb,
      {required String iosVersion}) {
    sb.writeln('settings:');
    sb.writeln('  base:');
    sb.writeln('    ALWAYS_SEARCH_USER_PATHS: NO');
    sb.writeln('    CLANG_ANALYZER_NONNULL: YES');
    sb.writeln('    CLANG_CXX_LANGUAGE_STANDARD: "gnu++0x"');
    sb.writeln('    CLANG_ENABLE_MODULES: YES');
    sb.writeln('    CLANG_ENABLE_OBJC_ARC: YES');
    sb.writeln('    CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING: YES');
    sb.writeln('    CLANG_WARN_BOOL_CONVERSION: YES');
    sb.writeln('    CLANG_WARN_COMMA: YES');
    sb.writeln('    CLANG_WARN_CONSTANT_CONVERSION: YES');
    sb.writeln('    CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS: YES');
    sb.writeln('    CLANG_WARN_DIRECT_OBJC_ISA_USAGE: YES_ERROR');
    sb.writeln('    CLANG_WARN_EMPTY_BODY: YES');
    sb.writeln('    CLANG_WARN_ENUM_CONVERSION: YES');
    sb.writeln('    CLANG_WARN_INFINITE_RECURSION: YES');
    sb.writeln('    CLANG_WARN_INT_CONVERSION: YES');
    sb.writeln('    CLANG_WARN_NON_LITERAL_NULL_CONVERSION: YES');
    sb.writeln('    CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF: YES');
    sb.writeln('    CLANG_WARN_OBJC_LITERAL_CONVERSION: YES');
    sb.writeln('    CLANG_WARN_OBJC_ROOT_CLASS: YES_ERROR');
    sb.writeln('    CLANG_WARN_RANGE_LOOP_ANALYSIS: YES');
    sb.writeln('    CLANG_WARN_STRICT_PROTOTYPES: YES');
    sb.writeln('    CLANG_WARN_SUSPICIOUS_MOVE: YES');
    sb.writeln('    CLANG_WARN_UNREACHABLE_CODE: YES');
    sb.writeln('    CLANG_WARN__DUPLICATE_METHOD_MATCH: YES');
    sb.writeln('    ENABLE_STRICT_OBJC_MSGSEND: YES');
    sb.writeln('    ENABLE_TESTABILITY: YES');
    sb.writeln('    GCC_NO_COMMON_BLOCKS: YES');
    sb.writeln('    GCC_WARN_64_TO_32_BIT_CONVERSION: YES');
    sb.writeln('    GCC_WARN_ABOUT_RETURN_TYPE: YES_ERROR');
    sb.writeln('    GCC_WARN_UNDECLARED_SELECTOR: YES');
    sb.writeln('    GCC_WARN_UNINITIALIZED_AUTOS: YES_AGGRESSIVE');
    sb.writeln('    GCC_WARN_UNUSED_FUNCTION: YES');
    sb.writeln('    GCC_WARN_UNUSED_VARIABLE: YES');
    sb.writeln('    IPHONEOS_DEPLOYMENT_TARGET: "$iosVersion"');
    sb.writeln('    SDKROOT: iphoneos');
    sb.writeln('  configs:');
    sb.writeln('    Debug:');
    sb.writeln('      MTL_ENABLE_DEBUG_INFO: INCLUDE_SOURCE');
    sb.writeln('      SWIFT_OPTIMIZATION_LEVEL: "-Onone"');
    sb.writeln('      ONLY_ACTIVE_ARCH: YES');
    sb.writeln('      GCC_DYNAMIC_NO_PIC: NO');
    sb.writeln("      GCC_PREPROCESSOR_DEFINITIONS: 'DEBUG=1 \$(inherited)'");
    sb.writeln('    Release:');
    sb.writeln('      MTL_ENABLE_DEBUG_INFO: "NO"');
    sb.writeln('      SWIFT_COMPILATION_MODE: wholemodule');
    sb.writeln('      VALIDATE_PRODUCT: YES');
    sb.writeln('      COPY_PHASE_STRIP: "NO"');
    sb.writeln();
  }

  /// targets 섹션을 생성합니다.
  static void _writeTargets(
      StringBuffer sb, Map<String, FlavorConfig> flavors) {
    sb.writeln('targets:');

    // Runner target
    _writeRunnerTarget(sb, flavors);

    // RunnerTests target
    _writeRunnerTestsTarget(sb);

    sb.writeln();
  }

  /// Runner target을 생성합니다.
  static void _writeRunnerTarget(
      StringBuffer sb, Map<String, FlavorConfig> flavors) {
    sb.writeln('  Runner:');
    sb.writeln('    type: application');
    sb.writeln('    platform: iOS');
    sb.writeln();

    // configFiles
    sb.writeln('    configFiles:');
    sb.writeln('      Debug: Flutter/Debug.xcconfig');
    sb.writeln('      Release: Flutter/Release.xcconfig');
    sb.writeln('      Profile: Flutter/Release.xcconfig');
    for (final flavor in flavors.keys) {
      sb.writeln('      Debug-$flavor: Flutter/Debug-$flavor.xcconfig');
      sb.writeln('      Release-$flavor: Flutter/Release-$flavor.xcconfig');
      sb.writeln('      Profile-$flavor: Flutter/Profile-$flavor.xcconfig');
    }
    sb.writeln();

    // sources
    sb.writeln('    sources:');
    sb.writeln('      - path: Runner');
    sb.writeln('      - path: Flutter');
    sb.writeln();

    // preBuildScripts
    // flavor localized가 있으면 copy_flavor_strings를 Run Script 앞에 배치
    final hasFlavorLocalized =
        flavors.values.any((f) => f.localized != null && f.localized!.isNotEmpty);

    sb.writeln('    preBuildScripts:');
    if (hasFlavorLocalized) {
      sb.writeln('      - name: Copy Flavor Strings');
      sb.writeln('        path: xcodegen/script/copy_flavor_strings.sh');
      sb.writeln('        basedOnDependencyAnalysis: false');
    }
    sb.writeln('      - name: Run Script');
    sb.writeln('        path: xcodegen/script/run_script.sh');
    sb.writeln('        basedOnDependencyAnalysis: false');
    sb.writeln();

    // postBuildScripts
    sb.writeln('    postBuildScripts:');
    sb.writeln('      - name: Thin Binary');
    sb.writeln('        path: xcodegen/script/thin_binary.sh');
    sb.writeln('        basedOnDependencyAnalysis: false');
    sb.writeln('        inputFiles:');
    sb.writeln(r'          - ${TARGET_BUILD_DIR}/${INFOPLIST_PATH}');
    sb.writeln();

    // settings
    sb.writeln('    settings:');
    sb.writeln('      base:');
    sb.writeln('        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon');
    sb.writeln('        ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS: "NO"');
    sb.writeln('        CLANG_ENABLE_MODULES: YES');
    sb.writeln('        CURRENT_PROJECT_VERSION: "\$(FLUTTER_BUILD_NUMBER)"');
    sb.writeln('        ENABLE_BITCODE: "NO"');
    sb.writeln('        INFOPLIST_FILE: Runner/Info.plist');
    sb.writeln('        PRODUCT_BUNDLE_IDENTIFIER: ""');
    sb.writeln('        PRODUCT_NAME: "\$(TARGET_NAME)"');
    sb.writeln(
        '        SWIFT_OBJC_BRIDGING_HEADER: Runner/Runner-Bridging-Header.h');
    sb.writeln('        SWIFT_VERSION: 5.0');
    sb.writeln('        VERSIONING_SYSTEM: apple-generic');
    sb.writeln('      configs:');

    // 기본 configs에도 Debug 최적화 설정
    sb.writeln('        Debug:');
    sb.writeln('          SWIFT_OPTIMIZATION_LEVEL: "-Onone"');

    // flavor별 config settings
    for (final entry in flavors.entries) {
      final flavor = entry.key;
      final config = entry.value;

      for (final buildType in ['Debug', 'Release', 'Profile']) {
        sb.writeln('        $buildType-$flavor:');
        sb.writeln(
            '          PRODUCT_BUNDLE_IDENTIFIER: ${config.bundleId}');
        if (config.appIcon != null) {
          sb.writeln(
              '          ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon-$flavor');
        }
        if (buildType == 'Debug') {
          sb.writeln('          SWIFT_OPTIMIZATION_LEVEL: "-Onone"');
        }
      }
    }
    sb.writeln();
  }

  /// RunnerTests target을 생성합니다.
  static void _writeRunnerTestsTarget(StringBuffer sb) {
    sb.writeln('  RunnerTests:');
    sb.writeln('    type: bundle.unit-test');
    sb.writeln('    platform: iOS');
    sb.writeln('    sources:');
    sb.writeln('      - path: RunnerTests');
    sb.writeln('    dependencies:');
    sb.writeln('      - target: Runner');
    sb.writeln('    settings:');
    sb.writeln('      base:');
    sb.writeln('        BUNDLE_LOADER: "\$(TEST_HOST)"');
    sb.writeln('        CODE_SIGN_STYLE: Automatic');
    sb.writeln('        CURRENT_PROJECT_VERSION: 1');
    sb.writeln('        GENERATE_INFOPLIST_FILE: YES');
    sb.writeln('        MARKETING_VERSION: 1.0');
    sb.writeln('        SWIFT_VERSION: 5.0');
    sb.writeln(
        '        TEST_HOST: "\$(BUILT_PRODUCTS_DIR)/Runner.app/\$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Runner"');
    sb.writeln();
  }

  /// schemes 섹션을 생성합니다.
  ///
  /// 기본 Runner scheme + flavor별 scheme을 생성합니다.
  /// 각 flavor scheme은 해당 flavor의 Debug/Release/Profile 구성을 매핑합니다.
  static void _writeSchemes(
      StringBuffer sb, Map<String, FlavorConfig> flavors) {
    sb.writeln('schemes:');

    // 기본 Runner scheme
    sb.writeln('  Runner:');
    sb.writeln('    build:');
    sb.writeln('      targets:');
    sb.writeln('        Runner: all');
    sb.writeln('    run:');
    sb.writeln('      config: Debug');
    sb.writeln('    test:');
    sb.writeln('      config: Debug');
    sb.writeln('    profile:');
    sb.writeln('      config: Profile');
    sb.writeln('    analyze:');
    sb.writeln('      config: Debug');
    sb.writeln('    archive:');
    sb.writeln('      config: Release');

    // flavor별 scheme
    for (final flavor in flavors.keys) {
      sb.writeln('  $flavor:');
      sb.writeln('    build:');
      sb.writeln('      targets:');
      sb.writeln('        Runner: all');
      sb.writeln('    run:');
      sb.writeln('      config: Debug-$flavor');
      sb.writeln('    test:');
      sb.writeln('      config: Debug-$flavor');
      sb.writeln('    profile:');
      sb.writeln('      config: Profile-$flavor');
      sb.writeln('    analyze:');
      sb.writeln('      config: Debug-$flavor');
      sb.writeln('    archive:');
      sb.writeln('      config: Release-$flavor');
    }
  }
}
