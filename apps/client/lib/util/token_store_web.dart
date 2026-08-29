// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

const _key = 'show.session.token';

Future<String?> readToken() async => html.window.localStorage[_key];

Future<void> writeToken(String? token) async {
  if (token == null || token.isEmpty) {
    html.window.localStorage.remove(_key);
  } else {
    html.window.localStorage[_key] = token;
  }
}
