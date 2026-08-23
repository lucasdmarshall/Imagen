import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:show_ui/show_ui.dart';

import '../state/session.dart';

/// Image Generator — render a prompt with one of the two image models.
class ImageGeneratorScreen extends StatefulWidget {
  const ImageGeneratorScreen({super.key});

  @override
  State<ImageGeneratorScreen> createState() => _ImageGeneratorScreenState();
}

class _ImageGeneratorScreenState extends State<ImageGeneratorScreen> {
  final _prompt = TextEditingController();
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
    try {
      await session.api.generateImage({'prompt': _prompt.text, 'model': _model});
      setState(() => _status = 'Requested. Rendering will appear in your library.');
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
      // Balance changes after a successful (credit-consuming) call.
      session.refreshBalance();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShowPage(
      title: 'Image Generator',
      children: [
        const SizedBox(height: ShowSpacing.md),
        ShowField(label: 'Prompt', controller: _prompt,
            hint: 'Describe the image…', maxLines: 4),
        const ShowSectionHeader('Model'),
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
        const ShowSectionHeader('Preview'),
        AspectRatio(
          aspectRatio: 1,
          child: ColoredBox(
            color: ShowColors.creamSunken,
            child: const Center(child: ShowEmpty(
              icon: HeroIcon(HeroIcons.photo, size: 40, color: ShowColors.inkFaint),
              title: 'Your image appears here',
            )),
          ),
        ),
        const SizedBox(height: ShowSpacing.xl),
        ShowButton(
          _busy ? 'Generating…' : 'Generate image (5 credits)',
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
