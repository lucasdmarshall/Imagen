import 'package:flutter/widgets.dart';

import '../state/session.dart';
import 'app_shell.dart';
import 'auth_screen.dart';
import 'banned_screen.dart';
import 'deleted_screen.dart';
import 'waiting_area_screen.dart';

/// Picks the post-auth destination from session flags.
Widget gateFor(Session s) {
  if (s.accountDeleted) return const DeletedAccountScreen();
  if (!s.isAuthenticated) return const AuthScreen();
  if (s.banned) return const BannedScreen();
  if (s.approved) return const AppShell();
  return const WaitingAreaScreen();
}
