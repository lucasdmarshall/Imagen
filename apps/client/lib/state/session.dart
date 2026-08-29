import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../api/api_client.dart';
import '../util/token_store.dart';

/// App-wide session: auth token, current user, and credit balance. A simple
/// [ChangeNotifier] avoids pulling in a state-management dependency.
///
/// The Go API already stores sessions in Postgres (30-day TTL). This class
/// keeps the bearer token in localStorage so a refresh doesn't force login.
class Session extends ChangeNotifier {
  Session(this.api);

  final ApiClient api;

  Map<String, dynamic>? user;
  int balance = 0;
  int subscriptionCredits = 0;
  int addonCredits = 0;
  String? subPeriodEndsAt;

  bool get isAuthenticated => api.token != null;

  bool get approved => user?['approved'] == true;
  bool get banned => user?['banned'] == true;
  bool accountDeleted = false;

  /// Current UI locale. Burmese is the app default; English is optional.
  String get locale {
    final l = user?['profile']?['locale'] as String?;
    return (l == 'en') ? 'en' : 'my';
  }
  String get displayName =>
      (user?['profile']?['displayName'] as String?)?.trim().isNotEmpty == true
          ? user!['profile']['displayName']
          : (user?['email'] as String? ?? 'Guest');

  /// Reload a saved SHOW session (and, if that token is dead, mint a new one
  /// from a still-signed-in Firebase Google user).
  Future<void> restore() async {
    final saved = await readToken();
    if (saved != null && saved.isNotEmpty) {
      api.token = saved;
      try {
        user = await api.profile();
        accountDeleted = false;
        await refreshBalance();
        return;
      } catch (e) {
        final gone = e is ApiException &&
            (e.status == 404 || e.code == 'account_deleted');
        api.token = null;
        user = null;
        await writeToken(null);
        if (gone) {
          accountDeleted = true;
          return;
        }
      }
    }
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final idToken = await firebaseUser?.getIdToken();
      if (idToken == null || idToken.isEmpty) return;
      await loginWithGoogle(idToken);
    } catch (e) {
      if (e is ApiException &&
          (e.status == 404 || e.code == 'account_deleted')) {
        accountDeleted = true;
      }
    }
  }

  Future<void> register(String email, String password, String name) async {
    final res = await api.register(email, password, name);
    await _apply(res);
    await refreshBalance();
  }

  Future<void> login(String email, String password) async {
    final res = await api.login(email, password);
    await _apply(res);
    await refreshBalance();
  }

  Future<void> loginWithGoogle(String idToken) async {
    final res = await api.googleLogin(idToken);
    await _apply(res);
    await refreshBalance();
  }

  Future<void> logout() async {
    try {
      await api.logout();
    } catch (_) {}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    api.token = null;
    user = null;
    balance = 0;
    subscriptionCredits = 0;
    addonCredits = 0;
    subPeriodEndsAt = null;
    accountDeleted = false;
    await writeToken(null);
    notifyListeners();
  }

  Future<void> refreshBalance() async {
    try {
      final m = await api.creditWallet();
      balance = (m['balance'] as num?)?.toInt() ?? 0;
      subscriptionCredits = (m['subscriptionCredits'] as num?)?.toInt() ?? 0;
      addonCredits = (m['addonCredits'] as num?)?.toInt() ?? 0;
      subPeriodEndsAt = m['subPeriodEndsAt'] as String?;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshProfile() async {
    user = await api.profile();
    notifyListeners();
  }

  Future<void> _apply(Map<String, dynamic> res) async {
    api.token = res['token'] as String?;
    user = res['user'] as Map<String, dynamic>?;
    await writeToken(api.token);
    notifyListeners();
  }
}

/// Makes the [Session] available to the widget tree.
class SessionScope extends InheritedNotifier<Session> {
  const SessionScope({super.key, required Session session, required super.child})
      : super(notifier: session);

  static Session of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'No SessionScope in context');
    return scope!.notifier!;
  }
}
