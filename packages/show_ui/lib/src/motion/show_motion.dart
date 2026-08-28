import 'package:flutter/material.dart';

/// SHOW motion system.
///
/// The visual language is Swiss-minimal (no gradients, no boxes), so the
/// premium feel is carried by **motion**: confident, smooth, and calm. Timings
/// are a touch slower than typical so the 50+ audience reads every transition
/// as intentional rather than twitchy.
class ShowMotion {
  ShowMotion._();

  static const Duration fast = Duration(milliseconds: 200);
  static const Duration base = Duration(milliseconds: 360);
  static const Duration slow = Duration(milliseconds: 560);

  /// The house entrance/exit curve — a soft, decelerating ease.
  static const Curve entrance = Curves.easeOutCubic;

  /// For emphasis / spring-like settles (scale, selection).
  static const Curve emphasized = Curves.easeOutBack;

  /// Per-item delay when staggering a list into view.
  static const Duration stagger = Duration(milliseconds: 70);
}

/// Fades + rises a child into view once, on first build. Optional [delay] makes
/// staggered lists trivial. Respects the platform "reduce motion" setting.
class ShowFadeIn extends StatefulWidget {
  const ShowFadeIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = ShowMotion.base,
    this.offset = 16,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Vertical distance (px) the child rises from.
  final double offset;

  @override
  State<ShowFadeIn> createState() => _ShowFadeInState();
}

class _ShowFadeInState extends State<ShowFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _t =
      CurvedAnimation(parent: _c, curve: ShowMotion.entrance);

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Honour reduced-motion accessibility preference.
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) => Opacity(
        opacity: _t.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - _t.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Wraps a list of children so each fades/rises in with an increasing delay.
/// Use in place of the raw children list inside a Column.
List<Widget> showStagger(
  List<Widget> children, {
  Duration initialDelay = Duration.zero,
  Duration step = ShowMotion.stagger,
}) {
  return [
    for (var i = 0; i < children.length; i++)
      ShowFadeIn(delay: initialDelay + step * i, child: children[i]),
  ];
}

/// Tactile press feedback: gently scales its child down while held. Gives every
/// tappable surface a physical, high-end response without borders or shadows.
class ShowPressable extends StatefulWidget {
  const ShowPressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final BorderRadius? borderRadius;

  @override
  State<ShowPressable> createState() => _ShowPressableState();
}

class _ShowPressableState extends State<ShowPressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null) return;
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: ShowMotion.fast,
        curve: ShowMotion.entrance,
        child: widget.child,
      ),
    );
  }
}

/// Applies the SHOW fade-through feel to every Navigator push, via the theme's
/// [PageTransitionsTheme]. Content fades and lifts; no hard platform slide.
class ShowPageTransitions extends PageTransitionsBuilder {
  const ShowPageTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: ShowMotion.entrance,
      reverseCurve: ShowMotion.entrance.flipped,
    );
    return FadeTransition(
      opacity: curved,
      child: AnimatedBuilder(
        animation: curved,
        builder: (context, c) => Transform.translate(
          offset: Offset(0, 14 * (1 - curved.value)),
          child: c,
        ),
        child: child,
      ),
    );
  }
}

/// A smooth fade-through page transition — the app's default navigation feel.
/// Content fades and lifts slightly; no hard horizontal slide.
Route<T> showFadeThroughRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: ShowMotion.base,
    reverseTransitionDuration: ShowMotion.fast,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondary, child) {
      final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (reduce) return child;
      final curved =
          CurvedAnimation(parent: animation, curve: ShowMotion.entrance);
      return FadeTransition(
        opacity: curved,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - curved.value)),
          child: child,
        ),
      );
    },
  );
}
