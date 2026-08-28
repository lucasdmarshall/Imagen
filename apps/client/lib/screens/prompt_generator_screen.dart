import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:show_ui/show_ui.dart';

import '../i18n.dart';
import '../models/flow.dart';
import '../state/session.dart';
import '../state/wizard_controller.dart';
import 'wizard_screen.dart';

/// Entry to the Guided Prompt Engine: fetch the flow, pick Quick vs Detailed,
/// then walk the wizard.
class PromptGeneratorScreen extends StatefulWidget {
  const PromptGeneratorScreen({super.key});

  @override
  State<PromptGeneratorScreen> createState() => _PromptGeneratorScreenState();
}

class _PromptGeneratorScreenState extends State<PromptGeneratorScreen> {
  Future<PromptFlow>? _flow;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Inherited widgets (SessionScope) are only safe to read here, not in
    // initState(). Guard so the flow is fetched once.
    _flow ??=
        SessionScope.of(context).api.promptFlow().then(PromptFlow.fromJson);
  }

  void _start(PromptFlow flow, {required bool detailed}) {
    final controller = WizardController(flow, detailed: detailed);
    Navigator.of(context)
        .push(showFadeThroughRoute(WizardScreen(controller: controller)));
  }

  @override
  Widget build(BuildContext context) {
    final t = T.of(context);
    return ShowPage(
      title: 'Prompt Generator',
      children: [
        FutureBuilder<PromptFlow>(
          future: _flow,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(ShowSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return ShowEmpty(
                icon: const HeroIcon(HeroIcons.exclamationTriangle,
                    size: 36, color: ShowColors.inkFaint),
                title: 'Could not load',
                subtitle: '${snap.error}',
              );
            }
            final flow = snap.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: showStagger([
                const SizedBox(height: ShowSpacing.lg),
                Text(t.chooseDepth,
                    style: ShowType.display
                        .copyWith(fontSize: 26, height: 1.15, fontWeight: FontWeight.w700)),
                const SizedBox(height: ShowSpacing.sm),
                Text(t.chooseDepthSub, style: ShowType.bodyLarge.copyWith(color: ShowColors.inkMuted)),
                const SizedBox(height: ShowSpacing.xl),
                _DepthCard(
                  icon: HeroIcons.bolt,
                  title: t.quick,
                  subtitle: t.quickSub,
                  onTap: () => _start(flow, detailed: false),
                ),
                const SizedBox(height: ShowSpacing.md),
                _DepthCard(
                  icon: HeroIcons.adjustmentsHorizontal,
                  title: t.detailed,
                  subtitle: t.detailedSub,
                  accent: true,
                  onTap: () => _start(flow, detailed: true),
                ),
              ], initialDelay: const Duration(milliseconds: 60)),
            );
          },
        ),
      ],
    );
  }
}

/// A bold, tactile choice card for the Quick/Detailed decision. The recommended
/// (Detailed) option is filled in the accent tone; the other is a soft field.
class _DepthCard extends StatefulWidget {
  const _DepthCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = false,
  });

  final HeroIcons icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool accent;

  @override
  State<_DepthCard> createState() => _DepthCardState();
}

class _DepthCardState extends State<_DepthCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final onColor = widget.accent ? ShowColors.cream : ShowColors.ink;
    final subColor = widget.accent
        ? ShowColors.cream.withValues(alpha: 0.82)
        : ShowColors.inkMuted;
    final base = widget.accent ? ShowColors.accent : ShowColors.creamSunken;
    final hovered = widget.accent ? ShowColors.accentPressed : ShowColors.creamRaised;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: ShowPressable(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: ShowMotion.fast,
          curve: ShowMotion.entrance,
          padding: const EdgeInsets.all(ShowSpacing.lg),
          decoration: BoxDecoration(
            color: _hover ? hovered : base,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              HeroIcon(widget.icon, size: 30, color: onColor),
              const SizedBox(width: ShowSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        style: ShowType.h3.copyWith(color: onColor)),
                    const SizedBox(height: ShowSpacing.xs),
                    Text(widget.subtitle,
                        style: ShowType.bodyMuted.copyWith(color: subColor)),
                  ],
                ),
              ),
              const SizedBox(width: ShowSpacing.md),
              AnimatedSlide(
                offset: Offset(_hover ? 0.28 : 0, 0),
                duration: ShowMotion.fast,
                curve: ShowMotion.entrance,
                child: HeroIcon(HeroIcons.arrowRight, size: 22, color: onColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
