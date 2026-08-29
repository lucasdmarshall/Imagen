import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:show_ui/show_ui.dart';

import '../api/api_client.dart';
import '../i18n.dart';
import '../state/session.dart';
import 'gate.dart';

/// Sign-in / sign-up. Bold editorial hero, a prominent "Continue with Google"
/// button, and email/password beneath. After auth, users pass through the
/// approval gate (Waiting Area until an admin approves them).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  void _afterAuth() {
    final s = SessionScope.of(context);
    Navigator.of(context).pushReplacement(showFadeThroughRoute(gateFor(s)));
  }

  bool _handleGone(Object e) {
    if (e is! ApiException ||
        (e.status != 404 && e.code != 'account_deleted')) {
      return false;
    }
    SessionScope.of(context).accountDeleted = true;
    Navigator.of(context).pushReplacement(
        showFadeThroughRoute(gateFor(SessionScope.of(context))));
    return true;
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = SessionScope.of(context);
    try {
      if (_register) {
        await session.register(_email.text, _password.text, _name.text);
      } else {
        await session.login(_email.text, _password.text);
      }
      if (!mounted) return;
      _afterAuth();
    } catch (e) {
      if (!mounted) return;
      if (_handleGone(e)) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = SessionScope.of(context);
    try {
      // Web: Google popup. Android/iOS: native account picker / Custom Tab.
      // signInWithPopup is a web-only API and never shows UI on an APK.
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');
      final cred = kIsWeb
          ? await FirebaseAuth.instance.signInWithPopup(provider)
          : await FirebaseAuth.instance.signInWithProvider(provider);
      final idToken = await cred.user?.getIdToken();
      if (idToken == null) throw Exception('No Google token');
      await session.loginWithGoogle(idToken);
      if (!mounted) return;
      _afterAuth();
    } catch (e) {
      if (!mounted) return;
      if (_handleGone(e)) return;
      final t = T.of(context);
      final raw = '$e';
      final setup = raw.contains('FirebaseApp') ||
          raw.contains('FirebaseException') ||
          raw.contains('ApiException: 10') ||
          raw.contains('DEVELOPER_ERROR') ||
          raw.contains('sign_in_failed');
      setState(() => _error = setup ? t.googleSetupNeeded : t.error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = T.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(ShowSpacing.pageInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: showStagger([
                    const SizedBox(height: ShowSpacing.xl),
                    // --- Hero ---
                    Text('SHOW',
                        style: ShowType.display.copyWith(
                            fontSize: 52, letterSpacing: 2, fontWeight: FontWeight.w700)),
                    const SizedBox(height: ShowSpacing.sm),
                    Container(
                      height: 4,
                      width: 64,
                      decoration: BoxDecoration(
                        color: ShowColors.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: ShowSpacing.md),
                    Text(_register ? t.createAccount : t.welcomeBack,
                        style: ShowType.bodyLarge.copyWith(color: ShowColors.inkMuted)),
                    const SizedBox(height: ShowSpacing.xxl),
                    // --- Google (primary) ---
                    _GoogleButton(onTap: _busy ? null : _google, label: t.continueWithGoogle),
                    const SizedBox(height: ShowSpacing.lg),
                    Row(children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: ShowSpacing.md),
                        child: Text(t.orUseEmail,
                            style: ShowType.caption.copyWith(color: ShowColors.inkFaint)),
                      ),
                      const Expanded(child: Divider()),
                    ]),
                    const SizedBox(height: ShowSpacing.lg),
                    // --- Email / password ---
                    if (_register) ...[
                      ShowField(label: t.name, controller: _name, hint: t.nameHint),
                      const SizedBox(height: ShowSpacing.lg),
                    ],
                    ShowField(
                      label: t.email,
                      controller: _email,
                      hint: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: ShowSpacing.lg),
                    ShowField(
                        label: t.password,
                        controller: _password,
                        hint: '••••••',
                        obscure: true),
                    const SizedBox(height: ShowSpacing.xl),
                    if (_error != null) ...[
                      Text(_error!,
                          style: ShowType.body.copyWith(color: ShowColors.danger)),
                      const SizedBox(height: ShowSpacing.md),
                    ],
                    ShowButton(
                      _busy ? t.pleaseWait : (_register ? t.createAccount : t.signIn),
                      leading: const HeroIcon(HeroIcons.arrowRightEndOnRectangle,
                          size: 20, color: ShowColors.cream),
                      onPressed: _busy ? null : _submit,
                    ),
                    const SizedBox(height: ShowSpacing.md),
                    TextButton(
                      onPressed: _busy ? null : () => setState(() => _register = !_register),
                      child: Text(_register ? t.haveAccount : t.newHere),
                    ),
                    const SizedBox(height: ShowSpacing.xl),
                  ], initialDelay: const Duration(milliseconds: 70)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A bold, high-contrast "Continue with Google" button.
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onTap, required this.label});
  final VoidCallback? onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ShowPressable(
      onTap: onTap,
      child: Container(
        height: ShowSizing.controlHeight,
        decoration: BoxDecoration(
          color: ShowColors.creamRaised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ShowColors.hairline),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // A simple, brand-neutral "G" mark (real logo asset added later).
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: ShowColors.accent,
                shape: BoxShape.circle,
              ),
              child: Text('G',
                  style: ShowType.button.copyWith(color: ShowColors.cream)),
            ),
            const SizedBox(width: ShowSpacing.md),
            Text(label,
                style: ShowType.button.copyWith(color: ShowColors.ink)),
          ],
        ),
      ),
    );
  }
}
