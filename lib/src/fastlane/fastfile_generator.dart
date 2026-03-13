import 'dart:io';

import 'package:path/path.dart' as p;

import '../exceptions.dart';

/// Fastfile 생성 및 lane 관리를 담당하는 클래스입니다.
///
/// - [generate]: 기본 Fastfile 골격 + 내장 lane (api_key, certificates, beta) 생성
/// - [addRegisterLane]: register lane 추가 (idempotent)
/// - [addLane]: 임의의 lane 코드를 Fastfile에 삽입 (idempotent)
class FastfileGenerator {
  /// [outputDir]에 Fastfile을 생성합니다 (기본 골격 + 내장 lane).
  ///
  /// [flavorNames]: 사용 가능한 flavor 이름 목록
  static void generate(
    String outputDir,
    List<String> flavorNames, {
    bool dryRun = false,
  }) {
    final path = p.join(outputDir, 'Fastfile');

    final defaultFlavor = flavorNames.contains('prod')
        ? 'prod'
        : flavorNames.first;

    final content = 'default_platform(:ios)\n'
        '\n'
        'platform :ios do\n'
        '  # ── API Key 설정 ──────────────────────────────────\n'
        '  api_key = app_store_connect_api_key(\n'
        '    key_id: ENV["API_KEY_ID"],\n'
        '    issuer_id: ENV["API_KEY_ISSUER_ID"],\n'
        '    key_filepath: "fastlane/AuthKey.p8", # TODO: .p8 키 파일 경로\n'
        '    duration: 1200,\n'
        '    in_house: false\n'
        '  )\n'
        '\n'
        '  # ── Build Number 자동 증가 ──────────────────────────\n'
        '  def increment_build_number_in_pubspec\n'
        '    pubspec_path = File.join(__dir__, "..", "..", "..", "pubspec.yaml")\n'
        '    content = File.read(pubspec_path)\n'
        '    unless content =~ /^(version:\\s*\\S+\\+)(\\d+)\$/m\n'
        '      UI.user_error!("Could not find version+build_number in pubspec.yaml")\n'
        '    end\n'
        '    old_build = \$2.to_i\n'
        '    new_build = old_build + 1\n'
        '    new_content = content.sub(/^(version:\\s*\\S+\\+)\\d+\$/m, "\\\\1#{new_build}")\n'
        '    File.write(pubspec_path, new_content)\n'
        '    UI.success("Build number: #{old_build} → #{new_build}")\n'
        '    new_build\n'
        '  end\n'
        '\n'
        '  # ── 인증서 동기화 + Xcode 서명 설정 ──────────────────\n'
        '  desc "Sync certificates and update Xcode signing settings"\n'
        '  lane :sync_certs do\n'
        '    # readonly: true를 주면 기존에 만들어진 걸 가져오기만 합니다 (팀원용)\n'
        '#     match(type: "development", readonly: true, api_key: api_key)\n'
        '#     match(type: "appstore", readonly: true, api_key: api_key)\n'
        '#     match(type: "adhoc", readonly: true, api_key: api_key)\n'
        '\n'
        '    # Xcode 프로젝트 서명 설정을 업데이트합니다.\n'
        '    # 개발용 매핑\n'
        '    update_code_signing_settings(\n'
        '      use_automatic_signing: false,\n'
        '      path: "ios/Runner.xcodeproj",\n'
        '      bundle_identifier: app_bundle_id,\n'
        '      build_configurations: "Debug",\n'
        '      profile_name: "match Development #{app_bundle_id}"\n'
        '    )\n'
        '\n'
        '    # 배포용 매핑\n'
        '    update_code_signing_settings(\n'
        '      use_automatic_signing: false,\n'
        '      path: "ios/Runner.xcodeproj",\n'
        '      bundle_identifier: app_bundle_id,\n'
        '      profile_name: "match AppStore #{app_bundle_id}",\n'
        '      build_configurations: "Release",\n'
        '      code_sign_identity: "Apple Distribution"\n'
        '    )\n'
        '\n'
        '    UI.success "Xcode 프로젝트에 프로필 매핑이 완료되었습니다!"\n'
        '  end\n'
        '\n'
        '  # ── 프로필만 재생성 ─────────────────────────────────\n'
        '  desc "인증서는 건드리지 않고 프로필만 생성/재생성"\n'
        '  lane :refresh_profiles do\n'
        '    match(type: "development", force: true, api_key: api_key)\n'
        '    match(type: "appstore", force: true, api_key: api_key)\n'
        '    match(type: "adhoc", force: true, api_key: api_key)\n'
        '\n'
        '    UI.success "인증서는 유지하고 프로비저닝 프로필만 새로 갱신했습니다!"\n'
        '  end\n'
        '\n'
        '  # ── flavor별 빌드 + TestFlight 배포 ───────────────\n'
        '  desc "Build and upload to TestFlight"\n'
        '  lane :beta do |options|\n'
        '    flavor = options[:flavor] || "$defaultFlavor"\n'
        '\n'
        '    sync_certs\n'
        '\n'
        '    increment_build_number_in_pubspec\n'
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
  /// [flavors]: flavor별 bundleId + name 맵 ({flavorName: {bundleId, name}})
  static void addRegisterLane({
    required String fastfilePath,
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
      laneCode.writeln('      team_id: ENV["TEAM_ID"],');
      laneCode.writeln('      itc_team_id: ENV["ITC_TEAM_ID"],');
      laneCode.writeln('      # username: "your@email.com",       # TODO: Apple ID (필요 시 주석 해제)');
      laneCode.writeln('      enable_services: {                  # 게임센터는 디폴트가 on이라 비활성화 시켜줘야 됨');
      laneCode.writeln('        game_center: "off"');
      laneCode.writeln('      },');
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

  /// Fastfile에 update_metadata lane을 추가합니다 (idempotent).
  ///
  /// `deliver`를 사용하여 App Store Connect 메타데이터를 업로드합니다.
  static void addMetadataLane({
    required String fastfilePath,
    bool dryRun = false,
  }) {
    final laneCode = StringBuffer();
    laneCode.writeln('  # ── 메타데이터 업로드 ─────────────────────────');
    laneCode.writeln(
        '  desc "Upload metadata to App Store Connect"');
    laneCode.writeln('  lane :update_metadata do');
    laneCode.writeln('    deliver(');
    laneCode.writeln('      api_key: api_key,');
    laneCode.writeln('      skip_binary_upload: true,');
    laneCode.writeln('      skip_screenshots: true,');
    laneCode.writeln('      force: true,');
    laneCode.writeln('      precheck_include_in_app_purchases: false,');
    laneCode.writeln('    )');
    laneCode.write('  end');

    addLane(
      fastfilePath: fastfilePath,
      marker: '  # ── 메타데이터 업로드',
      laneKeyword: 'lane :update_metadata do',
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
