import 'dart:io';

import 'package:easy_setup/src/ios/pbxproj_modifier.dart';
import 'package:easy_setup/easy_setup.dart';
import 'package:test/test.dart';

/// Minimal project.pbxproj fixture with the essential structure.
///
/// Sections follow the standard alphabetical order used by real Xcode
/// projects (PBXNativeTarget before XCBuildConfiguration/XCConfigurationList).
///
/// UUIDs used:
///   Debug.xcconfig file ref   : 9740EEB21CF90195004384FC
///   Release.xcconfig file ref : 7AFA3C8E1D35360C0083082E
///   Flutter PBXGroup          : 9740EEB11CF90186004384FC
///   Runner PBXNativeTarget    : 97C146ED1CF9000F007C117D
///   Project config list       : 97C146E91CF9000F007C117D
///   Runner config list        : 97C147051CF9000F007C117D
///   Project-level Debug       : 97C147031CF9000F007C117D
///   Project-level Release     : 97C147041CF9000F007C117D
///   Project-level Profile     : 249021D3217E4FDB00AE95B9
///   Runner-level Debug        : 97C147061CF9000F007C117D
///   Runner-level Release      : 97C147071CF9000F007C117D
///   Runner-level Profile      : 249021D4217E4FDB00AE95B9
const _minimalPbxproj = '// !\$*UTF8*\$!\n'
    '{\n'
    '\tarchiveVersion = 1;\n'
    '\tobjectVersion = 54;\n'
    '\tobjects = {\n'
    '\n'
    '/* Begin PBXFileReference section */\n'
    '\t\t9740EEB21CF90195004384FC /* Debug.xcconfig */ = {isa = PBXFileReference; lastKnownFileType = text.xcconfig; name = "Debug.xcconfig"; path = "Flutter/Debug.xcconfig"; sourceTree = "<group>"; };\n'
    '\t\t7AFA3C8E1D35360C0083082E /* Release.xcconfig */ = {isa = PBXFileReference; lastKnownFileType = text.xcconfig; name = "Release.xcconfig"; path = "Flutter/Release.xcconfig"; sourceTree = "<group>"; };\n'
    '/* End PBXFileReference section */\n'
    '\n'
    '/* Begin PBXGroup section */\n'
    '\t\t9740EEB11CF90186004384FC /* Flutter */ = {\n'
    '\t\t\tisa = PBXGroup;\n'
    '\t\t\tchildren = (\n'
    '\t\t\t\t9740EEB21CF90195004384FC /* Debug.xcconfig */,\n'
    '\t\t\t\t7AFA3C8E1D35360C0083082E /* Release.xcconfig */,\n'
    '\t\t\t);\n'
    '\t\t\tname = Flutter;\n'
    '\t\t\tsourceTree = "<group>";\n'
    '\t\t};\n'
    '/* End PBXGroup section */\n'
    '\n'
    '/* Begin PBXNativeTarget section */\n'
    '\t\t97C146ED1CF9000F007C117D /* Runner */ = {\n'
    '\t\t\tisa = PBXNativeTarget;\n'
    '\t\t\tbuildConfigurationList = 97C147051CF9000F007C117D /* Build configuration list for PBXNativeTarget "Runner" */;\n'
    '\t\t\tbuildPhases = (\n'
    '\t\t\t);\n'
    '\t\t\tbuildRules = (\n'
    '\t\t\t);\n'
    '\t\t\tdependencies = (\n'
    '\t\t\t);\n'
    '\t\t\tname = Runner;\n'
    '\t\t\tproductName = Runner;\n'
    '\t\t\tproductReference = 97C146EE1CF9000F007C117D /* Runner.app */;\n'
    '\t\t\tproductType = "com.apple.product-type.application";\n'
    '\t\t};\n'
    '/* End PBXNativeTarget section */\n'
    '\n'
    '/* Begin XCBuildConfiguration section */\n'
    '\t\t97C147031CF9000F007C117D /* Debug */ = {\n'
    '\t\t\tisa = XCBuildConfiguration;\n'
    '\t\t\tbuildSettings = {\n'
    '\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;\n'
    '\t\t\t};\n'
    '\t\t\tname = Debug;\n'
    '\t\t};\n'
    '\t\t97C147041CF9000F007C117D /* Release */ = {\n'
    '\t\t\tisa = XCBuildConfiguration;\n'
    '\t\t\tbuildSettings = {\n'
    '\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;\n'
    '\t\t\t};\n'
    '\t\t\tname = Release;\n'
    '\t\t};\n'
    '\t\t249021D3217E4FDB00AE95B9 /* Profile */ = {\n'
    '\t\t\tisa = XCBuildConfiguration;\n'
    '\t\t\tbuildSettings = {\n'
    '\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;\n'
    '\t\t\t};\n'
    '\t\t\tname = Profile;\n'
    '\t\t};\n'
    '\t\t97C147061CF9000F007C117D /* Debug */ = {\n'
    '\t\t\tisa = XCBuildConfiguration;\n'
    '\t\t\tbaseConfigurationReference = 9740EEB21CF90195004384FC /* Debug.xcconfig */;\n'
    '\t\t\tbuildSettings = {\n'
    '\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;\n'
    '\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.example.runner;\n'
    '\t\t\t};\n'
    '\t\t\tname = Debug;\n'
    '\t\t};\n'
    '\t\t97C147071CF9000F007C117D /* Release */ = {\n'
    '\t\t\tisa = XCBuildConfiguration;\n'
    '\t\t\tbaseConfigurationReference = 7AFA3C8E1D35360C0083082E /* Release.xcconfig */;\n'
    '\t\t\tbuildSettings = {\n'
    '\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;\n'
    '\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.example.runner;\n'
    '\t\t\t};\n'
    '\t\t\tname = Release;\n'
    '\t\t};\n'
    '\t\t249021D4217E4FDB00AE95B9 /* Profile */ = {\n'
    '\t\t\tisa = XCBuildConfiguration;\n'
    '\t\t\tbaseConfigurationReference = 7AFA3C8E1D35360C0083082E /* Release.xcconfig */;\n'
    '\t\t\tbuildSettings = {\n'
    '\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;\n'
    '\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.example.runner;\n'
    '\t\t\t};\n'
    '\t\t\tname = Profile;\n'
    '\t\t};\n'
    '/* End XCBuildConfiguration section */\n'
    '\n'
    '/* Begin XCConfigurationList section */\n'
    '\t\t97C146E91CF9000F007C117D /* Build configuration list for PBXProject "Runner" */ = {\n'
    '\t\t\tisa = XCConfigurationList;\n'
    '\t\t\tbuildConfigurations = (\n'
    '\t\t\t\t97C147031CF9000F007C117D /* Debug */,\n'
    '\t\t\t\t97C147041CF9000F007C117D /* Release */,\n'
    '\t\t\t\t249021D3217E4FDB00AE95B9 /* Profile */,\n'
    '\t\t\t);\n'
    '\t\t\tdefaultConfigurationIsVisible = 0;\n'
    '\t\t\tdefaultConfigurationName = Release;\n'
    '\t\t};\n'
    '\t\t97C147051CF9000F007C117D /* Build configuration list for PBXNativeTarget "Runner" */ = {\n'
    '\t\t\tisa = XCConfigurationList;\n'
    '\t\t\tbuildConfigurations = (\n'
    '\t\t\t\t97C147061CF9000F007C117D /* Debug */,\n'
    '\t\t\t\t97C147071CF9000F007C117D /* Release */,\n'
    '\t\t\t\t249021D4217E4FDB00AE95B9 /* Profile */,\n'
    '\t\t\t);\n'
    '\t\t\tdefaultConfigurationIsVisible = 0;\n'
    '\t\t\tdefaultConfigurationName = Release;\n'
    '\t\t};\n'
    '/* End XCConfigurationList section */\n'
    '\t};\n'
    '\trootObject = 97C146E61CF9000F007C117D /* Project object */;\n'
    '}\n';

