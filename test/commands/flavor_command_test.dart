import 'dart:async';
import 'dart:io';

import 'package:easy_setup/easy_setup.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Minimal build.gradle fixture with buildTypes block.
const _buildGradle = '''
android {
    buildTypes {
        release {
            signingConfig signingConfigs.debug
        }
    }
}
''';

/// Minimal Info.plist fixture.
const _infoPlist = '''<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
\t<key>CFBundleName</key>
\t<string>Runner</string>
\t<key>CFBundleDisplayName</key>
\t<string>Runner</string>
</dict>
</plist>
''';

/// Minimal Podfile fixture with the Release marker.
const _podfile = '''
platform :ios, '12.0'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}
''';

/// Minimal project.pbxproj with standard alphabetical section ordering.
final _pbxproj = '// !\$*UTF8*\$!\n'
    '{\n'
    '\tarchiveVersion = 1;\n'
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

const _easySetupYaml = '''
easy_setup:
  flavors:
    dev:
      bundle_id: com.example.app.dev
      name: MyApp Dev
    prod:
      bundle_id: com.example.app
      name: MyApp
''';

const _easySetupYamlWithFirebase = '''
easy_setup:
  flavors:
    dev:
      bundle_id: com.example.app.dev
      name: MyApp Dev
      firebase:
        android: config/dev/google-services.json
        ios: config/dev/GoogleService-Info.plist
    prod:
      bundle_id: com.example.app
      name: MyApp
''';

