import 'dart:io';

import '../models/flavor_config.dart';

/// iOS Podfile을 생성하거나 수정하는 클래스입니다.
///
/// Podfile이 없으면 Flutter 표준 Podfile을 생성하고,
/// 있으면 기존 Podfile에 flavor별 빌드 모드 매핑을 추가합니다.
///
/// permission이 제공되면 post_install 블록에
/// GCC_PREPROCESSOR_DEFINITIONS로 permission_handler 매크로를 추가합니다.
class PodfileModifier {
  /// Info.plist permission 키 → permission_handler GCC 매크로 매핑
  static const _permissionMacroMap = <String, String>{
    'NSCameraUsageDescription': 'PERMISSION_CAMERA=1',
    'NSMicrophoneUsageDescription': 'PERMISSION_MICROPHONE=1',
    'NSPhotoLibraryUsageDescription': 'PERMISSION_PHOTOS=1',
    'NSPhotoLibraryAddUsageDescription': 'PERMISSION_PHOTOS=1',
    'NSLocationWhenInUseUsageDescription': 'PERMISSION_LOCATION_WHENINUSE=1',
    'NSLocationAlwaysAndWhenInUseUsageDescription': 'PERMISSION_LOCATION=1',
    'NSLocationAlwaysUsageDescription': 'PERMISSION_LOCATION=1',
    'NSContactsUsageDescription': 'PERMISSION_CONTACTS=1',
    'NSCalendarsUsageDescription': 'PERMISSION_EVENTS=1',
    'NSCalendarsFullAccessUsageDescription': 'PERMISSION_EVENTS_FULL_ACCESS=1',
    'NSCalendarsWriteOnlyAccessUsageDescription': 'PERMISSION_EVENTS=1',
    'NSRemindersUsageDescription': 'PERMISSION_REMINDERS=1',
    'NSRemindersFullAccessUsageDescription': 'PERMISSION_REMINDERS=1',
    'NSSpeechRecognitionUsageDescription': 'PERMISSION_SPEECH_RECOGNIZER=1',
    'NSMotionUsageDescription': 'PERMISSION_SENSORS=1',
    'NSBluetoothAlwaysUsageDescription': 'PERMISSION_BLUETOOTH=1',
    'NSBluetoothPeripheralUsageDescription': 'PERMISSION_BLUETOOTH=1',
    'NSAppleMusicUsageDescription': 'PERMISSION_MEDIA_LIBRARY=1',
    'NSUserTrackingUsageDescription': 'PERMISSION_APP_TRACKING_TRANSPARENCY=1',
    'NSFaceIDUsageDescription': 'PERMISSION_SENSORS=1',
  };

  /// Podfile을 생성하거나 수정합니다.
  ///
  /// [permission]: easy_setup.yaml의 permission 맵 (키를 기반으로 매크로 매핑)
  /// [iosVersion]: iOS minimum deployment target (예: "15.0")
  static void modify(
    String podfilePath,
    Map<String, FlavorConfig> flavors, {
    Map<String, String>? permission,
    String? iosVersion,
    bool dryRun = false,
  }) {
    final version = iosVersion ?? '15.0';
    final file = File(podfilePath);

    if (!file.existsSync()) {
      _createPodfile(file, flavors,
          permission: permission, iosVersion: version, dryRun: dryRun);
      return;
    }

    _modifyExistingPodfile(file, flavors,
        permission: permission, iosVersion: version, dryRun: dryRun);
  }

  /// permission 키들로부터 필요한 GCC 매크로 목록을 생성합니다.
  static Set<String> _resolveMacros(Map<String, String>? permission) {
    if (permission == null || permission.isEmpty) return {};
    final macros = <String>{};
    for (final key in permission.keys) {
      final macro = _permissionMacroMap[key];
      if (macro != null) {
        macros.add(macro);
      }
    }
    return macros;
  }

  /// post_install 블록을 생성합니다.
  static String _buildPostInstall(Set<String> macros, String iosVersion) {
    final sb = StringBuffer();
    sb.writeln('post_install do |installer|');
    sb.writeln('  installer.pods_project.targets.each do |target|');
    sb.writeln('    flutter_additional_ios_build_settings(target)');
    sb.writeln('');
    sb.writeln('    target.build_configurations.each do |config|');

    if (macros.isNotEmpty) {
      sb.writeln(
          "      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [");
      sb.writeln("        '\$(inherited)',");
      for (final macro in macros) {
        sb.writeln("        '$macro',");
      }
      sb.writeln('      ]');
    }

    sb.writeln(
        "      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '$iosVersion'");
    sb.writeln('    end');

    sb.writeln('  end');
    sb.writeln('end');
    return sb.toString();
  }

