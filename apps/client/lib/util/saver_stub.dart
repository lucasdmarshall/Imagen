import 'dart:typed_data';

/// Non-web fallback. A real mobile build would save to the photo gallery.
Future<bool> saveBytes(String filename, Uint8List bytes) async => false;
