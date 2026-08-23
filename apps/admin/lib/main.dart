import 'package:flutter/material.dart';
import 'package:show_ui/show_ui.dart';

void main() => runApp(const ShowAdminApp());

class ShowAdminApp extends StatelessWidget {
  const ShowAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SHOW Admin',
      debugShowCheckedModeBanner: false,
      theme: ShowTheme.light(),
      darkTheme: ShowTheme.dark(),
      home: const AdminHome(),
    );
  }
}

/// Admin shell: borderless section list (users, store, subscriptions, etc.).
class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  static const _sections = <(String, String)>[
    ('Users', 'View, search, and manage user accounts.'),
    ('Store', 'Manage catalog and store items.'),
    ('Subscriptions', 'Plans: Free, Pro Monthly, Pro Yearly.'),
    ('Moderation', 'Review generated content.'),
    ('Analytics', 'Usage and revenue dashboards.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SHOW Admin')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: ShowSizing.maxContentWidth),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: ShowSpacing.pageInset,
                vertical: ShowSpacing.lg,
              ),
              itemCount: _sections.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, i) {
                final (title, subtitle) = _sections[i];
                return InkWell(
                  onTap: () {},
                  child: Container(
                    constraints:
                        const BoxConstraints(minHeight: ShowSizing.minTouch),
                    padding:
                        const EdgeInsets.symmetric(vertical: ShowSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: ShowType.h3),
                        const SizedBox(height: ShowSpacing.xs),
                        Text(subtitle, style: ShowType.bodyMuted),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
