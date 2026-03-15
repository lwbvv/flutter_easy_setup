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

    test('creates Podfile with permission macros when file does not exist', () {
      final file = File('${tempDir.path}/Podfile');

      PodfileModifier.modify(file.path, flavors, permission: {
        'NSCameraUsageDescription': 'Camera needed',
        'NSPhotoLibraryUsageDescription': 'Photos needed',
      });

      final result = file.readAsStringSync();
      expect(result, contains("'PERMISSION_CAMERA=1'"));
      expect(result, contains("'PERMISSION_PHOTOS=1'"));
      expect(result, contains("GCC_PREPROCESSOR_DEFINITIONS"));
    });

    test('adds permission macros to existing Podfile with post_install', () {
      final file = File('${tempDir.path}/Podfile');
      final podfileWithPostInstall = '''
platform :ios, '12.0'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

target 'Runner' do
  use_frameworks!
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
  end
end
''';
      file.writeAsStringSync(podfileWithPostInstall);

      PodfileModifier.modify(file.path, flavors, permission: {
        'NSCameraUsageDescription': 'Camera needed',
        'NSMicrophoneUsageDescription': 'Mic needed',
      });

      final result = file.readAsStringSync();
      expect(result, contains("'PERMISSION_CAMERA=1'"));
      expect(result, contains("'PERMISSION_MICROPHONE=1'"));
    });

    test('permission macros are idempotent', () {
      final file = File('${tempDir.path}/Podfile');

      PodfileModifier.modify(file.path, flavors, permission: {
        'NSCameraUsageDescription': 'Camera needed',
      });
      final first = file.readAsStringSync();

      PodfileModifier.modify(file.path, flavors, permission: {
        'NSCameraUsageDescription': 'Camera needed',
      });
      final second = file.readAsStringSync();

      expect(second, first);
    });

    test('maps all known permission keys correctly', () {
      final file = File('${tempDir.path}/Podfile');

      PodfileModifier.modify(file.path, flavors, permission: {
        'NSCameraUsageDescription': 'x',
        'NSMicrophoneUsageDescription': 'x',
        'NSLocationWhenInUseUsageDescription': 'x',
        'NSContactsUsageDescription': 'x',
        'NSSpeechRecognitionUsageDescription': 'x',
        'NSBluetoothAlwaysUsageDescription': 'x',
        'NSUserTrackingUsageDescription': 'x',
      });

      final result = file.readAsStringSync();
      expect(result, contains('PERMISSION_CAMERA=1'));
      expect(result, contains('PERMISSION_MICROPHONE=1'));
      expect(result, contains('PERMISSION_LOCATION_WHENINUSE=1'));
      expect(result, contains('PERMISSION_CONTACTS=1'));
      expect(result, contains('PERMISSION_SPEECH_RECOGNIZER=1'));
      expect(result, contains('PERMISSION_BLUETOOTH=1'));
      expect(result, contains('PERMISSION_APP_TRACKING_TRANSPARENCY=1'));
    });

    test('sets IPHONEOS_DEPLOYMENT_TARGET in post_install', () {
      final file = File('${tempDir.path}/Podfile');

      PodfileModifier.modify(file.path, flavors);

      final result = file.readAsStringSync();
      expect(result, contains("IPHONEOS_DEPLOYMENT_TARGET"));
      expect(result, contains("'15.0'"));
    });

    test('uses custom ios_version for platform and deployment target', () {
      final file = File('${tempDir.path}/Podfile');

      PodfileModifier.modify(file.path, flavors, iosVersion: '16.0');

      final result = file.readAsStringSync();
      expect(result, contains("platform :ios, '16.0'"));
      expect(result,
          contains("config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'"));
    });
  });
}
