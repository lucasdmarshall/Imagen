// Save bytes to the user's device. Web uses a browser download; other
// platforms fall back to a no-op (mobile would use a gallery-saver plugin).
export 'saver_stub.dart' if (dart.library.html) 'saver_web.dart';
