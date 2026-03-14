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
///   - XCBuildConfiguration (Runner 타겟): 기존 Debug/Release/Profile 블록을 복제하여
///     flavor별 빌드 구성 생성 (bundle ID, xcconfig 참조 변경)
///   - XCBuildConfiguration (Project 레벨): 프로젝트 레벨 빌드 구성도 동일하게 복제
///   - XCConfigurationList (Runner): Runner 타겟의 구성 목록에 새 UUID 추가
///   - XCConfigurationList (Project): 프로젝트 레벨 구성 목록에 새 UUID 추가
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

    // 기존 flavor 설정이 있으면 제거 후 재생성
    content = _stripExistingFlavorConfigs(content);

    // ---- 기존 정보 추출 ----

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

    // 기존 빌드 구성(Debug/Release/Profile)의 UUID 맵 추출
    // 이전 실행에서 기본 구성이 config list에서 제거된 경우,
    // XCBuildConfiguration 블록에서 직접 검색 (fallback)
    var runnerConfigUuids =
        _extractConfigsFromList(content, runnerConfigListUuid);
    if (runnerConfigUuids.isEmpty) {
      runnerConfigUuids =
          _findBaseConfigBlockUuids(content, isRunner: true);
    }
    var projectConfigUuids =
        _extractConfigsFromList(content, projectConfigListUuid);
    if (projectConfigUuids.isEmpty) {
      projectConfigUuids =
          _findBaseConfigBlockUuids(content, isRunner: false);
    }

    // 기존 xcconfig 파일 참조 UUID 추출 (새 빌드 구성에서 참조를 교체할 때 사용)
    final debugXcconfigRef = _extractXcconfigFileRefUuid(content, 'Debug.xcconfig');
    final releaseXcconfigRef =
        _extractXcconfigFileRefUuid(content, 'Release.xcconfig');

    // ---- flavor별 새 UUID 일괄 생성 ----
    // 각 flavor마다 9개의 UUID가 필요 (파일 참조 3개 + Runner 빌드 구성 3개 + Project 빌드 구성 3개)
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
      );
    }

    // Step c: PBXFileReference 섹션에 xcconfig 파일 참조 추가
    content = _addFileReferences(content, flavors, flavorUuids);

    // Step d: Flutter PBXGroup의 children 목록에 파일 참조 추가
    content = _addToFlutterGroup(content, flutterGroupUuid, flavors, flavorUuids);

    // Step e-1: Runner 타겟의 XCBuildConfiguration 블록 복제
    //           (bundle ID와 xcconfig 참조를 flavor별로 변경)
    content = _cloneRunnerXCBuildConfigurations(
      content,
      flavors,
      flavorUuids,
      runnerConfigUuids,
      debugXcconfigRef,
      releaseXcconfigRef,
    );

    // Step e-2: Project 레벨의 XCBuildConfiguration 블록 복제
    //           (이름과 UUID만 변경, xcconfig/bundle ID 교체 불필요)
    content = _cloneProjectXCBuildConfigurations(
      content,
      flavors,
      flavorUuids,
      projectConfigUuids,
    );

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

    // Step h: 기본 빌드 구성(Debug, Release, Profile) 제거
    //         flavor 구성이 클론 완료되었으므로 원본 기본 구성은 불필요
    content = _removeBaseConfigurations(
      content,
      runnerConfigUuids,
      projectConfigUuids,
    );

    if (dryRun) {
      print('  [dry-run] Would update iOS project.pbxproj');
    } else {
      file.writeAsStringSync(content);
      print('  Updated iOS project.pbxproj');
    }

    return runnerTargetUuid;
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

  /// 기본 빌드 구성(Debug, Release, Profile)을 XCConfigurationList에서 제거합니다.
  ///
  /// XCBuildConfiguration 블록 자체는 유지합니다 (재실행 시 클론 소스로 사용).
  /// Xcode는 XCConfigurationList에서 참조되지 않는 블록은 무시합니다.
  static String _removeBaseConfigurations(
    String content,
    Map<String, String> runnerConfigUuids,
    Map<String, String> projectConfigUuids,
  ) {
    // XCConfigurationList에서 기본 구성 참조만 제거 (블록은 유지)
    content = content.replaceAll(
      RegExp(
        r'\t\t\t\t[0-9A-F]{24} /\* (?:Debug|Release|Profile) \*/,\n',
      ),
      '',
    );

    return content;
  }

  /// XCBuildConfiguration 블록에서 기본 구성(Debug/Release/Profile)의 UUID를 직접 검색합니다.
  ///
  /// config list에서 기본 구성이 제거된 경우(이전 실행으로 인해) fallback으로 사용됩니다.
  /// [isRunner]가 true이면 PRODUCT_BUNDLE_IDENTIFIER가 있는 Runner 타겟 블록을,
  /// false이면 없는 Project 레벨 블록을 반환합니다.
  static Map<String, String> _findBaseConfigBlockUuids(
    String content, {
    required bool isRunner,
  }) {
    final result = <String, String>{};
    for (final name in ['Debug', 'Release', 'Profile']) {
      final matches = RegExp(
        r'([0-9A-F]{24}) /\* ' + name + r' \*/ = \{',
      ).allMatches(content);
      for (final m in matches) {
        final block = _extractXCBuildConfigBlock(content, m.group(1)!);
        if (block.isEmpty) continue;
        // isa = XCBuildConfiguration인지 확인
        if (!block.contains('isa = XCBuildConfiguration')) continue;
        final hasBundleId = block.contains('PRODUCT_BUNDLE_IDENTIFIER');
        if (isRunner == hasBundleId) {
          result[name] = m.group(1)!;
          break;
        }
      }
    }
    return result;
  }

  // ──────────────────────────── UUID 추출 메서드 ────────────────────────────

  /// pbxproj에서 Runner PBXNativeTarget의 24자리 UUID를 추출합니다.
  static String _extractRunnerTargetUuid(String content) {
    final matches =
        RegExp(r'([0-9A-F]{24}) /\* Runner \*/ = \{').allMatches(content);
    for (final m in matches) {
      // PBXNativeTarget 블록인지 확인 (다른 타입의 Runner 항목과 구분)
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
    String targetUuid,
  ) {
    final targetStart = content.indexOf('$targetUuid /* Runner */ = {');
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

  /// XCConfigurationList 내의 빌드 구성 UUID를 추출합니다.
  ///
  /// 반환값: {'Debug': uuid, 'Release': uuid, 'Profile': uuid} 형태의 맵
  static Map<String, String> _extractConfigsFromList(
    String content,
    String listUuid,
  ) {
    // 정의 라인(`UUID /* ... */ = {`)을 찾음. 참조 라인(`property = UUID /* ... */;`)과 구분하기 위해
    // `*/ = {` 패턴을 포함하는 매치만 사용
    final defMatch = RegExp(
      RegExp.escape(listUuid) + r' /\*[^*]*\*/ = \{',
    ).firstMatch(content);
    if (defMatch == null) return {};
    final listStart = defMatch.start;
    final braceStart = defMatch.end - 1; // 매치 끝의 '{' 위치
    final blockEnd = _findBlockEnd(content, braceStart);
    if (blockEnd == -1) return {};

    final block = content.substring(listStart, blockEnd + 1);
    final result = <String, String>{};
    final matches =
        RegExp(r'([0-9A-F]{24}) /\* (Debug|Release|Profile) \*/')
            .allMatches(block);
    for (final m in matches) {
      result[m.group(2)!] = m.group(1)!;
    }
    return result;
  }

  /// 특정 xcconfig 파일의 PBXFileReference UUID를 추출합니다.
  static String _extractXcconfigFileRefUuid(String content, String filename) {
    final escaped = filename.replaceAll('.', r'\.');
    final match =
        RegExp(r'([0-9A-F]{24}) /\* ' + escaped + r' \*/').firstMatch(content);
    return match?.group(1) ?? '';
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

  // ─────────────────────────── 내용 수정 메서드 ───────────────────────────

  /// 기존 flavor별 빌드 구성을 모두 제거합니다.
  ///
  /// PBXFileReference, PBXGroup children, XCBuildConfiguration,
  /// XCConfigurationList에서 flavor 관련 항목을 제거합니다.
  static String _stripExistingFlavorConfigs(String content) {
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

    // 3. XCBuildConfiguration: flavor 빌드 구성 블록 제거 (brace-counting 사용)
    while (true) {
      final match = RegExp(
        r'\t\t[0-9A-F]{24} /\* (?:Debug|Release|Profile)-\w+ \*/ = \{',
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

    // 4. XCConfigurationList: flavor 빌드 구성 참조 제거
    content = content.replaceAll(
      RegExp(
        r'\t\t\t\t[0-9A-F]{24} /\* (?:Debug|Release|Profile)-\w+ \*/,\n',
      ),
      '',
    );

    return content;
  }

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

  /// Runner 타겟의 기존 XCBuildConfiguration 블록을 복제하여 flavor별 빌드 구성을 생성합니다.
  ///
  /// 복제 시 변경되는 항목:
  ///   - UUID → 새로 생성한 UUID
  ///   - name → "Debug-{flavor}", "Release-{flavor}", "Profile-{flavor}"
  ///   - PRODUCT_BUNDLE_IDENTIFIER → flavor의 bundle_id
  ///   - baseConfigurationReference → flavor별 xcconfig 파일 참조
  static String _cloneRunnerXCBuildConfigurations(
    String content,
    Map<String, FlavorConfig> flavors,
    Map<String, _FlavorUuids> flavorUuids,
    Map<String, String> runnerConfigUuids,
    String debugXcconfigRef,
    String releaseXcconfigRef,
  ) {
    final sb = StringBuffer();
    for (final entry in flavors.entries) {
      final flavor = entry.key;
      final config = entry.value;
      final uuids = flavorUuids[flavor]!;

      // Debug 빌드 구성 복제
      if (runnerConfigUuids['Debug'] != null) {
        final original =
            _extractXCBuildConfigBlock(content, runnerConfigUuids['Debug']!);
        if (original.isNotEmpty) {
          sb.write(_cloneXCBuildConfig(
            original,
            runnerConfigUuids['Debug']!,
            uuids.debugRunnerConfig,
            'Debug',
            'Debug-$flavor',
            config.bundleId,
            debugXcconfigRef,
            uuids.debugFileRef,
          ));
        }
      }

      // Release 빌드 구성 복제
      if (runnerConfigUuids['Release'] != null) {
        final original =
            _extractXCBuildConfigBlock(content, runnerConfigUuids['Release']!);
        if (original.isNotEmpty) {
          sb.write(_cloneXCBuildConfig(
            original,
            runnerConfigUuids['Release']!,
            uuids.releaseRunnerConfig,
            'Release',
            'Release-$flavor',
            config.bundleId,
            releaseXcconfigRef,
            uuids.releaseFileRef,
          ));
        }
      }

      // Profile 빌드 구성 복제 (Profile은 Release xcconfig를 기반으로 함)
      if (runnerConfigUuids['Profile'] != null) {
        final original =
            _extractXCBuildConfigBlock(content, runnerConfigUuids['Profile']!);
        if (original.isNotEmpty) {
          sb.write(_cloneXCBuildConfig(
            original,
            runnerConfigUuids['Profile']!,
            uuids.profileRunnerConfig,
            'Profile',
            'Profile-$flavor',
            config.bundleId,
            releaseXcconfigRef, // Profile은 Release.xcconfig를 재사용
            uuids.profileFileRef,
          ));
        }
      }
    }

    if (sb.isEmpty) return content;
    // XCBuildConfiguration 섹션 끝 마커 직전에 삽입
    return content.replaceFirst(
      '/* End XCBuildConfiguration section */',
      '${sb.toString()}/* End XCBuildConfiguration section */',
    );
  }

  /// Project 레벨의 XCBuildConfiguration 블록을 복제합니다.
  ///
  /// Runner 타겟과 달리 bundle ID나 xcconfig 참조를 변경하지 않고,
  /// UUID와 이름(name)만 변경합니다.
  static String _cloneProjectXCBuildConfigurations(
    String content,
    Map<String, FlavorConfig> flavors,
    Map<String, _FlavorUuids> flavorUuids,
    Map<String, String> projectConfigUuids,
  ) {
    final sb = StringBuffer();
    for (final entry in flavors.entries) {
      final flavor = entry.key;
      final uuids = flavorUuids[flavor]!;

      for (final configEntry in projectConfigUuids.entries) {
        final buildType = configEntry.key; // Debug, Release, Profile
        final originalUuid = configEntry.value;

        // buildType에 따라 적절한 새 UUID 선택
        final newUuid = buildType == 'Debug'
            ? uuids.debugProjectConfig
            : buildType == 'Release'
                ? uuids.releaseProjectConfig
                : uuids.profileProjectConfig;
        final newName = '$buildType-$flavor'; // 예: "Debug-dev"

        final original = _extractXCBuildConfigBlock(content, originalUuid);
        if (original.isEmpty) continue;

        // UUID, 주석, name 필드만 교체
        var cloned = original;
        cloned = cloned.replaceFirst(originalUuid, newUuid);
        cloned = cloned.replaceFirst('/* $buildType */', '/* $newName */');
        cloned = cloned.replaceFirst(
          RegExp(r'\bname = ' + buildType + r';'),
          'name = $newName;',
        );
        sb.write(cloned);
      }
    }

    if (sb.isEmpty) return content;
    return content.replaceFirst(
      '/* End XCBuildConfiguration section */',
      '${sb.toString()}/* End XCBuildConfiguration section */',
    );
  }

  /// 단일 XCBuildConfiguration 블록을 복제하고 주요 값을 교체합니다.
  ///
  /// 교체 항목:
  ///   1. 선행 UUID
  ///   2. 주석의 이름 (/* Debug */ → /* Debug-dev */)
  ///   3. name 속성값
  ///   4. PRODUCT_BUNDLE_IDENTIFIER 값
  ///   5. baseConfigurationReference (xcconfig 파일 참조)
  static String _cloneXCBuildConfig(
    String original,
    String originalUuid,
    String newUuid,
    String originalName,
    String newName,
    String newBundleId,
    String? oldXcconfigRef,
    String? newXcconfigRef,
  ) {
    var result = original;

    // 1. UUID 교체
    result = result.replaceFirst(originalUuid, newUuid);

    // 2. 주석 내 이름 교체: `/* Debug */` → `/* Debug-dev */`
    result = result.replaceFirst('/* $originalName */', '/* $newName */');

    // 3. name 속성 교체: `name = Debug;` → `name = Debug-dev;`
    result = result.replaceFirst(
      RegExp(r'\bname = ' + originalName + r';'),
      'name = $newName;',
    );

    // 4. PRODUCT_BUNDLE_IDENTIFIER 교체
    result = result.replaceFirst(
      RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = [^;]+;'),
      'PRODUCT_BUNDLE_IDENTIFIER = $newBundleId;',
    );

    // 5. baseConfigurationReference 교체 (xcconfig 파일 경로 변경)
    if (oldXcconfigRef != null &&
        newXcconfigRef != null &&
        oldXcconfigRef.isNotEmpty &&
        newXcconfigRef.isNotEmpty) {
      result = result.replaceFirst(
        RegExp(
          r'baseConfigurationReference = ' +
              oldXcconfigRef +
              r' /\* [^*]+ \*/;',
        ),
        'baseConfigurationReference = $newXcconfigRef /* $newName.xcconfig */;',
      );
    }

    return result;
  }

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
    final configsStart = content.indexOf('buildConfigurations = (', listStart);
    if (configsStart == -1 || configsStart > blockEnd) return content;
    final configsEnd = content.indexOf(');', configsStart);
    if (configsEnd == -1 || configsEnd > blockEnd) return content;

    final sb = StringBuffer();
    for (final entry in flavors.entries) {
      final flavor = entry.key;
      final uuids = flavorUuids[flavor]!;
      if (isRunner) {
        sb.writeln('\t\t\t\t${uuids.debugRunnerConfig} /* Debug-$flavor */,');
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
}

// ──────────────────────────── 내부 데이터 클래스 ─────────────────────────────

/// 하나의 flavor에 대해 필요한 9개의 UUID를 묶어 관리하는 내부 클래스입니다.
///
/// - 파일 참조 UUID 3개: Debug/Release/Profile xcconfig 파일의 PBXFileReference
/// - Runner 빌드 구성 UUID 3개: Runner 타겟의 XCBuildConfiguration
/// - Project 빌드 구성 UUID 3개: Project 레벨의 XCBuildConfiguration
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
  });
}
