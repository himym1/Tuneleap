import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

import 'server_config_provider.dart';
import 'server_scope.dart';

/// Catalog of online platforms the player can search through Cloud.
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

String? canonicalizeCatalogSource(String source) {
  final normalized = source.trim().toLowerCase();
  final canonical = switch (normalized) {
    'qq' || 'qqmusic' || 'qq_music' => 'tencent',
    _ => normalized,
  };
  return kOnlineCatalogSources.contains(canonical) ? canonical : null;
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

final onlineSourcePreferencesProvider =
    NotifierProvider<OnlineSourcePreferencesNotifier, List<String>>(
      OnlineSourcePreferencesNotifier.new,
    );

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

  Future<bool> setEnabled(String source, {required bool enabled}) async {
    final canonical = canonicalizeCatalogSource(source);
    if (canonical == null) return false;

    final next = List<String>.of(state);
    if (enabled) {
      if (!next.contains(canonical)) {
        next.add(canonical);
        next.sort(
          (a, b) => kOnlineCatalogSources
              .indexOf(a)
              .compareTo(kOnlineCatalogSources.indexOf(b)),
        );
      }
    } else {
      next.remove(canonical);
      if (next.isEmpty) return false;
    }

    final serverId = ref.read(serverConfigProvider).serverId;
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(onlineSourcesPreferenceKey(serverId), next);
    state = next;
    return true;
  }
}
