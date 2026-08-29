import 'dart:typed_data';

import 'package:gal/gal.dart';

/// Saves [bytes] into the device photo gallery.
Future<bool> saveBytes(String filename, Uint8List bytes) async {
  try {
    if (!await Gal.hasAccess()) {
      final granted = await Gal.requestAccess();
      if (!granted) return false;
    }
    final dot = filename.lastIndexOf('.');
    final name = (dot > 0) ? filename.substring(0, dot) : filename;
    await Gal.putImageBytes(bytes, name: name);
    return true;
  } on GalException {
    return false;
  } catch (_) {
    return false;
  }
}
