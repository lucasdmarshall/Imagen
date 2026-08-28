import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:show_ui/show_ui.dart';

import '../i18n.dart';
import '../state/session.dart';

class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  Future<List<dynamic>>? _history;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // SessionScope is an inherited widget; read it here, not in initState().
    if (_history != null) return;
    final session = SessionScope.of(context);
    _history = session.api.creditHistory();
    session.refreshBalance();
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final t = T.of(context);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => ShowPage(
        title: t.creditsTitle,
        children: [
          const SizedBox(height: ShowSpacing.lg),
          Text('${session.balance}', style: ShowType.display),
          Text(t.creditsAvailable, style: ShowType.bodyMuted),
          ShowSectionHeader(t.history),
          FutureBuilder<List<dynamic>>(
            future: _history,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(ShowSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final txs = snap.data ?? const [];
              if (txs.isEmpty) {
                return ShowEmpty(
                  icon: const HeroIcon(HeroIcons.sparkles, size: 36, color: ShowColors.inkFaint),
                  title: t.noActivity,
                  subtitle: t.noActivitySub,
                );
              }
              return Column(children: [
                for (var i = txs.length - 1; i >= 0; i--) ...[
                  _txRow(txs[i] as Map<String, dynamic>),
                  if (i > 0) const Divider(),
                ],
              ]);
            },
          ),
        ],
      ),
    );
  }

  Widget _txRow(Map<String, dynamic> tx) {
    final amount = tx['amount'] as int;
    final positive = amount >= 0;
    return ShowRow(
      title: T.of(context).reason('${tx['reason']}'),
      subtitle: (tx['note'] as String?)?.isNotEmpty == true ? tx['note'] : null,
      trailing: Text(
        '${positive ? '+' : ''}$amount',
        style: ShowType.h3.copyWith(
          color: positive ? ShowColors.success : ShowColors.ink,
        ),
      ),
    );
  }
}
