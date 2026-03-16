import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

/// 多服务器管理页面
class MultiServerScreen extends ConsumerWidget {
  const MultiServerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(serversListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                S.of(context).multiServerManage,
                style: Theme.of(context).textTheme.pageTitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                S.of(context).multiServerCount(servers.length),
                style: Theme.of(context).textTheme.chipLabel.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: FilledButton.icon(
              onPressed: () => _showServerDialog(context, ref, null),
              icon: const Icon(Icons.add, size: 18),
              label: Text(S.of(context).multiServerAdd),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (servers.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Center(
                child: Text(
                  S.of(context).multiServerEmptyHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.songSubtitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
              ),
            )
          else
            ...servers.map(
              (server) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ServerCard(
                  server: server,
                  onEdit: () => _showServerDialog(context, ref, server),
                  onDelete: () => _confirmDelete(context, ref, server),
                  onSwitch: () => ref
                      .read(serversListProvider.notifier)
                      .setActive(server.id),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showServerDialog(
    BuildContext context,
    WidgetRef ref,
    ServerEntry? existing,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _ServerDialog(
        existing: existing,
        onSave: (name, url, username, password) async {
          final notifier = ref.read(serversListProvider.notifier);
          if (existing == null) {
            await notifier.addServer(
              name: name,
              url: url,
              username: username,
              password: password,
            );
          } else {
            await notifier.updateServer(
              existing.id,
              name: name,
              url: url,
              username: username,
              password: password,
            );
          }
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, ServerEntry server) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of(context).multiServerDeleteTitle),
        content: Text(S.of(context).multiServerDeleteConfirm(server.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(serversListProvider.notifier).removeServer(server.id);
            },
            style: FilledButton.styleFrom(backgroundColor: context.colors.error),
            child: Text(S.of(context).commonDelete),
          ),
        ],
      ),
    );
  }
}

// ── 添加/编辑对话框 ───────────────────────────────────────────────────────────

class _ServerDialog extends StatefulWidget {
  final ServerEntry? existing;
  final Future<void> Function(
    String name,
    String url,
    String username,
    String password,
  )
  onSave;

  const _ServerDialog({this.existing, required this.onSave});

  @override
  State<_ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<_ServerDialog> {
  late final TextEditingController _name;
  late final TextEditingController _url;
  late final TextEditingController _username;
  late final TextEditingController _password;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _url = TextEditingController(text: widget.existing?.url ?? '');
    _username = TextEditingController(text: widget.existing?.username ?? '');
    _password = TextEditingController(text: widget.existing?.password ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? S.of(context).multiServerAdd
            : S.of(context).multiServerEdit,
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: S.of(context).multiServerName,
                hintText: S.of(context).multiServerNameHint,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _url,
              decoration: InputDecoration(
                labelText: S.of(context).multiServerUrl,
                hintText: S.of(context).serverUrlExample,
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _username,
              decoration: InputDecoration(
                labelText: S.of(context).multiServerUsername,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              decoration: InputDecoration(
                labelText: S.of(context).multiServerPassword,
              ),
              obscureText: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(S.of(context).commonCancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.colors.onEmphasis,
                  ),
                )
              : Text(S.of(context).commonSave),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final url = _url.text.trim();
    final username = _username.text.trim();
    final password = _password.text;
    if (name.isEmpty || url.isEmpty || username.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(name, url, username, password);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── 服务器卡片 ────────────────────────────────────────────────────────────────

class _ServerCard extends StatelessWidget {
  final ServerEntry server;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSwitch;

  const _ServerCard({
    required this.server,
    required this.onEdit,
    required this.onDelete,
    required this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: server.isActive
              ? context.colors.primary
              : Theme.of(context).colorScheme.outlineVariant,
          width: server.isActive ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color:
                  (server.isActive
                          ? context.colors.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant)
                      .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.dns_outlined,
              color: server.isActive
                  ? context.colors.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  server.name,
                  style: Theme.of(context).textTheme.songTitle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${server.url} · ${server.username}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.songSubtitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (server.isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: context.colors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                S.of(context).multiServerCurrent,
                style: Theme.of(context).textTheme.chipLabel.copyWith(
                  fontWeight: FontWeight.w500,
                  color: context.colors.onEmphasis,
                ),
              ),
            )
          else
            TextButton(
              onPressed: onSwitch,
              child: Text(
                S.of(context).multiServerSwitch,
                style: Theme.of(context).textTheme.segmentLabel,
              ),
            ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            tooltip: S.of(context).tooltipEdit,
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            tooltip: S.of(context).tooltipDelete,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
