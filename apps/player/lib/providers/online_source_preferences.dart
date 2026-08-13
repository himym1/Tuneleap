import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/music_capabilities.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

import 'audio_providers.dart';
import 'server_config_provider.dart';
import 'server_scope.dart';

/// Catalog of online platforms exposed by the player UI.
const kOnlineCatalogSources = <String>[
  'netease',
  'tencent',
  'kugou',
  'migu',
  'joox',
];

const kDefaultOnlineSources = <String>['netease', 'tencent', 'kugou'];

String onlineSourcesPreferenceKey(String serverId) =>
    'online_search_sources_${normalizeServerId(serverId)}';

String onlineAdapterPreferenceKey(String serverId) =>
    'online_search_adapter_${normalizeServerId(serverId)}';

String? canonicalizeCatalogSource(String source) {
  final normalized = source.trim().toLowerCase();
  final canonical = switch (normalized) {
    'qq' || 'qqmusic' || 'qq_music' => 'tencent',
    _ => normalized,
  };
  return kOnlineCatalogSources.contains(canonical) ? canonical : null;
}

String? canonicalizeOnlineAdapter(String? adapter) {
  final normalized = adapter?.trim().toLowerCase() ?? '';
  if (normalized.isEmpty || normalized == 'auto') return null;
  return RegExp(r'^[a-z0-9_-]+$').hasMatch(normalized) ? normalized : null;
}

List<String> sanitizeOnlineSources(Iterable<String> raw) {
  final unique = <String>[];
  for (final source in raw) {
    final canonical = canonicalizeCatalogSource(source);
    if (canonical != null && !unique.contains(canonical)) {
      unique.add(canonical);
    }
  }
  return unique.isEmpty ? List<String>.of(kDefaultOnlineSources) : unique;
}

List<String> catalogSourcesSupportedBy(
  MusicCapabilities? capabilities,
  String? provider,
) {
  if (capabilities == null) return List<String>.of(kOnlineCatalogSources);
  final supported = capabilities.sourcesFor(provider).toSet();
  return [
    for (final source in kOnlineCatalogSources)
      if (supported.contains(source)) source,
  ];
}

List<String> filterEnabledOnlineSources(
  Iterable<String> enabled,
  Iterable<String> supported,
) {
  final enabledSet = enabled.toSet();
  final supportedList = supported.toList();
  final filtered = [
    for (final source in supportedList)
      if (enabledSet.contains(source)) source,
  ];
  if (filtered.isNotEmpty || supportedList.isEmpty) return filtered;
  return [supportedList.first];
}

String onlineSourceLabel(BuildContext context, String source) {
  final l10n = S.of(context);
  return switch (source) {
    'netease' => l10n.searchBackendNetease,
    'tencent' => l10n.searchBackendTencent,
    'kugou' => l10n.searchBackendKugou,
    'migu' => l10n.searchBackendMigu,
    'joox' => l10n.searchBackendJoox,
    'kuwo' => l10n.searchBackendKuwo,
    _ => source,
  };
}

String onlineAdapterLabel(BuildContext context, String? adapter) {
  final l10n = S.of(context);
  return switch (adapter) {
    null => l10n.settingsOnlineAdapterAuto,
    'meting' => 'Meting',
    'gdstudio' => 'GDStudio',
    'chksz' => 'ChKSz',
    _ => adapter,
  };
}

final musicCapabilitiesProvider = FutureProvider<MusicCapabilities>((
  ref,
) async {
  ref.watch(serverConfigProvider.select((config) => config.serverId));
  return ref.watch(backendClientProvider).getMusicCapabilities();
});

final onlineSearchAdapterProvider =
    NotifierProvider<OnlineSearchAdapterNotifier, String?>(
      OnlineSearchAdapterNotifier.new,
    );

class OnlineSearchAdapterNotifier extends Notifier<String?> {
  @override
  String? build() {
    final serverId = ref.watch(
      serverConfigProvider.select((config) => config.serverId),
    );
    final stored = ref
        .watch(sharedPreferencesProvider)
        .getString(onlineAdapterPreferenceKey(serverId));
    return canonicalizeOnlineAdapter(stored);
  }

  Future<void> setProvider(String? provider) async {
    final canonical = canonicalizeOnlineAdapter(provider);
    final serverId = ref.read(serverConfigProvider).serverId;
    final preferences = ref.read(sharedPreferencesProvider);
    if (canonical == null) {
      await preferences.remove(onlineAdapterPreferenceKey(serverId));
    } else {
      await preferences.setString(
        onlineAdapterPreferenceKey(serverId),
        canonical,
      );
    }
    state = canonical;
  }
}

final effectiveOnlineSearchAdapterProvider = Provider<String?>((ref) {
  final selected = ref.watch(onlineSearchAdapterProvider);
  if (selected == null) return null;
  final capabilities = ref.watch(musicCapabilitiesProvider);
  if (capabilities.hasError) return null;
  final value = capabilities.value;
  if (value == null) return selected;
  return value.adapter(selected) == null ? null : selected;
});

final supportedOnlineSourcesProvider = Provider<List<String>>((ref) {
  final capabilities = ref.watch(musicCapabilitiesProvider);
  final selected = ref.watch(onlineSearchAdapterProvider);
  if (selected != null && capabilities.isLoading) return const [];
  final provider = ref.watch(effectiveOnlineSearchAdapterProvider);
  return catalogSourcesSupportedBy(capabilities.value, provider);
});

final onlineSourcePreferencesProvider =
    NotifierProvider<OnlineSourcePreferencesNotifier, List<String>>(
      OnlineSourcePreferencesNotifier.new,
    );

final effectiveOnlineSourcesProvider = Provider<List<String>>((ref) {
  return filterEnabledOnlineSources(
    ref.watch(onlineSourcePreferencesProvider),
    ref.watch(supportedOnlineSourcesProvider),
  );
});

class OnlineSourcePreferencesNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    final serverId = ref.watch(
      serverConfigProvider.select((config) => config.serverId),
    );
    final stored = ref
        .watch(sharedPreferencesProvider)
        .getStringList(onlineSourcesPreferenceKey(serverId));
    return sanitizeOnlineSources(stored ?? kDefaultOnlineSources);
  }

  Future<void> ensureAny(Iterable<String> supported) async {
    final supportedList = supported
        .map(canonicalizeCatalogSource)
        .whereType<String>()
        .toList();
    if (supportedList.isEmpty || state.any(supportedList.contains)) return;
    final next = sanitizeOnlineSources([...state, supportedList.first]);
    await _save(next);
  }

  Future<bool> setEnabled(
    String source, {
    required bool enabled,
    Iterable<String>? requiredSources,
  }) async {
    final canonical = canonicalizeCatalogSource(source);
    if (canonical == null) return false;

    final next = List<String>.of(state);
    if (enabled) {
      if (!next.contains(canonical)) next.add(canonical);
    } else {
      next.remove(canonical);
      final required = (requiredSources ?? kOnlineCatalogSources).toSet();
      if (!next.any(required.contains)) return false;
    }
    next.sort(
      (a, b) => kOnlineCatalogSources
          .indexOf(a)
          .compareTo(kOnlineCatalogSources.indexOf(b)),
    );
    await _save(next);
    return true;
  }

  Future<void> _save(List<String> next) async {
    final serverId = ref.read(serverConfigProvider).serverId;
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(onlineSourcesPreferenceKey(serverId), next);
    state = next;
  }
}
