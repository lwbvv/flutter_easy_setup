import 'package:easy_setup/easy_setup.dart';
import 'package:test/test.dart';

void main() {
  group('UuidGenerator', () {
    test('generates a 24-character string', () {
      final uuid = UuidGenerator.generate();
      expect(uuid.length, 24);
    });

    test('contains only uppercase hex characters', () {
      final uuid = UuidGenerator.generate();
      expect(uuid, matches(RegExp(r'^[0-9A-F]{24}$')));
    });

    test('generates unique values on successive calls', () {
      final uuid1 = UuidGenerator.generate();
      final uuid2 = UuidGenerator.generate();
      expect(uuid1, isNot(equals(uuid2)));
    });

    test('multiple generations all match hex format', () {
      for (var i = 0; i < 20; i++) {
        final uuid = UuidGenerator.generate();
        expect(uuid.length, 24);
        expect(uuid, matches(RegExp(r'^[0-9A-F]{24}$')));
      }
    });
  });
}
