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
  late final ApiClient _api = SessionScope.of(context).api;
  late Future<List<dynamic>> _items;

  @override
  void initState() {
    super.initState();
    _items = _api.storeItems();
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
            return Column(children: [
              ShowSectionHeader(t.subscriptions),
              _list(subs, subtitleFor: (e) => t.renewsAuto),
              ShowSectionHeader(t.addonCredits),
              _list(packs, subtitleFor: (e) => t.creditsAmount(e['credits'] as int)),
            ]);
          },
        ),
      ],
    );
  }

  Widget _list(List<Map<String, dynamic>> items, {required String Function(Map<String, dynamic>) subtitleFor}) {
    return Column(children: [
      for (var i = 0; i < items.length; i++) ...[
        ShowRow(
          title: items[i]['name'] as String,
          subtitle: subtitleFor(items[i]),
          trailing: ShowTag(_price(items[i]['priceMmk'] as int)),
          onTap: () => _openPayment(items[i]),
        ),
        if (i < items.length - 1) const Divider(),
      ],
    ]);
  }

  Future<void> _openPayment(Map<String, dynamic> item) async {
    final methods = await _api.paymentMethods();
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
