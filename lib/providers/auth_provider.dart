import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_providers.dart';
import 'server_config_provider.dart';

const authSignedOutPreferenceKey = 'auth_signed_out';

enum AuthStatus { authenticated, unauthenticated }

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthStatus>(
  AuthNotifier.new,
);

class AuthNotifier extends AsyncNotifier<AuthStatus> {
  int _generation = 0;
  Future<void> _preferenceChain = Future<void>.value();

  int _startOperation() => ++_generation;

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;

  Future<void> _queuePreference(Future<void> Function() action) {
    final next = _preferenceChain.then((_) => action());
    _preferenceChain = next.catchError((Object _) {});
    return next;
  }

  Future<void> _markSignedOut() async {
    final saved = await ref
        .read(sharedPreferencesProvider)
        .setBool(authSignedOutPreferenceKey, true);
    if (!saved) throw StateError('Failed to persist signed-out state');
  }

  Future<void> _clearSignedOut() async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (!prefs.containsKey(authSignedOutPreferenceKey)) return;
    final removed = await prefs.remove(authSignedOutPreferenceKey);
    if (!removed) throw StateError('Failed to clear signed-out state');
  }

  Future<bool> _commitAuthenticated(int generation) async {
    var committed = false;
    await _queuePreference(() async {
      if (!_isCurrent(generation)) return;
      await _clearSignedOut();
      committed = _isCurrent(generation);
    });
    if (committed) {
      state = const AsyncData(AuthStatus.authenticated);
    }
    return committed;
  }

  @override
  Future<AuthStatus> build() async {
    final generation = _startOperation();
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getBool(authSignedOutPreferenceKey) == true) {
      return AuthStatus.unauthenticated;
    }

    final config = ref.read(serverConfigProvider);
    if (!config.isConfigured) return AuthStatus.unauthenticated;

    final authenticated = await ref.read(subsonicClientProvider).ping();
    if (!_isCurrent(generation)) {
      return state.value ?? AuthStatus.unauthenticated;
    }
    return authenticated
        ? AuthStatus.authenticated
        : AuthStatus.unauthenticated;
  }

  Future<bool> signIn({
    required String url,
    required String username,
    required String password,
    String backendUrl = '',
    String backendApiKey = '',
  }) async {
    final generation = _startOperation();
    await ref
        .read(serverConfigProvider.notifier)
        .save(
          url: url,
          username: username,
          password: password,
          backendUrl: backendUrl,
          backendApiKey: backendApiKey,
        );

    final authenticated = await ref.read(subsonicClientProvider).ping();
    if (!_isCurrent(generation)) return false;

    if (authenticated) {
      return _commitAuthenticated(generation);
    }
    state = const AsyncData(AuthStatus.unauthenticated);
    return false;
  }

  Future<void> signOut() async {
    final generation = _startOperation();
    await _queuePreference(_markSignedOut);
    if (_isCurrent(generation)) {
      state = const AsyncData(AuthStatus.unauthenticated);
    }
  }

  void authenticationFailed() {
    _startOperation();
    state = const AsyncData(AuthStatus.unauthenticated);
  }

  Future<bool> activateServer(String serverId) async {
    final generation = _startOperation();
    // Server selection is a user configuration change; generation only gates
    // whether this operation may commit a later authentication result.
    await ref.read(serversListProvider.notifier).setActive(serverId);
    if (!_isCurrent(generation)) return false;

    final authenticated = await ref.read(subsonicClientProvider).ping();
    if (!_isCurrent(generation)) return false;

    if (authenticated) {
      return _commitAuthenticated(generation);
    }
    state = const AsyncData(AuthStatus.unauthenticated);
    return false;
  }

  Future<void> forgetAccount() async {
    final generation = _startOperation();
    await ref.read(serverConfigProvider.notifier).clear();
    await _queuePreference(_markSignedOut);
    if (_isCurrent(generation)) {
      state = const AsyncData(AuthStatus.unauthenticated);
    }
  }
}
