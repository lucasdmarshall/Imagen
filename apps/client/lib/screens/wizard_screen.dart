import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:show_ui/show_ui.dart';

import '../i18n.dart';
import '../models/flow.dart';
import '../state/session.dart';
import '../state/wizard_controller.dart';
import 'prompt_review_screen.dart';

/// Renders the guided questionnaire one question at a time.
class WizardScreen extends StatefulWidget {
  const WizardScreen({super.key, required this.controller});
  final WizardController controller;

  @override
  State<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends State<WizardScreen> {
  final _text = TextEditingController();
  final _other = TextEditingController();
  final _multi = <String>{};
  String? _syncedFor;
  Uint8List? _imageBytes;
  String? _preview;
  bool _showOther = false;

  WizardController get c => widget.controller;

  void _syncFor(FlowNode node) {
    if (_syncedFor == node.id) return;
    _syncedFor = node.id;
    _imageBytes = null;
    _multi.clear();
    _other.clear();
    _showOther = false;
    final existing = c.answer(node.id);
    if (node.type == NodeType.multi) {
      if (existing != null) _multi.addAll(existing.split(','));
    } else if (node.type == NodeType.text) {
      _text.text = existing ?? '';
    } else if (node.type == NodeType.single && existing != null) {
      final isOption = node.options.any((o) => o.value == existing);
      if (!isOption) {
        _showOther = true;
        _other.text = existing;
      }
    }
  }

  Future<void> _refreshPreview() async {
    try {
      final p = await SessionScope.of(context).api.compilePrompt(c.answers);
      if (mounted) setState(() => _preview = p);
    } catch (_) {}
  }

  void _goNext() {
    c.next();
    _refreshPreview();
  }

  Future<void> _pickImage(FlowNode node, ImageSource source) async {
    final api = SessionScope.of(context).api;
    final messenger = ScaffoldMessenger.of(context);
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 1600);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _imageBytes = bytes);
    try {
      final res = await api.uploadImage(
          bytes, picked.name, picked.mimeType ?? 'image/jpeg');
      c.setAnswer(node.id, res['id'] as String);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final node = c.current;
        if (node == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (_) => PromptReviewScreen(controller: c)));
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        _syncFor(node);
        final t = T.of(context);
        final locale = SessionScope.of(context).locale;

