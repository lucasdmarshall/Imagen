import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:show_ui/show_ui.dart';

import '../state/session.dart';
import 'credits_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'store_screen.dart';

/// Bottom-nav shell. The bar is borderless — separated from content by a single
/// hairline rule, matte fills, no shadow, generous 64dp targets.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _tabs = <(HeroIcons, String)>[
    (HeroIcons.squares2x2, 'Home'),
    (HeroIcons.shoppingBag, 'Store'),
    (HeroIcons.sparkles, 'Credits'),
    (HeroIcons.user, 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = SessionScope.of(context);
      s.refreshBalance();
      if (s.user == null) s.refreshProfile().catchError((_) {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = const [HomeScreen(), StoreScreen(), CreditsScreen(), ProfileScreen()];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: ShowColors.hairline, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(child: _NavItem(
                    icon: _tabs[i].$1,
                    label: _tabs[i].$2,
                    selected: _index == i,
                    onTap: () => setState(() => _index = i),
                  )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final HeroIcons icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? ShowColors.ink : ShowColors.inkFaint;
    return InkResponse(
      onTap: onTap,
      radius: 40,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HeroIcon(icon,
              size: 24, color: color,
              style: selected ? HeroIconStyle.solid : HeroIconStyle.outline),
          const SizedBox(height: 4),
          Text(label, style: ShowType.caption.copyWith(
            color: color, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
        ],
      ),
    );
  }
}
