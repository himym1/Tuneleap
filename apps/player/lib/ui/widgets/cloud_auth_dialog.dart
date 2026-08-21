import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/providers/cloud_auth_provider.dart';

enum _CloudAuthMode { login, register }

enum _CloudAuthFailure {
  invalidInput,
  invalidCredentials,
  usernameExists,
  network,
  other,
}

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
  _CloudAuthFailure? _failure;

  @override
  void dispose() {
    _username.dispose();
    _credential.dispose();
    super.dispose();
  }

  _CloudAuthFailure _failureFrom(Object? error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 401) return _CloudAuthFailure.invalidCredentials;
      if (statusCode == 409) return _CloudAuthFailure.usernameExists;
      if (statusCode == 422) return _CloudAuthFailure.invalidInput;
      if (error.response == null) return _CloudAuthFailure.network;
    }
    return _CloudAuthFailure.other;
  }

  String _failureText(S s) => switch (_failure) {
    _CloudAuthFailure.invalidInput => s.cloudInvalidInput,
    _CloudAuthFailure.invalidCredentials => s.cloudInvalidCredentials,
    _CloudAuthFailure.usernameExists => s.cloudUsernameExists,
    _CloudAuthFailure.network => s.cloudNetworkError,
    _CloudAuthFailure.other || null => s.cloudAuthFailed,
  };

  Future<void> _submit() async {
    final username = _username.text.trim();
    final credential = _credential.text;
    if (username.length < 2 || credential.length < 8) {
      setState(() => _failure = _CloudAuthFailure.invalidInput);
      return;
    }
    setState(() {
      _submitting = true;
      _failure = null;
    });
    final notifier = ref.read(cloudAuthProvider.notifier);
    final ok = _mode == _CloudAuthMode.login
        ? await notifier.login(username: username, credential: credential)
        : await notifier.register(username: username, credential: credential);
    if (!mounted) return;
    final error = ref.read(cloudAuthProvider).error;
    setState(() {
      _submitting = false;
      if (!ok) _failure = _failureFrom(error);
    });
    if (ok) Navigator.pop(context, true);
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
                      _failure = null;
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
                prefixIcon: const Icon(Icons.person_outline_rounded),
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
                prefixIcon: const Icon(Icons.lock_outline_rounded),
              ),
            ),
            if (_failure != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _failureText(s),
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
