import 'dart:io';

import '../exceptions.dart';
import '../models/flavor_config.dart';

/// Android의 build.gradle(.kts) 파일에 flavor 설정을 추가하는 클래스입니다.
///
/// buildTypes 블록 바로 뒤에 flavorDimensions와 productFlavors 블록을 삽입합니다.
/// Groovy DSL(.gradle)과 Kotlin DSL(.kts) 양쪽 문법을 모두 지원합니다.
class BuildGradleModifier {
  /// build.gradle 파일을 읽고 flavor 설정을 삽입합니다.
  ///
  /// - 파일이 없으면 건너뜁니다 (Android 프로젝트가 아닐 수 있음).
  /// - 이미 flavorDimensions가 있으면 중복 삽입을 방지합니다 (멱등성 보장).
  /// - buildTypes 블록의 닫는 중괄호를 찾아 그 뒤에 flavor 설정을 삽입합니다.
  static void modify(
    String gradlePath,
    Map<String, FlavorConfig> flavors, {
    bool dryRun = false,
  }) {
    final file = File(gradlePath);
    if (!file.existsSync()) {
      print('  Android build.gradle not found at $gradlePath, skipping.');
      return;
    }

    var content = file.readAsStringSync();
    final isKts = gradlePath.endsWith('.kts');

    // 멱등성 가드: 이미 설정되어 있으면 건너뜀
    if (content.contains('flavorDimensions')) {
      print('  Android build.gradle already has flavorDimensions, skipping.');
      return;
    }

    // buildTypes { ... } 블록의 위치를 찾음
    final buildTypesMatch = RegExp(r'\bbuildTypes\s*\{').firstMatch(content);
    if (buildTypesMatch == null) {
      print('  buildTypes block not found in build.gradle, skipping Android setup.');
      return;
    }

    // 여는 중괄호 위치로부터 짝이 맞는 닫는 중괄호를 탐색
    final openBrace = content.indexOf('{', buildTypesMatch.start);
    final blockEnd = _findBlockEnd(content, openBrace);
    if (blockEnd == -1) {
      throw SetupException('Could not find end of buildTypes block in build.gradle');
    }

    // signingConfigs 블록 삽입 (signing이 있는 flavor가 있으면)
    final signingBlock = _buildSigningConfigsBlock(flavors, isKts);
    final hasSigningConfigsBlock = RegExp(r'\bsigningConfigs\s*\{').hasMatch(content);
    if (signingBlock != null && !hasSigningConfigsBlock) {
      // android { 블록 내, buildTypes 앞에 삽입
      content = '${content.substring(0, buildTypesMatch.start)}$signingBlock\n    ${content.substring(buildTypesMatch.start)}';
      // buildTypes 위치가 바뀌었으므로 다시 찾음
      final newBuildTypesMatch = RegExp(r'\bbuildTypes\s*\{').firstMatch(content)!;
      final newOpenBrace = content.indexOf('{', newBuildTypesMatch.start);
      final newBlockEnd = _findBlockEnd(content, newOpenBrace);
      if (newBlockEnd == -1) {
        throw SetupException('Could not find end of buildTypes block in build.gradle');
      }

      final flavorBlock = _buildFlavorBlock(flavors, isKts);
      content =
          '${content.substring(0, newBlockEnd + 1)}\n\n$flavorBlock${content.substring(newBlockEnd + 1)}';
    } else {
      // buildTypes 블록 바로 뒤에 flavor 설정 블록을 삽입
      final flavorBlock = _buildFlavorBlock(flavors, isKts);
      content =
          '${content.substring(0, blockEnd + 1)}\n\n$flavorBlock${content.substring(blockEnd + 1)}';
    }

    if (dryRun) {
      print('  [dry-run] Would write Android flavor config to ${file.path}');
      return;
    }

    file.writeAsStringSync(content);
    print('  Wrote Android flavor config to ${file.path}');
  }

  // ---- 내부 헬퍼 메서드 ----

