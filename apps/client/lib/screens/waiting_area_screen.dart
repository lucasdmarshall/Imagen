import 'dart:async';

import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:show_ui/show_ui.dart';

import '../i18n.dart';
import '../state/session.dart';
import 'auth_screen.dart';
import 'gate.dart';

/// Post-login gate: a signed-in but not-yet-approved user waits here. We poll
/// the profile; the moment an admin approves them, they slide into the app.
class WaitingAreaScreen extends StatefulWidget {
  const WaitingAreaScreen({super.key});

  @override
  State<WaitingAreaScreen> createState() => _WaitingAreaScreenState();
}

class _WaitingAreaScreenState extends State<WaitingAreaScreen> {
  Timer? _poll;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 6), (_) => _check());
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (_checking || !mounted) return;
    setState(() => _checking = true);
    final s = SessionScope.of(context);
    try {
      await s.refreshProfile();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _checking = false);
    if (s.approved || s.banned || s.accountDeleted) {
      _poll?.cancel();
      Navigator.of(context)
          .pushReplacement(showFadeThroughRoute(gateFor(s)));
    }
  }

  Future<void> _signOut() async {
    final s = SessionScope.of(context);
    await s.logout();
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacement(showFadeThroughRoute(const AuthScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final t = T.of(context);
    final session = SessionScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(ShowSpacing.pageInset),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: showStagger([
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: ShowColors.creamSunken,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const HeroIcon(HeroIcons.clock,
                        size: 32, color: ShowColors.accent),
                  ),
                  const SizedBox(height: ShowSpacing.xl),
                  Text('${t.hello(session.displayName)} 👋',
                      style: ShowType.bodyMuted),
                  const SizedBox(height: ShowSpacing.sm),
                  Text(t.waitingTitle,
                      style: ShowType.display.copyWith(
                          fontSize: 30, height: 1.15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: ShowSpacing.md),
                  Text(t.waitingSub,
                      style: ShowType.bodyLarge
                          .copyWith(color: ShowColors.inkMuted, height: 1.5)),
                  const SizedBox(height: ShowSpacing.xl),
                  Row(children: [
                    if (_checking)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    if (_checking) const SizedBox(width: ShowSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: _checking ? null : _check,
                      icon: const HeroIcon(HeroIcons.arrowPath, size: 20),
                      label: Text(t.checkAgain),
                    ),
                  ]),
                  const SizedBox(height: ShowSpacing.sm),
                  TextButton(onPressed: _signOut, child: Text(t.signOut)),
                ], initialDelay: const Duration(milliseconds: 80)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
