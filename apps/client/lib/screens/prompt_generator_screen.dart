import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:show_ui/show_ui.dart';

import '../i18n.dart';
import '../models/flow.dart';
import '../state/session.dart';
import '../state/wizard_controller.dart';
import 'wizard_screen.dart';

/// Entry to the Guided Prompt Engine: fetch the flow, pick Quick vs Detailed,
/// then walk the wizard.
class PromptGeneratorScreen extends StatefulWidget {
  const PromptGeneratorScreen({super.key});

  @override
  State<PromptGeneratorScreen> createState() => _PromptGeneratorScreenState();
}

class _PromptGeneratorScreenState extends State<PromptGeneratorScreen> {
  late Future<PromptFlow> _flow;

  @override
  void initState() {
    super.initState();
    _flow = SessionScope.of(context).api.promptFlow().then(PromptFlow.fromJson);
  }

  void _start(PromptFlow flow, {required bool detailed}) {
    final controller = WizardController(flow, detailed: detailed);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WizardScreen(controller: controller)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = T.of(context);
    return ShowPage(
      title: 'Prompt Generator',
      children: [
        FutureBuilder<PromptFlow>(
          future: _flow,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(ShowSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return ShowEmpty(
                icon: const HeroIcon(HeroIcons.exclamationTriangle,
                    size: 36, color: ShowColors.inkFaint),
                title: 'Could not load',
                subtitle: '${snap.error}',
              );
            }
            final flow = snap.data!;
            return Column(children: [
              const SizedBox(height: ShowSpacing.md),
              Text(t.chooseDepth, style: ShowType.h1),
              const SizedBox(height: ShowSpacing.xl),
              ShowRow(
                leading: const HeroIcon(HeroIcons.bolt, size: 26),
                title: t.quick,
                trailing: const HeroIcon(HeroIcons.chevronRight, size: 20),
                onTap: () => _start(flow, detailed: false),
              ),
              const Divider(),
              ShowRow(
                leading: const HeroIcon(HeroIcons.adjustmentsHorizontal, size: 26),
                title: t.detailed,
                trailing: const HeroIcon(HeroIcons.chevronRight, size: 20),
                onTap: () => _start(flow, detailed: true),
              ),
            ]);
          },
        ),
      ],
    );
  }
}
