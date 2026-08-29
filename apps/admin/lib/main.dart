import 'dart:async';

import 'package:flutter/material.dart';
import 'package:show_ui/show_ui.dart';

import 'api.dart';
import 'store_screen.dart';
import 'users_screen.dart';

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

class AdminHome extends StatefulWidget {
  const AdminHome({super.key, required this.api});
  final AdminApi api;

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  @override
  void initState() {
    super.initState();
    widget.api.startLive();
  }

  @override
  void dispose() {
    widget.api.stopLive();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = widget.api;
    final sections = <(String, String, Widget?)>[
      ('Approvals', 'Approve users waiting in the gate.',
          ApprovalsScreen(api: api)),
      ('Users', 'View, search, and manage user accounts.',
          UsersScreen(api: api)),
      ('Store', 'Edit prices and credit amounts. Changes apply immediately.',
          StoreScreen(api: api)),
      ('Subscriptions', 'Approve store payments. Credits enter after Approve.',
          SubscriptionsScreen(api: api)),
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
  StreamSubscription<String>? _live;

  @override
  void initState() {
    super.initState();
    _future = widget.api.listUsers();
    _live = widget.api.live.listen((topic) {
      if (topic == 'users' && mounted) _reload(silent: true);
    });
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  void _reload({bool silent = false}) {
    final f = widget.api.listUsers();
    if (!silent) {
      setState(() => _future = f);
      return;
    }
    f.whenComplete(() {
      if (mounted) setState(() => _future = f);
    });
  }

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
                    .where((u) =>
                        u['approved'] != true &&
                        u['banned'] != true &&
                        u['role'] != 'admin')
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

/// Pending store purchases. Credits / plans apply only after Approve.
class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key, required this.api});
  final AdminApi api;

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  String _filter = 'pending';
  late Future<List<Map<String, dynamic>>> _future;
  final _working = <String>{};
  StreamSubscription<String>? _live;

  @override
  void initState() {
    super.initState();
    _future = widget.api.listPayments(_filter);
    _live = widget.api.live.listen((topic) {
      if (topic == 'payments' && mounted) _reload(silent: true);
    });
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  void _reload({bool silent = false}) {
    final f = widget.api.listPayments(_filter);
    if (!silent) {
      setState(() => _future = f);
      return;
    }
    f.whenComplete(() {
      if (mounted) setState(() => _future = f);
    });
  }

  Future<void> _approve(String id) async {
    setState(() => _working.add(id));
    try {
      await widget.api.approvePayment(id);
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

  Future<void> _reject(String id) async {
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Reject payment'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(hintText: 'Note (optional)'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: const Text('Reject')),
          ],
        );
      },
    );
    if (note == null) return;
    setState(() => _working.add(id));
    try {
      await widget.api.rejectPayment(id, note);
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
        title: const Text('Subscriptions'),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: ShowSizing.maxContentWidth),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      ShowSpacing.pageInset, ShowSpacing.md, ShowSpacing.pageInset, 0),
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Pending'),
                        selected: _filter == 'pending',
                        onSelected: (_) {
                          _filter = 'pending';
                          _reload();
                        },
                      ),
                      const SizedBox(width: ShowSpacing.sm),
                      FilterChip(
                        label: const Text('All'),
                        selected: _filter.isEmpty,
                        onSelected: (_) {
                          _filter = '';
                          _reload();
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
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
                      final rows = snap.data ?? const [];
                      if (rows.isEmpty) {
                        return const Center(
                          child: ShowEmpty(
                            title: 'No payments',
                            subtitle:
                                'Store submissions show up here for review.',
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: ShowSpacing.pageInset,
                            vertical: ShowSpacing.lg),
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (context, i) => _PaymentRow(
                          order: rows[i],
                          busy: _working.contains(
                              rows[i]['id'] as String? ?? ''),
                          onApprove: () =>
                              _approve(rows[i]['id'] as String),
                          onReject: () =>
                              _reject(rows[i]['id'] as String),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.order,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final Map<String, dynamic> order;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final pending = order['status'] == 'pending';
    final email = order['userEmail'] as String? ?? '';
    final name = (order['userName'] as String?)?.trim() ?? '';
    final item =
        order['itemName'] as String? ?? order['itemId'] as String? ?? '';
    final kind = order['kind'] as String? ?? '';
    final method = order['method'] as String? ?? '';
    final price = order['priceMmk'];
    final status = order['status'] as String? ?? '';
    final created = _fmtDate(order['createdAt'] as String?);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ShowSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item, style: ShowType.h3),
                const SizedBox(height: ShowSpacing.xs),
                Text(
                  [
                    name.isEmpty ? email : '$name · $email',
                    kind == 'subscription' ? 'Subscription' : 'Add-on',
                    if (method.isNotEmpty) method,
                    if (price != null) '$price MMK',
                    if (created.isNotEmpty) created,
                    status,
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: ShowType.bodyMuted,
                ),
              ],
            ),
          ),
          if (pending) ...[
            const SizedBox(width: ShowSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FilledButton(
                  onPressed: busy ? null : onApprove,
                  style: FilledButton.styleFrom(
                      minimumSize: const Size(0, ShowSizing.controlHeight)),
                  child: Text(busy ? '…' : 'Approve'),
                ),
                const SizedBox(height: ShowSpacing.xs),
                TextButton(
                  onPressed: busy ? null : onReject,
                  child: const Text('Reject'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    return '${d.day}/${d.month}/${d.year}';
  }
}
