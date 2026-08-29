import 'package:flutter/material.dart';
import 'package:show_ui/show_ui.dart';

import '../data/effects.dart';
import '../i18n.dart';

/// 3:2 before/after cover photo. Used as the gallery card face and as the
/// small preview on an individual effect page.
class EffectCover extends StatelessWidget {
  const EffectCover({super.key, required this.effect, this.width});
  final Effect effect;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final face = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 1.5,
        child: ColoredBox(
          color: effect.color,
          child: Image.asset(
            effect.coverAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
    return width == null ? face : SizedBox(width: width, child: face);
  }
}

/// Photo cover card for an [Effect]. Fills its parent's constraints — the
/// carousel and gallery both use a 3:2 frame so before/after splits stay visible.
class EffectCard extends StatefulWidget {
  const EffectCard({super.key, required this.effect, this.onTap});
  final Effect effect;
  final VoidCallback? onTap;

  @override
  State<EffectCard> createState() => _EffectCardState();
}

class _EffectCardState extends State<EffectCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = T.of(context);
    final e = widget.effect;
    final cream = ShowColors.cream;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: ShowPressable(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hover ? 1.02 : 1.0,
          duration: ShowMotion.fast,
          curve: ShowMotion.entrance,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: e.color),
                Image.asset(
                  e.coverAsset,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x00000000),
                        Color(0x66000000),
                      ],
                      stops: [0.62, 1.0],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      ShowSpacing.sm, ShowSpacing.sm, ShowSpacing.sm, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _StrokedText(
                        t.pick(e.titleMy, e.titleEn),
                        style: ShowType.label.copyWith(
                          fontSize: 13,
                          height: 1.15,
                          color: cream,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      _StrokedText(
                        t.pick(e.subMy, e.subEn),
                        style: ShowType.caption.copyWith(
                          fontSize: 11,
                          height: 1.2,
                          color: cream.withValues(alpha: 0.95),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cream fill with a 1px black outline so type stays readable on any photo.
///
/// Do not use [PaintingStyle.stroke] on [TextStyle.foreground] — CanvasKit
/// skips HarfBuzz shaping for stroked runs, so Myanmar combining marks show
/// as dotted circles. Offset shadows keep a true outline and still shape.
class _StrokedText extends StatelessWidget {
  const _StrokedText(this.text, {required this.style, this.maxLines = 1});
  final String text;
  final TextStyle style;
  final int maxLines;

  static const _outline = Color(0xFF000000);
  static const _shadows = <Shadow>[
    Shadow(color: _outline, offset: Offset(-1, -1), blurRadius: 0),
    Shadow(color: _outline, offset: Offset(0, -1), blurRadius: 0),
    Shadow(color: _outline, offset: Offset(1, -1), blurRadius: 0),
    Shadow(color: _outline, offset: Offset(-1, 0), blurRadius: 0),
    Shadow(color: _outline, offset: Offset(1, 0), blurRadius: 0),
    Shadow(color: _outline, offset: Offset(-1, 1), blurRadius: 0),
    Shadow(color: _outline, offset: Offset(0, 1), blurRadius: 0),
    Shadow(color: _outline, offset: Offset(1, 1), blurRadius: 0),
  ];

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: ShowType.withMyanmar(style).copyWith(shadows: _shadows),
    );
  }
}