  /// 중괄호 깊이(depth)를 추적하여 짝이 맞는 닫는 중괄호의 인덱스를 반환합니다.
  static int _findBlockEnd(String content, int openBraceIndex) {
    int depth = 0;
    for (int i = openBraceIndex; i < content.length; i++) {
      final ch = content[i];
      if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  /// signing이 있는 flavor들에 대해 signingConfigs 블록을 생성합니다.
  /// signing이 있는 flavor가 없으면 null을 반환합니다.
  static String? _buildSigningConfigsBlock(
    Map<String, FlavorConfig> flavors,
    bool isKts,
  ) {
    final signingFlavors = flavors.entries
        .where((e) => e.value.signing != null)
        .toList();
    if (signingFlavors.isEmpty) return null;

    final sb = StringBuffer();
    if (isKts) {
      sb.writeln('    signingConfigs {');
      for (final entry in signingFlavors) {
        final flavor = entry.key;
        final signing = entry.value.signing!;
        sb.writeln('        create("$flavor") {');
        sb.writeln('            storeFile = file("${signing.keystore}")');
        sb.writeln('            keyAlias = "${signing.alias}"');
        sb.writeln('        }');
      }
      sb.writeln('    }');
    } else {
      sb.writeln('    signingConfigs {');
      for (final entry in signingFlavors) {
        final flavor = entry.key;
        final signing = entry.value.signing!;
        sb.writeln('        $flavor {');
        sb.writeln('            storeFile file("${signing.keystore}")');
        sb.writeln('            keyAlias "${signing.alias}"');
        sb.writeln('        }');
      }
      sb.writeln('    }');
    }
    return sb.toString();
  }

  /// flavor 설정을 위한 Gradle 코드 블록을 생성합니다.
  ///
  /// [isKts]가 true이면 Kotlin DSL 문법으로, false이면 Groovy DSL 문법으로 생성합니다.
  static String _buildFlavorBlock(
    Map<String, FlavorConfig> flavors,
    bool isKts,
  ) {
    final sb = StringBuffer();
    if (isKts) {
      // Kotlin DSL 문법
      sb.writeln('    flavorDimensions += listOf("env")');
      sb.writeln('    productFlavors {');
      for (final entry in flavors.entries) {
        final flavor = entry.key;
        final config = entry.value;
        sb.writeln('        create("$flavor") {');
        sb.writeln('            dimension = "env"');
        sb.writeln('            applicationId = "${config.bundleId}"');
        sb.writeln('            resValue("string", "app_name", "${config.name}")');
        if (config.versionCode != null) {
          sb.writeln('            versionCode = ${config.versionCode}');
        }
        if (config.versionName != null) {
          sb.writeln('            versionName = "${config.versionName}"');
        }
        sb.writeln('            manifestPlaceholders += mapOf("appName" to "${config.name}")');
        if (config.signing != null) {
          sb.writeln('            signingConfig = signingConfigs.getByName("$flavor")');
        }
        sb.writeln('        }');
      }
      sb.writeln('    }');
    } else {
      // Groovy DSL 문법
      sb.writeln('    flavorDimensions "env"');
      sb.writeln('    productFlavors {');
      for (final entry in flavors.entries) {
        final flavor = entry.key;
        final config = entry.value;
        sb.writeln('        $flavor {');
        sb.writeln('            dimension "env"');
        sb.writeln('            applicationId "${config.bundleId}"');
        sb.writeln('            resValue "string", "app_name", "${config.name}"');
        if (config.versionCode != null) {
          sb.writeln('            versionCode ${config.versionCode}');
        }
        if (config.versionName != null) {
          sb.writeln('            versionName "${config.versionName}"');
        }
        sb.writeln('            manifestPlaceholders = [appName: "${config.name}"]');
        if (config.signing != null) {
          sb.writeln('            signingConfig signingConfigs.$flavor');
        }
        sb.writeln('        }');
      }
      sb.writeln('    }');
    }
    return sb.toString();
  }
}
