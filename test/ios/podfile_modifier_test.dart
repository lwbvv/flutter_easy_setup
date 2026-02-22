import 'dart:io';

import 'package:easy_setup/src/ios/podfile_modifier.dart';
import 'package:easy_setup/easy_setup.dart';
import 'package:test/test.dart';

const _podfileContent = '''
platform :ios, '12.0'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

target 'Runner' do
  use_frameworks!
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
end
''';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('podfile_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  final flavors = {
    'dev': const FlavorConfig(bundleId: 'com.example.dev', name: 'Dev'),
    'prod': const FlavorConfig(bundleId: 'com.example.prod', name: 'Prod'),
  };

  group('PodfileModifier', () {
    test('adds flavor mappings after Release marker', () {
      final file = File('${tempDir.path}/Podfile');
      file.writeAsStringSync(_podfileContent);

      PodfileModifier.modify(file.path, flavors);

      final result = file.readAsStringSync();
      expect(result, contains("'Debug-dev' => :debug,"));
      expect(result, contains("'Profile-dev' => :release,"));
      expect(result, contains("'Release-dev' => :release,"));
      expect(result, contains("'Debug-prod' => :debug,"));
      expect(result, contains("'Profile-prod' => :release,"));
      expect(result, contains("'Release-prod' => :release,"));
    });

    test('maps Debug to :debug and Profile/Release to :release', () {
      final file = File('${tempDir.path}/Podfile');
      file.writeAsStringSync(_podfileContent);

      PodfileModifier.modify(file.path, {'dev': const FlavorConfig(bundleId: 'x', name: 'X')});

      final result = file.readAsStringSync();
      expect(result, contains("'Debug-dev' => :debug,"));
      expect(result, contains("'Profile-dev' => :release,"));
      expect(result, contains("'Release-dev' => :release,"));
    });

    test('is idempotent — skips when already configured', () {
      final file = File('${tempDir.path}/Podfile');
      file.writeAsStringSync(_podfileContent);

      PodfileModifier.modify(file.path, flavors);
      final afterFirst = file.readAsStringSync();

      PodfileModifier.modify(file.path, flavors);
      final afterSecond = file.readAsStringSync();

      expect(afterSecond, afterFirst);
    });

    test('skips when Release marker is not found', () {
      final file = File('${tempDir.path}/Podfile');
      file.writeAsStringSync('platform :ios, "12.0"\ntarget "Runner" do\nend\n');

      PodfileModifier.modify(file.path, flavors);

      final result = file.readAsStringSync();
      expect(result, isNot(contains('Debug-dev')));
    });

    test('skips when file does not exist', () {
      // Should not throw
      PodfileModifier.modify('${tempDir.path}/nonexistent', flavors);
    });

    test('does not modify file in dry-run mode', () {
      final file = File('${tempDir.path}/Podfile');
      file.writeAsStringSync(_podfileContent);

      PodfileModifier.modify(file.path, flavors, dryRun: true);

      expect(file.readAsStringSync(), _podfileContent);
    });
  });
}
