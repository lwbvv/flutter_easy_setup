import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import '../exceptions.dart';

/// App Store Connect API 인증을 위한 JWT 토큰을 생성합니다.
///
/// ES256 알고리즘으로 .p8 키 파일을 사용하여 서명합니다.
class JwtGenerator {
  /// JWT 토큰을 생성합니다.
  ///
  /// [keyId]: App Store Connect API Key ID (JWT header `kid`)
  /// [issuerId]: API Key Issuer ID (JWT payload `iss`)
  /// [privateKeyPath]: .p8 키 파일의 절대 경로
  /// [duration]: 토큰 유효 기간 (초, 기본 1200 = 20분)
  static String generate({
    required String keyId,
    required String issuerId,
    required String privateKeyPath,
    int duration = 1200,
  }) {
    final keyFile = File(privateKeyPath);
    if (!keyFile.existsSync()) {
      throw SetupException(
        'API Key file not found: $privateKeyPath\n'
        'Place your App Store Connect .p8 key file at this path.',
      );
    }

    final privateKeyPem = keyFile.readAsStringSync().trim();

    final jwt = JWT(
      {'iss': issuerId, 'aud': 'appstoreconnect-v1'},
      header: {'kid': keyId},
    );

    return jwt.sign(
      ECPrivateKey(privateKeyPem),
      algorithm: JWTAlgorithm.ES256,
      expiresIn: Duration(seconds: duration),
    );
  }
}
