import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:show_ui/show_ui.dart';

import '../state/session.dart';
import 'app_shell.dart';

/// Combined sign-in / sign-up. Large targets & type for the 40+ audience.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = SessionScope.of(context);
    try {
      if (_register) {
        await session.register(_email.text, _password.text, _name.text);
      } else {
        await session.login(_email.text, _password.text);
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShowPage(
      title: 'SHOW',
      children: [
        const SizedBox(height: ShowSpacing.xl),
        Text(_register ? 'Create your account' : 'Welcome back', style: ShowType.h1),
        const SizedBox(height: ShowSpacing.xl),
        if (_register) ...[
          ShowField(label: 'Name', controller: _name, hint: 'Your name'),
          const SizedBox(height: ShowSpacing.lg),
        ],
        ShowField(
          label: 'Email',
          controller: _email,
          hint: 'you@example.com',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: ShowSpacing.lg),
        ShowField(label: 'Password', controller: _password, hint: '••••••', obscure: true),
        const SizedBox(height: ShowSpacing.xl),
        if (_error != null) ...[
          Text(_error!, style: ShowType.body.copyWith(color: ShowColors.danger)),
          const SizedBox(height: ShowSpacing.md),
        ],
        ShowButton(
          _busy ? 'Please wait…' : (_register ? 'Create account' : 'Sign in'),
          leading: const HeroIcon(HeroIcons.arrowRightEndOnRectangle, size: 20, color: ShowColors.cream),
          onPressed: _busy ? null : _submit,
        ),
        const SizedBox(height: ShowSpacing.md),
        TextButton(
          onPressed: _busy ? null : () => setState(() => _register = !_register),
          child: Text(_register
              ? 'Have an account? Sign in'
              : 'New here? Create an account'),
        ),
      ],
    );
  }
}
