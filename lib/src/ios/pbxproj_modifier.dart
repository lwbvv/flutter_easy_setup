import 'dart:io';

import '../exceptions.dart';
import '../models/flavor_config.dart';
import '../utils/uuid_generator.dart';

/// iOS project.pbxproj 파일에 flavor별 빌드 구성을 추가하는 클래스입니다.
///
/// 이 클래스는 easy_setup 도구에서 가장 복잡한 로직을 담당합니다.
/// Xcode의 project.pbxproj는 구조화된 텍스트 형식으로, 아래 섹션들을 수정합니다:
///
///   - PBXFileReference: flavor xcconfig 파일 참조 추가
///   - PBXGroup (Flutter): xcconfig 파일을 Flutter 그룹에 등록
///   - XCBuildConfiguration (Runner 타겟): easy_setup.yaml 설정 기반으로
///     flavor별 빌드 구성 생성 (bundle ID, team ID, app icon 등)
///   - XCBuildConfiguration (Project 레벨): 표준 Xcode 프로젝트 설정 템플릿으로 생성
///   - XCBuildConfiguration (RunnerTests): 테스트 타겟 설정 템플릿으로 생성
///   - XCConfigurationList (Runner/Project/RunnerTests): 구성 목록에 UUID 등록
///
/// 반환값: Runner 타겟의 UUID (scheme 생성 시 필요)
class PbxprojModifier {
  /// project.pbxproj 파일을 수정하여 flavor 빌드 구성을 추가합니다.
  ///
  /// Runner PBXNativeTarget의 UUID를 반환합니다.
  /// 이 UUID는 .xcscheme 파일 생성 시 BuildableReference에 사용됩니다.
  static String modify(
    String pbxprojPath,
    Map<String, FlavorConfig> flavors, {
    bool dryRun = false,
  }) {
    final file = File(pbxprojPath);
    if (!file.existsSync()) {
      throw SetupException('project.pbxproj not found: $pbxprojPath');
    }

    var content = file.readAsStringSync();

    // ---- 구조 UUID 추출 ----

    // Runner 타겟(PBXNativeTarget)의 UUID 추출
    final runnerTargetUuid = _extractRunnerTargetUuid(content);
    if (runnerTargetUuid.isEmpty) {
      throw SetupException(
        'Could not find Runner PBXNativeTarget UUID in project.pbxproj',
      );
    }

    // Flutter PBXGroup의 UUID 추출 (xcconfig 파일을 이 그룹에 추가)
    final flutterGroupUuid = _extractFlutterGroupUuid(content);
    if (flutterGroupUuid.isEmpty) {
      throw SetupException(
        'Could not find Flutter PBXGroup UUID in project.pbxproj',
      );
    }

    // Runner 타겟의 buildConfigurationList UUID 추출
    final runnerConfigListUuid =
        _extractBuildConfigListForTarget(content, runnerTargetUuid);
    if (runnerConfigListUuid.isEmpty) {
      throw SetupException(
        'Could not find Runner buildConfigurationList UUID',
      );
    }

    // Project 레벨의 buildConfigurationList UUID 추출
    final projectConfigListUuid = _extractProjectConfigListUuid(content);
    if (projectConfigListUuid.isEmpty) {
      throw SetupException(
        'Could not find Project buildConfigurationList UUID',
      );
    }

    // RunnerTests 타겟 (존재하지 않을 수 있음)
    final runnerTestsTargetUuid =
        _extractNativeTargetUuid(content, 'RunnerTests');
    String runnerTestsConfigListUuid = '';
    String testBundleId = '';
    if (runnerTestsTargetUuid.isNotEmpty) {
      runnerTestsConfigListUuid = _extractBuildConfigListForTarget(
        content,
        runnerTestsTargetUuid,
        'RunnerTests',
      );
      // 스트리핑 전에 테스트 번들 ID를 추출
      testBundleId = _extractTestBundleId(content);
    }

    // ---- 기존 빌드 구성 모두 제거 (base + flavor) ----
    content = _stripAllBuildConfigurations(content);

    // ---- flavor별 새 UUID 일괄 생성 ----
    final flavorUuids = <String, _FlavorUuids>{};
    for (final flavor in flavors.keys) {
      flavorUuids[flavor] = _FlavorUuids(
        debugFileRef: UuidGenerator.generate(),
        releaseFileRef: UuidGenerator.generate(),
        profileFileRef: UuidGenerator.generate(),
        debugRunnerConfig: UuidGenerator.generate(),
        releaseRunnerConfig: UuidGenerator.generate(),
        profileRunnerConfig: UuidGenerator.generate(),
        debugProjectConfig: UuidGenerator.generate(),
        releaseProjectConfig: UuidGenerator.generate(),
        profileProjectConfig: UuidGenerator.generate(),
        debugRunnerTestsConfig: UuidGenerator.generate(),
        releaseRunnerTestsConfig: UuidGenerator.generate(),
        profileRunnerTestsConfig: UuidGenerator.generate(),
      );
    }

    // Step a: PBXFileReference 섹션에 xcconfig 파일 참조 추가
    content = _addFileReferences(content, flavors, flavorUuids);

    // Step b: Flutter PBXGroup의 children 목록에 파일 참조 추가
    content =
        _addToFlutterGroup(content, flutterGroupUuid, flavors, flavorUuids);

    // Step c: Runner 타겟의 XCBuildConfiguration 블록 생성
    content = _insertRunnerConfigs(content, flavors, flavorUuids);

    // Step d: Project 레벨의 XCBuildConfiguration 블록 생성
    content = _insertProjectConfigs(content, flavors, flavorUuids);

    // Step e: RunnerTests 타겟의 XCBuildConfiguration 블록 생성 (존재하는 경우)
    if (runnerTestsTargetUuid.isNotEmpty && testBundleId.isNotEmpty) {
      content = _insertRunnerTestsConfigs(
        content,
        flavors,
        flavorUuids,
        testBundleId,
      );
    }

    // Step f: Runner의 XCConfigurationList에 새 빌드 구성 UUID 등록
    content = _addToConfigList(
      content,
      runnerConfigListUuid,
      flavors,
      flavorUuids,
      isRunner: true,
    );

    // Step g: Project의 XCConfigurationList에 새 빌드 구성 UUID 등록
    content = _addToConfigList(
      content,
      projectConfigListUuid,
      flavors,
      flavorUuids,
      isRunner: false,
    );

    // Step h: RunnerTests의 XCConfigurationList에 새 빌드 구성 UUID 등록
    if (runnerTestsConfigListUuid.isNotEmpty) {
      content = _addToConfigListGeneric(
        content,
        runnerTestsConfigListUuid,
        flavors,
        flavorUuids,
        uuidSelector: (uuids, buildType) => buildType == 'Debug'
            ? uuids.debugRunnerTestsConfig
            : buildType == 'Release'
                ? uuids.releaseRunnerTestsConfig
                : uuids.profileRunnerTestsConfig,
      );
    }

    if (dryRun) {
      print('  [dry-run] Would update iOS project.pbxproj');
    } else {
      file.writeAsStringSync(content);
      print('  Updated iOS project.pbxproj');
    }

    return runnerTargetUuid;
  }

