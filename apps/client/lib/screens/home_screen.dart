import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:show_ui/show_ui.dart';

import '../state/session.dart';
import 'image_generator_screen.dart';
import 'notifications_screen.dart';
import 'prompt_generator_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
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
          Text('Hello, ${session.displayName}', style: ShowType.h1),
          const SizedBox(height: ShowSpacing.md),
          Row(children: [
            ShowTag('${session.balance} credits', emphasis: true),
          ]),
          const ShowSectionHeader('Modes'),
          ShowRow(
            leading: const HeroIcon(HeroIcons.pencilSquare, size: 26),
            title: 'Prompt Generator',
            subtitle: 'Build structured, perimeter-aware prompts.',
            trailing: const HeroIcon(HeroIcons.chevronRight, size: 20),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PromptGeneratorScreen())),
          ),
          const Divider(),
          ShowRow(
            leading: const HeroIcon(HeroIcons.photo, size: 26),
            title: 'Image Generator',
            subtitle: 'Render with Nano Banana Pro or GPT Image 2.',
            trailing: const HeroIcon(HeroIcons.chevronRight, size: 20),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ImageGeneratorScreen())),
          ),
        ],
      ),
    );
  }
}
