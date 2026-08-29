// Save bytes to the user's device. Web uses a browser download; Android/iOS
// write into the photo gallery via `gal`.
export 'saver_stub.dart'
    if (dart.library.html) 'saver_web.dart'
    if (dart.library.io) 'saver_io.dart';
