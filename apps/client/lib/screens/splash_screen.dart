import 'package:flutter/material.dart';
import 'package:show_ui/show_ui.dart';

import '../i18n.dart';
import '../state/session.dart';
import 'gate.dart';

/// Minimal splash: the wordmark rises in, an accent rule draws beneath it, then
/// the tagline fades up. Swiss alignment, no box/card/gradient — motion only.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
        ..forward();

  late final Animation<double> _rise = CurvedAnimation(
      parent: _c, curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic));
  late final Animation<double> _line = CurvedAnimation(
      parent: _c, curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic));
  late final Animation<double> _tag = CurvedAnimation(
      parent: _c, curve: const Interval(0.55, 1.0, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1900), _next);
  }

  void _next() {
    if (!mounted) return;
    final s = SessionScope.of(context);
    Navigator.of(context).pushReplacement(showFadeThroughRoute(gateFor(s)));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
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
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Opacity(
                    opacity: _rise.value,
                    child: Transform.translate(
                      offset: Offset(0, 24 * (1 - _rise.value)),
                      child: Text('SHOW', style: ShowType.display),
                    ),
                  ),
                  const SizedBox(height: ShowSpacing.sm),
                  // Accent rule that draws in from the left.
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: (_line.value * 0.42).clamp(0.0, 1.0),
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: ShowColors.accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: ShowSpacing.md),
                  Opacity(
                    opacity: _tag.value,
                    child: Transform.translate(
                      offset: Offset(0, 12 * (1 - _tag.value)),
                      child: Text(T.of(context).tagline, style: ShowType.bodyMuted),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ShowSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
