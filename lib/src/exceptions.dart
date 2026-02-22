/// easy_setup 도구에서 발생하는 모든 예외를 나타내는 클래스입니다.
///
/// 파일 미발견, YAML 파싱 실패, pbxproj 구조 이상 등
/// 사용자에게 알려야 하는 오류 상황에서 throw됩니다.
class SetupException implements Exception {
  final String message;
  SetupException(this.message);

  @override
  String toString() => 'SetupException: $message';
}
