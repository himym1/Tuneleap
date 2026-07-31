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
  final _backendUrlController = TextEditingController();
  final _cloudUsernameController = TextEditingController();
  final _cloudCredentialController = TextEditingController();
  final _nasAgentUrlController = TextEditingController();
  final _nasAgentKeyController = TextEditingController();
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
    _backendUrlController.text = config.backendUrl;
    _cloudUsernameController.text =
        prefs.getString('cloud_username_$serverId') ?? '';
    _nasAgentUrlController.text = config.nasAgentUrl;
    _nasAgentKeyController.text = config.nasAgentKey;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _backendUrlController.dispose();
    _cloudUsernameController.dispose();
    _cloudCredentialController.dispose();
    _nasAgentUrlController.dispose();
    _nasAgentKeyController.dispose();
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
      final backendUrl = _backendUrlController.text.trim();
      final cloudUsername = _cloudUsernameController.text.trim();
      final cloudCredential = _cloudCredentialController.text;
      final nasAgentUrl = _nasAgentUrlController.text.trim();
      final nasAgentKey = _nasAgentKeyController.text;

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
            backendUrl: backendUrl,
            backendApiKey: '',
            nasAgentUrl: nasAgentUrl,
            nasAgentKey: nasAgentKey,
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
                        prefixIcon: const Icon(Icons.dns),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: s.multiServerUsername,
                        prefixIcon: const Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: s.multiServerPassword,
                        prefixIcon: const Icon(Icons.lock),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _backendUrlController,
                      decoration: InputDecoration(
                        labelText: s.backendUrl,
                        hintText: s.backendUrlHint,
                        prefixIcon: const Icon(Icons.cloud_outlined),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _cloudUsernameController,
                      decoration: InputDecoration(
                        labelText: s.cloudUsername,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _cloudCredentialController,
                      decoration: InputDecoration(
                        labelText: s.cloudCredential,
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nasAgentUrlController,
                      decoration: InputDecoration(
                        labelText: s.nasAgentUrl,
                        hintText: s.nasAgentUrlHint,
                        prefixIcon: const Icon(Icons.storage_outlined),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nasAgentKeyController,
                      decoration: InputDecoration(
                        labelText: s.nasAgentKey,
                        hintText: s.nasAgentKeyHint,
                        prefixIcon: const Icon(Icons.vpn_key_outlined),
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
