import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/providers/cloud_auth_provider.dart';

enum _CloudAuthMode { login, register }

class CloudAuthDialog extends ConsumerStatefulWidget {
  const CloudAuthDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => const CloudAuthDialog(),
        ) ??
        false;
  }

  @override
  ConsumerState<CloudAuthDialog> createState() => _CloudAuthDialogState();
}

class _CloudAuthDialogState extends ConsumerState<CloudAuthDialog> {
  final _username = TextEditingController();
  final _credential = TextEditingController();
  _CloudAuthMode _mode = _CloudAuthMode.login;
  bool _submitting = false;
  bool _failed = false;

  @override
  void dispose() {
    _username.dispose();
    _credential.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _username.text.trim();
    final credential = _credential.text;
    if (username.length < 2 || credential.length < 8) {
      setState(() => _failed = true);
      return;
    }
    setState(() {
      _submitting = true;
      _failed = false;
    });
    final notifier = ref.read(cloudAuthProvider.notifier);
    final ok = _mode == _CloudAuthMode.login
        ? await notifier.login(username: username, credential: credential)
        : await notifier.register(username: username, credential: credential);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AlertDialog(
      title: Text(s.cloudAccount),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<_CloudAuthMode>(
              segments: [
                ButtonSegment(
                  value: _CloudAuthMode.login,
                  label: Text(s.cloudSignIn),
                ),
                ButtonSegment(
                  value: _CloudAuthMode.register,
                  label: Text(s.cloudRegister),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: _submitting
                  ? null
                  : (value) => setState(() {
                      _mode = value.first;
                      _failed = false;
                    }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _username,
              enabled: !_submitting,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: s.cloudUsername,
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _credential,
              enabled: !_submitting,
              obscureText: true,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: s.cloudCredential,
                prefixIcon: const Icon(Icons.lock_outline),
              ),
            ),
            if (_failed) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  s.cloudAuthFailed,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: Text(s.commonCancel),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  _mode == _CloudAuthMode.login
                      ? s.cloudSignIn
                      : s.cloudRegister,
                ),
        ),
      ],
    );
  }
}
