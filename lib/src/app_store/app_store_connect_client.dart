import 'dart:convert';
import 'dart:io';

import '../exceptions.dart';

/// App Store Connect API 클라이언트입니다.
///
/// Bundle ID 등록과 앱 생성을 위한 API 호출을 제공합니다.
/// JWT 토큰을 사용하여 인증합니다.
class AppStoreConnectClient {
  final String _jwt;
  static const _baseUrl = 'https://api.appstoreconnect.apple.com/v1';

  AppStoreConnectClient(this._jwt);

  /// Bundle ID가 이미 존재하는지 확인합니다.
  ///
  /// 존재하면 리소스 ID를 반환, 없으면 null을 반환합니다.
  Future<String?> findBundleId(String identifier) async {
    final response = await _get(
      '/bundleIds?filter[identifier]=$identifier'
      '&fields[bundleIds]=identifier',
    );
    final data = response['data'] as List;
    if (data.isEmpty) return null;
    return data.first['id'] as String;
  }

  /// Bundle ID를 생성합니다.
  ///
  /// [identifier]: 번들 식별자 (예: com.example.app)
  /// [name]: Apple Developer에서 표시되는 설명 이름
  /// 생성된 리소스 ID를 반환합니다.
  Future<String> createBundleId(String identifier, String name) async {
    final response = await _post('/bundleIds', {
      'data': {
        'type': 'bundleIds',
        'attributes': {
          'identifier': identifier,
          'name': name,
          'platform': 'IOS',
        },
      },
    });
    return response['data']['id'] as String;
  }

  /// 특정 Bundle ID를 가진 앱이 이미 존재하는지 확인합니다.
  Future<bool> appExists(String bundleId) async {
    final response = await _get(
      '/apps?filter[bundleId]=$bundleId&fields[apps]=bundleId',
    );
    final data = response['data'] as List;
    return data.isNotEmpty;
  }

  /// App Store Connect에 앱을 생성합니다.
  ///
  /// [bundleIdResourceId]: Bundle ID 리소스 ID (findBundleId/createBundleId에서 반환된 값)
  /// [name]: 앱 이름 (App Store에 표시됨)
  /// [sku]: 앱 고유 식별자 (사용자에게 표시되지 않음)
  /// [primaryLocale]: 기본 언어 (기본: en-US)
  Future<void> createApp({
    required String bundleIdResourceId,
    required String name,
    required String sku,
    String primaryLocale = 'en-US',
  }) async {
    await _post('/apps', {
      'data': {
        'type': 'apps',
        'attributes': {
          'name': name,
          'primaryLocale': primaryLocale,
          'sku': sku,
        },
        'relationships': {
          'bundleId': {
            'data': {
              'type': 'bundleIds',
              'id': bundleIdResourceId,
            },
          },
        },
      },
    });
  }

  // ── HTTP 헬퍼 ──────────────────────────────────────────────

  Future<Map<String, dynamic>> _get(String path) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse('$_baseUrl$path'));
      request.headers.set('Authorization', 'Bearer $_jwt');
      request.headers.set('Accept', 'application/json');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode >= 400) {
        _handleError(response.statusCode, body);
      }

      return jsonDecode(body) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> data,
  ) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse('$_baseUrl$path'));
      request.headers.set('Authorization', 'Bearer $_jwt');
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(data));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode >= 400) {
        _handleError(response.statusCode, body);
      }

      return jsonDecode(body) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  Never _handleError(int statusCode, String body) {
    String message;
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final errors = json['errors'] as List?;
      if (errors != null && errors.isNotEmpty) {
        message = errors
            .map((e) => e['detail'] ?? e['title'] ?? '')
            .join(', ');
      } else {
        message = body;
      }
    } catch (_) {
      message = body;
    }
    throw SetupException(
      'App Store Connect API error ($statusCode): $message',
    );
  }
}
