import 'dart:io';

import 'package:path/path.dart' as p;

/// XcodeGen이 참조하는 빌드 스크립트 파일을 생성하는 클래스입니다.
///
/// Flutter의 xcode_backend.sh를 호출하는 셸 스크립트를 생성합니다:
///   - run_script.sh: 빌드 전 Flutter 빌드 실행
///   - thin_binary.sh: 빌드 후 바이너리 최적화
class XcodeGenScriptsGenerator {
  /// 빌드 스크립트 파일들을 생성합니다.
  ///
  /// [projectRoot]: Flutter 프로젝트 루트
  static void generate(String projectRoot, {bool dryRun = false}) {
    final scriptsDir = p.join(projectRoot, 'ios', 'xcodegen', 'script');

    _writeScript(
      p.join(scriptsDir, 'run_script.sh'),
      _runScriptContent,
      dryRun: dryRun,
    );

    _writeScript(
      p.join(scriptsDir, 'thin_binary.sh'),
      _thinBinaryContent,
      dryRun: dryRun,
    );
  }

  static void _writeScript(
    String path,
    String content, {
    required bool dryRun,
  }) {
    if (dryRun) {
      print('  [dry-run] Would write: $path');
      return;
    }

    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);

    // 실행 권한 부여
    Process.runSync('chmod', ['+x', path]);
    print('  Wrote: $path');
  }

  static const _runScriptContent = '''#!/bin/sh
/bin/sh "\$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh" build
''';

  static const _thinBinaryContent = '''#!/bin/sh
/bin/sh "\$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh" embed_and_thin
''';
}
