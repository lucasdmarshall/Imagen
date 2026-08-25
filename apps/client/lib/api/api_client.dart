import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

/// Thrown for non-2xx API responses.
class ApiException implements Exception {
  ApiException(this.status, this.code, this.detail);
  final int status;
  final String code;
  final String detail;
  @override
  String toString() => detail.isNotEmpty ? detail : code;
}

/// Thin client for the SHOW Go API. Base URL is injected at build time:
/// `--dart-define=API_BASE_URL=http://localhost:8080`.
class ApiClient {
  ApiClient({String? baseUrl})
      : baseUrl = baseUrl ??
            const String.fromEnvironment('API_BASE_URL',
                defaultValue: 'http://localhost:8080');

  final String baseUrl;
  String? token;

  static final _rand = Random.secure();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  /// A fresh idempotency key. Retrying a failed request should REUSE the key
  /// from the original attempt; a brand-new user action gets a new one.
  static String newIdempotencyKey() =>
      List.generate(16, (_) => _rand.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

  Future<dynamic> _send(String method, String path,
      [Object? body, String? idempotencyKey]) async {
    final uri = Uri.parse('$baseUrl$path');
    final req = http.Request(method, uri)..headers.addAll(_headers);
    // Mutating requests require an Idempotency-Key (server enforces this).
    if (method != 'GET') {
      req.headers['Idempotency-Key'] = idempotencyKey ?? newIdempotencyKey();
    }
    if (body != null) req.body = jsonEncode(body);
    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    final decoded = resp.body.isEmpty ? null : jsonDecode(resp.body);
    if (resp.statusCode >= 400) {
      final m = decoded is Map ? decoded : const {};
      throw ApiException(resp.statusCode, '${m['error'] ?? 'error'}',
          '${m['detail'] ?? resp.reasonPhrase ?? 'Request failed'}');
    }
    return decoded;
  }

  // --- Auth ---
  Future<Map<String, dynamic>> register(String email, String password, String name) async =>
      (await _send('POST', '/api/v1/auth/register',
          {'email': email, 'password': password, 'displayName': name})) as Map<String, dynamic>;

  Future<Map<String, dynamic>> login(String email, String password) async =>
      (await _send('POST', '/api/v1/auth/login',
          {'email': email, 'password': password})) as Map<String, dynamic>;

  Future<void> logout() => _send('POST', '/api/v1/auth/logout');

  // --- Profile ---
  Future<Map<String, dynamic>> profile() async =>
      (await _send('GET', '/api/v1/profile')) as Map<String, dynamic>;

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> patch) async =>
      (await _send('PATCH', '/api/v1/profile', patch)) as Map<String, dynamic>;

  // --- Credits ---
  Future<int> balance() async =>
      ((await _send('GET', '/api/v1/credits/balance')) as Map)['balance'] as int;

  Future<List<dynamic>> creditHistory() async =>
      ((await _send('GET', '/api/v1/credits/history')) as Map)['transactions'] as List;

  // --- Catalog ---
  Future<List<dynamic>> storeItems() async =>
      ((await _send('GET', '/api/v1/store/items')) as Map)['items'] as List;

  Future<List<dynamic>> plans() async =>
      ((await _send('GET', '/api/v1/subscriptions/plans')) as Map)['plans'] as List;

  Future<List<dynamic>> paymentMethods() async =>
      ((await _send('GET', '/api/v1/payments/methods')) as Map)['methods'] as List;

  Future<Map<String, dynamic>?> mySubscription() async =>
      (await _send('GET', '/api/v1/subscriptions/me')) as Map<String, dynamic>?;

  // --- Notifications ---
  Future<List<dynamic>> notifications() async =>
      ((await _send('GET', '/api/v1/notifications')) as Map)['notifications'] as List;

  Future<void> markRead(String id) => _send('POST', '/api/v1/notifications/$id/read');

  // --- Guided Prompt Engine ---
  Future<Map<String, dynamic>> promptFlow() async =>
      (await _send('GET', '/api/v1/prompts/flow')) as Map<String, dynamic>;

  Future<String> compilePrompt(Map<String, String> answers) async =>
      ((await _send('POST', '/api/v1/prompts/compile', {'answers': answers})) as Map)['prompt']
          as String;

  /// Uploads a reference photo, returning its {id, url}.
  Future<Map<String, dynamic>> uploadImage(
      Uint8List bytes, String filename, String contentType) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/v1/uploads'))
      ..headers['Idempotency-Key'] = newIdempotencyKey();
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.files.add(http.MultipartFile.fromBytes('file', bytes,
        filename: filename, contentType: MediaType.parse(contentType)));
    final resp = await http.Response.fromStream(await req.send());
    final decoded = resp.body.isEmpty ? null : jsonDecode(resp.body);
    if (resp.statusCode >= 400) {
      final m = decoded is Map ? decoded : const {};
      throw ApiException(resp.statusCode, '${m['error'] ?? 'error'}',
          '${m['detail'] ?? 'Upload failed'}');
    }
    return decoded as Map<String, dynamic>;
  }

  // --- Generation ---
  Future<dynamic> generatePrompt(Map<String, dynamic> body) =>
      _send('POST', '/api/v1/prompts/generate', body);

  Future<dynamic> generateImage(Map<String, dynamic> body) =>
      _send('POST', '/api/v1/images/generate', body);
}
