import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:show_ui/show_ui.dart';

import 'api.dart';

/// Live catalog editor: subscription prices / monthly credits, and add-on packs.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key, required this.api});
  final AdminApi api;

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  Map<String, dynamic>? _data;
  Object? _error;
  bool _loading = true;
  StreamSubscription<String>? _live;

  @override
  void initState() {
    super.initState();
    _reload();
    _live = widget.api.live.listen((topic) {
      if (topic == 'catalog' && mounted) _reload(silent: true);
    });
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  Future<void> _reload({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final data = await widget.api.catalog();
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _plans =>
      ((_data?['plans'] as List?) ?? const []).cast<Map<String, dynamic>>();

  List<Map<String, dynamic>> get _packs =>
      ((_data?['items'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .where((e) => e['kind'] == 'credit_pack')
          .toList();

  Future<void> _addPack() async {
    final credits = TextEditingController(text: '50');
    final price = TextEditingController(text: '1500');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add credit pack'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: credits,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Credits'),
            ),
            TextField(
              controller: price,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Price (MMK)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.api.addPack(
        int.parse(credits.text.trim()),
        int.parse(price.text.trim()),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Store'),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: ShowSizing.maxContentWidth),
            child: _body(),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading && _data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(ShowSpacing.xl),
          child: Text('$_error',
              style: ShowType.bodyMuted, textAlign: TextAlign.center),
        ),
      );
    }
    final paid = _plans.where((p) => p['id'] != 'free').toList();
    final free = _plans.where((p) => p['id'] == 'free').toList();
    return ListView(
      padding: const EdgeInsets.symmetric(
          horizontal: ShowSpacing.pageInset, vertical: ShowSpacing.lg),
      children: [
        Text('Prices and monthly credits apply to the client store immediately. Pending orders keep the amount they were submitted with.',
            style: ShowType.bodyMuted),
        const SizedBox(height: ShowSpacing.xl),
        Text('Subscriptions', style: ShowType.h2),
        const SizedBox(height: ShowSpacing.xs),
        Text('Price and how many credits a buyer gets each month.',
            style: ShowType.bodyMuted),
        const SizedBox(height: ShowSpacing.md),
        for (final p in paid)
          _PlanEditor(
            key: ValueKey('plan-${p['id']}-${p['priceMmk']}-${p['monthlyCredits']}'),
            plan: p,
            onSave: (price, credits) async {
              await widget.api.updatePlan(p['id'] as String,
                  priceMmk: price, monthlyCredits: credits);
              await _reload();
            },
          ),
        if (free.isNotEmpty) ...[
          const SizedBox(height: ShowSpacing.lg),
          Text('Free plan', style: ShowType.h2),
          const SizedBox(height: ShowSpacing.xs),
          Text('Monthly credits for new accounts. Price stays 0.',
              style: ShowType.bodyMuted),
          const SizedBox(height: ShowSpacing.md),
          _PlanEditor(
            key: ValueKey('plan-free-${free.first['monthlyCredits']}'),
            plan: free.first,
            priceLocked: true,
            onSave: (price, credits) async {
              await widget.api.updatePlan('free', monthlyCredits: credits);
              await _reload();
            },
          ),
        ],
        const SizedBox(height: ShowSpacing.xl),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add-on credits', style: ShowType.h2),
                  const SizedBox(height: ShowSpacing.xs),
                  Text('Never expire. Set how many credits at what price.',
                      style: ShowType.bodyMuted),
                ],
              ),
            ),
            FilledButton(onPressed: _addPack, child: const Text('Add pack')),
          ],
        ),
        const SizedBox(height: ShowSpacing.md),
        for (final pack in _packs)
          _PackEditor(
            key: ValueKey('pack-${pack['id']}-${pack['credits']}-${pack['priceMmk']}'),
            pack: pack,
            canDelete: !_builtinPack(pack['id'] as String? ?? ''),
            onSave: (credits, price) async {
              await widget.api.updatePack(pack['id'] as String,
                  credits: credits, priceMmk: price);
              await _reload();
            },
            onDelete: () async {
              await widget.api.removePack(pack['id'] as String);
              await _reload();
            },
          ),
      ],
    );
  }

  bool _builtinPack(String id) =>
      id == 'credits_100' || id == 'credits_300' || id == 'credits_1000';
}

class _PlanEditor extends StatefulWidget {
  const _PlanEditor({
    super.key,
    required this.plan,
    required this.onSave,
    this.priceLocked = false,
  });

  final Map<String, dynamic> plan;
  final bool priceLocked;
  final Future<void> Function(int priceMmk, int monthlyCredits) onSave;

  @override
  State<_PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends State<_PlanEditor> {
  late final TextEditingController _price;
  late final TextEditingController _credits;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _price = TextEditingController(
        text: '${(widget.plan['priceMmk'] as num?)?.toInt() ?? 0}');
    _credits = TextEditingController(
        text: '${(widget.plan['monthlyCredits'] as num?)?.toInt() ?? 0}');
  }

  @override
  void dispose() {
    _price.dispose();
    _credits.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await widget.onSave(
        int.parse(_price.text.trim()),
        int.parse(_credits.text.trim()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ShowSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(ShowSpacing.md),
        decoration: BoxDecoration(
          color: ShowColors.creamSunken,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.plan['name'] as String? ?? '', style: ShowType.h3),
            const SizedBox(height: ShowSpacing.md),
            Row(
              children: [
                if (!widget.priceLocked)
                  Expanded(
                    child: TextField(
                      controller: _price,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration:
                          const InputDecoration(labelText: 'Price (MMK)'),
                    ),
                  ),
                if (!widget.priceLocked)
                  const SizedBox(width: ShowSpacing.md),
                Expanded(
                  child: TextField(
                    controller: _credits,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                        labelText: 'Credits / month'),
                  ),
                ),
                const SizedBox(width: ShowSpacing.md),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? '…' : 'Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PackEditor extends StatefulWidget {
  const _PackEditor({
    super.key,
    required this.pack,
    required this.onSave,
    required this.onDelete,
    required this.canDelete,
  });

  final Map<String, dynamic> pack;
  final bool canDelete;
  final Future<void> Function(int credits, int priceMmk) onSave;
  final Future<void> Function() onDelete;

  @override
  State<_PackEditor> createState() => _PackEditorState();
}

class _PackEditorState extends State<_PackEditor> {
  late final TextEditingController _credits;
  late final TextEditingController _price;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _credits = TextEditingController(
        text: '${(widget.pack['credits'] as num?)?.toInt() ?? 0}');
    _price = TextEditingController(
        text: '${(widget.pack['priceMmk'] as num?)?.toInt() ?? 0}');
  }

  @override
  void dispose() {
    _credits.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await widget.onSave(
        int.parse(_credits.text.trim()),
        int.parse(_price.text.trim()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ShowSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(ShowSpacing.md),
        decoration: BoxDecoration(
          color: ShowColors.creamSunken,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _credits,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Credits'),
              ),
            ),
            const SizedBox(width: ShowSpacing.md),
            Expanded(
              child: TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Price (MMK)'),
              ),
            ),
            const SizedBox(width: ShowSpacing.md),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? '…' : 'Save'),
            ),
            if (widget.canDelete)
              IconButton(
                tooltip: 'Remove pack',
                onPressed: _busy
                    ? null
                    : () async {
                        try {
                          await widget.onDelete();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text('$e')));
                          }
                        }
                      },
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
      ),
    );
  }
}
