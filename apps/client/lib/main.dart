import 'package:flutter/material.dart';
import 'package:show_ui/show_ui.dart';

import 'api/api_client.dart';
import 'screens/splash_screen.dart';
import 'state/session.dart';

void main() {
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
        home: const SplashScreen(),
      ),
    );
  }
}
