import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heroicons/heroicons.dart';
import 'package:show_ui/show_ui.dart';

import '../i18n.dart';
import '../models/flow.dart';
import '../state/session.dart';
import '../state/wizard_controller.dart';
import 'image_generator_screen.dart';
import 'wizard_screen.dart';

/// End of the guided flow: shows the answer summary and the compiled prompt to
/// copy, enhance, or send straight to the Image Generator.
class PromptReviewScreen extends StatefulWidget {
  const PromptReviewScreen({super.key, required this.controller});
  final WizardController controller;

  @override
  State<PromptReviewScreen> createState() => _PromptReviewScreenState();
}

class _PromptReviewScreenState extends State<PromptReviewScreen> {
  String _prompt = '';
  bool _loading = true;
  bool _enhancing = false;

  WizardController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _compile();
  }

  Future<void> _compile() async {
    try {
      final p = await SessionScope.of(context).api.compilePrompt(c.answers);
      setState(() {
        _prompt = p;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _prompt = '';
        _loading = false;
      });
    }
  }

  List<String> get _referenceIds => [
        for (final n in c.answeredVisible)
          if (n.type == NodeType.image) c.answers[n.id]!
      ];

  Future<void> _copy(T t) async {
    await Clipboard.setData(ClipboardData(text: _prompt));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.copied)));
    }
  }

  Future<void> _enhance() async {
    setState(() => _enhancing = true);
    final session = SessionScope.of(context);
    try {
      final res = await session.api.generatePrompt({'base_prompt': _prompt});
      final text = _extractText(res);
      if (text != null && text.isNotEmpty) setState(() => _prompt = text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Enhance failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _enhancing = false);
      session.refreshBalance();
    }
  }

  void _generate() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ImageGeneratorScreen(
        initialPrompt: _prompt,
        referenceIds: _referenceIds,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = T.of(context);
    final locale = SessionScope.of(context).locale;
    return ShowPage(
      title: t.review,
      children: [
        const SizedBox(height: ShowSpacing.md),
        // --- Answer summary (edit any step) ---
        for (final n in c.answeredVisible) ...[
          ShowRow(
            title: n.question.t(locale),
            subtitle: _display(n, locale),
            trailing: TextButton(
              onPressed: () {
                c.editNode(n.id);
                Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => WizardScreen(controller: c)));
              },
              child: Text(t.editStep),
            ),
          ),
          const Divider(),
        ],

        // --- Compiled prompt ---
        ShowSectionHeader(t.yourPrompt),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(ShowSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ShowSpacing.md),
            decoration: BoxDecoration(
              color: ShowColors.creamSunken,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(_prompt, style: ShowType.body),
          ),
        const SizedBox(height: ShowSpacing.md),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _loading ? null : () => _copy(t),
              icon: const HeroIcon(HeroIcons.clipboard, size: 20),
              label: Text(t.copy),
            ),
          ),
          const SizedBox(width: ShowSpacing.md),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _loading || _enhancing ? null : _enhance,
              icon: const HeroIcon(HeroIcons.sparkles, size: 20),
              label: Text(_enhancing ? '…' : t.enhance),
            ),
          ),
        ]),

        // --- Generate CTA ---
        const SizedBox(height: ShowSpacing.xl),
        Text(t.generateCta, style: ShowType.h3),
        const SizedBox(height: ShowSpacing.md),
        ShowButton(
          t.generate,
          leading: const HeroIcon(HeroIcons.photo, size: 20, color: ShowColors.cream),
          onPressed: _loading ? null : _generate,
        ),
      ],
    );
  }

  /// Human-readable answer value for the summary (localized option label when
  /// the answer matches an option; otherwise the raw text / a photo marker).
  String _display(FlowNode n, String locale) {
    final v = c.answers[n.id] ?? '';
    if (n.type == NodeType.image) return '📷';
    if (n.type == NodeType.multi) {
      final labels = v.split(',').map((val) {
        final o = n.options.where((o) => o.value == val);
        return o.isNotEmpty ? o.first.label.t(locale) : val;
      });
      return labels.join(', ');
    }
    final match = n.options.where((o) => o.value == v);
    return match.isNotEmpty ? match.first.label.t(locale) : v;
  }

  String? _extractText(dynamic res) {
    try {
      return res['choices'][0]['message']['content'] as String?;
    } catch (_) {
      return null;
    }
  }
}
