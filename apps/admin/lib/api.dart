import 'dart:async';
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
  final _live = StreamController<String>.broadcast();
  bool _listening = false;
  bool _stopLive = false;

  /// Topic names from GET /api/v1/admin/events (`users`, `payments`).
  Stream<String> get live => _live.stream;

  String _key() => List.generate(
      16, (_) => _rand.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final req = http.Request(method, Uri.parse('$baseUrl$path'));
    req.headers['Content-Type'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (method != 'GET') req.headers['Idempotency-Key'] = _key();
    if (body != null) req.body = jsonEncode(body);
    final resp = await http.Response.fromStream(await req.send());
    final decoded = _decode(resp);
    if (resp.statusCode >= 400) {
      final m = decoded is Map ? decoded : const {};
      final detail = m['detail'] ?? m['error'];
      throw Exception(detail is String && detail.isNotEmpty
          ? '${resp.statusCode}: $detail'
          : '${resp.statusCode}: ${resp.body.trim().isEmpty ? 'error' : _snippet(resp.body)}');
    }
    return decoded;
  }

  static String _snippet(String body) {
    final t = body.trim().replaceAll(RegExp(r'\s+'), ' ');
    return t.length > 160 ? '${t.substring(0, 160)}…' : t;
  }

  static dynamic _decode(http.Response resp) {
    final body = resp.body;
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      throw Exception(
          '${resp.statusCode}: server returned non-JSON (${_snippet(body)})');
    }
  }

  Future<void> login(String email, String password) async {
    final res = await _send('POST', '/api/v1/auth/login',
        {'email': email, 'password': password});
    token = (res as Map)['token'] as String?;
    if (token == null) throw Exception('No token returned');
  }

  /// Opens a reconnecting SSE stream. Call after login; [stopLive] on logout.
  void startLive() {
    if (_listening || token == null) return;
    _listening = true;
    _stopLive = false;
    () async {
      while (!_stopLive && token != null) {
        try {
          await _pumpEvents();
        } catch (_) {}
        if (_stopLive || token == null) break;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      _listening = false;
    }();
  }

  void stopLive() {
    _stopLive = true;
  }

  Future<void> _pumpEvents() async {
    final req = http.Request('GET', Uri.parse('$baseUrl/api/v1/admin/events'));
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.headers['Accept'] = 'text/event-stream';
    req.headers['Cache-Control'] = 'no-cache';
    final resp = await req.send();
    if (resp.statusCode >= 400) {
      throw Exception('sse ${resp.statusCode}');
    }
    var carry = '';
    await for (final chunk in resp.stream.transform(utf8.decoder)) {
      if (_stopLive) return;
      carry += chunk;
      var idx = carry.indexOf('\n\n');
      while (idx >= 0) {
        final block = carry.substring(0, idx);
        carry = carry.substring(idx + 2);
        for (final raw in block.split('\n')) {
          final line = raw.trimRight();
          if (!line.startsWith('data:')) continue;
          final data = line.substring(5).trim();
          if (data.isEmpty) continue;
          var topic = data;
          try {
            final decoded = jsonDecode(data);
            if (decoded is Map && decoded['topic'] is String) {
              topic = decoded['topic'] as String;
            }
          } catch (_) {}
          if (topic == 'hello') continue;
          _live.add(topic);
        }
        idx = carry.indexOf('\n\n');
      }
    }
  }

  Future<List<Map<String, dynamic>>> listUsers() async {
    final res = await _send('GET', '/api/v1/admin/users');
    final users = (res as Map)['users'] as List? ?? const [];
    return users.cast<Map<String, dynamic>>();
  }

  Future<void> setApproval(String id, bool approved) =>
      _send('POST', '/api/v1/admin/users/$id/approve', {'approved': approved});

  Future<void> setBan(String id, bool banned) =>
      _send('POST', '/api/v1/admin/users/$id/ban', {'banned': banned});

  Future<void> deleteUser(String id) =>
      _send('POST', '/api/v1/admin/users/$id/delete');

  Future<String> resetPassword(String id, [String password = '']) async {
    final res = await _send(
        'POST', '/api/v1/admin/users/$id/password', {'password': password});
    return (res as Map)['password'] as String? ?? '';
  }

  Future<List<Map<String, dynamic>>> listPayments([String? status]) async {
    final q = (status == null || status.isEmpty) ? '' : '?status=$status';
    final res = await _send('GET', '/api/v1/admin/payments$q');
    final payments = (res as Map)['payments'] as List? ?? const [];
    return payments.cast<Map<String, dynamic>>();
  }

  Future<void> approvePayment(String id) =>
      _send('POST', '/api/v1/admin/payments/$id/approve');

  Future<void> rejectPayment(String id, [String note = '']) =>
      _send('POST', '/api/v1/admin/payments/$id/reject', {'note': note});

  Future<Map<String, dynamic>> catalog() async =>
      (await _send('GET', '/api/v1/admin/catalog')) as Map<String, dynamic>;

  Future<void> updatePlan(String id,
      {int? priceMmk, int? monthlyCredits}) async {
    await _send('PATCH', '/api/v1/admin/catalog/plans/$id', {
      ?'priceMmk': priceMmk,
      ?'monthlyCredits': monthlyCredits,
    });
  }

  Future<void> updatePack(String id, {int? credits, int? priceMmk}) async {
    await _send('PATCH', '/api/v1/admin/catalog/packs/$id', {
      ?'credits': credits,
      ?'priceMmk': priceMmk,
    });
  }

  Future<void> addPack(int credits, int priceMmk) =>
      _send('POST', '/api/v1/admin/catalog/packs',
          {'credits': credits, 'priceMmk': priceMmk});

  Future<void> removePack(String id) =>
      _send('DELETE', '/api/v1/admin/catalog/packs/$id');
}
