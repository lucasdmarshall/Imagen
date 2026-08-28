// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// Triggers a browser download of [bytes] as [filename].
Future<bool> saveBytes(String filename, Uint8List bytes) async {
  final blob = html.Blob(<Uint8List>[bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = filename
    ..click();
  html.Url.revokeObjectUrl(url);
  return true;
}
