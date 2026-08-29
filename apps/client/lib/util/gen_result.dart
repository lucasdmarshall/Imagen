import 'dart:convert';
import 'dart:typed_data';

/// Image payload from POST /api/v1/images/generate.
class GenResult {
  const GenResult({this.bytes, this.url});
  final Uint8List? bytes;
  final String? url;
  bool get isEmpty => bytes == null && url == null;
}

/// Pull an image out of the model response, tolerating a few shapes
/// (data[0].url / data[0].b64_json / top-level url / data URI).
GenResult parseGenResult(dynamic res) {
  final m = res is Map ? res : const {};
  final data = m['data'];
  final first = (data is List && data.isNotEmpty) ? data.first : null;
  String? url;
  String? b64;
  if (first is Map) {
    url = first['url'] as String?;
    b64 = first['b64_json'] as String?;
    url ??= first['image'] as String?;
  }
  url ??= m['url'] as String?;
  b64 ??= m['b64_json'] as String?;

  if (url != null && url.startsWith('data:')) {
    b64 = url.split(',').last;
    url = null;
  }
  Uint8List? bytes;
  if (b64 != null) {
    try {
      bytes = base64Decode(b64.split(',').last);
    } catch (_) {}
  }
  return GenResult(bytes: bytes, url: url);
}
