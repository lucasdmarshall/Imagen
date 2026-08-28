import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:show_ui/show_ui.dart';

import 'api/api_client.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'state/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase powers Google sign-in. Non-fatal if it fails (email login still works).
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}
  // Register the bundled Myanmar face so SHOW type tokens fall back to it.
  ShowType.myanmarFontFamily = 'NamKhone';
  final session = Session(ApiClient());
  runApp(ShowClientApp(session: session));
}

class ShowClientApp extends StatelessWidget {
  const ShowClientApp({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      session: session,
      child: MaterialApp(
        title: 'SHOW',
        debugShowCheckedModeBanner: false,
        theme: ShowTheme.light(),
        darkTheme: ShowTheme.dark(),
        // The design system is light/cream Swiss; the ShowType tokens hardcode
        // dark ink, so the dark theme renders text invisibly. Pin to light
        // until dark-mode typography is theme-aware.
        themeMode: ThemeMode.light,
        home: const SplashScreen(),
      ),
    );
  }
}
