import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:show_ui/show_ui.dart';

import '../i18n.dart';
import '../state/session.dart';
import 'image_generator_screen.dart';
import 'notifications_screen.dart';
import 'prompt_generator_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final t = T.of(context);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => ShowPage(
        title: 'SHOW',
        actions: [
          IconButton(
            icon: const HeroIcon(HeroIcons.bell, size: 22),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          ),
        ],
        children: [
          const SizedBox(height: ShowSpacing.md),
          Text(t.hello(session.displayName), style: ShowType.h1),
          const SizedBox(height: ShowSpacing.md),
          Row(children: [
            ShowTag(t.credits(session.balance), emphasis: true),
          ]),
          ShowSectionHeader(t.modes),
          ShowRow(
            leading: const HeroIcon(HeroIcons.pencilSquare, size: 26),
            title: t.promptGen,
            subtitle: t.promptGenSub,
            trailing: const HeroIcon(HeroIcons.chevronRight, size: 20),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PromptGeneratorScreen())),
          ),
          const Divider(),
          ShowRow(
            leading: const HeroIcon(HeroIcons.photo, size: 26),
            title: t.imageGen,
            subtitle: t.imageGenSub,
            trailing: const HeroIcon(HeroIcons.chevronRight, size: 20),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ImageGeneratorScreen())),
          ),
        ],
      ),
    );
  }
}
