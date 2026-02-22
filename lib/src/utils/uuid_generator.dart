import 'dart:math';

/// Xcode 프로젝트에서 사용하는 UUID를 생성하는 유틸리티 클래스입니다.
///
/// Xcode의 project.pbxproj 파일은 24자리 대문자 16진수 문자열을
/// 오브젝트 식별자로 사용합니다. (예: "33CC10EC2044A3C60003C045")
class UuidGenerator {
  static final _random = Random.secure();

  /// 24자리 대문자 16진수 문자열(Xcode UUID 형식)을 생성합니다.
  ///
  /// 암호학적으로 안전한 난수 생성기([Random.secure])를 사용하여
  /// 기존 UUID와 충돌할 가능성을 최소화합니다.
  static String generate() {
    final buffer = StringBuffer();
    for (int i = 0; i < 24; i++) {
      buffer.write(_random.nextInt(16).toRadixString(16).toUpperCase());
    }
    return buffer.toString();
  }
}
