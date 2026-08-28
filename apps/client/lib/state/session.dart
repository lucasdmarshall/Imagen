import 'package:flutter/widgets.dart';

import '../api/api_client.dart';

/// App-wide session: auth token, current user, and credit balance. A simple
/// [ChangeNotifier] avoids pulling in a state-management dependency.
class Session extends ChangeNotifier {
  Session(this.api);

  final ApiClient api;

  Map<String, dynamic>? user;
  int balance = 0;

  bool get isAuthenticated => api.token != null;

  /// Whether an admin has let this user past the Waiting Area gate.
  bool get approved => user?['approved'] == true;

  /// Current UI locale. Burmese is the app default; English is optional.
  String get locale {
    final l = user?['profile']?['locale'] as String?;
    return (l == 'en') ? 'en' : 'my';
  }
  String get displayName =>
      (user?['profile']?['displayName'] as String?)?.trim().isNotEmpty == true
          ? user!['profile']['displayName']
          : (user?['email'] as String? ?? 'Guest');

  Future<void> register(String email, String password, String name) async {
    final res = await api.register(email, password, name);
    _apply(res);
    await refreshBalance();
  }

  Future<void> login(String email, String password) async {
    final res = await api.login(email, password);
    _apply(res);
    await refreshBalance();
  }

  Future<void> loginWithGoogle(String idToken) async {
    final res = await api.googleLogin(idToken);
    _apply(res);
    await refreshBalance();
  }

  Future<void> logout() async {
    try {
      await api.logout();
    } catch (_) {}
    api.token = null;
    user = null;
    balance = 0;
    notifyListeners();
  }

  Future<void> refreshBalance() async {
    try {
      balance = await api.balance();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshProfile() async {
    user = await api.profile();
    notifyListeners();
  }

  void _apply(Map<String, dynamic> res) {
    api.token = res['token'] as String?;
    user = res['user'] as Map<String, dynamic>?;
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
