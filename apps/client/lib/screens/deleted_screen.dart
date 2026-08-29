import 'package:flutter/material.dart';
import 'package:show_ui/show_ui.dart';

import '../i18n.dart';
import '../state/session.dart';
import 'auth_screen.dart';

/// Shown when the account has been deleted. Looks like a 404.
class DeletedAccountScreen extends StatelessWidget {
  const DeletedAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = T.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(ShowSpacing.pageInset),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: showStagger([
                  Text(t.deletedTitle,
                      style: ShowType.display.copyWith(
                          fontSize: 72, height: 1, fontWeight: FontWeight.w700)),
                  const SizedBox(height: ShowSpacing.md),
                  Text(t.deletedSub,
                      style: ShowType.bodyLarge
                          .copyWith(color: ShowColors.inkMuted, height: 1.5)),
                  const SizedBox(height: ShowSpacing.xl),
                  TextButton(
                    onPressed: () async {
                      await SessionScope.of(context).logout();
                      if (!context.mounted) return;
                      Navigator.of(context).pushReplacement(
                          showFadeThroughRoute(const AuthScreen()));
                    },
                    child: Text(t.backToSignIn),
                  ),
                ], initialDelay: const Duration(milliseconds: 80)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
