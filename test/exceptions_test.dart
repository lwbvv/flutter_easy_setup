import 'package:easy_setup/easy_setup.dart';
import 'package:test/test.dart';

void main() {
  group('SetupException', () {
    test('stores message', () {
      final e = SetupException('something went wrong');
      expect(e.message, 'something went wrong');
    });

    test('toString() includes class name and message', () {
      final e = SetupException('file not found');
      expect(e.toString(), 'SetupException: file not found');
    });

    test('implements Exception', () {
      final e = SetupException('test');
      expect(e, isA<Exception>());
    });
  });
}
