import 'dart:io';

/// iOS Info.plist 파일을 수정하는 클래스입니다.
///
/// 1. CFBundleDisplayName의 값을 $(APP_DISPLAY_NAME)으로 변경
/// 2. permission 맵의 키들을 Info.plist에 추가 (없는 키만)
class InfoPlistModifier {
  /// Info.plist 파일을 수정합니다.
  ///
  /// [permission]: easy_setup.yaml의 permission 맵 (키만 사용하여 Info.plist에 추가)
  static void modify(
    String plistPath, {
    Map<String, String>? permission,
    bool dryRun = false,
  }) {
    final file = File(plistPath);
    if (!file.existsSync()) {
      print('  Info.plist not found at $plistPath, skipping.');
      return;
    }

    var content = file.readAsStringSync();

    // 1. CFBundleDisplayName → $(APP_DISPLAY_NAME)
    content = _setDisplayName(content);

    // 2. permission 키들을 Info.plist에 추가
    if (permission != null && permission.isNotEmpty) {
      content = _addPermissions(content, permission);
    }

    if (dryRun) {
      print(r'  [dry-run] Would update Info.plist');
      return;
    }

    file.writeAsStringSync(content);
    print(r'  Updated Info.plist: CFBundleDisplayName → $(APP_DISPLAY_NAME)');
    if (permission != null && permission.isNotEmpty) {
      for (final key in permission.keys) {
        print('  Updated Info.plist: $key');
      }
    }
  }

  /// CFBundleDisplayName을 $(APP_DISPLAY_NAME)으로 설정합니다.
  static String _setDisplayName(String content) {
    final pattern = RegExp(
      r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)',
      dotAll: true,
    );

    if (pattern.hasMatch(content)) {
      return content.replaceFirstMapped(pattern, (match) {
        return '${match.group(1)}\$(APP_DISPLAY_NAME)${match.group(2)}';
      });
    }

    // CFBundleDisplayName이 없으면 </dict> 직전에 추가
    return content.replaceFirst(
      '</dict>\n</plist>',
      '\t<key>CFBundleDisplayName</key>\n'
      '\t<string>\$(APP_DISPLAY_NAME)</string>\n'
      '</dict>\n</plist>',
    );
  }

  /// permission 키들을 Info.plist에 추가합니다.
  /// 이미 존재하는 키는 값을 업데이트하고, 없는 키는 새로 추가합니다.
  static String _addPermissions(
      String content, Map<String, String> permission) {
    final newEntries = StringBuffer();

    for (final entry in permission.entries) {
      final key = entry.key;
      final value = entry.value;

      final existingPattern = RegExp(
        '(<key>${RegExp.escape(key)}</key>\\s*<string>)[^<]*(</string>)',
        dotAll: true,
      );

      if (existingPattern.hasMatch(content)) {
        // 이미 존재하면 값 업데이트
        content = content.replaceFirstMapped(existingPattern, (match) {
          return '${match.group(1)}$value${match.group(2)}';
        });
      } else {
        // 없으면 나중에 일괄 추가
        newEntries.writeln('\t<key>$key</key>');
        newEntries.writeln('\t<string>$value</string>');
      }
    }

    // 새 항목들을 </dict> 직전에 삽입
    final newContent = newEntries.toString();
    if (newContent.isNotEmpty) {
      content = content.replaceFirst(
        '</dict>\n</plist>',
        '$newContent</dict>\n</plist>',
      );
    }

    return content;
  }
}