/// Creates a minimal Flutter project directory structure for integration tests.
Directory _createFlutterProject(Directory parent, {String? yamlContent}) {
  final root = parent;

  // pubspec.yaml (Flutter project)
  File(p.join(root.path, 'pubspec.yaml')).writeAsStringSync('''
name: my_app
dependencies:
  flutter:
    sdk: flutter
''');

  // easy_setup.yaml
  File(p.join(root.path, 'easy_setup.yaml'))
      .writeAsStringSync(yamlContent ?? _easySetupYaml);

  // Android
  final androidAppDir = Directory(p.join(root.path, 'android', 'app'));
  androidAppDir.createSync(recursive: true);
  File(p.join(androidAppDir.path, 'build.gradle')).writeAsStringSync(_buildGradle);

  // iOS
  final flutterDir = Directory(p.join(root.path, 'ios', 'Flutter'));
  flutterDir.createSync(recursive: true);

  final pbxprojDir = Directory(p.join(root.path, 'ios', 'Runner.xcodeproj'));
  pbxprojDir.createSync(recursive: true);
  File(p.join(pbxprojDir.path, 'project.pbxproj')).writeAsStringSync(_pbxproj);

  final schemesDir = Directory(
    p.join(root.path, 'ios', 'Runner.xcodeproj', 'xcshareddata', 'xcschemes'),
  );
  schemesDir.createSync(recursive: true);

  final runnerDir = Directory(p.join(root.path, 'ios', 'Runner'));
  runnerDir.createSync(recursive: true);
  File(p.join(runnerDir.path, 'Info.plist')).writeAsStringSync(_infoPlist);

  File(p.join(root.path, 'ios', 'Podfile')).writeAsStringSync(_podfile);

  return root;
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('flavor_cmd_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('FlavorCommand', () {
    test('throws SetupException when Flutter root not found', () {
      // Use a temp dir that has no pubspec.yaml
      final emptyDir = Directory(p.join(tempDir.path, 'empty'));
      emptyDir.createSync();

      final saved = Directory.current;
      try {
        Directory.current = emptyDir;
        expect(
          () => FlavorCommand.run(),
          throwsA(
            isA<SetupException>().having(
              (e) => e.message,
              'message',
              contains('Could not find a Flutter project root'),
            ),
          ),
        );
      } finally {
        Directory.current = saved;
      }
    });

    test('throws SetupException when flavors are empty', () {
      File(p.join(tempDir.path, 'easy_setup.yaml'))
          .writeAsStringSync('easy_setup:\n  flavors:\n');

      // Provide valid YAML with empty flavors map — the YAML parser returns
      // null for the 'flavors' key which triggers a parse error.
      expect(
        () => FlavorCommand.run(projectRoot: tempDir.path),
        throwsA(isA<SetupException>()),
      );
    });

    test('dry-run does not modify any files', () {
      final root = _createFlutterProject(tempDir);

      final gradleBefore = File(p.join(root.path, 'android', 'app', 'build.gradle'))
          .readAsStringSync();
      final pbxprojBefore = File(p.join(root.path, 'ios', 'Runner.xcodeproj', 'project.pbxproj'))
          .readAsStringSync();
      final plistBefore = File(p.join(root.path, 'ios', 'Runner', 'Info.plist'))
          .readAsStringSync();
      final podfileBefore = File(p.join(root.path, 'ios', 'Podfile'))
          .readAsStringSync();

      FlavorCommand.run(projectRoot: root.path, dryRun: true);

      expect(
        File(p.join(root.path, 'android', 'app', 'build.gradle')).readAsStringSync(),
        gradleBefore,
      );
      expect(
        File(p.join(root.path, 'ios', 'Runner.xcodeproj', 'project.pbxproj')).readAsStringSync(),
        pbxprojBefore,
      );
      expect(
        File(p.join(root.path, 'ios', 'Runner', 'Info.plist')).readAsStringSync(),
        plistBefore,
      );
      expect(
        File(p.join(root.path, 'ios', 'Podfile')).readAsStringSync(),
        podfileBefore,
      );
      // xcconfig files should not be created
      expect(
        File(p.join(root.path, 'ios', 'Flutter', 'Debug-dev.xcconfig')).existsSync(),
        isFalse,
      );
    });

    test('full pipeline modifies all expected files', () {
      final root = _createFlutterProject(tempDir);

      FlavorCommand.run(projectRoot: root.path);

      // Android build.gradle should have flavorDimensions
      final gradle = File(p.join(root.path, 'android', 'app', 'build.gradle'))
          .readAsStringSync();
      expect(gradle, contains('flavorDimensions'));
      expect(gradle, contains('productFlavors'));

      // iOS xcconfig files should be created
      expect(
        File(p.join(root.path, 'ios', 'Flutter', 'Debug-dev.xcconfig')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(root.path, 'ios', 'Flutter', 'Release-prod.xcconfig')).existsSync(),
        isTrue,
      );

      // iOS pbxproj should have flavor build configurations
      final pbxproj = File(p.join(root.path, 'ios', 'Runner.xcodeproj', 'project.pbxproj'))
          .readAsStringSync();
      expect(pbxproj, contains('Debug-dev'));
      expect(pbxproj, contains('Release-prod'));

      // Scheme files should be created
      expect(
        File(p.join(root.path, 'ios', 'Runner.xcodeproj', 'xcshareddata', 'xcschemes', 'dev.xcscheme'))
            .existsSync(),
        isTrue,
      );
      expect(
        File(p.join(root.path, 'ios', 'Runner.xcodeproj', 'xcshareddata', 'xcschemes', 'prod.xcscheme'))
            .existsSync(),
        isTrue,
      );

      // Info.plist should use APP_DISPLAY_NAME variable
      final plist = File(p.join(root.path, 'ios', 'Runner', 'Info.plist'))
          .readAsStringSync();
      expect(plist, contains(r'$(APP_DISPLAY_NAME)'));

      // Podfile should have flavor mappings
      final podfile = File(p.join(root.path, 'ios', 'Podfile')).readAsStringSync();
      expect(podfile, contains("'Debug-dev' => :debug,"));
      expect(podfile, contains("'Release-prod' => :release,"));
    });

    test('copies Firebase config files when firebase is configured', () {
      final root = _createFlutterProject(tempDir, yamlContent: _easySetupYamlWithFirebase);

      // Create Firebase source files
      final devConfigDir = Directory(p.join(root.path, 'config', 'dev'));
      devConfigDir.createSync(recursive: true);
      File(p.join(devConfigDir.path, 'google-services.json'))
          .writeAsStringSync('{"project_id":"dev"}');
      File(p.join(devConfigDir.path, 'GoogleService-Info.plist'))
          .writeAsStringSync('<plist>dev</plist>');

      FlavorCommand.run(projectRoot: root.path);

      // Android Firebase config should be copied
      final androidDest = File(p.join(
        root.path, 'android', 'app', 'src', 'dev', 'google-services.json',
      ));
      expect(androidDest.existsSync(), isTrue);
      expect(androidDest.readAsStringSync(), '{"project_id":"dev"}');

      // iOS Firebase config should be copied
      final iosDest = File(p.join(
        root.path, 'ios', 'Runner', 'Firebase', 'dev', 'GoogleService-Info.plist',
      ));
      expect(iosDest.existsSync(), isTrue);
      expect(iosDest.readAsStringSync(), '<plist>dev</plist>');
    });

    test('skips Firebase copy when source files do not exist', () {
      final root = _createFlutterProject(tempDir, yamlContent: _easySetupYamlWithFirebase);

      // Do NOT create Firebase source files — should not throw
      FlavorCommand.run(projectRoot: root.path);

      final androidDest = File(p.join(
        root.path, 'android', 'app', 'src', 'dev', 'google-services.json',
      ));
      expect(androidDest.existsSync(), isFalse);
    });

    test('each flavor defines locale-specific variables in its xcconfig', () {
      // Multiple flavors with different app_names for the same locale
      // → Each flavor should have its own xcconfig with locale-specific variables
      final multiFlavorYaml = '''
easy_setup:
  flavors:
    dev:
      bundle_id: com.example.dev
      name: Test Dev
      localized:
        ko:
          app_name: 개발 앱
        en:
          app_name: Test Dev
    prod:
      bundle_id: com.example.prod
      name: Test Prod
      localized:
        ko:
          app_name: 상용 앱
        en:
          app_name: Test Prod
''';

      final root = _createFlutterProject(tempDir, yamlContent: multiFlavorYaml);
      FlavorCommand.run(projectRoot: root.path);

      // Dev flavor's xcconfig should have APP_DISPLAY_NAME_KO=개발 앱
      final devDebugXcconfig = File(p.join(
        root.path,
        'ios',
        'Flutter',
        'Debug-dev.xcconfig',
      )).readAsStringSync();
      expect(devDebugXcconfig, contains('APP_DISPLAY_NAME_KO=개발 앱'));
      expect(devDebugXcconfig, contains('APP_DISPLAY_NAME_EN=Test Dev'));

      // Prod flavor's xcconfig should have APP_DISPLAY_NAME_KO=상용 앱
      final prodDebugXcconfig = File(p.join(
        root.path,
        'ios',
        'Flutter',
        'Debug-prod.xcconfig',
      )).readAsStringSync();
      expect(prodDebugXcconfig, contains('APP_DISPLAY_NAME_KO=상용 앱'));
      expect(prodDebugXcconfig, contains('APP_DISPLAY_NAME_EN=Test Prod'));

      // InfoPlist.strings should reference the xcconfig variables
      final koStringsPath =
          p.join(root.path, 'ios', 'Runner', 'ko.lproj', 'InfoPlist.strings');
      final koContent = File(koStringsPath).readAsStringSync();
      // Should reference the variable, not hardcode the value
      expect(koContent, contains('"CFBundleDisplayName" = "(\$APP_DISPLAY_NAME_KO)";'));

      final enStringsPath =
          p.join(root.path, 'ios', 'Runner', 'en.lproj', 'InfoPlist.strings');
      final enContent = File(enStringsPath).readAsStringSync();
      expect(enContent, contains('"CFBundleDisplayName" = "(\$APP_DISPLAY_NAME_EN)";'));
    });
  });
}
