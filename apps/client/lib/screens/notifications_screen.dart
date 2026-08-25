import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:show_ui/show_ui.dart';

import '../i18n.dart';
import '../state/session.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = SessionScope.of(context).api.notifications();
  }

  @override
  Widget build(BuildContext context) {
    final t = T.of(context);
    return ShowPage(
      title: t.notifications,
      children: [
        FutureBuilder<List<dynamic>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(ShowSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final items = (snap.data ?? const []).cast<Map<String, dynamic>>();
            if (items.isEmpty) {
              return ShowEmpty(
                icon: const HeroIcon(HeroIcons.bell, size: 36, color: ShowColors.inkFaint),
                title: t.noNotifications,
              );
            }
            return Column(children: [
              for (var i = 0; i < items.length; i++) ...[
                _row(items[i]),
                if (i < items.length - 1) const Divider(),
              ],
            ]);
          },
        ),
      ],
    );
  }

  Widget _row(Map<String, dynamic> n) {
    final read = n['read'] == true;
    return ShowRow(
      leading: HeroIcon(
        read ? HeroIcons.bell : HeroIcons.bellAlert,
        style: read ? HeroIconStyle.outline : HeroIconStyle.solid,
        size: 22,
        color: read ? ShowColors.inkFaint : ShowColors.accent,
      ),
      title: n['title'] as String,
      subtitle: n['body'] as String?,
      onTap: read
          ? null
          : () async {
              await SessionScope.of(context).api.markRead(n['id'] as String);
              setState(() => n['read'] = true);
            },
    );
  }
}
