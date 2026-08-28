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
                _list(subs, subtitleFor: (e) => t.renewsAuto, accent: true),
                ShowSectionHeader(t.addonCredits),
                _list(packs, subtitleFor: (e) => t.creditsAmount(e['credits'] as int)),
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
    final methods = await SessionScope.of(context).api.paymentMethods();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PaymentSheet(
        item: item,
        methods: methods.cast<Map<String, dynamic>>(),
        price: _price(item['priceMmk'] as int),
      ),
    );
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

/// Manual-transfer payment sheet (AYA Pay / KBZ Pay). Shows the payee details;
/// the buyer transfers, then submits proof for admin verification.
class _PaymentSheet extends StatelessWidget {
  const _PaymentSheet({required this.item, required this.methods, required this.price});
  final Map<String, dynamic> item;
  final List<Map<String, dynamic>> methods;
  final String price;

  @override
  Widget build(BuildContext context) {
    final t = T.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          ShowSpacing.pageInset, ShowSpacing.lg, ShowSpacing.pageInset, ShowSpacing.xl),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(item['name'] as String, style: ShowType.h2),
            const SizedBox(height: ShowSpacing.xs),
            Text(t.payVia(price), style: ShowType.bodyMuted),
            for (final m in methods) ...[
              const ShowSectionHeader(''),
              Text(m['name'] as String, style: ShowType.h3),
              const SizedBox(height: ShowSpacing.sm),
              _line(t.receiver, m['receiverName'] as String? ?? ''),
              _line(t.number, m['receiverPhone'] as String? ?? ''),
              const SizedBox(height: ShowSpacing.md),
              // QR placeholder — real image is served by the API before launch.
              Center(
                child: Container(
                  width: 160, height: 160, color: ShowColors.creamSunken,
                  child: const Center(child: HeroIcon(HeroIcons.qrCode, size: 56, color: ShowColors.inkFaint)),
                ),
              ),
            ],
            const SizedBox(height: ShowSpacing.xl),
            ShowButton(t.iPaid, onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(t.proofSubmitted),
              ));
            }),
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
