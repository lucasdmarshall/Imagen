import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:http/http.dart' as http;
import 'package:show_ui/show_ui.dart';

import '../i18n.dart';
import '../state/session.dart';
import '../util/gen_result.dart';
import '../util/saver.dart';
import '../widgets/generating_sparkle.dart';

/// Image Generator — write (or receive) a prompt, pick a model, and render
/// on this page. Same generate API as the effect runner; the result is shown
/// here instead of being deferred to a library.
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
  Uint8List? _resultBytes;
  String? _resultUrl;
  String? _error;

  int _loadingIdx = 0;
  Timer? _loadTimer;

  static const _models = {
    'nano_banana_pro': 'Nano Banana Pro',
    'gpt_image': 'GPT Image 2',
  };

  @override
  void initState() {
    super.initState();
    _prompt.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    _prompt.dispose();
    super.dispose();
  }

  void _startLoading() {
    _loadingIdx = 0;
    _loadTimer = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      if (mounted) setState(() => _loadingIdx++);
    });
  }

  Future<void> _generate() async {
    final t = T.of(context);
    final text = _prompt.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.error('prompt is required'))));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _resultBytes = null;
      _resultUrl = null;
    });
    _startLoading();
    final session = SessionScope.of(context);
    try {
      final res = await session.api.generateImage({
        'prompt': text,
        'model': _model,
        if (widget.referenceIds.isNotEmpty) 'reference_ids': widget.referenceIds,
      });
      final g = parseGenResult(res);
      setState(() {
        _resultBytes = g.bytes;
        _resultUrl = g.url;
        if (g.isEmpty) _error = t.error('no image in response');
      });
    } catch (e) {
      setState(() => _error = t.error(e));
    } finally {
      _loadTimer?.cancel();
      if (mounted) setState(() => _busy = false);
      session.refreshBalance();
    }
  }

  Future<void> _save(T t) async {
    var bytes = _resultBytes;
    if (bytes == null && _resultUrl != null) {
      final r = await http.get(Uri.parse(_resultUrl!));
      if (r.statusCode == 200) bytes = r.bodyBytes;
    }
    if (bytes == null) return;
    final ok = await saveBytes('show_generate.png', bytes);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? t.savedOk : t.error('save failed'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = T.of(context);
    final ready = !_busy && _prompt.text.trim().isNotEmpty;
    final hasResult = _resultBytes != null || _resultUrl != null;

    return ShowPage(
      title: t.imageGen,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: showStagger([
            const SizedBox(height: ShowSpacing.md),
            Text(
              t.imageGenSub,
              style: ShowType.withMyanmar(
                ShowType.bodyMuted.copyWith(height: 1.45),
              ),
            ),
            const SizedBox(height: ShowSpacing.xl),
            Text(t.promptLabel,
                style: ShowType.label.copyWith(color: ShowColors.inkMuted)),
            const SizedBox(height: ShowSpacing.sm),
            _promptBox(t),
            const SizedBox(height: ShowSpacing.lg),
            _modelSelector(t),
            const SizedBox(height: ShowSpacing.xl),
            Text(t.effectResult,
                style: ShowType.label.copyWith(color: ShowColors.inkMuted)),
            const SizedBox(height: ShowSpacing.sm),
            _resultArea(t),
            const SizedBox(height: ShowSpacing.lg),
            ShowButton(
              _busy ? t.generating : t.generateImage,
              leading: const HeroIcon(HeroIcons.sparkles,
                  size: 20, color: ShowColors.cream),
              onPressed: ready ? _generate : null,
            ),
            if (hasResult && !_busy) ...[
              const SizedBox(height: ShowSpacing.md),
              OutlinedButton.icon(
                onPressed: () => _save(t),
                icon: const HeroIcon(HeroIcons.arrowDownTray, size: 20),
                label: Text(t.saveToGallery),
              ),
            ],
          ], initialDelay: const Duration(milliseconds: 60)),
        ),
      ],
    );
  }

  Widget _promptBox(T t) {
    return Container(
      height: 148,
      padding: const EdgeInsets.all(ShowSpacing.md),
      decoration: BoxDecoration(
        color: ShowColors.creamSunken,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: _prompt,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: ShowType.body,
        decoration: InputDecoration.collapsed(
          hintText: t.promptHint,
          hintStyle: ShowType.body.copyWith(color: ShowColors.inkFaint),
        ),
      ),
    );
  }

  Widget _modelSelector(T t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.model.toUpperCase(),
            style: ShowType.label
                .copyWith(color: ShowColors.inkFaint, letterSpacing: 1.2)),
        const SizedBox(height: ShowSpacing.sm),
        Wrap(
          spacing: ShowSpacing.sm,
          runSpacing: ShowSpacing.sm,
          children: [
            for (final m in _models.entries) _modelPill(m.key, m.value),
          ],
        ),
      ],
    );
  }

  Widget _modelPill(String key, String label) {
    final selected = _model == key;
    return ShowPressable(
      onTap: _busy ? null : () => setState(() => _model = key),
      child: AnimatedContainer(
        duration: ShowMotion.fast,
        curve: ShowMotion.entrance,
        padding: const EdgeInsets.symmetric(
            horizontal: ShowSpacing.md, vertical: ShowSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? ShowColors.accent : ShowColors.creamSunken,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: ShowMotion.fast,
              curve: ShowMotion.entrance,
              child: selected
                  ? const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: HeroIcon(HeroIcons.check,
                          size: 16,
                          color: ShowColors.cream,
                          style: HeroIconStyle.solid),
                    )
                  : const SizedBox.shrink(),
            ),
            Text(label,
                style: ShowType.body.copyWith(
                    color: selected ? ShowColors.cream : ShowColors.ink)),
          ],
        ),
      ),
    );
  }

  Widget _resultArea(T t) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          color: ShowColors.creamSunken,
          alignment: Alignment.center,
          child: _busy
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const GeneratingSparkle(),
                    const SizedBox(height: ShowSpacing.md),
                    AnimatedSwitcher(
                      duration: ShowMotion.base,
                      child: Text(
                        t.effectLoading[_loadingIdx % t.effectLoading.length],
                        key: ValueKey(_loadingIdx),
                        style: ShowType.body.copyWith(color: ShowColors.inkMuted),
                      ),
                    ),
                  ],
                )
              : _resultBytes != null
                  ? Image.memory(_resultBytes!, fit: BoxFit.cover)
                  : _resultUrl != null
                      ? Image.network(_resultUrl!, fit: BoxFit.cover)
                      : _error != null
                          ? Padding(
                              padding: const EdgeInsets.all(ShowSpacing.lg),
                              child: Text(_error!,
                                  textAlign: TextAlign.center,
                                  style: ShowType.bodyMuted),
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const HeroIcon(HeroIcons.photo,
                                    size: 40, color: ShowColors.inkFaint),
                                const SizedBox(height: ShowSpacing.md),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: ShowSpacing.lg),
                                  child: Text(
                                    t.imageAppears,
                                    textAlign: TextAlign.center,
                                    style: ShowType.withMyanmar(
                                      ShowType.bodyMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
        ),
      ),
    );
  }
}
