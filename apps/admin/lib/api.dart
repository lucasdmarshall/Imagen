import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

/// Minimal admin API client. Talks to the same Go API as the client app; all
/// /admin/* routes require an admin bearer token (AdminOnly middleware).
class AdminApi {
  AdminApi({String? baseUrl})
      : baseUrl = baseUrl ??
            const String.fromEnvironment('API_BASE_URL',
                defaultValue: 'http://localhost:8080');

  final String baseUrl;
  String? token;
  final _rand = Random.secure();

  String _key() => List.generate(
      16, (_) => _rand.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final req = http.Request(method, Uri.parse('$baseUrl$path'));
    req.headers['Content-Type'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (method != 'GET') req.headers['Idempotency-Key'] = _key();
    if (body != null) req.body = jsonEncode(body);
    final resp = await http.Response.fromStream(await req.send());
    final decoded = resp.body.isEmpty ? null : jsonDecode(resp.body);
    if (resp.statusCode >= 400) {
      final m = decoded is Map ? decoded : const {};
      throw Exception('${resp.statusCode}: ${m['detail'] ?? m['error'] ?? 'error'}');
    }
    return decoded;
  }

  Future<void> login(String email, String password) async {
    final res = await _send('POST', '/api/v1/auth/login',
        {'email': email, 'password': password});
    token = (res as Map)['token'] as String?;
    if (token == null) throw Exception('No token returned');
  }

  Future<List<Map<String, dynamic>>> listUsers() async {
    final res = await _send('GET', '/api/v1/admin/users');
    final users = (res as Map)['users'] as List? ?? const [];
    return users.cast<Map<String, dynamic>>();
  }

  Future<void> setApproval(String id, bool approved) =>
      _send('POST', '/api/v1/admin/users/$id/approve', {'approved': approved});
}
