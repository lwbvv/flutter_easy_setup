import 'dart:io';

import 'package:path/path.dart' as p;

import '../exceptions.dart';
import '../models/ci_cd_config.dart';

/// Fastfile 생성 및 lane 관리를 담당하는 클래스입니다.
///
/// - [generate]: 기본 Fastfile 골격 + 내장 lane (api_key, certificates, beta) 생성
/// - [addRegisterLane]: register lane 추가 (idempotent)
/// - [addLane]: 임의의 lane 코드를 Fastfile에 삽입 (idempotent)
class FastfileGenerator {
  /// [outputDir]에 Fastfile을 생성합니다 (기본 골격 + 내장 lane).
  ///
  /// [ios]: CI/CD iOS 설정 (api_key 등)
  /// [flavorNames]: 사용 가능한 flavor 이름 목록
  static void generate(
    String outputDir,
    CiCdIosConfig ios,
    List<String> flavorNames, {
    bool dryRun = false,
  }) {
    final path = p.join(outputDir, 'Fastfile');

    final apiKey = ios.apiKey;
    final defaultFlavor = flavorNames.contains('prod')
        ? 'prod'
        : flavorNames.first;

    final content = 'default_platform(:ios)\n'
        '\n'
        'platform :ios do\n'
        '  # ── API Key 설정 ──────────────────────────────────\n'
        '  def api_key\n'
        '    app_store_connect_api_key(\n'
        '      key_id: "${apiKey.id}",\n'
        '      issuer_id: "${apiKey.issuerId}",\n'
        '      key_filepath: "${apiKey.keyPath}",\n'
        '      duration: ${apiKey.duration},\n'
        '      in_house: ${apiKey.inHouse},\n'
        '    )\n'
        '  end\n'
        '\n'
        '  # ── 인증서 동기화 ─────────────────────────────────\n'
        '  desc "Sync all certificates and provisioning profiles"\n'
        '  lane :certificates do\n'
        '    ["development", "adhoc", "appstore"].each do |type|\n'
        '      match(\n'
        '        type: type,\n'
        '        api_key: api_key,\n'
        '        readonly: is_ci,\n'
        '      )\n'
        '    end\n'
        '  end\n'
        '\n'
        '  # ── flavor별 빌드 + TestFlight 배포 ───────────────\n'
        '  desc "Build and upload to TestFlight"\n'
        '  lane :beta do |options|\n'
        '    flavor = options[:flavor] || "$defaultFlavor"\n'
        '\n'
        '    certificates\n'
        '\n'
        '    sh("cd ../../.. && flutter build ipa --flavor #{flavor} --release")\n'
        '\n'
        '    upload_to_testflight(\n'
        '      api_key: api_key,\n'
        '      skip_waiting_for_build_processing: true,\n'
        '    )\n'
        '  end\n'
        'end\n';

    _writeFile(path, content, dryRun: dryRun);
  }

  /// Fastfile에 register lane을 추가합니다 (idempotent).
  ///
  /// [fastfilePath]: Fastfile 경로
  /// [ios]: CI/CD iOS 설정
  /// [flavors]: flavor별 bundleId + name 맵 ({flavorName: {bundleId, name}})
  static void addRegisterLane({
    required String fastfilePath,
    required CiCdIosConfig ios,
    required Map<String, ({String bundleId, String name})> flavors,
    bool dryRun = false,
  }) {
    final laneCode = StringBuffer();
    laneCode.writeln('  # ── Bundle ID + App 등록 ──────────────────────');
    laneCode.writeln(
        '  desc "Register Bundle IDs and create apps on App Store Connect"');
    laneCode.writeln('  lane :register do');

    for (final entry in flavors.entries) {
      final info = entry.value;
      laneCode.writeln('    produce(');
      laneCode.writeln('      app_identifier: "${info.bundleId}",');
      laneCode.writeln('      app_name: "${info.name}",');
      laneCode.writeln('      sku: "${info.bundleId}",');
      laneCode.writeln('      team_id: "${ios.teamId}",');
      laneCode.writeln('      itc_team_id: "${ios.itcTeamId}",');
      if (ios.appleId != null) {
        laneCode.writeln('      username: "${ios.appleId}",');
      }
      laneCode.writeln('    )');
      laneCode.writeln('');
    }

    laneCode.writeln('    UI.success("All apps registered!")');
    laneCode.write('  end');

    addLane(
      fastfilePath: fastfilePath,
      marker: '  # ── Bundle ID + App 등록',
      laneKeyword: 'lane :register do',
      laneCode: laneCode.toString(),
      dryRun: dryRun,
    );
  }