  /// project.pbxproj의 knownRegions를 업데이트합니다.
  ///
  /// [localizations] 목록의 언어 + Base를 knownRegions에 설정합니다.
  static void modifyKnownRegions(
    String pbxprojPath,
    List<String> localizations, {
    bool dryRun = false,
  }) {
    final file = File(pbxprojPath);
    if (!file.existsSync()) {
      throw SetupException('project.pbxproj not found: $pbxprojPath');
    }

    var content = file.readAsStringSync();

    // knownRegions = ( ... ); 블록을 찾아서 교체
    final regionPattern = RegExp(
      r'knownRegions = \(\n([\s\S]*?)\t\t\t\);',
    );
    final match = regionPattern.firstMatch(content);
    if (match == null) {
      print('  Warning: knownRegions not found in project.pbxproj');
      return;
    }

    // 새 knownRegions 목록 생성 (중복 제거, Base 포함)
    final regions = <String>{'Base', ...localizations};
    final sb = StringBuffer();
    sb.writeln('knownRegions = (');
    for (final region in regions) {
      sb.writeln('\t\t\t\t$region,');
    }
    sb.write('\t\t\t);');

    content = content.replaceFirst(regionPattern, sb.toString());

    if (dryRun) {
      print('  [dry-run] Would update knownRegions: ${regions.join(', ')}');
    } else {
      file.writeAsStringSync(content);
      print('  Updated knownRegions: ${regions.join(', ')}');
    }
  }

  /// pbxproj 파일에서 Runner 타겟의 모든 빌드 구성(이름 + bundle ID)을 추출합니다.
  ///
  /// flavor 설정 후 생성된 Debug-dev, Release-prod 등의 구성을 포함합니다.
  /// 기본 Debug/Release/Profile 구성은 제외하고 flavor 구성만 반환합니다.
  static List<({String name, String bundleId})> extractRunnerBuildConfigs(
    String pbxprojPath,
  ) {
    final file = File(pbxprojPath);
    if (!file.existsSync()) {
      throw SetupException(
        'project.pbxproj not found: $pbxprojPath\n'
        'Run "easy_setup flavor" first to set up build configurations.',
      );
    }

    final content = file.readAsStringSync();

    // Runner PBXNativeTarget UUID 추출
    final targetUuid = _extractRunnerTargetUuid(content);
    if (targetUuid.isEmpty) {
      throw SetupException(
        'Could not find Runner PBXNativeTarget in project.pbxproj',
      );
    }

    // Runner 타겟의 buildConfigurationList UUID 추출
    final configListUuid =
        _extractBuildConfigListForTarget(content, targetUuid);
    if (configListUuid.isEmpty) {
      throw SetupException(
        'Could not find Runner buildConfigurationList UUID',
      );
    }

    // XCConfigurationList에서 모든 구성 UUID + 이름 추출
    final allConfigs = _extractAllConfigsFromList(content, configListUuid);

    // 각 구성 UUID에서 PRODUCT_BUNDLE_IDENTIFIER 추출
    final result = <({String name, String bundleId})>[];
    for (final entry in allConfigs.entries) {
      final configName = entry.key;
      final configUuid = entry.value;

      final block = _extractXCBuildConfigBlock(content, configUuid);
      if (block.isEmpty) continue;

      final bundleIdMatch = RegExp(
        r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*"?([^";]+)"?\s*;',
      ).firstMatch(block);
      if (bundleIdMatch == null) continue;

