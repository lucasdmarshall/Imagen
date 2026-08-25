import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:show_ui/show_ui.dart';

import '../i18n.dart';
import '../state/session.dart';

/// Image Generator — render a prompt with one of the two image models.
class ImageGeneratorScreen extends StatefulWidget {
  const ImageGeneratorScreen({
    super.key,
    this.initialPrompt,
    this.referenceIds = const [],
  });

  /// Prompt prefilled from the Guided Prompt Engine (optional).
  final String? initialPrompt;

  /// Reference-photo upload ids to pass to the multimodal image model.
  final List<String> referenceIds;

  @override
  State<ImageGeneratorScreen> createState() => _ImageGeneratorScreenState();
}

class _ImageGeneratorScreenState extends State<ImageGeneratorScreen> {
  late final _prompt = TextEditingController(text: widget.initialPrompt ?? '');
  String _model = 'nano_banana_pro';
  bool _busy = false;
  String? _status;

  static const _models = {
    'nano_banana_pro': 'Nano Banana Pro',
    'gpt_image': 'GPT Image 2',
  };

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    final session = SessionScope.of(context);
    final t = T.of(context);
    try {
      await session.api.generateImage({
        'prompt': _prompt.text,
        'model': _model,
        if (widget.referenceIds.isNotEmpty) 'reference_ids': widget.referenceIds,
      });
      setState(() => _status = t.imgRequested);
    } catch (e) {
      setState(() => _status = t.error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
      // Balance changes after a successful (credit-consuming) call.
      session.refreshBalance();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = T.of(context);
    return ShowPage(
      title: t.imageGen,
      children: [
        const SizedBox(height: ShowSpacing.md),
        ShowField(label: t.promptLabel, controller: _prompt,
            hint: t.promptHint, maxLines: 4),
        ShowSectionHeader(t.model),
        for (final e in _models.entries) ...[
          ShowRow(
            leading: const HeroIcon(HeroIcons.cpuChip, size: 24),
            title: e.value,
            trailing: HeroIcon(
              _model == e.key ? HeroIcons.checkCircle : HeroIcons.stop,
              style: _model == e.key ? HeroIconStyle.solid : HeroIconStyle.outline,
              size: 24,
              color: _model == e.key ? ShowColors.accent : ShowColors.inkFaint,
            ),
            onTap: () => setState(() => _model = e.key),
          ),
          if (e.key != _models.keys.last) const Divider(),
        ],
        ShowSectionHeader(t.preview),
        AspectRatio(
          aspectRatio: 1,
          child: ColoredBox(
            color: ShowColors.creamSunken,
            child: Center(child: ShowEmpty(
              icon: const HeroIcon(HeroIcons.photo, size: 40, color: ShowColors.inkFaint),
              title: t.imageAppears,
            )),
          ),
        ),
        const SizedBox(height: ShowSpacing.xl),
        ShowButton(
          _busy ? t.generating : t.generateImage,
          leading: const HeroIcon(HeroIcons.sparkles, size: 20, color: ShowColors.cream),
          onPressed: _busy ? null : _generate,
        ),
        if (_status != null) ...[
          const SizedBox(height: ShowSpacing.md),
          Text(_status!, style: ShowType.bodyMuted),
        ],
      ],
    );
  }
}
