/// Represents all exceptions thrown by the easy_setup tool.
///
/// Thrown in error situations that need to be reported to the user,
/// such as file not found, YAML parsing failure, or pbxproj structure issues.
class SetupException implements Exception {
  final String message;
  SetupException(this.message);

  @override
  String toString() => 'SetupException: $message';
}
