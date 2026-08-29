import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Gallery/camera pick with resize + JPEG quality so uploads stay under the
/// API body limit (phone originals are often 8–15 MiB; Flutter web also
/// ignores maxWidth unless imageQuality is set).
Future<XFile?> pickCompressedImage({
  ImageSource source = ImageSource.gallery,
}) {
  return ImagePicker().pickImage(
    source: source,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 82,
  );
}

Future<Uint8List?> pickCompressedBytes({
  ImageSource source = ImageSource.gallery,
}) async {
  final picked = await pickCompressedImage(source: source);
  return picked?.readAsBytes();
}
