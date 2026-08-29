import 'package:shared_preferences/shared_preferences.dart';

const _key = 'show.session.token';

Future<String?> readToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_key);
}

Future<void> writeToken(String? token) async {
  final prefs = await SharedPreferences.getInstance();
  if (token == null || token.isEmpty) {
    await prefs.remove(_key);
  } else {
    await prefs.setString(_key, token);
  }
}
