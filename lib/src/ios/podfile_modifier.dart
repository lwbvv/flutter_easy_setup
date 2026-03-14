import 'dart:io';

import '../models/flavor_config.dart';

/// iOS Podfile을 생성하거나 수정하는 클래스입니다.
///
/// Podfile이 없으면 Flutter 표준 Podfile을 생성하고,
/// 있으면 기존 Podfile에 flavor별 빌드 모드 매핑을 추가합니다.
///
/// project 'Runner' 블록에 각 flavor의 빌드 구성을 매핑합니다:
///   - Debug-{flavor}   → :debug
///   - Profile-{flavor}  → :release
///   - Release-{flavor}  → :release
class PodfileModifier {
  /// Podfile을 생성하거나 수정합니다.
  ///
  /// - Podfile이 없으면 Flutter 표준 Podfile을 생성하며, flavor 매핑을 포함합니다.
  /// - Podfile이 있으면 기존 파일에 flavor 매핑을 추가/갱신합니다.
  static void modify(
    String podfilePath,
    Map<String, FlavorConfig> flavors, {
    bool dryRun = false,
  }) {
    final file = File(podfilePath);

    if (!file.existsSync()) {
      _createPodfile(file, flavors, dryRun: dryRun);
      return;
    }

    _modifyExistingPodfile(file, flavors, dryRun: dryRun);
  }

  /// Flutter 표준 Podfile을 생성합니다.
  static void _createPodfile(
    File file,
    Map<String, FlavorConfig> flavors, {
    required bool dryRun,
  }) {
    final configBlock = _buildConfigBlock(flavors);

    final content = '''# Uncomment this line to define a global platform for your project
# platform :ios, '13.0'

# CocoaPods analytics sends network stats synchronously affecting flutter build latency.
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
$configBlock}

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

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
  end
end
''';

    if (dryRun) {
      print('  [dry-run] Would create Podfile: ${file.path}');
      return;
    }

    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    print('  Created Podfile: ${file.path}');
  }

  /// 기존 Podfile에 flavor별 빌드 모드 매핑을 추가합니다.
  static void _modifyExistingPodfile(
    File file,
    Map<String, FlavorConfig> flavors, {
    required bool dryRun,
  }) {
    var content = file.readAsStringSync();

    // 기존 flavor 매핑이 있으면 제거 후 재생성
    content = content.replaceAll(
      RegExp(r"  '(?:Debug|Profile|Release)-[^']+' => :(?:debug|release),\n"),
      '',
    );

    // 삽입 위치 마커: Flutter가 기본으로 생성하는 빌드 모드 매핑의 마지막 줄
    const marker = "'Release' => :release,";
    if (!content.contains(marker)) {
      print('  Could not find "$marker" in Podfile, skipping.');
      return;
    }

    // 각 flavor에 대해 매핑 생성
    final sb = StringBuffer();
    for (final flavor in flavors.keys) {
      sb.writeln("  'Debug-$flavor' => :debug,");
      sb.writeln("  'Profile-$flavor' => :release,");
      sb.writeln("  'Release-$flavor' => :release,");
    }

    // 마커 줄 바로 뒤에 새 매핑 삽입
    content = content.replaceFirst(
      marker,
      "$marker\n${sb.toString().trimRight()}",
    );

    if (dryRun) {
      print('  [dry-run] Would update Podfile with flavor configuration mappings.');
      return;
    }

    file.writeAsStringSync(content);
    print('  Updated Podfile with flavor configuration mappings.');
  }

  /// project 'Runner' 블록 내용을 생성합니다.
  ///
  /// 기본 Debug/Profile/Release + flavor별 매핑을 포함합니다.
  static String _buildConfigBlock(Map<String, FlavorConfig> flavors) {
    final sb = StringBuffer();
    sb.writeln("  'Debug' => :debug,");
    sb.writeln("  'Profile' => :release,");
    sb.writeln("  'Release' => :release,");
    for (final flavor in flavors.keys) {
      sb.writeln("  'Debug-$flavor' => :debug,");
      sb.writeln("  'Profile-$flavor' => :release,");
      sb.writeln("  'Release-$flavor' => :release,");
    }
    return sb.toString().trimRight();
  }
}
