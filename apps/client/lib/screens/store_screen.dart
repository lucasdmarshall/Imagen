import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:show_ui/show_ui.dart';

import '../api/api_client.dart';
import '../i18n.dart';
import '../state/session.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  ApiClient? _api;
  Future<List<dynamic>>? _items;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // SessionScope is an inherited widget; read it here, not in initState()
    // or a field initializer (both run before dependencies are available).
    if (_api != null) return;
    _api = SessionScope.of(context).api;
    _items = _api!.storeItems();
  }

  String _price(int mmk) => mmk == 0 ? T.of(context).free : '${_fmt(mmk)} MMK';
  String _fmt(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  int _credits(Map<String, dynamic> e) => (e['credits'] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final t = T.of(context);
    return ShowPage(
      title: t.store,
      children: [
        FutureBuilder<List<dynamic>>(
          future: _items,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(ShowSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return ShowEmpty(
                icon: const HeroIcon(HeroIcons.shoppingBag, size: 36, color: ShowColors.inkFaint),
                title: t.storeUnavailable,
                subtitle: '${snap.error}',
              );
            }
            final items = (snap.data ?? const []).cast<Map<String, dynamic>>();
            final subs = items.where((e) => e['kind'] == 'subscription').toList();
            final packs = items.where((e) => e['kind'] == 'credit_pack').toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: showStagger([
                const SizedBox(height: ShowSpacing.lg),
                Text(t.storeHero,
                    style: ShowType.display.copyWith(
                        fontSize: 26, height: 1.15, fontWeight: FontWeight.w700)),
                const SizedBox(height: ShowSpacing.sm),
                Text(t.storeHeroSub,
                    style: ShowType.bodyLarge.copyWith(color: ShowColors.inkMuted)),
                ShowSectionHeader(t.subscriptions),
                _list(subs, subtitleFor: (e) => t.subCreditsExpire(_credits(e)), accent: true),
                ShowSectionHeader(t.addonCredits),
                _list(packs, subtitleFor: (e) => t.addonNeverExpires(_credits(e))),
              ], initialDelay: const Duration(milliseconds: 60)),
            );
          },
        ),
      ],
    );
  }

  Widget _list(
    List<Map<String, dynamic>> items, {
    required String Function(Map<String, dynamic>) subtitleFor,
    bool accent = false,
  }) {
    return Column(children: [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: ShowSpacing.md),
          child: _PlanCard(
            title: items[i]['name'] as String,
            subtitle: subtitleFor(items[i]),
            price: _price(items[i]['priceMmk'] as int),
            accent: accent,
            onTap: () => _openPayment(items[i]),
          ),
        ),
    ]);
  }

  Future<void> _openPayment(Map<String, dynamic> item) async {
    final session = SessionScope.of(context);
    final methods = await session.api.paymentMethods();
    if (!mounted) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PaymentSheet(
        item: item,
        methods: methods.cast<Map<String, dynamic>>(),
        price: _price(item['priceMmk'] as int),
        api: session.api,
      ),
    );
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(T.of(context).proofSubmitted),
      ));
    }
  }
}

/// A tactile plan / credit-pack card. Subscriptions render in the accent tone
/// to stand out; credit packs use a soft field. Hover warms, press scales.
class _PlanCard extends StatefulWidget {
  const _PlanCard({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.onTap,
    this.accent = false,
  });

  final String title;
  final String subtitle;
  final String price;
  final VoidCallback onTap;
  final bool accent;

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final onColor = widget.accent ? ShowColors.cream : ShowColors.ink;
    final subColor = widget.accent
        ? ShowColors.cream.withValues(alpha: 0.82)
        : ShowColors.inkMuted;
    final base = widget.accent ? ShowColors.accent : ShowColors.creamSunken;
    final hovered =
        widget.accent ? ShowColors.accentPressed : ShowColors.creamRaised;

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
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
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
              Text(widget.price,
                  style: ShowType.h3.copyWith(
                      color: onColor, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Manual-transfer payment sheet (AYA Pay / KBZ Pay). The buyer transfers,
/// then taps the button — no screenshot. Admin sees the order live via SSE.
class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({
    required this.item,
    required this.methods,
    required this.price,
    required this.api,
  });
  final Map<String, dynamic> item;
  final List<Map<String, dynamic>> methods;
  final String price;
  final ApiClient api;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  late String _methodId;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _methodId = widget.methods.isNotEmpty
        ? (widget.methods.first['id'] as String? ?? '')
        : '';
  }

  Future<void> _submit() async {
    final t = T.of(context);
    if (_methodId.isEmpty) {
      setState(() => _error = t.pickMethodFirst);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.submitPaymentProof(
        itemId: widget.item['id'] as String,
        method: _methodId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = T.of(context);
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          ShowSpacing.pageInset, ShowSpacing.sm, ShowSpacing.pageInset, ShowSpacing.xl + inset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: t.back,
                  onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                  icon: const HeroIcon(HeroIcons.arrowLeft, size: 22),
                ),
                Expanded(
                  child: Text(widget.item['name'] as String, style: ShowType.h2),
                ),
              ],
            ),
            const SizedBox(height: ShowSpacing.xs),
            Text(t.payVia(widget.price), style: ShowType.bodyMuted),
            for (final m in widget.methods) ...[
              const SizedBox(height: ShowSpacing.md),
              _methodCard(m),
            ],
            if (_error != null) ...[
              const SizedBox(height: ShowSpacing.md),
              Text(_error!,
                  style: ShowType.body.copyWith(color: ShowColors.danger)),
            ],
            const SizedBox(height: ShowSpacing.xl),
            ShowButton(
              _busy ? t.submittingProof : t.iPaid,
              onPressed: _busy ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _methodCard(Map<String, dynamic> m) {
    final t = T.of(context);
    final id = m['id'] as String? ?? '';
    final selected = id == _methodId;
    return ShowPressable(
      onTap: _busy ? null : () => setState(() => _methodId = id),
      child: AnimatedContainer(
        duration: ShowMotion.fast,
        padding: const EdgeInsets.all(ShowSpacing.md),
        decoration: BoxDecoration(
          color: selected ? ShowColors.creamRaised : ShowColors.creamSunken,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? ShowColors.accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m['name'] as String? ?? '', style: ShowType.h3),
            const SizedBox(height: ShowSpacing.sm),
            _line(t.receiver, m['receiverName'] as String? ?? ''),
            _line(t.number, m['receiverPhone'] as String? ?? ''),
            const SizedBox(height: ShowSpacing.md),
            Center(
              child: Container(
                width: 160,
                height: 160,
                color: ShowColors.creamSunken,
                child: const Center(
                    child: HeroIcon(HeroIcons.qrCode, size: 56, color: ShowColors.inkFaint)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(width: 96, child: Text(label, style: ShowType.label.copyWith(color: ShowColors.inkMuted))),
          Expanded(child: Text(value, style: ShowType.body)),
        ]),
      );
}
