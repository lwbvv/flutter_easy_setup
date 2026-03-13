import 'dart:io';

import 'package:path/path.dart' as p;

/// Fastlane용 .env 파일을 생성하는 클래스입니다.
///
/// Fastlane은 fastlane/ 디렉터리의 .env 파일을 자동으로 로드합니다.
/// 생성된 .env 파일에는 TODO 플레이스홀더가 포함되어 있으며,
/// 사용자가 직접 실제 값을 채워야 합니다.
class DotenvGenerator {
  /// [outputDir]에 .env 파일을 생성합니다.
  ///
  /// 이미 파일이 존재하면 덮어쓰지 않습니다 (사용자가 채운 값 보호).
  static void generate(String outputDir, {bool dryRun = false}) {
    final path = p.join(outputDir, '.env');

    if (File(path).existsSync()) {
      print('  Skipped (already exists): $path');
      return;
    }

    const content = '# Fastlane 환경 변수\n'
        '# 아래 값들을 실제 값으로 변경하세요.\n'
        '\n'
        '# Apple Developer Team ID\n'
        'TEAM_ID=YOUR_TEAM_ID\n'
        '\n'
        '# App Store Connect Team ID\n'
        'ITC_TEAM_ID=YOUR_ITC_TEAM_ID\n'
        '\n'
        '# App Store Connect API Key\n'
        'API_KEY_ID=YOUR_KEY_ID\n'
        'API_KEY_ISSUER_ID=YOUR_ISSUER_ID\n'
        '\n'
        '# 인증서 저장 Git 저장소 URL (예: https://github.com/your-org/certs.git)\n'
        'CERTS_REPO_URL=YOUR_CERTS_REPO_URL\n'
        '\n'
        '# Apple ID (예: your@email.com)\n'
        'APPLE_ID=YOUR_APPLE_ID\n';

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
