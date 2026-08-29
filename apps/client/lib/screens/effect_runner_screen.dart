import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:http/http.dart' as http;
import 'package:show_ui/show_ui.dart';

import '../data/effects.dart';
import '../i18n.dart';
import '../state/session.dart';
import '../util/gen_result.dart';
import '../util/image_pick.dart';
import '../util/saver.dart';
import '../widgets/effect_card.dart';
import '../widgets/generating_sparkle.dart';

/// One page per effect: upload the required photo(s), tap generate (the prompt
/// is hidden), watch the ChatGPT-style loading lines, then view and save the
/// result. Fully data-driven from [Effect] — the same page serves every card.
class EffectRunnerScreen extends StatefulWidget {
  const EffectRunnerScreen({super.key, required this.effect});
  final Effect effect;

  @override
  State<EffectRunnerScreen> createState() => _EffectRunnerScreenState();
}

class _EffectRunnerScreenState extends State<EffectRunnerScreen> {
  Effect get e => widget.effect;

  late final List<Uint8List?> _picked =
      List<Uint8List?>.filled(e.inputs.length, null);

  // For slots that allow a typed alternative (e.g. describe a background):
  // a per-slot text controller and whether the slot is in text mode.
  late final List<TextEditingController> _textCtrls =
      List.generate(e.inputs.length, (_) => TextEditingController());
  late final List<bool> _textMode = List<bool>.filled(e.inputs.length, false);

  /// Whether slot [i] is currently a typed field rather than a photo upload.
  bool _isText(int i) {
    final inp = e.inputs[i];
    return inp.textOnly || (inp.allowText && _textMode[i]);
  }

  /// A slot is satisfied by an uploaded image, or by non-empty text in text mode.
  bool _slotReady(int i) =>
      _isText(i) ? _textCtrls[i].text.trim().isNotEmpty : _picked[i] != null;

  static const _models = {
    'nano_banana_pro': 'Nano Banana Pro',
    'gpt_image': 'GPT Image 2',
  };
  String _model = 'nano_banana_pro';

  bool _busy = false;
  Uint8List? _resultBytes;
  String? _resultUrl;
  String? _error;

  int _loadingIdx = 0;
  Timer? _loadTimer;

  @override
  void dispose() {
    _loadTimer?.cancel();
    for (final c in _textCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick(int i) async {
    final bytes = await pickCompressedBytes();
    if (bytes == null) return;
    if (mounted) setState(() => _picked[i] = bytes);
  }

  void _startLoading() {
    _loadingIdx = 0;
    _loadTimer = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      if (mounted) setState(() => _loadingIdx++);
    });
  }

