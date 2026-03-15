import 'dart:io';

import 'package:path/path.dart' as p;

/// XcodeGen이 참조하는 빌드 스크립트 파일을 생성하는 클래스입니다.
///
/// Flutter의 xcode_backend.sh를 호출하는 셸 스크립트를 생성합니다:
///   - copy_flavor_strings.sh: 빌드 전 현재 flavor의 InfoPlist.strings를 Runner로 복사
///   - run_script.sh: 빌드 전 Flutter 빌드 실행
///   - thin_binary.sh: 빌드 후 바이너리 최적화
class XcodeGenScriptsGenerator {
  /// 빌드 스크립트 파일들을 생성합니다.
  ///
  /// [projectRoot]: Flutter 프로젝트 루트
  /// [hasFlavors]: flavor가 있는 경우에만 copy_flavor_strings.sh 생성
  static void generate(
    String projectRoot, {
    bool hasFlavors = false,
    bool dryRun = false,
  }) {
    final scriptsDir = p.join(projectRoot, 'ios', 'xcodegen', 'script');

    if (hasFlavors) {
      _writeScript(
        p.join(scriptsDir, 'copy_flavor_strings.sh'),
        _copyFlavorStringsContent,
        dryRun: dryRun,
      );
    }

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

  /// 현재 빌드 configuration에서 flavor를 추출하고
  /// Flavors/{flavor}/{locale}.lproj/InfoPlist.strings를
  /// Runner/{locale}.lproj/InfoPlist.strings에 병합(CFBundleDisplayName만)하는 스크립트
  static const _copyFlavorStringsContent = r'''#!/bin/sh

# Extract flavor from CONFIGURATION (e.g. "Debug-dev" → "dev", "Release-prod" → "prod")
FLAVOR=$(echo "$CONFIGURATION" | sed -n 's/^[^-]*-\(.*\)/\1/p')

if [ -z "$FLAVOR" ]; then
  echo "No flavor detected in configuration: $CONFIGURATION, skipping flavor strings copy."
  exit 0
fi

FLAVORS_DIR="${SRCROOT}/Flavors/${FLAVOR}"

if [ ! -d "$FLAVORS_DIR" ]; then
  echo "Flavors directory not found: $FLAVORS_DIR, skipping."
  exit 0
fi

echo "Copying InfoPlist.strings for flavor: $FLAVOR"

# Find all .lproj directories in the flavor directory
for LPROJ in "$FLAVORS_DIR"/*.lproj; do
  if [ ! -d "$LPROJ" ]; then
    continue
  fi

  LOCALE=$(basename "$LPROJ")
  SRC_STRINGS="$LPROJ/InfoPlist.strings"
  DST_DIR="${SRCROOT}/Runner/${LOCALE}"
  DST_STRINGS="${DST_DIR}/InfoPlist.strings"

  if [ ! -f "$SRC_STRINGS" ]; then
    continue
  fi

  # Create destination directory if needed
  mkdir -p "$DST_DIR"

  if [ -f "$DST_STRINGS" ]; then
    # Merge: remove existing CFBundleDisplayName from destination, then append from source
    # 1. Remove CFBundleDisplayName line from existing file
    TEMP_FILE=$(mktemp)
    grep -v '"CFBundleDisplayName"' "$DST_STRINGS" > "$TEMP_FILE" || true

    # 2. Add CFBundleDisplayName from source
    grep '"CFBundleDisplayName"' "$SRC_STRINGS" >> "$TEMP_FILE" || true

    # 3. Remove empty lines and write back
    grep -v '^$' "$TEMP_FILE" > "$DST_STRINGS" || true
    rm -f "$TEMP_FILE"
  else
    # No existing file, just copy
    cp "$SRC_STRINGS" "$DST_STRINGS"
  fi

  echo "  Merged: $SRC_STRINGS → $DST_STRINGS"
done
''';

  static const _runScriptContent = '''#!/bin/sh
/bin/sh "\$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh" build
''';

  static const _thinBinaryContent = '''#!/bin/sh
/bin/sh "\$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh" embed_and_thin
''';
}
