import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/ci_cd_config.dart';

/// Fastfile을 생성하는 클래스입니다.
class FastfileGenerator {
  /// [outputDir]에 Fastfile을 생성합니다.
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
        '    sh("cd ../.. && flutter build ipa --flavor #{flavor} --release")\n'
        '\n'
        '    upload_to_testflight(\n'
        '      api_key: api_key,\n'
        '      skip_waiting_for_build_processing: true,\n'
        '    )\n'
        '  end\n'
        'end\n';

    _writeFile(path, content, dryRun: dryRun);
  }

  static void _writeFile(String path, String content, {required bool dryRun}) {
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
