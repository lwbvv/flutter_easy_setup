import 'dart:io';

/// iOS Info.plist 파일의 앱 표시 이름을 xcconfig 변수로 교체하는 클래스입니다.
///
/// CFBundleDisplayName의 값을 $(APP_DISPLAY_NAME)으로 변경하여,
/// 각 flavor의 xcconfig 파일에서 정의한 APP_DISPLAY_NAME 값이
/// 빌드 시점에 자동으로 반영되도록 합니다.
///
/// 예시:
///   변경 전: `<string>Runner</string>`
///   변경 후: `<string>$(APP_DISPLAY_NAME)</string>`
class InfoPlistModifier {
  /// Info.plist 파일을 수정합니다.
  ///
  /// CFBundleDisplayName 키가 이미 존재하면 값만 교체하고,
  /// 존재하지 않으면 `</dict>` 직전에 새로 추가합니다.
  static void modify(String plistPath, {bool dryRun = false}) {
    final file = File(plistPath);
    if (!file.existsSync()) {
      print('  Info.plist not found at $plistPath, skipping.');
      return;
    }

    var content = file.readAsStringSync();

    // CFBundleDisplayName 키의 값을 $(APP_DISPLAY_NAME)으로 교체
    final pattern = RegExp(
      r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)',
      dotAll: true,
    );

    if (pattern.hasMatch(content)) {
      // 기존 CFBundleDisplayName의 값만 교체
      content = content.replaceFirstMapped(pattern, (match) {
        return '${match.group(1)}\$(APP_DISPLAY_NAME)${match.group(2)}';
      });
    } else {
      // CFBundleDisplayName이 없으면 새로 추가 (plist 루트 </dict> 직전)
      content = content.replaceFirst(
        '</dict>\n</plist>',
        '\t<key>CFBundleDisplayName</key>\n'
        '\t<string>\$(APP_DISPLAY_NAME)</string>\n'
        '</dict>\n</plist>',
      );
    }

    if (dryRun) {
      print(r'  [dry-run] Would update Info.plist: CFBundleDisplayName → $(APP_DISPLAY_NAME)');
      return;
    }

    file.writeAsStringSync(content);
    print(r'  Updated Info.plist: CFBundleDisplayName → $(APP_DISPLAY_NAME)');
  }
}
