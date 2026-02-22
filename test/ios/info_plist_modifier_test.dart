import 'dart:io';

import 'package:easy_setup/src/ios/info_plist_modifier.dart';
import 'package:test/test.dart';

const _plistWithDisplayName = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>Runner</string>
	<key>CFBundleDisplayName</key>
	<string>Runner</string>
	<key>CFBundleIdentifier</key>
	<string>\$(PRODUCT_BUNDLE_IDENTIFIER)</string>
</dict>
</plist>
''';

const _plistWithoutDisplayName = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>Runner</string>
	<key>CFBundleIdentifier</key>
	<string>\$(PRODUCT_BUNDLE_IDENTIFIER)</string>
</dict>
</plist>
''';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('info_plist_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('InfoPlistModifier', () {
    test('replaces existing CFBundleDisplayName value', () {
      final file = File('${tempDir.path}/Info.plist');
      file.writeAsStringSync(_plistWithDisplayName);

      InfoPlistModifier.modify(file.path);

      final result = file.readAsStringSync();
      expect(result, contains(r'$(APP_DISPLAY_NAME)'));
      expect(result, contains('<key>CFBundleDisplayName</key>'));
      // Original static value should be gone
      expect(
        RegExp(r'<key>CFBundleDisplayName</key>\s*<string>Runner</string>')
            .hasMatch(result),
        isFalse,
      );
    });

    test('adds CFBundleDisplayName when it does not exist', () {
      final file = File('${tempDir.path}/Info.plist');
      file.writeAsStringSync(_plistWithoutDisplayName);

      InfoPlistModifier.modify(file.path);

      final result = file.readAsStringSync();
      expect(result, contains('<key>CFBundleDisplayName</key>'));
      expect(result, contains(r'$(APP_DISPLAY_NAME)'));
    });

    test('is idempotent — skips when already using variable', () {
      final file = File('${tempDir.path}/Info.plist');
      file.writeAsStringSync(_plistWithDisplayName);

      InfoPlistModifier.modify(file.path);
      final afterFirst = file.readAsStringSync();

      InfoPlistModifier.modify(file.path);
      final afterSecond = file.readAsStringSync();

      expect(afterSecond, afterFirst);
    });

    test('skips when file does not exist', () {
      // Should not throw
      InfoPlistModifier.modify('${tempDir.path}/nonexistent.plist');
    });

    test('does not modify file in dry-run mode', () {
      final file = File('${tempDir.path}/Info.plist');
      file.writeAsStringSync(_plistWithDisplayName);

      InfoPlistModifier.modify(file.path, dryRun: true);

      expect(file.readAsStringSync(), _plistWithDisplayName);
    });
  });
}