        return Scaffold(
          appBar: AppBar(
            title: Text(t.stepOf(c.position, c.totalVisible)),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(2),
              child: LinearProgressIndicator(
                value: c.progress,
                minHeight: 2,
                backgroundColor: ShowColors.creamSunken,
                color: ShowColors.accent,
              ),
            ),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: ShowSizing.maxContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: ShowSpacing.pageInset, vertical: ShowSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(node.question.t(locale), style: ShowType.h2),
                            if (node.help.t(locale).isNotEmpty) ...[
                              const SizedBox(height: ShowSpacing.sm),
                              Text(node.help.t(locale), style: ShowType.bodyMuted),
                            ],
                            const SizedBox(height: ShowSpacing.lg),
                            _input(node, locale, t),
                          ],
                        ),
                      ),
                    ),
                    _previewBar(t),
                    _bottomBar(node, t),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _input(FlowNode node, String locale, T t) {
    switch (node.type) {
      case NodeType.single:
        return _singleInput(node, locale, t);
      case NodeType.multi:
        return _multiInput(node, locale, t);
      case NodeType.image:
        return _imageInput(node, t);
      case NodeType.text:
      case NodeType.slider:
        return TextField(
          controller: _text,
          maxLines: 3,
          minLines: 1,
          style: ShowType.body,
          decoration: InputDecoration(hintText: t.typeHere),
          onChanged: (v) => c.setAnswer(node.id, v.trim()),
        );
    }
  }

  Widget _singleInput(FlowNode node, String locale, T t) {
    final selected = c.answer(node.id);
    return Column(children: [
      for (final o in node.options) ...[
        _choiceRow(
          label: o.label.t(locale),
          checked: !_showOther && selected == o.value,
          onTap: () {
            setState(() => _showOther = false);
            _other.clear();
            c.setAnswer(node.id, o.value);
          },
        ),
        const Divider(),
      ],
      _choiceRow(
        label: t.other,
        checked: _showOther,
        onTap: () => setState(() => _showOther = true),
      ),
      if (_showOther) ...[
        const SizedBox(height: ShowSpacing.sm),
        TextField(
          controller: _other,
          autofocus: true,
          style: ShowType.body,
          decoration: InputDecoration(hintText: t.typeHere),
          onChanged: (v) => c.setAnswer(node.id, v.trim()),
        ),
      ],
    ]);
  }

  Widget _multiInput(FlowNode node, String locale, T t) {
    void commit() => c.setAnswer(node.id, _multi.join(','));
    return Column(children: [
      for (final o in node.options) ...[
        _choiceRow(
          label: o.label.t(locale),
          checked: _multi.contains(o.value),
          box: true,
          onTap: () {
            setState(() => _multi.contains(o.value)
                ? _multi.remove(o.value)
                : _multi.add(o.value));
            commit();
          },
        ),
        const Divider(),
      ],
    ]);
  }

  Widget _imageInput(FlowNode node, T t) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_imageBytes != null)
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(_imageBytes!, height: 220, fit: BoxFit.cover),
        )
      else
        Container(
          height: 220,
          color: ShowColors.creamSunken,
          child: const Center(
            child: HeroIcon(HeroIcons.photo, size: 44, color: ShowColors.inkFaint)),
        ),
      const SizedBox(height: ShowSpacing.md),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickImage(node, ImageSource.gallery),
            icon: const HeroIcon(HeroIcons.photo, size: 20),
            label: Text(_imageBytes == null ? t.uploadPhoto : t.changePhoto),
          ),
        ),
        const SizedBox(width: ShowSpacing.md),
        IconButton.outlined(
          onPressed: () => _pickImage(node, ImageSource.camera),
          icon: const HeroIcon(HeroIcons.camera, size: 20),
        ),
      ]),
    ]);
  }

  Widget _choiceRow({
    required String label,
    required bool checked,
    required VoidCallback onTap,
    bool box = false,
  }) {
    return ShowRow(
      title: label,
      onTap: onTap,
      trailing: HeroIcon(
        checked
            ? (box ? HeroIcons.checkCircle : HeroIcons.checkCircle)
            : (box ? HeroIcons.stop : HeroIcons.stop),
        style: checked ? HeroIconStyle.solid : HeroIconStyle.outline,
        size: 26,
        color: checked ? ShowColors.accent : ShowColors.inkFaint,
      ),
    );
  }

  Widget _previewBar(T t) {
    if (_preview == null || _preview!.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: ShowColors.creamSunken,
      padding: const EdgeInsets.symmetric(
          horizontal: ShowSpacing.pageInset, vertical: ShowSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t.livePreview, style: ShowType.label.copyWith(color: ShowColors.inkFaint)),
        const SizedBox(height: 4),
        Text(_preview!, style: ShowType.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _bottomBar(FlowNode node, T t) {
    final optional = node.type == NodeType.text ||
        node.type == NodeType.image ||
        node.type == NodeType.slider;
    final answered = (c.answer(node.id) ?? '').isNotEmpty;
    final canNext = optional || answered;
    return Padding(
      padding: const EdgeInsets.all(ShowSpacing.md),
      child: Row(children: [
        if (c.canBack)
          TextButton.icon(
            onPressed: () {
              c.back();
              _syncedFor = null;
            },
            icon: const HeroIcon(HeroIcons.arrowLeft, size: 20),
            label: Text(t.back),
          ),
        const Spacer(),
        if (optional && !answered)
          TextButton(onPressed: _goNext, child: Text(t.skip)),
        const SizedBox(width: ShowSpacing.sm),
        FilledButton(
          onPressed: canNext ? _goNext : null,
          child: Text(t.next),
        ),
      ]),
    );
  }
}