  /// Flutter 표준 Podfile을 생성합니다.
  static void _createPodfile(
    File file,
    Map<String, FlavorConfig> flavors, {
    Map<String, String>? permission,
    required String iosVersion,
    required bool dryRun,
  }) {
    final configBlock = _buildConfigBlock(flavors);
    final macros = _resolveMacros(permission);
    final postInstall = _buildPostInstall(macros, iosVersion);

    final content = '''# Uncomment this line to define a global platform for your project
platform :ios, '$iosVersion'

# CocoaPods analytics sends network stats synchronously affecting flutter build latency.
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
$configBlock
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure flutter pub get is executed first"
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. Try deleting Generated.xcconfig, then run flutter pub get"
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  target 'RunnerTests' do
    inherit! :search_paths
  end
end

$postInstall''';

    if (dryRun) {
      print('  [dry-run] Would create Podfile: ${file.path}');
      return;
    }

    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    print('  Created Podfile: ${file.path}');
  }

  /// 기존 Podfile에 flavor별 빌드 모드 매핑과 permission 매크로를 추가합니다.
  static void _modifyExistingPodfile(
    File file,
    Map<String, FlavorConfig> flavors, {
    Map<String, String>? permission,
    required String iosVersion,
    required bool dryRun,
  }) {
    var content = file.readAsStringSync();

    // 1. platform :ios 버전 업데이트
    content = _applyPlatformVersion(content, iosVersion);

    // 2. flavor 매핑 처리
    content = _applyFlavorMappings(content, flavors);

    // 3. permission 매크로 + IPHONEOS_DEPLOYMENT_TARGET 처리
    final macros = _resolveMacros(permission);
    content = _applyPostInstallConfig(content, macros, iosVersion);

    if (dryRun) {
      print('  [dry-run] Would update Podfile.');
      return;
    }

    file.writeAsStringSync(content);
    print('  Updated Podfile with flavor mappings and permission macros.');
  }

  /// platform :ios 버전을 업데이트합니다.
  static String _applyPlatformVersion(String content, String iosVersion) {
    final pattern = RegExp(r"platform\s*:ios\s*,\s*'[^']*'");
    if (pattern.hasMatch(content)) {
      return content.replaceFirst(pattern, "platform :ios, '$iosVersion'");
    }
    return content;
  }

  /// flavor 매핑을 적용합니다.
  static String _applyFlavorMappings(
      String content, Map<String, FlavorConfig> flavors) {
    // 기존 flavor 매핑이 있으면 제거 후 재생성
    content = content.replaceAll(
      RegExp(r"  '(?:Debug|Profile|Release)-[^']+' => :(?:debug|release),\n"),
      '',
    );

    const marker = "'Release' => :release,";
    if (!content.contains(marker)) {
      print('  Could not find "$marker" in Podfile, skipping flavor mappings.');
      return content;
    }

    final sb = StringBuffer();
    for (final flavor in flavors.keys) {
      sb.writeln("  'Debug-$flavor' => :debug,");
      sb.writeln("  'Profile-$flavor' => :release,");
      sb.writeln("  'Release-$flavor' => :release,");
    }

    return content.replaceFirst(
      marker,
      "$marker\n${sb.toString().trimRight()}",
    );
  }

  /// post_install 블록 전체를 교체합니다.
  static String _applyPostInstallConfig(
      String content, Set<String> macros, String iosVersion) {
    // post_install 블록 전체를 찾아서 교체
    final postInstallBlock = RegExp(
      r'post_install do \|installer\|[\s\S]*?^end\n?',
      multiLine: true,
    );

    final newPostInstall = _buildPostInstall(macros, iosVersion);

    if (postInstallBlock.hasMatch(content)) {
      return content.replaceFirst(postInstallBlock, newPostInstall);
    }

    // post_install이 없으면 끝에 추가
    return '$content\n$newPostInstall';
  }

  /// target.build_configurations.each 블록을 생성합니다.
  static String _buildConfigIterationBlock(
      Set<String> macros, String iosVersion) {
    final sb = StringBuffer();
    sb.writeln('    target.build_configurations.each do |config|');

    if (macros.isNotEmpty) {
      sb.writeln(
          "      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [");
      sb.writeln("        '\$(inherited)',");
      for (final macro in macros) {
        sb.writeln("        '$macro',");
      }
      sb.writeln('      ]');
    }

    sb.writeln(
        "      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '$iosVersion'");
    sb.writeln('    end');
    return sb.toString();
  }

  /// project 'Runner' 블록 내용을 생성합니다.
  static String _buildConfigBlock(Map<String, FlavorConfig> flavors) {
    final sb = StringBuffer();
    for (final flavor in flavors.keys) {
      sb.writeln("  'Debug-$flavor' => :debug,");
      sb.writeln("  'Profile-$flavor' => :release,");
      sb.writeln("  'Release-$flavor' => :release,");
    }
    return sb.toString().trimRight();
  }
}
