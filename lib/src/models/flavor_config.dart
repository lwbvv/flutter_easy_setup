import 'dart:io';

import 'package:yaml/yaml.dart';

import '../exceptions.dart';

/// 단일 flavor의 설정값을 담는 모델 클래스입니다.
///
/// [bundleId]: 앱의 고유 식별자 (예: com.example.app.dev)
/// [name]: 사용자에게 보이는 앱 이름 (예: MyApp Dev)
class FlavorConfig {
  final String bundleId;
  final String name;

  const FlavorConfig({required this.bundleId, required this.name});

  /// YAML 맵으로부터 FlavorConfig 인스턴스를 생성합니다.
  ///
  /// 예상되는 YAML 구조:
  /// ```yaml
  /// bundle_id: com.example.app.dev
  /// name: MyApp Dev
  /// ```
  factory FlavorConfig.fromYaml(Map yaml) {
    return FlavorConfig(
      bundleId: yaml['bundle_id'] as String,
      name: yaml['name'] as String,
    );
  }
}

/// easy_setup.yaml 파일 전체를 파싱한 결과를 담는 클래스입니다.
///
/// [flavors]: flavor 이름(dev, prod 등)을 키로, [FlavorConfig]를 값으로 하는 맵
class EasySetupConfig {
  final Map<String, FlavorConfig> flavors;

  const EasySetupConfig({required this.flavors});

  /// [path]에 위치한 easy_setup.yaml 파일을 읽고 파싱합니다.
  ///
  /// 파일이 없으면 사용 예시와 함께 [SetupException]을 throw합니다.
  /// YAML 구문 오류 시에도 [SetupException]을 throw합니다.
  factory EasySetupConfig.fromFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw SetupException(
        'easy_setup.yaml not found at $path\n'
        'Create it with:\n'
        'flavors:\n'
        '  dev:\n'
        '    bundle_id: com.example.app.dev\n'
        '    name: MyApp Dev',
      );
    }
    try {
      final doc = loadYaml(file.readAsStringSync()) as Map;
      final flavorsMap = doc['flavors'] as Map;
      final flavors = <String, FlavorConfig>{};
      for (final entry in flavorsMap.entries) {
        flavors[entry.key as String] = FlavorConfig.fromYaml(entry.value as Map);
      }
      return EasySetupConfig(flavors: flavors);
    } catch (e) {
      if (e is SetupException) rethrow;
      throw SetupException('Failed to parse easy_setup.yaml: $e');
    }
  }
}
