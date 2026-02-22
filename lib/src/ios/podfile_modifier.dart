import 'dart:io';

import '../models/flavor_config.dart';

/// iOS Podfile에 flavor별 빌드 모드 매핑을 추가하는 클래스입니다.
///
/// Flutter iOS 프로젝트의 Podfile에는 빌드 구성(configuration) 이름을
/// CocoaPods 빌드 모드(:debug / :release)로 매핑하는 코드가 있습니다.
/// flavor를 추가하면 "Debug-dev", "Release-dev" 같은 새로운 구성 이름이 생기므로,
/// 이 매핑에도 해당 항목을 추가해야 합니다.
///
/// 삽입 위치: `'Release' => :release,` 줄 바로 뒤
///
/// 추가 예시:
/// ```ruby
/// 'Debug-dev' => :debug,
/// 'Profile-dev' => :release,
/// 'Release-dev' => :release,
/// ```
class PodfileModifier {
  /// Podfile에 flavor별 빌드 모드 매핑을 추가합니다.
  ///
  /// - Podfile이 없으면 건너뜁니다.
  /// - 이미 flavor 매핑이 존재하면 중복 삽입을 방지합니다 (멱등성 보장).
  /// - `'Release' => :release,` 마커를 찾을 수 없으면 건너뜁니다.
  static void modify(
    String podfilePath,
    Map<String, FlavorConfig> flavors, {
    bool dryRun = false,
  }) {
    final file = File(podfilePath);
    if (!file.existsSync()) {
      print('  Podfile not found at $podfilePath, skipping.');
      return;
    }

    var content = file.readAsStringSync();

    // 멱등성 가드: 첫 번째 flavor의 매핑이 이미 존재하면 건너뜀
    final firstFlavor = flavors.keys.first;
    if (content.contains("'Debug-$firstFlavor'")) {
      print('  Podfile already configured for flavor "$firstFlavor", skipping.');
      return;
    }

    // 삽입 위치 마커: Flutter가 기본으로 생성하는 빌드 모드 매핑의 마지막 줄
    const marker = "'Release' => :release,";
    if (!content.contains(marker)) {
      print('  Could not find "$marker" in Podfile, skipping.');
      return;
    }

    // 각 flavor에 대해 Debug → :debug, Profile/Release → :release 매핑 생성
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
}
