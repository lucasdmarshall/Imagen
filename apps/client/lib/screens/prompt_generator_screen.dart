import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:show_ui/show_ui.dart';

import '../state/session.dart';

/// A pixel-perfect region with its own instruction. Coordinates are normalized
/// (0..1) so the same layout maps to any output resolution.
class Perimeter {
  Perimeter(this.label, this.prompt, this.x, this.y, this.w, this.h);
  String label;
  String prompt;
  double x, y, w, h;
}

/// Prompt Generator — the perimeter-driven core. Define regions on the canvas,
/// give each its own instruction, then compose one precise prompt.
class PromptGeneratorScreen extends StatefulWidget {
  const PromptGeneratorScreen({super.key});

  @override
  State<PromptGeneratorScreen> createState() => _PromptGeneratorScreenState();
}

class _PromptGeneratorScreenState extends State<PromptGeneratorScreen> {
  final _base = TextEditingController();
  final _perimeters = <Perimeter>[];
  String _model = 'gemini_flash';
  bool _busy = false;
  String? _result;

  static const _models = {
    'gemini_flash': 'Gemini 3.7 Flash',
    'gpt_luna': 'GPT-5.6 Luna',
    'gpt_mini': 'GPT-5 mini',
  };

  Future<void> _addPerimeter() async {
    final p = await showModalBottomSheet<Perimeter>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _PerimeterSheet(),
    );
    if (p != null) setState(() => _perimeters.add(p));
  }

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _result = null;
    });
    final session = SessionScope.of(context);
    try {
      final res = await session.api.generatePrompt({
        'base_prompt': _base.text,
        'model': _model,
        'perimeters': [
          for (final p in _perimeters)
            {'label': p.label, 'prompt': p.prompt, 'x': p.x, 'y': p.y, 'width': p.w, 'height': p.h}
        ],
      });
      setState(() => _result = res.toString());
    } catch (e) {
      setState(() => _result = 'Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
      // Balance changes after a successful (credit-consuming) call.
      session.refreshBalance();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShowPage(
      title: 'Prompt Generator',
      children: [
        const SizedBox(height: ShowSpacing.md),
        ShowField(label: 'Base prompt', controller: _base,
            hint: 'Describe the whole image…', maxLines: 3),
        const ShowSectionHeader('Perimeters'),
        AspectRatio(
          aspectRatio: 1,
          child: _Canvas(perimeters: _perimeters),
        ),
        const SizedBox(height: ShowSpacing.md),
        for (var i = 0; i < _perimeters.length; i++) ...[
          ShowRow(
            leading: _Swatch(index: i),
            title: _perimeters[i].label,
            subtitle: _perimeters[i].prompt,
            trailing: IconButton(
              icon: const HeroIcon(HeroIcons.trash, size: 20),
              onPressed: () => setState(() => _perimeters.removeAt(i)),
            ),
          ),
          if (i < _perimeters.length - 1) const Divider(),
        ],
        const SizedBox(height: ShowSpacing.sm),
        TextButton.icon(
          onPressed: _addPerimeter,
          icon: const HeroIcon(HeroIcons.plus, size: 20),
          label: const Text('Add perimeter'),
        ),
        const ShowSectionHeader('Model'),
        _ModelSelector(
          options: _models,
          value: _model,
          onChanged: (v) => setState(() => _model = v),
        ),
        const SizedBox(height: ShowSpacing.xl),
        ShowButton(
          _busy ? 'Generating…' : 'Generate prompt (1 credit)',
          leading: const HeroIcon(HeroIcons.sparkles, size: 20, color: ShowColors.cream),
          onPressed: _busy ? null : _generate,
        ),
        if (_result != null) ...[
          const ShowSectionHeader('Result'),
          Text(_result!, style: ShowType.body),
        ],
      ],
    );
  }
}

