import 'dart:math';

import 'package:flutter/material.dart';
import 'package:show_ui/show_ui.dart';

/// Soft rising sparkles used while an effect is generating. Replaces a spinner.
class GeneratingSparkle extends StatefulWidget {
  const GeneratingSparkle({super.key, this.size = 120});
  final double size;

  @override
  State<GeneratingSparkle> createState() => _GeneratingSparkleState();
}

class _GeneratingSparkleState extends State<GeneratingSparkle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Spark> _sparks;

  @override
  void initState() {
    super.initState();
    final rng = Random(7);
    _sparks = List.generate(36, (_) => _Spark.random(rng));
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) => CustomPaint(
          painter: _SparkPainter(_sparks, _ctrl.value),
        ),
      ),
    );
  }
}

class _Spark {
  _Spark({
    required this.x,
    required this.phase,
    required this.speed,
    required this.radius,
    required this.drift,
    required this.color,
    required this.twinkle,
  });

  factory _Spark.random(Random rng) {
    const palette = [
      ShowColors.accent,
      ShowColors.warning,
      ShowColors.cream,
      ShowColors.grey300,
    ];
    return _Spark(
      x: rng.nextDouble(),
      phase: rng.nextDouble(),
      speed: 0.35 + rng.nextDouble() * 0.7,
      radius: 1.2 + rng.nextDouble() * 2.8,
      drift: (rng.nextDouble() - 0.5) * 0.22,
      color: palette[rng.nextInt(palette.length)],
      twinkle: 0.4 + rng.nextDouble() * 0.6,
    );
  }

  final double x;
  final double phase;
  final double speed;
  final double radius;
  final double drift;
  final Color color;
  final double twinkle;
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.sparks, this.t);
  final List<_Spark> sparks;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final s in sparks) {
      final life = (t * s.speed + s.phase) % 1.0;
      final y = size.height * (1.08 - life * 1.2);
      final x = size.width * (s.x + sin((t + s.phase) * pi * 2) * s.drift);
      final fade = (sin(life * pi) * s.twinkle).clamp(0.0, 1.0);
      paint.color = s.color.withValues(alpha: fade);
      canvas.drawCircle(Offset(x, y), s.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.t != t;
}
