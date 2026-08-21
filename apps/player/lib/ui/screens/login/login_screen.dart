import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/providers/server_scope.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _cloudUsernameController = TextEditingController();
  final _cloudCredentialController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final config = ref.read(serverConfigProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    final serverId = normalizeServerId(config.serverId);
    _urlController.text = config.url;
    _usernameController.text = config.username;
    _passwordController.text = config.password;
    _cloudUsernameController.text =
        prefs.getString('cloud_username_$serverId') ?? '';
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _cloudUsernameController.dispose();
    _cloudCredentialController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final s = S.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final url = _urlController.text.trim();
      final username = _usernameController.text.trim();
      final password = _passwordController.text;
      final cloudUsername = _cloudUsernameController.text.trim();
      final cloudCredential = _cloudCredentialController.text;

      if (url.isEmpty || username.isEmpty || password.isEmpty) {
        setState(() => _error = s.loginFieldsRequired);
        return;
      }

      final ok = await ref
          .read(authProvider.notifier)
          .signIn(
            url: url,
            username: username,
            password: password,
            backendUrl: '',
            backendApiKey: '',
          );

      if (!mounted) return;
      if (!ok) {
        setState(() => _error = s.loginFailed);
        return;
      }

      // Optional Cloud login on the same page so users don't hit a second dialog.
      if (cloudUsername.isNotEmpty && cloudCredential.isNotEmpty) {
        final cloudOk = await ref
            .read(cloudAuthProvider.notifier)
            .login(username: cloudUsername, credential: cloudCredential);
        if (!mounted) return;
        if (!cloudOk) {
          setState(() => _error = s.cloudAuthFailed);
          return;
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = s.loginError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                Theme.of(context).colorScheme.surface,
              ],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.music_note_rounded,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      s.appName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.pageTitle,
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        labelText: s.multiServerUrl,
                        hintText: s.serverUrlExample,
                        prefixIcon: const Icon(Icons.dns_rounded),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: s.multiServerUsername,
                        prefixIcon: const Icon(Icons.person_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: s.multiServerPassword,
                        prefixIcon: const Icon(Icons.lock_rounded),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _cloudUsernameController,
                      decoration: InputDecoration(
                        labelText: s.cloudUsername,
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _cloudCredentialController,
                      decoration: InputDecoration(
                        labelText: s.cloudCredential,
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                      ),
                      obscureText: true,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _connect,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(s.loginConnect),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
