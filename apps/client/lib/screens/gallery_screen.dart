import 'package:flutter/material.dart';
import 'package:show_ui/show_ui.dart';

import '../data/effects.dart';
import '../i18n.dart';
import '../widgets/effect_card.dart';
import 'effect_runner_screen.dart';

/// The full effect gallery — every card, in a two-column grid that scrolls from
/// the top. Reached from the blurred teaser at the end of the home carousel.
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  void _open(BuildContext context, Effect e) {
    Navigator.of(context)
        .push(showFadeThroughRoute(EffectRunnerScreen(effect: e)));
  }

  @override
  Widget build(BuildContext context) {
    final t = T.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.galleryTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: ShowSizing.maxContentWidth),
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(ShowSpacing.pageInset,
                  ShowSpacing.lg, ShowSpacing.pageInset, ShowSpacing.xxl),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: ShowSpacing.md,
                crossAxisSpacing: ShowSpacing.md,
                childAspectRatio: 1.15,
              ),
              itemCount: effects.length,
              itemBuilder: (context, i) => ShowFadeIn(
                delay: ShowMotion.stagger * (i % 6),
                child: EffectCard(
                  effect: effects[i],
                  onTap: () => _open(context, effects[i]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
