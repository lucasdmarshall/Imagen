import 'dart:async';

import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:show_ui/show_ui.dart';

import '../i18n.dart';
import '../state/session.dart';
import 'auth_screen.dart';
import 'gate.dart';

/// Shown when an admin has banned the account. Polls until the ban is lifted.
class BannedScreen extends StatefulWidget {
  const BannedScreen({super.key});

  @override
  State<BannedScreen> createState() => _BannedScreenState();
}

class _BannedScreenState extends State<BannedScreen> {
  Timer? _poll;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 6), (_) => _check());
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
    if (!s.banned) {
      _poll?.cancel();
      Navigator.of(context).pushReplacement(showFadeThroughRoute(gateFor(s)));
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
                    child: const HeroIcon(HeroIcons.xCircle,
                        size: 32, color: ShowColors.inkMuted),
                  ),
                  const SizedBox(height: ShowSpacing.xl),
                  Text(t.bannedTitle,
                      style: ShowType.display.copyWith(
                          fontSize: 30, height: 1.25, fontWeight: FontWeight.w700)),
                  const SizedBox(height: ShowSpacing.md),
                  Text(t.bannedSub,
                      style: ShowType.bodyLarge
                          .copyWith(color: ShowColors.inkMuted, height: 1.5)),
                  const SizedBox(height: ShowSpacing.xl),
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
