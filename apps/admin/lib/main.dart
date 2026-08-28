import 'package:flutter/material.dart';
import 'package:show_ui/show_ui.dart';

import 'api.dart';

void main() => runApp(const ShowAdminApp());

class ShowAdminApp extends StatelessWidget {
  const ShowAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SHOW Admin',
      debugShowCheckedModeBanner: false,
      theme: ShowTheme.light(),
      darkTheme: ShowTheme.dark(),
      themeMode: ThemeMode.light,
      home: const AdminRoot(),
    );
  }
}

/// Holds the admin session (token) and switches between login and the shell.
class AdminRoot extends StatefulWidget {
  const AdminRoot({super.key});

  @override
  State<AdminRoot> createState() => _AdminRootState();
}

class _AdminRootState extends State<AdminRoot> {
  final _api = AdminApi();

  @override
  Widget build(BuildContext context) {
    if (_api.token == null) {
      return AdminLogin(api: _api, onDone: () => setState(() {}));
    }
    return AdminHome(api: _api);
  }
}

class AdminLogin extends StatefulWidget {
  const AdminLogin({super.key, required this.api, required this.onDone});
  final AdminApi api;
  final VoidCallback onDone;

  @override
  State<AdminLogin> createState() => _AdminLoginState();
}

class _AdminLoginState extends State<AdminLogin> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.login(_email.text.trim(), _password.text);
      widget.onDone();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(ShowSpacing.pageInset),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('SHOW Admin',
                      style: ShowType.h1.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: ShowSpacing.xl),
                  ShowField(label: 'Email', controller: _email, hint: 'admin@show.dev'),
                  const SizedBox(height: ShowSpacing.lg),
                  ShowField(
                      label: 'Password', controller: _password, obscure: true),
                  const SizedBox(height: ShowSpacing.xl),
                  if (_error != null) ...[
                    Text(_error!,
                        style:
                            ShowType.body.copyWith(color: ShowColors.danger)),
                    const SizedBox(height: ShowSpacing.md),
                  ],
                  ShowButton(_busy ? 'Signing in…' : 'Sign in',
                      onPressed: _busy ? null : _login),
                  const SizedBox(height: ShowSpacing.sm),
                  Text('Admin accounts only.',
                      style: ShowType.caption
                          .copyWith(color: ShowColors.inkFaint)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminHome extends StatelessWidget {
  const AdminHome({super.key, required this.api});
  final AdminApi api;

  @override
  Widget build(BuildContext context) {
    final sections = <(String, String, Widget?)>[
      ('Approvals', 'Approve users waiting in the gate.',
          ApprovalsScreen(api: api)),
      ('Users', 'View, search, and manage user accounts.', null),
      ('Store', 'Manage catalog and store items.', null),
      ('Subscriptions', 'Plans: Free, Pro Monthly, Pro Yearly.', null),
      ('Moderation', 'Review generated content.', null),
      ('Analytics', 'Usage and revenue dashboards.', null),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('SHOW Admin')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: ShowSizing.maxContentWidth),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                  horizontal: ShowSpacing.pageInset, vertical: ShowSpacing.lg),
              itemCount: sections.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, i) {
                final (title, subtitle, screen) = sections[i];
                return InkWell(
                  onTap: screen == null
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => screen)),
                  child: Container(
                    constraints:
                        const BoxConstraints(minHeight: ShowSizing.minTouch),
                    padding:
                        const EdgeInsets.symmetric(vertical: ShowSpacing.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: ShowType.h3),
                              const SizedBox(height: ShowSpacing.xs),
                              Text(subtitle, style: ShowType.bodyMuted),
                            ],
                          ),
                        ),
                        if (screen != null)
                          const Icon(Icons.chevron_right,
                              color: ShowColors.inkFaint),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Lists users awaiting approval and lets the admin approve them.
class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key, required this.api});
  final AdminApi api;

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  final _working = <String>{};

  @override
  void initState() {
    super.initState();
    _future = widget.api.listUsers();
  }

  void _reload() => setState(() => _future = widget.api.listUsers());

  Future<void> _approve(String id) async {
    setState(() => _working.add(id));
    try {
      await widget.api.setApproval(id, true);
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _working.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Approvals'),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: ShowSizing.maxContentWidth),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(ShowSpacing.xl),
                      child: Text('${snap.error}',
                          style: ShowType.bodyMuted,
                          textAlign: TextAlign.center),
                    ),
                  );
                }
                final pending = (snap.data ?? const [])
                    .where((u) => u['approved'] != true)
                    .toList();
                if (pending.isEmpty) {
                  return const Center(
                    child: ShowEmpty(
                      title: 'All caught up',
                      subtitle: 'No users are waiting for approval.',
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: ShowSpacing.pageInset,
                      vertical: ShowSpacing.lg),
                  itemCount: pending.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, i) {
                    final u = pending[i];
                    final id = u['id'] as String;
                    final email = u['email'] as String? ?? '';
                    final name =
                        (u['profile']?['displayName'] as String?)?.trim() ?? '';
                    final busy = _working.contains(id);
                    return Container(
                      constraints: const BoxConstraints(
                          minHeight: ShowSizing.minTouch),
                      padding: const EdgeInsets.symmetric(
                          vertical: ShowSpacing.md),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name.isEmpty ? email : name,
                                    style: ShowType.h3),
                                const SizedBox(height: ShowSpacing.xs),
                                Text(email, style: ShowType.bodyMuted),
                              ],
                            ),
                          ),
                          const SizedBox(width: ShowSpacing.md),
                          FilledButton(
                            onPressed: busy ? null : () => _approve(id),
                            style: FilledButton.styleFrom(
                                minimumSize:
                                    const Size(0, ShowSizing.controlHeight)),
                            child: Text(busy ? '…' : 'Approve'),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
