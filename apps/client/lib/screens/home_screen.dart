import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:show_ui/show_ui.dart';

import '../data/effects.dart';
import '../i18n.dart';
import '../state/session.dart';
import '../widgets/effect_card.dart';
import 'effect_runner_screen.dart';
import 'gallery_screen.dart';
import 'image_generator_screen.dart';
import 'notifications_screen.dart';
import 'prompt_generator_screen.dart';

/// Editorial landing: an oversized headline, a bold primary call-to-action, a
/// side-scrolling effects carousel (cards peek to invite a swipe), then the
/// mode entries. Borderless/matte per the SHOW system.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final t = T.of(context);

    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          titleSpacing: ShowSpacing.pageInset,
          title: Text('SHOW',
              style: ShowType.h3
                  .copyWith(letterSpacing: 2, fontWeight: FontWeight.w700)),
          actions: [
            IconButton(
              icon: const HeroIcon(HeroIcons.bell, size: 22),
              onPressed: () => Navigator.of(context)
                  .push(showFadeThroughRoute(const NotificationsScreen())),
            ),
            const SizedBox(width: ShowSpacing.sm),
          ],
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: ShowSpacing.xxxl),
            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: ShowSizing.maxContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Hero(session: session, t: t),
                    const SizedBox(height: ShowSpacing.xl),
                    _EffectsCarousel(t: t),
                    const SizedBox(height: ShowSpacing.xl),
                    _Modes(t: t),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.session, required this.t});
  final dynamic session;
  final T t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          ShowSpacing.pageInset, ShowSpacing.lg, ShowSpacing.pageInset, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: showStagger([
          Row(children: [ShowTag(t.credits(session.balance), emphasis: true)]),
          const SizedBox(height: ShowSpacing.lg),
          Text(
            t.heroTitle,
            style: ShowType.display.copyWith(
                fontSize: 32, height: 1.12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: ShowSpacing.md),
          Text(t.heroSub,
              style: ShowType.bodyLarge.copyWith(color: ShowColors.inkMuted)),
          const SizedBox(height: ShowSpacing.xl),
          FilledButton(
            onPressed: () => Navigator.of(context)
                .push(showFadeThroughRoute(const PromptGeneratorScreen())),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(t.ctaStart),
                const SizedBox(width: ShowSpacing.sm),
                const HeroIcon(HeroIcons.arrowRight, size: 20),
              ],
            ),
          ),
        ], initialDelay: const Duration(milliseconds: 60)),
      ),
    );
  }
}

/// Horizontal, side-scrolling effect cards. Each card is 2/3 of the available
/// width so the next one peeks — inviting a swipe. A blurred teaser at the end
/// points to the full gallery.
class _EffectsCarousel extends StatelessWidget {
  const _EffectsCarousel({required this.t});
  final T t;

  void _open(BuildContext context, Effect e) {
    Navigator.of(context)
        .push(showFadeThroughRoute(EffectRunnerScreen(effect: e)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ShowSpacing.pageInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.effectsTitle.toUpperCase(),
                  style: ShowType.label
                      .copyWith(color: ShowColors.inkFaint, letterSpacing: 1.2)),
              const SizedBox(height: ShowSpacing.xs),
              Text(t.effectsSub, style: ShowType.bodyMuted),
            ],
          ),
        ),
        const SizedBox(height: ShowSpacing.md),
        LayoutBuilder(builder: (context, cons) {
          final cardW = cons.maxWidth * 0.55;
          return SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: ShowSpacing.pageInset),
              itemCount: homeEffects.length + 1,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: ShowSpacing.md),
              itemBuilder: (context, i) {
                if (i == homeEffects.length) {
                  return SizedBox(width: cardW, child: _GalleryTeaser(t: t));
                }
                final e = homeEffects[i];
                return SizedBox(
                  width: cardW,
                  child: EffectCard(effect: e, onTap: () => _open(context, e)),
                );
              },
            ),
          );
        }),
      ],
    );
  }
}

/// The peeking "there's more" card: the next effect, blurred, with an arrow to
/// the full gallery.
class _GalleryTeaser extends StatelessWidget {
  const _GalleryTeaser({required this.t});
  final T t;

  @override
  Widget build(BuildContext context) {
    final peek = effects.length > homeEffects.length
        ? effects[homeEffects.length]
        : effects.last;
    return ShowPressable(
      onTap: () =>
          Navigator.of(context).push(showFadeThroughRoute(const GalleryScreen())),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                child: EffectCard(effect: peek),
              ),
            ),
            IgnorePointer(
              child: Container(color: ShowColors.ink.withValues(alpha: 0.38)),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const HeroIcon(HeroIcons.arrowRight,
                      size: 30, color: ShowColors.cream),
                  const SizedBox(height: ShowSpacing.sm),
                  Text(t.seeAll,
                      style: ShowType.label.copyWith(
                          color: ShowColors.cream, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Modes extends StatelessWidget {
  const _Modes({required this.t});
  final T t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ShowSpacing.pageInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.modes.toUpperCase(),
              style: ShowType.label
                  .copyWith(color: ShowColors.inkFaint, letterSpacing: 1.2)),
          const SizedBox(height: ShowSpacing.sm),
          _ModeTile(
            icon: HeroIcons.pencilSquare,
            title: t.promptGen,
            subtitle: t.promptGenSub,
            onTap: () => Navigator.of(context)
                .push(showFadeThroughRoute(const PromptGeneratorScreen())),
          ),
          const Divider(),
          _ModeTile(
            icon: HeroIcons.photo,
            title: t.imageGen,
            subtitle: t.imageGenSub,
            onTap: () => Navigator.of(context)
                .push(showFadeThroughRoute(const ImageGeneratorScreen())),
          ),
        ],
      ),
    );
  }
}

/// A large, tactile mode entry: hover lifts the arrow and warms the row (web),
/// press gently scales it.
class _ModeTile extends StatefulWidget {
  const _ModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final HeroIcons icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_ModeTile> createState() => _ModeTileState();
}

class _ModeTileState extends State<_ModeTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: ShowPressable(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: ShowMotion.fast,
          curve: ShowMotion.entrance,
          constraints: const BoxConstraints(minHeight: ShowSizing.minTouch),
          padding: const EdgeInsets.symmetric(
              horizontal: ShowSpacing.md, vertical: ShowSpacing.md),
          decoration: BoxDecoration(
            color: _hover ? ShowColors.creamSunken : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              HeroIcon(widget.icon, size: 28, color: ShowColors.accent),
              const SizedBox(width: ShowSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: ShowType.h3),
                    const SizedBox(height: ShowSpacing.xs),
                    Text(widget.subtitle, style: ShowType.bodyMuted),
                  ],
                ),
              ),
              const SizedBox(width: ShowSpacing.md),
              AnimatedSlide(
                offset: Offset(_hover ? 0.28 : 0, 0),
                duration: ShowMotion.fast,
                curve: ShowMotion.entrance,
                child: HeroIcon(
                  HeroIcons.arrowRight,
                  size: 20,
                  color: _hover ? ShowColors.accent : ShowColors.inkFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