/// Canvas showing perimeters as normalized overlays. Region outlines are data,
/// not UI chrome, so thin accent strokes are used to make them selectable.
class _Canvas extends StatelessWidget {
  const _Canvas({required this.perimeters});
  final List<Perimeter> perimeters;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      return Container(
        color: ShowColors.creamSunken,
        child: Stack(children: [
          if (perimeters.isEmpty)
            const Center(child: ShowEmpty(
              icon: HeroIcon(HeroIcons.viewfinderCircle, size: 40, color: ShowColors.inkFaint),
              title: 'No perimeters yet',
              subtitle: 'Add a region to control part of the image.',
            )),
          for (var i = 0; i < perimeters.length; i++)
            Positioned(
              left: perimeters[i].x * c.maxWidth,
              top: perimeters[i].y * c.maxHeight,
              width: perimeters[i].w * c.maxWidth,
              height: perimeters[i].h * c.maxHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: _palette[i % _palette.length], width: 2),
                  color: _palette[i % _palette.length].withValues(alpha: 0.10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(perimeters[i].label,
                      style: ShowType.caption.copyWith(color: _palette[i % _palette.length])),
                ),
              ),
            ),
        ]),
      );
    });
  }
}

const _palette = [
  ShowColors.accent,
  ShowColors.warning,
  ShowColors.success,
  ShowColors.danger,
];

class _Swatch extends StatelessWidget {
  const _Swatch({required this.index});
  final int index;
  @override
  Widget build(BuildContext context) => Container(
        width: 18, height: 18,
        decoration: BoxDecoration(
          color: _palette[index % _palette.length],
          borderRadius: BorderRadius.circular(4),
        ),
      );
}

class _ModelSelector extends StatelessWidget {
  const _ModelSelector({required this.options, required this.value, required this.onChanged});
  final Map<String, String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final e in options.entries) ...[
          ShowRow(
            title: e.value,
            trailing: HeroIcon(
              value == e.key ? HeroIcons.checkCircle : HeroIcons.stop,
              style: value == e.key ? HeroIconStyle.solid : HeroIconStyle.outline,
              size: 24,
              color: value == e.key ? ShowColors.accent : ShowColors.inkFaint,
            ),
            onTap: () => onChanged(e.key),
          ),
          if (e.key != options.keys.last) const Divider(),
        ],
      ],
    );
  }
}

/// Bottom sheet to define a perimeter's label, prompt, and normalized bounds.
class _PerimeterSheet extends StatefulWidget {
  const _PerimeterSheet();
  @override
  State<_PerimeterSheet> createState() => _PerimeterSheetState();
}

class _PerimeterSheetState extends State<_PerimeterSheet> {
  final _label = TextEditingController();
  final _prompt = TextEditingController();
  double _x = 0.1, _y = 0.1, _w = 0.4, _h = 0.4;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          ShowSpacing.pageInset, ShowSpacing.lg, ShowSpacing.pageInset, inset + ShowSpacing.lg),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New perimeter', style: ShowType.h2),
            const SizedBox(height: ShowSpacing.lg),
            ShowField(label: 'Label', controller: _label, hint: 'e.g. Sky'),
            const SizedBox(height: ShowSpacing.md),
            ShowField(label: 'Region prompt', controller: _prompt,
                hint: 'What goes in this region', maxLines: 2),
            const SizedBox(height: ShowSpacing.lg),
            _slider('X', _x, (v) => setState(() => _x = v)),
            _slider('Y', _y, (v) => setState(() => _y = v)),
            _slider('Width', _w, (v) => setState(() => _w = v)),
            _slider('Height', _h, (v) => setState(() => _h = v)),
            const SizedBox(height: ShowSpacing.lg),
            ShowButton('Add', onPressed: () {
              Navigator.of(context).pop(Perimeter(
                _label.text.isEmpty ? 'Region' : _label.text,
                _prompt.text, _x, _y, _w, _h));
            }),
          ],
        ),
      ),
    );
  }

  Widget _slider(String label, double v, ValueChanged<double> onChanged) {
    return Row(children: [
      SizedBox(width: 72, child: Text(label, style: ShowType.label)),
      Expanded(child: Slider(value: v, onChanged: onChanged, activeColor: ShowColors.accent)),
      SizedBox(width: 44, child: Text(v.toStringAsFixed(2), style: ShowType.caption)),
    ]);
  }
}
