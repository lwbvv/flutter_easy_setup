import 'dart:io';

import 'package:path/path.dart' as p;

/// iOS flavor별 .xcscheme 파일을 생성하는 클래스입니다.
///
/// Xcode의 빌드 스키마(scheme)는 빌드/실행/테스트/프로파일/분석/아카이브 시
/// 어떤 빌드 구성(configuration)을 사용할지 지정합니다.
///
/// 각 flavor에 대해 다음과 같이 빌드 구성을 매핑합니다:
///   - Build/Launch/Test/Analyze → Debug-{flavor}
///   - Profile                  → Profile-{flavor}
///   - Archive                  → Release-{flavor}
class SchemeGenerator {
  /// [schemesDir]에 flavor.xcscheme 파일을 생성합니다.
  ///
  /// [runnerTargetUuid]는 Runner PBXNativeTarget의 UUID로,
  /// BuildableReference에서 빌드 타겟을 지정하는 데 사용됩니다.
  static void generate(
    String schemesDir,
    String flavor,
    String runnerTargetUuid, {
    bool dryRun = false,
  }) {
    final outPath = p.join(schemesDir, '$flavor.xcscheme');

    if (dryRun) {
      print('  [dry-run] Would create scheme: $outPath');
      return;
    }

    // 디렉터리가 없으면 재귀적으로 생성
    final dir = Directory(schemesDir);
    dir.createSync(recursive: true);

    // 멱등성 가드: 이미 존재하면 건너뜀
    if (File(outPath).existsSync()) {
      print('  Scheme already exists: $outPath, skipping.');
      return;
    }

    File(outPath).writeAsStringSync(_buildSchemeXml(flavor, runnerTargetUuid));
    print('  Created scheme: $outPath');
  }

  /// flavor에 맞는 .xcscheme XML 전체를 생성합니다.
  ///
  /// Xcode 15.1 형식을 기반으로 하며,
  /// 각 액션(Build, Test, Launch, Profile, Analyze, Archive)에
  /// flavor별 빌드 구성을 지정합니다.
  static String _buildSchemeXml(String flavor, String runnerTargetUuid) {
    final ref = _buildableRef(runnerTargetUuid);
    return '''<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1510"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
$ref
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug-$flavor"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug-$flavor"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
$ref
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Profile-$flavor"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
$ref
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug-$flavor">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release-$flavor"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
''';
  }

  /// BuildableReference XML 요소를 생성합니다.
  ///
  /// Runner 타겟(Runner.app)을 빌드 대상으로 지정하며,
  /// Runner.xcodeproj를 참조 컨테이너로 설정합니다.
  static String _buildableRef(String runnerTargetUuid) {
    return '''            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "$runnerTargetUuid"
               BuildableName = "Runner.app"
               BlueprintName = "Runner"
               ReferencedContainer = "container:Runner.xcodeproj">
            </BuildableReference>''';
  }
}
