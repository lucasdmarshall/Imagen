import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:show_ui/show_ui.dart';

import 'api.dart';

/// Search, ban / lift, delete, and reset passwords for client accounts.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key, required this.api});
  final AdminApi api;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  final _search = TextEditingController();
  final _working = <String>{};
  String _filter = 'all';
  StreamSubscription<String>? _live;

  @override
  void initState() {
    super.initState();
    _future = widget.api.listUsers();
    _search.addListener(() => setState(() {}));
    _live = widget.api.live.listen((topic) {
      if (topic == 'users' && mounted) _reload(silent: true);
    });
  }

  @override
  void dispose() {
    _live?.cancel();
    _search.dispose();
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

  List<Map<String, dynamic>> _visible(List<Map<String, dynamic>> users) {
    final q = _search.text.trim().toLowerCase();
    return users.where((u) {
      if (u['role'] == 'admin') return false;
      final banned = u['banned'] == true;
      final waiting = u['approved'] != true;
      if (_filter == 'banned' && !banned) return false;
      if (_filter == 'waiting' && (!waiting || banned)) return false;
      if (_filter == 'active' && (banned || waiting)) return false;
      if (q.isEmpty) return true;
      final email = (u['email'] as String? ?? '').toLowerCase();
      final name =
          (u['profile']?['displayName'] as String? ?? '').toLowerCase();
      return email.contains(q) || name.contains(q);
    }).toList();
  }

  Future<void> _run(String id, Future<void> Function() fn) async {
    setState(() => _working.add(id));
    try {
      await fn();
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

  Future<void> _ban(String id, bool banned) =>
      _run(id, () => widget.api.setBan(id, banned));

  Future<void> _delete(String id, String label) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account'),
        content: Text(
            '$label will be removed. Signing in with this email will show 404. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(id, () => widget.api.deleteUser(id));
  }

  Future<void> _resetPassword(String id, String label) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset password'),
        content: Text(
            'Generate a new password for $label? Their current sessions will be signed out.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Generate')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _working.add(id));
    try {
      final password = await widget.api.resetPassword(id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('New password'),
          content: SelectableText(password,
              style: ShowType.h3.copyWith(letterSpacing: 0.4)),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: password));
                Navigator.pop(ctx);
              },
              child: const Text('Copy'),
            ),
            FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done')),
          ],
        ),
      );
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
        title: const Text('Users'),
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
                  padding: const EdgeInsets.fromLTRB(ShowSpacing.pageInset,
                      ShowSpacing.md, ShowSpacing.pageInset, 0),
                  child: TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      hintText: 'Search name or email',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(ShowSpacing.pageInset,
                      ShowSpacing.md, ShowSpacing.pageInset, 0),
                  child: Wrap(
                    spacing: ShowSpacing.sm,
                    children: [
                      for (final f in [
                        ('all', 'All'),
                        ('active', 'Active'),
                        ('waiting', 'Waiting'),
                        ('banned', 'Banned'),
                      ])
                        FilterChip(
                          label: Text(f.$2),
                          selected: _filter == f.$1,
                          onSelected: (_) => setState(() => _filter = f.$1),
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
                      final rows = _visible(snap.data ?? const []);
                      if (rows.isEmpty) {
                        return const Center(
                          child: ShowEmpty(
                            title: 'No users',
                            subtitle: 'Nothing matches this search or filter.',
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: ShowSpacing.pageInset,
                            vertical: ShowSpacing.lg),
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (context, i) {
                          final u = rows[i];
                          final id = u['id'] as String;
                          final email = u['email'] as String? ?? '';
                          final name =
                              (u['profile']?['displayName'] as String?)
                                      ?.trim() ??
                                  '';
                          final banned = u['banned'] == true;
                          final waiting = u['approved'] != true;
                          final status = banned
                              ? 'Banned'
                              : waiting
                                  ? 'Waiting'
                                  : 'Active';
                          final busy = _working.contains(id);
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: ShowSpacing.sm),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(name.isEmpty ? email : name,
                                          style: ShowType.h3),
                                      const SizedBox(height: ShowSpacing.xs),
                                      Text('$email · $status',
                                          style: ShowType.bodyMuted),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  enabled: !busy,
                                  onSelected: (v) {
                                    if (v == 'ban') _ban(id, true);
                                    if (v == 'lift') _ban(id, false);
                                    if (v == 'password') {
                                      _resetPassword(
                                          id, name.isEmpty ? email : name);
                                    }
                                    if (v == 'delete') {
                                      _delete(
                                          id, name.isEmpty ? email : name);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    if (!banned)
                                      const PopupMenuItem(
                                          value: 'ban', child: Text('Ban')),
                                    if (banned)
                                      const PopupMenuItem(
                                          value: 'lift',
                                          child: Text('Lift ban')),
                                    const PopupMenuItem(
                                        value: 'password',
                                        child: Text('Reset password')),
                                    const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete account')),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
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