/// Fixture with RunnerTests target included.
///
/// Additional UUIDs:
///   RunnerTests PBXNativeTarget : 331C8080294A63A400263BE5
///   RunnerTests config list     : 331C8087294A63A400263BE5
///   RunnerTests Debug           : 331C8088294A63A400263BE5
///   RunnerTests Release         : 331C8089294A63A400263BE5
///   RunnerTests Profile         : 331C808A294A63A400263BE5
final _pbxprojWithRunnerTests = _minimalPbxproj
    // PBXNativeTarget 섹션에 RunnerTests 추가
    .replaceFirst(
      '/* End PBXNativeTarget section */\n',
      '\t\t331C8080294A63A400263BE5 /* RunnerTests */ = {\n'
      '\t\t\tisa = PBXNativeTarget;\n'
      '\t\t\tbuildConfigurationList = 331C8087294A63A400263BE5 /* Build configuration list for PBXNativeTarget "RunnerTests" */;\n'
      '\t\t\tbuildPhases = (\n'
      '\t\t\t);\n'
      '\t\t\tbuildRules = (\n'
      '\t\t\t);\n'
      '\t\t\tdependencies = (\n'
      '\t\t\t);\n'
      '\t\t\tname = RunnerTests;\n'
      '\t\t\tproductName = RunnerTests;\n'
      '\t\t\tproductType = "com.apple.product-type.bundle.unit-test";\n'
      '\t\t};\n'
      '/* End PBXNativeTarget section */\n',
    )
    // XCBuildConfiguration 섹션에 RunnerTests 구성 추가 (Runner 구성 앞에)
    .replaceFirst(
      '/* Begin XCBuildConfiguration section */\n',
      '/* Begin XCBuildConfiguration section */\n'
      '\t\t331C8088294A63A400263BE5 /* Debug */ = {\n'
      '\t\t\tisa = XCBuildConfiguration;\n'
      '\t\t\tbuildSettings = {\n'
      '\t\t\t\tBUNDLE_LOADER = "\$(TEST_HOST)";\n'
      '\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.example.runner.RunnerTests;\n'
      '\t\t\t\tTEST_HOST = "\$(BUILT_PRODUCTS_DIR)/Runner.app/\$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Runner";\n'
      '\t\t\t};\n'
      '\t\t\tname = Debug;\n'
      '\t\t};\n'
      '\t\t331C8089294A63A400263BE5 /* Release */ = {\n'
      '\t\t\tisa = XCBuildConfiguration;\n'
      '\t\t\tbuildSettings = {\n'
      '\t\t\t\tBUNDLE_LOADER = "\$(TEST_HOST)";\n'
      '\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.example.runner.RunnerTests;\n'
      '\t\t\t\tTEST_HOST = "\$(BUILT_PRODUCTS_DIR)/Runner.app/\$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Runner";\n'
      '\t\t\t};\n'
      '\t\t\tname = Release;\n'
      '\t\t};\n'
      '\t\t331C808A294A63A400263BE5 /* Profile */ = {\n'
      '\t\t\tisa = XCBuildConfiguration;\n'
      '\t\t\tbuildSettings = {\n'
      '\t\t\t\tBUNDLE_LOADER = "\$(TEST_HOST)";\n'
      '\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.example.runner.RunnerTests;\n'
      '\t\t\t\tTEST_HOST = "\$(BUILT_PRODUCTS_DIR)/Runner.app/\$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Runner";\n'
      '\t\t\t};\n'
      '\t\t\tname = Profile;\n'
      '\t\t};\n',
    )
    // XCConfigurationList 섹션에 RunnerTests 구성 목록 추가
    .replaceFirst(
      '/* End XCConfigurationList section */\n',
      '\t\t331C8087294A63A400263BE5 /* Build configuration list for PBXNativeTarget "RunnerTests" */ = {\n'
      '\t\t\tisa = XCConfigurationList;\n'
      '\t\t\tbuildConfigurations = (\n'
      '\t\t\t\t331C8088294A63A400263BE5 /* Debug */,\n'
      '\t\t\t\t331C8089294A63A400263BE5 /* Release */,\n'
      '\t\t\t\t331C808A294A63A400263BE5 /* Profile */,\n'
      '\t\t\t);\n'
      '\t\t\tdefaultConfigurationIsVisible = 0;\n'
      '\t\t\tdefaultConfigurationName = Release;\n'
      '\t\t};\n'
      '/* End XCConfigurationList section */\n',
    );

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('pbxproj_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  final flavors = {
    'dev': const FlavorConfig(bundleId: 'com.example.app.dev', name: 'MyApp Dev'),
    'prod': const FlavorConfig(bundleId: 'com.example.app', name: 'MyApp'),
  };

  group('PbxprojModifier', () {
    test('adds flavor build configurations to pbxproj', () {
      final file = File('${tempDir.path}/project.pbxproj');
      file.writeAsStringSync(_minimalPbxproj);

      final uuid = PbxprojModifier.modify(file.path, flavors);
      final result = file.readAsStringSync();

      // Returns Runner target UUID
      expect(uuid, '97C146ED1CF9000F007C117D');

      // Debug/Release/Profile for each flavor
      expect(result, contains('Debug-dev'));
      expect(result, contains('Release-dev'));
      expect(result, contains('Profile-dev'));
      expect(result, contains('Debug-prod'));
      expect(result, contains('Release-prod'));
      expect(result, contains('Profile-prod'));
    });

    test('adds PBXFileReference entries for flavor xcconfigs', () {
      final file = File('${tempDir.path}/project.pbxproj');
      file.writeAsStringSync(_minimalPbxproj);

      PbxprojModifier.modify(file.path, flavors);
      final result = file.readAsStringSync();

      expect(result, contains('Debug-dev.xcconfig'));
      expect(result, contains('Release-dev.xcconfig'));
      expect(result, contains('Profile-dev.xcconfig'));
      expect(result, contains('Debug-prod.xcconfig'));
      expect(result, contains('Release-prod.xcconfig'));
      expect(result, contains('Profile-prod.xcconfig'));
      // File references should be before the end marker
      expect(result, contains('/* End PBXFileReference section */'));
    });

    test('adds xcconfig references to Flutter PBXGroup children', () {
      final file = File('${tempDir.path}/project.pbxproj');
      file.writeAsStringSync(_minimalPbxproj);

      PbxprojModifier.modify(file.path, flavors);
      final result = file.readAsStringSync();

      // Extract the Flutter group block
      final flutterGroupStart = result.indexOf('9740EEB11CF90186004384FC /* Flutter */');
      final childrenStart = result.indexOf('children = (', flutterGroupStart);
      final childrenEnd = result.indexOf(');', childrenStart);
      final childrenBlock = result.substring(childrenStart, childrenEnd);

      expect(childrenBlock, contains('Debug-dev.xcconfig'));
      expect(childrenBlock, contains('Release-dev.xcconfig'));
      expect(childrenBlock, contains('Profile-dev.xcconfig'));
    });

    test('adds new UUIDs to XCConfigurationList buildConfigurations', () {
      final file = File('${tempDir.path}/project.pbxproj');
      file.writeAsStringSync(_minimalPbxproj);

      PbxprojModifier.modify(file.path, flavors);
      final result = file.readAsStringSync();

      // Runner config list: search for the entry definition (with ` = {`)
      final runnerListStart = result.indexOf(
        '97C147051CF9000F007C117D /* Build configuration list for PBXNativeTarget "Runner" */ = {',
      );
      expect(runnerListStart, isNot(-1));
      final runnerListEnd = result.indexOf('};', runnerListStart);
      final runnerListBlock = result.substring(runnerListStart, runnerListEnd);

      expect(runnerListBlock, contains('Debug-dev'));
      expect(runnerListBlock, contains('Release-dev'));
      expect(runnerListBlock, contains('Profile-dev'));

      // Project config list
      final projListStart = result.indexOf(
        '97C146E91CF9000F007C117D /* Build configuration list for PBXProject "Runner" */ = {',
      );
      expect(projListStart, isNot(-1));
      final projListEnd = result.indexOf('};', projListStart);
      final projListBlock = result.substring(projListStart, projListEnd);

      expect(projListBlock, contains('Debug-dev'));
      expect(projListBlock, contains('Release-dev'));
      expect(projListBlock, contains('Profile-dev'));
    });

    test('cloned Runner configs have correct bundle IDs', () {
      final file = File('${tempDir.path}/project.pbxproj');
      file.writeAsStringSync(_minimalPbxproj);

      PbxprojModifier.modify(file.path, {'dev': const FlavorConfig(bundleId: 'com.example.app.dev', name: 'Dev')});
      final result = file.readAsStringSync();

      // Find a Debug-dev config that has PRODUCT_BUNDLE_IDENTIFIER (Runner-level clone)
      final pattern = RegExp(
        r'/\* Debug-dev \*/ = \{[^}]*PRODUCT_BUNDLE_IDENTIFIER[^}]*\}',
        dotAll: true,
      );
      final match = pattern.firstMatch(result);
      expect(match, isNotNull, reason: 'Should find a Debug-dev config with PRODUCT_BUNDLE_IDENTIFIER');
      expect(match!.group(0), contains('PRODUCT_BUNDLE_IDENTIFIER = com.example.app.dev;'));
    });

    test('returns Runner target UUID', () {
      final file = File('${tempDir.path}/project.pbxproj');
      file.writeAsStringSync(_minimalPbxproj);

      final uuid = PbxprojModifier.modify(file.path, flavors);
      expect(uuid, '97C146ED1CF9000F007C117D');
    });

    test('overwrites existing flavor configs on second run', () {
      final file = File('${tempDir.path}/project.pbxproj');
      file.writeAsStringSync(_minimalPbxproj);

      PbxprojModifier.modify(file.path, flavors);
      final afterFirst = file.readAsStringSync();

      final uuid = PbxprojModifier.modify(file.path, flavors);
      final afterSecond = file.readAsStringSync();

      // UUID는 매번 새로 생성되므로 정확한 일치 대신 구조적 동일성 검증
      expect(afterSecond, contains('Debug-dev'));
      expect(afterSecond, contains('Release-dev'));
      expect(afterSecond, contains('Debug-prod'));
      expect(afterSecond, contains('Release-prod'));
      // 중복이 없는지 확인
      expect('Debug-dev'.allMatches(afterFirst).length,
             'Debug-dev'.allMatches(afterSecond).length);
      expect(uuid, '97C146ED1CF9000F007C117D');
    });

    test('clones RunnerTests configurations for each flavor', () {
      final file = File('${tempDir.path}/project.pbxproj');
      file.writeAsStringSync(_pbxprojWithRunnerTests);

      PbxprojModifier.modify(file.path, flavors);
      final result = file.readAsStringSync();

      // RunnerTests config list should have flavor configs
      final rtListStart = result.indexOf(
        '331C8087294A63A400263BE5 /* Build configuration list for PBXNativeTarget "RunnerTests" */ = {',
      );
      expect(rtListStart, isNot(-1));
      final rtListEnd = result.indexOf('};', rtListStart);
      final rtListBlock = result.substring(rtListStart, rtListEnd);

      expect(rtListBlock, contains('Debug-dev'));
      expect(rtListBlock, contains('Release-dev'));
      expect(rtListBlock, contains('Profile-dev'));
      expect(rtListBlock, contains('Debug-prod'));
      expect(rtListBlock, contains('Release-prod'));
      expect(rtListBlock, contains('Profile-prod'));

      // Base configs should be removed from RunnerTests config list
      expect(rtListBlock, isNot(contains('331C8088294A63A400263BE5')));
      expect(rtListBlock, isNot(contains('331C8089294A63A400263BE5')));
      expect(rtListBlock, isNot(contains('331C808A294A63A400263BE5')));
    });

    test('RunnerTests flavor configs are idempotent on second run', () {
      final file = File('${tempDir.path}/project.pbxproj');
      file.writeAsStringSync(_pbxprojWithRunnerTests);

      PbxprojModifier.modify(file.path, flavors);
      final afterFirst = file.readAsStringSync();
      final firstCount = 'Debug-dev'.allMatches(afterFirst).length;

      PbxprojModifier.modify(file.path, flavors);
      final afterSecond = file.readAsStringSync();
      final secondCount = 'Debug-dev'.allMatches(afterSecond).length;

      expect(secondCount, firstCount);
    });

    test('throws SetupException when file does not exist', () {
      expect(
        () => PbxprojModifier.modify('${tempDir.path}/nonexistent.pbxproj', flavors),
        throwsA(isA<SetupException>()),
      );
    });

    test('does not modify file in dry-run mode but returns UUID', () {
      final file = File('${tempDir.path}/project.pbxproj');
      file.writeAsStringSync(_minimalPbxproj);

      final uuid = PbxprojModifier.modify(file.path, flavors, dryRun: true);

      expect(file.readAsStringSync(), _minimalPbxproj);
      expect(uuid, '97C146ED1CF9000F007C117D');
    });
  });
}
