import 'package:flutter/material.dart';
import 'package:show_ui/show_ui.dart';

void main() => runApp(const ShowClientApp());

class ShowClientApp extends StatelessWidget {
  const ShowClientApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SHOW',
      debugShowCheckedModeBanner: false,
      theme: ShowTheme.light(),
      darkTheme: ShowTheme.dark(),
      home: const SplashScreen(),
    );
  }
}

/// Minimal splash: wordmark on cream, Swiss alignment, no box/card/gradient.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(ShowSpacing.pageInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('SHOW', style: ShowType.display),
            const SizedBox(height: ShowSpacing.sm),
            Text('Perimeter-driven image prompter', style: ShowType.bodyMuted),
            const SizedBox(height: ShowSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

/// Home: choose one of the two modes. Borderless list, no cards.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SHOW')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: ShowSpacing.pageInset,
            vertical: ShowSpacing.lg,
          ),
          children: [
            Text('Modes', style: ShowType.h2),
            const SizedBox(height: ShowSpacing.lg),
            _ModeRow(
              title: 'Prompt Generator',
              subtitle: 'Build structured, perimeter-aware prompts.',
              onTap: () {},
            ),
            const Divider(),
            _ModeRow(
              title: 'Image Generator',
              subtitle: 'Render with Nano Banana Pro or GPT Image.',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: ShowSizing.minTouch),
        padding: const EdgeInsets.symmetric(vertical: ShowSpacing.md),
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
  }
}
