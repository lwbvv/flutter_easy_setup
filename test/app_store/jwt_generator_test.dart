import 'package:easy_setup/easy_setup.dart';
import 'package:test/test.dart';

void main() {
  group('JwtGenerator', () {
    test('throws SetupException when key file does not exist', () {
      expect(
        () => JwtGenerator.generate(
          keyId: 'KEY_ID',
          issuerId: 'ISSUER_ID',
          privateKeyPath: '/nonexistent/AuthKey.p8',
        ),
        throwsA(isA<SetupException>()),
      );
    });

    test('throws SetupException with helpful message for missing key', () {
      try {
        JwtGenerator.generate(
          keyId: 'KEY_ID',
          issuerId: 'ISSUER_ID',
          privateKeyPath: '/nonexistent/AuthKey.p8',
        );
        fail('Expected SetupException');
      } on SetupException catch (e) {
        expect(e.message, contains('API Key file not found'));
        expect(e.message, contains('/nonexistent/AuthKey.p8'));
      }
    });
  });
}