      result.add((name: configName, bundleId: bundleIdMatch.group(1)!));
    }

    return result;
  }

  // ──────────────────────────── 스트리핑 ────────────────────────────────────

  /// 기존의 모든 빌드 구성을 제거합니다 (base + flavor).
  ///
  /// PBXFileReference, PBXGroup children, XCBuildConfiguration,
  /// XCConfigurationList에서 관련 항목을 모두 제거합니다.
  static String _stripAllBuildConfigurations(String content) {
    // 1. PBXFileReference: flavor xcconfig 파일 참조 제거
    content = content.replaceAll(
      RegExp(
        r'\t\t[0-9A-F]{24} /\* (?:Debug|Release|Profile)-\w+\.xcconfig \*/ = \{isa = PBXFileReference;[^\n]+\n',
      ),
      '',
    );

    // 2. PBXGroup children: flavor xcconfig 파일 참조 제거
    content = content.replaceAll(
      RegExp(
        r'\t\t\t\t[0-9A-F]{24} /\* (?:Debug|Release|Profile)-\w+\.xcconfig \*/,\n',
      ),
      '',
    );

    // 3. XCBuildConfiguration: 모든 빌드 구성 블록 제거 (base + flavor)
    while (true) {
      final match = RegExp(
        r'\t\t[0-9A-F]{24} /\* (?:Debug|Release|Profile)(?:-\w+)? \*/ = \{',
      ).firstMatch(content);
      if (match == null) break;

      final braceStart = match.end - 1;
      final blockEnd = _findBlockEnd(content, braceStart);
      if (blockEnd == -1) break;

      var end = blockEnd + 1;
      if (end < content.length && content[end] == ';') end++;
      if (end < content.length && content[end] == '\n') end++;
      content = content.substring(0, match.start) + content.substring(end);
    }

    // 4. XCConfigurationList: 모든 빌드 구성 참조 제거 (base + flavor)
    content = content.replaceAll(
      RegExp(
        r'\t\t\t\t[0-9A-F]{24} /\* (?:Debug|Release|Profile)(?:-\w+)? \*/,\n',
      ),
      '',
    );

    return content;
  }

  // ─────────── 빌드 구성 템플릿 생성 (Runner / Project / RunnerTests) ──────────

  /// Runner 타겟의 XCBuildConfiguration 블록을 템플릿에서 생성합니다.
  static String _generateRunnerConfigBlock({
    required String uuid,
    required String name,
    required String bundleId,
    required String xcconfigRefUuid,
    required String xcconfigName,
    required String buildType,
    String? teamId,
    String? appIconName,
  }) {
    final sb = StringBuffer();
    sb.writeln('\t\t$uuid /* $name */ = {');
    sb.writeln('\t\t\tisa = XCBuildConfiguration;');
    sb.writeln(
      '\t\t\tbaseConfigurationReference = $xcconfigRefUuid /* $xcconfigName */;',
    );
    sb.writeln('\t\t\tbuildSettings = {');
    sb.writeln(
      '\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = ${appIconName ?? "AppIcon"};',
    );
    sb.writeln('\t\t\t\tCLANG_ENABLE_MODULES = YES;');
    sb.writeln(
      '\t\t\t\tCURRENT_PROJECT_VERSION = "\$(FLUTTER_BUILD_NUMBER)";',
    );
    if (teamId != null) {
      sb.writeln('\t\t\t\tDEVELOPMENT_TEAM = $teamId;');
    }
    sb.writeln('\t\t\t\tENABLE_BITCODE = NO;');
    sb.writeln('\t\t\t\tINFOPLIST_FILE = Runner/Info.plist;');
    sb.writeln('\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (');
    sb.writeln('\t\t\t\t\t"\$(inherited)",');
    sb.writeln('\t\t\t\t\t"@executable_path/Frameworks",');
    sb.writeln('\t\t\t\t);');
    sb.writeln('\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = $bundleId;');
    sb.writeln('\t\t\t\tPRODUCT_NAME = "\$(TARGET_NAME)";');
    sb.writeln(
      '\t\t\t\tSWIFT_OBJC_BRIDGING_HEADER = "Runner/Runner-Bridging-Header.h";',
    );
    if (buildType == 'Debug') {
      sb.writeln('\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";');
    }
    sb.writeln('\t\t\t\tSWIFT_VERSION = 5.0;');
    sb.writeln('\t\t\t\tVERSIONING_SYSTEM = "apple-generic";');
    sb.writeln('\t\t\t};');
    sb.writeln('\t\t\tname = "$name";');
    sb.writeln('\t\t};');
    return sb.toString();
  }

  /// Project 레벨의 XCBuildConfiguration 블록을 템플릿에서 생성합니다.
  ///
  /// Debug / Release / Profile에 따라 최적화, 디버그 설정이 다릅니다.
  static String _generateProjectConfigBlock({
    required String uuid,
    required String name,
    required String buildType,
  }) {
    final sb = StringBuffer();
    sb.writeln('\t\t$uuid /* $name */ = {');
    sb.writeln('\t\t\tisa = XCBuildConfiguration;');
    sb.writeln('\t\t\tbuildSettings = {');
    sb.writeln('\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;');
    sb.writeln(
      '\t\t\t\tASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;',
    );
    sb.writeln('\t\t\t\tCLANG_ANALYZER_NONNULL = YES;');
    sb.writeln('\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++0x";');
    sb.writeln('\t\t\t\tCLANG_CXX_LIBRARY = "libc++";');
    sb.writeln('\t\t\t\tCLANG_ENABLE_MODULES = YES;');
    sb.writeln('\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;');
    sb.writeln('\t\t\t\tCLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;');
    sb.writeln('\t\t\t\tCLANG_WARN_BOOL_CONVERSION = YES;');
    sb.writeln('\t\t\t\tCLANG_WARN_COMMA = YES;');
    sb.writeln('\t\t\t\tCLANG_WARN_CONSTANT_CONVERSION = YES;');
    sb.writeln(
      '\t\t\t\tCLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;',
    );
    sb.writeln('\t\t\t\tCLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;');
    sb.writeln('\t\t\t\tCLANG_WARN_EMPTY_BODY = YES;');
    sb.writeln('\t\t\t\tCLANG_WARN_ENUM_CONVERSION = YES;');
    sb.writeln('\t\t\t\tCLANG_WARN_INFINITE_RECURSION = YES;');
    sb.writeln('\t\t\t\tCLANG_WARN_INT_CONVERSION = YES;');
    sb.writeln('\t\t\t\tCLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;');
    sb.writeln('\t\t\t\tCLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;');
    sb.writeln('\t\t\t\tCLANG_WARN_OBJC_LITERAL_CONVERSION = YES;');
    sb.writeln('\t\t\t\tCLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;');
    sb.writeln('\t\t\t\tCLANG_WARN_RANGE_LOOP_ANALYSIS = YES;');
    sb.writeln('\t\t\t\tCLANG_WARN_STRICT_PROTOTYPES = YES;');
    sb.writeln('\t\t\t\tCLANG_WARN_SUSPICIOUS_MOVE = YES;');
    sb.writeln('\t\t\t\tCLANG_WARN_UNREACHABLE_CODE = YES;');
    sb.writeln('\t\t\t\tCLANG_WARN__DUPLICATE_METHOD_MATCH = YES;');
    sb.writeln(
      '\t\t\t\t"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "iPhone Developer";',
    );
    sb.writeln('\t\t\t\tCOPY_PHASE_STRIP = NO;');

    if (buildType == 'Debug') {
      sb.writeln('\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;');
    } else {
      sb.writeln('\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";');
    }

    sb.writeln('\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;');

    if (buildType == 'Debug') {
      sb.writeln('\t\t\t\tENABLE_TESTABILITY = YES;');
    } else {
      sb.writeln('\t\t\t\tENABLE_NS_ASSERTIONS = NO;');
    }

    sb.writeln('\t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = NO;');
    sb.writeln('\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu99;');

    if (buildType == 'Debug') {
      sb.writeln('\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;');
    }

    sb.writeln('\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;');

    if (buildType == 'Debug') {
      sb.writeln('\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;');
      sb.writeln('\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (');
      sb.writeln('\t\t\t\t\t"DEBUG=1",');
      sb.writeln('\t\t\t\t\t"\$(inherited)",');
      sb.writeln('\t\t\t\t);');
    }

    sb.writeln('\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;');
    sb.writeln('\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;');
    sb.writeln('\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;');
    sb.writeln('\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;');
    sb.writeln('\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;');
    sb.writeln('\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;');
    sb.writeln('\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 13.0;');

    if (buildType == 'Debug') {
      sb.writeln('\t\t\t\tMTL_ENABLE_DEBUG_INFO = YES;');
      sb.writeln('\t\t\t\tONLY_ACTIVE_ARCH = YES;');
    } else {
      sb.writeln('\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;');
    }

    sb.writeln('\t\t\t\tSDKROOT = iphoneos;');

    if (buildType != 'Debug') {
      sb.writeln('\t\t\t\tSUPPORTED_PLATFORMS = iphoneos;');
      if (buildType == 'Release') {
        sb.writeln('\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;');
        sb.writeln('\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";');
      }
    }

    sb.writeln('\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";');

    if (buildType != 'Debug') {
      sb.writeln('\t\t\t\tVALIDATE_PRODUCT = YES;');
    }

    sb.writeln('\t\t\t};');
    sb.writeln('\t\t\tname = "$name";');
    sb.writeln('\t\t};');
    return sb.toString();
  }

  /// RunnerTests 타겟의 XCBuildConfiguration 블록을 템플릿에서 생성합니다.
  static String _generateRunnerTestsConfigBlock({
    required String uuid,
    required String name,
    required String testBundleId,
    required String buildType,
  }) {
    final sb = StringBuffer();
    sb.writeln('\t\t$uuid /* $name */ = {');
    sb.writeln('\t\t\tisa = XCBuildConfiguration;');
    sb.writeln('\t\t\tbuildSettings = {');
    sb.writeln('\t\t\t\tBUNDLE_LOADER = "\$(TEST_HOST)";');
    sb.writeln('\t\t\t\tCODE_SIGN_STYLE = Automatic;');
    sb.writeln('\t\t\t\tCURRENT_PROJECT_VERSION = 1;');
    sb.writeln('\t\t\t\tGENERATE_INFOPLIST_FILE = YES;');
    sb.writeln('\t\t\t\tMARKETING_VERSION = 1.0;');
    sb.writeln('\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = $testBundleId;');
    sb.writeln('\t\t\t\tPRODUCT_NAME = "\$(TARGET_NAME)";');
    if (buildType == 'Debug') {
      sb.writeln('\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;');
      sb.writeln('\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";');
    }
    sb.writeln('\t\t\t\tSWIFT_VERSION = 5.0;');
    sb.writeln(
      '\t\t\t\tTEST_HOST = "\$(BUILT_PRODUCTS_DIR)/Runner.app/\$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Runner";',
    );
    sb.writeln('\t\t\t};');
    sb.writeln('\t\t\tname = "$name";');
    sb.writeln('\t\t};');
    return sb.toString();
  }

  // ────────────────── 빌드 구성 삽입 (flavor별 생성 + 섹션에 삽입) ──────────────

  /// Runner 타겟의 flavor별 XCBuildConfiguration 블록을 생성하고 섹션에 삽입합니다.
  static String _insertRunnerConfigs(
    String content,
    Map<String, FlavorConfig> flavors,
    Map<String, _FlavorUuids> flavorUuids,
  ) {
    final sb = StringBuffer();
    for (final entry in flavors.entries) {
      final flavor = entry.key;
      final config = entry.value;
      final uuids = flavorUuids[flavor]!;
      final teamId = config.ios?.teamId;
      final appIconName =
          config.appIcon != null ? 'AppIcon-$flavor' : null;

      for (final buildType in ['Debug', 'Release', 'Profile']) {
        final configUuid = buildType == 'Debug'
            ? uuids.debugRunnerConfig
            : buildType == 'Release'
                ? uuids.releaseRunnerConfig
                : uuids.profileRunnerConfig;
        final fileRefUuid = buildType == 'Debug'
            ? uuids.debugFileRef
            : buildType == 'Release'
                ? uuids.releaseFileRef
                : uuids.profileFileRef;
        final configName = '$buildType-$flavor';

        sb.write(_generateRunnerConfigBlock(
          uuid: configUuid,
          name: configName,
          bundleId: config.bundleId,
          xcconfigRefUuid: fileRefUuid,
          xcconfigName: '$configName.xcconfig',
          buildType: buildType,
          teamId: teamId,
          appIconName: appIconName,
        ));
      }
    }

    if (sb.isEmpty) return content;
    return content.replaceFirst(
      '/* End XCBuildConfiguration section */',
      '${sb.toString()}/* End XCBuildConfiguration section */',
    );
  }

  /// Project 레벨의 flavor별 XCBuildConfiguration 블록을 생성하고 섹션에 삽입합니다.
  static String _insertProjectConfigs(
    String content,
    Map<String, FlavorConfig> flavors,
    Map<String, _FlavorUuids> flavorUuids,
  ) {
    final sb = StringBuffer();
    for (final entry in flavors.entries) {
      final flavor = entry.key;
      final uuids = flavorUuids[flavor]!;

      for (final buildType in ['Debug', 'Release', 'Profile']) {
        final configUuid = buildType == 'Debug'
            ? uuids.debugProjectConfig
            : buildType == 'Release'
                ? uuids.releaseProjectConfig
                : uuids.profileProjectConfig;

        sb.write(_generateProjectConfigBlock(
          uuid: configUuid,
          name: '$buildType-$flavor',
          buildType: buildType,
        ));
      }
    }

    if (sb.isEmpty) return content;
    return content.replaceFirst(
      '/* End XCBuildConfiguration section */',
      '${sb.toString()}/* End XCBuildConfiguration section */',
    );
  }

  /// RunnerTests 타겟의 flavor별 XCBuildConfiguration 블록을 생성하고 섹션에 삽입합니다.
  static String _insertRunnerTestsConfigs(
    String content,
    Map<String, FlavorConfig> flavors,
    Map<String, _FlavorUuids> flavorUuids,
    String testBundleId,
  ) {
    final sb = StringBuffer();
    for (final entry in flavors.entries) {
      final flavor = entry.key;
      final uuids = flavorUuids[flavor]!;

      for (final buildType in ['Debug', 'Release', 'Profile']) {
        final configUuid = buildType == 'Debug'
            ? uuids.debugRunnerTestsConfig
            : buildType == 'Release'
                ? uuids.releaseRunnerTestsConfig
                : uuids.profileRunnerTestsConfig;

        sb.write(_generateRunnerTestsConfigBlock(
          uuid: configUuid,
          name: '$buildType-$flavor',
          testBundleId: testBundleId,
          buildType: buildType,
        ));
      }
    }

    if (sb.isEmpty) return content;
    return content.replaceFirst(
      '/* End XCBuildConfiguration section */',
      '${sb.toString()}/* End XCBuildConfiguration section */',
    );
  }

  // ──────────────────────────── PBXFileReference / PBXGroup ─────────────────

  /// PBXFileReference 섹션 끝에 flavor xcconfig 파일 참조를 삽입합니다.
  ///
  /// 각 flavor마다 Debug/Release/Profile 3개의 참조를 추가합니다.
  static String _addFileReferences(
    String content,
    Map<String, FlavorConfig> flavors,
    Map<String, _FlavorUuids> flavorUuids,
  ) {
    final sb = StringBuffer();
    for (final entry in flavors.entries) {
      final flavor = entry.key;
      final uuids = flavorUuids[flavor]!;
      sb.writeln(
        '\t\t${uuids.debugFileRef} /* Debug-$flavor.xcconfig */ = '
        '{isa = PBXFileReference; lastKnownFileType = text.xcconfig; '
        'name = "Debug-$flavor.xcconfig"; '
        'path = "Flutter/Debug-$flavor.xcconfig"; '
        'sourceTree = "<group>"; };',
      );
      sb.writeln(
        '\t\t${uuids.releaseFileRef} /* Release-$flavor.xcconfig */ = '
        '{isa = PBXFileReference; lastKnownFileType = text.xcconfig; '
        'name = "Release-$flavor.xcconfig"; '
        'path = "Flutter/Release-$flavor.xcconfig"; '
        'sourceTree = "<group>"; };',
      );
      sb.writeln(
        '\t\t${uuids.profileFileRef} /* Profile-$flavor.xcconfig */ = '
        '{isa = PBXFileReference; lastKnownFileType = text.xcconfig; '
        'name = "Profile-$flavor.xcconfig"; '
        'path = "Flutter/Profile-$flavor.xcconfig"; '
        'sourceTree = "<group>"; };',
      );
    }
    // "/* End PBXFileReference section */" 마커 직전에 삽입
    return content.replaceFirst(
      '/* End PBXFileReference section */',
      '${sb.toString()}/* End PBXFileReference section */',
    );
  }

  /// Flutter PBXGroup의 children 배열에 xcconfig 파일 참조를 추가합니다.
  static String _addToFlutterGroup(
    String content,
    String flutterGroupUuid,
    Map<String, FlavorConfig> flavors,
    Map<String, _FlavorUuids> flavorUuids,
  ) {
    final groupStart = content.indexOf('$flutterGroupUuid /* Flutter */ = {');
    if (groupStart == -1) return content;
    final braceStart = content.indexOf('{', groupStart);
    if (braceStart == -1) return content;
    final blockEnd = _findBlockEnd(content, braceStart);
    if (blockEnd == -1) return content;

    // children = ( ... ); 블록의 닫는 ); 위치를 찾음
    final childrenStart = content.indexOf('children = (', groupStart);
    if (childrenStart == -1 || childrenStart > blockEnd) return content;
    final childrenEnd = content.indexOf(');', childrenStart);
    if (childrenEnd == -1 || childrenEnd > blockEnd) return content;

    final sb = StringBuffer();
    for (final entry in flavors.entries) {
      final flavor = entry.key;
      final uuids = flavorUuids[flavor]!;
      sb.writeln(
        '\t\t\t\t${uuids.debugFileRef} /* Debug-$flavor.xcconfig */,',
      );
      sb.writeln(
        '\t\t\t\t${uuids.releaseFileRef} /* Release-$flavor.xcconfig */,',
      );
      sb.writeln(
        '\t\t\t\t${uuids.profileFileRef} /* Profile-$flavor.xcconfig */,',
      );
    }

    // ); 직전에 새 항목들을 삽입
    return content.substring(0, childrenEnd) +
        sb.toString() +
        content.substring(childrenEnd);
  }

  // ──────────────────────────── XCConfigurationList ──────────────────────────

  /// XCConfigurationList의 buildConfigurations 배열에 새 빌드 구성 UUID를 추가합니다.
  ///
  /// [isRunner]가 true이면 Runner 타겟용 UUID를, false이면 Project 레벨 UUID를 사용합니다.
  static String _addToConfigList(
    String content,
    String listUuid,
    Map<String, FlavorConfig> flavors,
    Map<String, _FlavorUuids> flavorUuids, {
    required bool isRunner,
  }) {
    // 정의 라인(`UUID /* ... */ = {`)을 찾음
    final defMatch = RegExp(
      RegExp.escape(listUuid) + r' /\*[^*]*\*/ = \{',
    ).firstMatch(content);
    if (defMatch == null) return content;
    final listStart = defMatch.start;
    final braceStart = defMatch.end - 1;
    final blockEnd = _findBlockEnd(content, braceStart);
    if (blockEnd == -1) return content;

    // buildConfigurations = ( ... ); 의 닫는 ); 위치를 찾음
    final configsStart =
        content.indexOf('buildConfigurations = (', listStart);
    if (configsStart == -1 || configsStart > blockEnd) return content;
    final configsEnd = content.indexOf(');', configsStart);
    if (configsEnd == -1 || configsEnd > blockEnd) return content;

    final sb = StringBuffer();
    for (final entry in flavors.entries) {
      final flavor = entry.key;
      final uuids = flavorUuids[flavor]!;
      if (isRunner) {
        sb.writeln(
          '\t\t\t\t${uuids.debugRunnerConfig} /* Debug-$flavor */,',
        );
        sb.writeln(
          '\t\t\t\t${uuids.releaseRunnerConfig} /* Release-$flavor */,',
        );
        sb.writeln(
          '\t\t\t\t${uuids.profileRunnerConfig} /* Profile-$flavor */,',
        );
      } else {
        sb.writeln(
          '\t\t\t\t${uuids.debugProjectConfig} /* Debug-$flavor */,',
        );
        sb.writeln(
          '\t\t\t\t${uuids.releaseProjectConfig} /* Release-$flavor */,',
        );
        sb.writeln(
          '\t\t\t\t${uuids.profileProjectConfig} /* Profile-$flavor */,',
        );
      }
    }

    // ); 직전에 새 항목들을 삽입
    return content.substring(0, configsEnd) +
        sb.toString() +
        content.substring(configsEnd);
  }

  /// 범용 XCConfigurationList UUID 등록 메서드입니다.
  ///
  /// [uuidSelector]로 각 buildType에 맞는 UUID를 선택합니다.
  static String _addToConfigListGeneric(
    String content,
    String listUuid,
    Map<String, FlavorConfig> flavors,
    Map<String, _FlavorUuids> flavorUuids, {
    required String Function(_FlavorUuids uuids, String buildType)
        uuidSelector,
  }) {
    final defMatch = RegExp(
      RegExp.escape(listUuid) + r' /\*[^*]*\*/ = \{',
    ).firstMatch(content);
    if (defMatch == null) return content;
    final listStart = defMatch.start;
    final braceStart = defMatch.end - 1;
    final blockEnd = _findBlockEnd(content, braceStart);
    if (blockEnd == -1) return content;

    final configsStart =
        content.indexOf('buildConfigurations = (', listStart);
    if (configsStart == -1 || configsStart > blockEnd) return content;
    final configsEnd = content.indexOf(');', configsStart);
    if (configsEnd == -1 || configsEnd > blockEnd) return content;

    final sb = StringBuffer();
    for (final entry in flavors.entries) {
      final flavor = entry.key;
      final uuids = flavorUuids[flavor]!;
      for (final buildType in ['Debug', 'Release', 'Profile']) {
        final uuid = uuidSelector(uuids, buildType);
        sb.writeln('\t\t\t\t$uuid /* $buildType-$flavor */,');
      }
    }

    return content.substring(0, configsEnd) +
        sb.toString() +
        content.substring(configsEnd);
  }

  // ──────────────────────────── UUID 추출 메서드 ────────────────────────────

  /// pbxproj에서 Runner PBXNativeTarget의 24자리 UUID를 추출합니다.
  static String _extractRunnerTargetUuid(String content) {
    return _extractNativeTargetUuid(content, 'Runner');
  }

  /// pbxproj에서 지정된 이름의 PBXNativeTarget UUID를 추출합니다.
  static String _extractNativeTargetUuid(String content, String targetName) {
    final matches = RegExp(
      r'([0-9A-F]{24}) /\* ' + RegExp.escape(targetName) + r' \*/ = \{',
    ).allMatches(content);
    for (final m in matches) {
      final snippet = content.substring(m.start, m.start + 300);
      if (snippet.contains('isa = PBXNativeTarget')) return m.group(1)!;
    }
    return '';
  }

  /// pbxproj에서 Flutter PBXGroup의 UUID를 추출합니다.
  static String _extractFlutterGroupUuid(String content) {
    final matches =
        RegExp(r'([0-9A-F]{24}) /\* Flutter \*/ = \{').allMatches(content);
    for (final m in matches) {
      final snippet = content.substring(m.start, m.start + 500);
      if (snippet.contains('isa = PBXGroup')) return m.group(1)!;
    }
    return '';
  }

  /// 특정 타겟의 buildConfigurationList UUID를 추출합니다.
  static String _extractBuildConfigListForTarget(
    String content,
    String targetUuid, [
    String targetName = 'Runner',
  ]) {
    final targetStart = content.indexOf('$targetUuid /* $targetName */ = {');
    if (targetStart == -1) return '';
    final braceStart = content.indexOf('{', targetStart);
    if (braceStart == -1) return '';
    final blockEnd = _findBlockEnd(content, braceStart);
    if (blockEnd == -1) return '';

    final block = content.substring(targetStart, blockEnd + 1);
    final match =
        RegExp(r'buildConfigurationList = ([0-9A-F]{24})').firstMatch(block);
    return match?.group(1) ?? '';
  }

  /// PBXProject "Runner"의 buildConfigurationList UUID를 추출합니다.
  static String _extractProjectConfigListUuid(String content) {
    final match = RegExp(
      r'([0-9A-F]{24}) /\* Build configuration list for PBXProject "Runner" \*/',
    ).firstMatch(content);
    return match?.group(1) ?? '';
  }

  /// XCConfigurationList 내의 모든 빌드 구성 UUID를 추출합니다 (이름 제한 없음).
  ///
  /// 반환값: {configName: uuid} 형태의 맵
  static Map<String, String> _extractAllConfigsFromList(
    String content,
    String listUuid,
  ) {
    final defMatch = RegExp(
      RegExp.escape(listUuid) + r' /\*[^*]*\*/ = \{',
    ).firstMatch(content);
    if (defMatch == null) return {};
    final braceStart = defMatch.end - 1;
    final blockEnd = _findBlockEnd(content, braceStart);
    if (blockEnd == -1) return {};

    final block = content.substring(defMatch.start, blockEnd + 1);
    final result = <String, String>{};
    final matches =
        RegExp(r'([0-9A-F]{24}) /\* ([^*]+) \*/').allMatches(block);
    for (final m in matches) {
      result[m.group(2)!.trim()] = m.group(1)!;
    }
    return result;
  }

  /// RunnerTests 타겟의 PRODUCT_BUNDLE_IDENTIFIER를 추출합니다.
  ///
  /// TEST_HOST를 포함하는 XCBuildConfiguration 블록에서 번들 ID를 찾습니다.
  static String _extractTestBundleId(String content) {
    final matches = RegExp(
      r'([0-9A-F]{24}) /\* (?:Debug|Release|Profile)(?:-\w+)? \*/ = \{',
    ).allMatches(content);
    for (final m in matches) {
      final block = _extractXCBuildConfigBlock(content, m.group(1)!);
      if (block.isEmpty) continue;
      if (!block.contains('isa = XCBuildConfiguration')) continue;
      if (!block.contains('TEST_HOST')) continue;

      final bundleIdMatch = RegExp(
        r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*"?([^";]+)"?\s*;',
      ).firstMatch(block);
      if (bundleIdMatch != null) return bundleIdMatch.group(1)!;
    }
    return '';
  }

  // ──────────────────────────── 블록 탐색 헬퍼 ───────────────────────────────

  /// 중괄호 깊이를 추적하여 짝이 맞는 닫는 중괄호의 인덱스를 반환합니다.
  static int _findBlockEnd(String content, int openBraceIndex) {
    int depth = 0;
    for (int i = openBraceIndex; i < content.length; i++) {
      final ch = content[i];
      if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  /// 단일 XCBuildConfiguration 블록 전체를 문자열로 추출합니다.
  ///
  /// UUID로 시작하는 줄부터 `};` 이후 개행까지를 반환합니다.
  static String _extractXCBuildConfigBlock(String content, String uuid) {
    final startStr = '\t\t$uuid /*';
    final startIdx = content.indexOf(startStr);
    if (startIdx == -1) return '';
    final braceStart = content.indexOf('{', startIdx);
    if (braceStart == -1) return '';
    final blockEnd = _findBlockEnd(content, braceStart);
    if (blockEnd == -1) return '';

    // `};` 뒤의 개행까지 포함
    final lineEnd = content.indexOf('\n', blockEnd);
    final end = lineEnd == -1 ? blockEnd + 1 : lineEnd + 1;
    return content.substring(startIdx, end);
  }
}

// ──────────────────────────── 내부 데이터 클래스 ─────────────────────────────

/// 하나의 flavor에 대해 필요한 UUID를 묶어 관리하는 내부 클래스입니다.
///
/// - 파일 참조 UUID 3개: Debug/Release/Profile xcconfig 파일의 PBXFileReference
/// - Runner 빌드 구성 UUID 3개: Runner 타겟의 XCBuildConfiguration
/// - Project 빌드 구성 UUID 3개: Project 레벨의 XCBuildConfiguration
/// - RunnerTests 빌드 구성 UUID 3개: RunnerTests 타겟의 XCBuildConfiguration
class _FlavorUuids {
  final String debugFileRef;
  final String releaseFileRef;
  final String profileFileRef;
  final String debugRunnerConfig;
  final String releaseRunnerConfig;
  final String profileRunnerConfig;
  final String debugProjectConfig;
  final String releaseProjectConfig;
  final String profileProjectConfig;
  final String debugRunnerTestsConfig;
  final String releaseRunnerTestsConfig;
  final String profileRunnerTestsConfig;

  const _FlavorUuids({
    required this.debugFileRef,
    required this.releaseFileRef,
    required this.profileFileRef,
    required this.debugRunnerConfig,
    required this.releaseRunnerConfig,
    required this.profileRunnerConfig,
    required this.debugProjectConfig,
    required this.releaseProjectConfig,
    required this.profileProjectConfig,
    required this.debugRunnerTestsConfig,
    required this.releaseRunnerTestsConfig,
    required this.profileRunnerTestsConfig,
  });
}
