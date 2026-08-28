import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:show_ui/show_ui.dart';

import '../i18n.dart';
import '../state/session.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _sub;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // SessionScope is an inherited widget; read it here, not in initState().
    if (_loaded) return;
    _loaded = true;
    final session = SessionScope.of(context);
    session.refreshProfile().catchError((_) {});
    session.api.mySubscription().then((s) {
      if (mounted) setState(() => _sub = s);
    }).catchError((_) {});
  }

  Future<void> _editName() async {
    final session = SessionScope.of(context);
    final t = T.of(context);
    final controller = TextEditingController(text: session.displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.displayName, style: ShowType.h3),
        content: ShowField(label: t.name, controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(t.save)),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await session.api.updateProfile({'displayName': name});
      await session.refreshProfile();
    }
  }

  Future<void> _setLocale(String locale) async {
    final session = SessionScope.of(context);
    await session.api.updateProfile({'locale': locale});
    await session.refreshProfile();
  }

  Future<void> _logout() async {
    final session = SessionScope.of(context);
    await session.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final t = T.of(context);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final email = session.user?['email'] as String? ?? '';
        final locale = session.locale;
        final plan = _sub?['planId'] as String?;
        return ShowPage(
          title: t.profile,
          children: [
            const SizedBox(height: ShowSpacing.lg),
            Text(session.displayName, style: ShowType.h1),
            const SizedBox(height: ShowSpacing.xs),
            Text(email, style: ShowType.bodyMuted),
            if (plan != null) ...[
              const SizedBox(height: ShowSpacing.md),
              Row(children: [ShowTag(t.plan(plan), emphasis: true)]),
            ],
            ShowSectionHeader(t.account),
            ShowRow(
              leading: const HeroIcon(HeroIcons.pencil, size: 22),
              title: t.editName,
              trailing: const HeroIcon(HeroIcons.chevronRight, size: 20),
              onTap: _editName,
            ),
            const Divider(),
            ShowRow(
              leading: const HeroIcon(HeroIcons.language, size: 22),
              title: t.language,
              trailing: _LocaleToggle(value: locale, onChanged: _setLocale),
            ),
            ShowSectionHeader(t.sessionLabel),
            ShowRow(
              leading: const HeroIcon(HeroIcons.arrowLeftStartOnRectangle, size: 22, color: ShowColors.danger),
              title: t.signOut,
              onTap: _logout,
            ),
          ],
        );
      },
    );
  }
}

class _LocaleToggle extends StatelessWidget {
  const _LocaleToggle({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (final l in const [('en', 'EN'), ('my', 'မြန်မာ')]) ...[
        GestureDetector(
          onTap: () => onChanged(l.$1),
          child: ShowTag(l.$2, emphasis: value == l.$1),
        ),
        const SizedBox(width: ShowSpacing.sm),
      ],
    ]);
  }
}