  Future<void> _run(T t) async {
    if (!List.generate(e.inputs.length, _slotReady).every((r) => r)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.needAllPhotos)));
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
      // Collect typed text from any text field. A toggled photo-alternative
      // (allowText) selects the text-variant prompt; otherwise the base prompt
      // is used and any {text} placeholder is filled from the typed value.
      String? typed;
      var fromAllowText = false;
      for (var i = 0; i < e.inputs.length; i++) {
        if (_isText(i)) {
          final s = _textCtrls[i].text.trim();
          if (s.isNotEmpty) {
            typed = s;
            if (e.inputs[i].allowText) fromAllowText = true;
          }
        }
      }
      final base = (fromAllowText && e.promptText.isNotEmpty)
          ? e.promptText
          : e.prompt;
      final prompt = base.replaceAll('{text}', typed ?? '');
      if (prompt.trim().isEmpty) {
        throw StateError('Effect ${e.id} has an empty prompt');
      }

      final ids = <String>[];
      for (var i = 0; i < _picked.length; i++) {
        if (_isText(i)) continue; // text field, not a photo
        final bytes = _picked[i];
        if (bytes == null) continue;
        final res =
            await session.api.uploadImage(bytes, 'input_$i.jpg', 'image/jpeg');
        ids.add(res['id'] as String);
      }
      final res = await session.api.generateImage({
        'prompt': prompt,
        'model': _model,
        'reference_ids': ids,
      });
      _applyResult(res, t);
    } catch (err) {
      setState(() => _error = t.error(err));
    } finally {
      _loadTimer?.cancel();
      if (mounted) setState(() => _busy = false);
      session.refreshBalance();
    }
  }

  void _applyResult(dynamic res, T t) {
    final g = parseGenResult(res);
    setState(() {
      _resultBytes = g.bytes;
      _resultUrl = g.url;
      if (g.isEmpty) _error = t.error('no image in response');
    });
  }

  Future<void> _save(T t) async {
    var bytes = _resultBytes;
    if (bytes == null && _resultUrl != null) {
      final r = await http.get(Uri.parse(_resultUrl!));
      if (r.statusCode == 200) bytes = r.bodyBytes;
    }
    if (bytes == null) return;
    final ok = await saveBytes('show_${e.id}.png', bytes);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? t.savedOk : t.error('save failed'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = T.of(context);
    final ready =
        !_busy && List.generate(e.inputs.length, _slotReady).every((r) => r);
    final hasResult = _resultBytes != null || _resultUrl != null;

    return ShowPage(
      title: t.pick(e.titleMy, e.titleEn),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: showStagger([
            const SizedBox(height: ShowSpacing.md),
            _intro(t),
            const SizedBox(height: ShowSpacing.xl),
            _inputSection(t),
            const SizedBox(height: ShowSpacing.xl),
            Text(t.effectResult,
                style: ShowType.label.copyWith(color: ShowColors.inkMuted)),
            const SizedBox(height: ShowSpacing.sm),
            _resultArea(t),
            const SizedBox(height: ShowSpacing.lg),
            _modelSelector(t),
            const SizedBox(height: ShowSpacing.md),
            ShowButton(
              _busy ? t.generating : t.effectRun,
              leading: const HeroIcon(HeroIcons.sparkles,
                  size: 20, color: ShowColors.cream),
              onPressed: ready ? () => _run(t) : null,
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

  /// Title lives in the app bar (`<- Effect name`). Description left, card
  /// face (the same 3:2 before/after as the gallery) on the right.
  Widget _intro(T t) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              t.pick(e.subMy, e.subEn),
              style: ShowType.withMyanmar(
                ShowType.bodyMuted.copyWith(height: 1.45),
              ),
            ),
          ),
        ),
        const SizedBox(width: ShowSpacing.md),
        EffectCover(effect: e, width: 168),
      ],
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
            for (final m in _models.entries)
              _modelPill(m.key, m.value),
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

  Widget _inputSection(T t) {
    final photoIdx = [
      for (var i = 0; i < e.inputs.length; i++)
        if (!e.inputs[i].textOnly) i
    ];
    final textIdx = [
      for (var i = 0; i < e.inputs.length; i++)
        if (e.inputs[i].textOnly) i
    ];

    final Widget photos;
    if (photoIdx.length == 1) {
      photos = Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(width: 156, child: _slot(photoIdx.first, t, compact: true)),
      );
    } else {
      photos = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var n = 0; n < photoIdx.length; n++) ...[
            if (n > 0) const SizedBox(width: ShowSpacing.md),
            Expanded(child: _slot(photoIdx[n], t)),
          ],
        ],
      );
    }

    if (textIdx.isEmpty) return photos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        photos,
        const SizedBox(height: ShowSpacing.md),
        for (final i in textIdx) _slot(i, t),
      ],
    );
  }

  Widget _slot(int i, T t, {bool compact = false}) {
    final inp = e.inputs[i];
    final textMode = _isText(i);
    final label = textMode
        ? t.pick(inp.textLabelMy, inp.textLabelEn)
        : t.pick(inp.labelMy, inp.labelEn);
    final bytes = _picked[i];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: ShowType.label.copyWith(color: ShowColors.inkMuted)),
            ),
            if (inp.allowText) _modeToggle(i, t),
          ],
        ),
        const SizedBox(height: ShowSpacing.sm),
        if (textMode)
          Container(
            height: compact ? 120 : 112,
            padding: const EdgeInsets.all(ShowSpacing.md),
            decoration: BoxDecoration(
              color: ShowColors.creamSunken,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _textCtrls[i],
              onChanged: (_) => setState(() {}),
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: ShowType.body,
              decoration: InputDecoration.collapsed(
                hintText: t.pick(inp.textHintMy, inp.textHintEn),
                hintStyle: ShowType.body.copyWith(color: ShowColors.inkFaint),
              ),
            ),
          )
        else
          ShowPressable(
            onTap: () => _pick(i),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  color: ShowColors.creamSunken,
                  child: bytes != null
                      ? Image.memory(bytes, fit: BoxFit.cover)
                      : Center(
                          child: HeroIcon(HeroIcons.photo,
                              size: compact ? 22 : 30,
                              color: ShowColors.inkFaint),
                        ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// A compact Photo ⇄ Text switch for slots that accept a typed alternative.
  Widget _modeToggle(int i, T t) {
    Widget seg(String label, bool active, VoidCallback onTap) => ShowPressable(
          onTap: _busy ? null : onTap,
          child: AnimatedContainer(
            duration: ShowMotion.fast,
            curve: ShowMotion.entrance,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: active ? ShowColors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(label,
                style: ShowType.caption.copyWith(
                    color: active ? ShowColors.cream : ShowColors.inkMuted)),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: ShowColors.creamSunken,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg(t.pick('ပုံ', 'Photo'), !_textMode[i],
              () => setState(() => _textMode[i] = false)),
          seg(t.pick('စာ', 'Text'), _textMode[i],
              () => setState(() => _textMode[i] = true)),
        ],
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
                          : ShowEmpty(
                              icon: const HeroIcon(HeroIcons.photo,
                                  size: 40, color: ShowColors.inkFaint),
                              title: t.effectResultHere,
                            ),
        ),
      ),
    );
  }
}
