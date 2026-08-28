import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:show_ui/show_ui.dart';

import '../data/effects.dart';
import '../i18n.dart';

/// A matte colour-field card for an [Effect]: big icon, title, Myanmar hint.
/// Fills its parent's constraints, so the carousel and the gallery grid each
/// size it. Hover lifts it slightly (web); press scales it.
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
            child: Container(
              color: e.color,
              padding: const EdgeInsets.all(ShowSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  HeroIcon(e.icon,
                      size: 30, color: cream.withValues(alpha: 0.95)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t.pick(e.titleMy, e.titleEn),
                        style: ShowType.h3
                            .copyWith(color: cream, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t.pick(e.subMy, e.subEn),
                        style: ShowType.caption
                            .copyWith(color: cream.withValues(alpha: 0.85)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