  /// Fastfile에 lane 코드를 추가합니다 (idempotent).
  ///
  /// [marker]로 시작하는 기존 블록이 있으면 제거 후 재삽입합니다.
  /// lane 코드는 Fastfile의 마지막 `end` (platform 블록 종료) 앞에 삽입됩니다.
  ///
  /// [fastfilePath]: Fastfile 경로
  /// [marker]: 기존 블록 탐지용 주석 마커
  /// [laneKeyword]: lane 시작 키워드 (예: 'lane :register do')
  /// [laneCode]: 삽입할 lane 전체 코드 (마커 + desc + lane 블록)
  static void addLane({
    required String fastfilePath,
    required String marker,
    required String laneKeyword,
    required String laneCode,
    bool dryRun = false,
  }) {
    final fastfile = File(fastfilePath);

    if (!fastfile.existsSync()) {
      throw SetupException(
        'Fastfile not found: $fastfilePath\n'
        'Run "easy_setup ci-cd" first to generate Fastlane files.',
      );
    }

    if (dryRun) {
      print('  [dry-run] Would add lane to: $fastfilePath');
      return;
    }

    var content = fastfile.readAsStringSync();

    // 기존 블록 제거
    content = _stripLaneBlock(content, marker, laneKeyword);

    // 마지막 'end' (platform :ios do ... end) 앞에 삽입
    final lastEndIndex = content.lastIndexOf('end');
    if (lastEndIndex == -1) {
      throw SetupException('Invalid Fastfile format: missing closing "end"');
    }

    content = '${content.substring(0, lastEndIndex)}'
        '\n$laneCode\n'
        '${content.substring(lastEndIndex)}';

    fastfile.writeAsStringSync(content);
    print('  Added lane to: $fastfilePath');
  }

  /// [marker]로 시작하여 [laneKeyword]를 포함하는 lane 블록을 제거합니다.
  static String _stripLaneBlock(
    String content,
    String marker,
    String laneKeyword,
  ) {
    final startIndex = content.indexOf(marker);
    if (startIndex == -1) return content;

    // lane 시작 찾기
    final laneStart = content.indexOf(laneKeyword, startIndex);
    if (laneStart == -1) return content;

    // lane의 end 찾기 (들여쓰기 레벨 매칭)
    var depth = 0;
    var endIndex = laneStart;
    final lines = content.substring(laneStart).split('\n');
    var lineCount = 0;
    for (final line in lines) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('lane ') || trimmed.startsWith('do')) {
        depth++;
      }
      if (trimmed == 'end') {
        depth--;
        if (depth <= 0) {
          endIndex = laneStart +
              lines.sublist(0, lineCount + 1).join('\n').length;
          break;
        }
      }
      lineCount++;
    }

    // marker 이전 줄바꿈부터 end 다음 줄바꿈까지 제거
    var removeStart = startIndex;
    if (removeStart > 0 && content[removeStart - 1] == '\n') {
      removeStart--;
    }
    var removeEnd = endIndex;
    if (removeEnd < content.length && content[removeEnd] == '\n') {
      removeEnd++;
    }

    return content.substring(0, removeStart) + content.substring(removeEnd);
  }

  static void _writeFile(String path, String content,
      {required bool dryRun}) {
    if (dryRun) {
      print('  [dry-run] Would write: $path');
      return;
    }
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    print('  Wrote: $path');
  }
}
