import 'package:flutter/material.dart';
import 'package:show_ui/show_ui.dart';

import '../i18n.dart';
import '../state/session.dart';
import 'app_shell.dart';
import 'auth_screen.dart';

/// Minimal splash: wordmark on cream, Swiss alignment, no box/card/gradient.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1300), _next);
  }

  void _next() {
    if (!mounted) return;
    final authed = SessionScope.of(context).isAuthenticated;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => authed ? const AppShell() : const AuthScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(ShowSpacing.pageInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('SHOW', style: ShowType.display),
            const SizedBox(height: ShowSpacing.sm),
            Text(T.of(context).tagline, style: ShowType.bodyMuted),
            const SizedBox(height: ShowSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
