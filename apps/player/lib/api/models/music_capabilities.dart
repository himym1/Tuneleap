const kDefaultSearchPageSize = 30;
const kMaxSearchPageSize = 50;

class SourceSearchWindow {
  const SourceSearchWindow({required this.maxCount, required this.paginates});

  final int maxCount;
  final bool paginates;

  factory SourceSearchWindow.fromJson(Map<String, dynamic> json) {
    final rawCount =
        json['max_count'] ?? json['maxCount'] ?? kDefaultSearchPageSize;
    final parsed = rawCount is num ? rawCount.toInt() : kDefaultSearchPageSize;
    return SourceSearchWindow(
      maxCount: parsed.clamp(1, kMaxSearchPageSize),
      paginates: json['paginates'] == true,
    );
  }
}

class MusicAdapterCapability {
  const MusicAdapterCapability({required this.id, required this.sources});

  final String id;
  final List<String> sources;

  factory MusicAdapterCapability.fromJson(Map<String, dynamic> json) {
    final rawSources = json['sources'];
    if (rawSources is! List) {
      throw const FormatException('Music adapter sources must be a list');
    }
    return MusicAdapterCapability(
      id: json['id']?.toString() ?? '',
      sources: rawSources.map((source) => source.toString()).toList(),
    );
  }
}

class MusicCapabilities {
  const MusicCapabilities({
    required this.adapters,
    this.defaultProvider,
    this.sources = const {},
  });

  final String? defaultProvider;
  final List<MusicAdapterCapability> adapters;
  final Map<String, SourceSearchWindow> sources;

  factory MusicCapabilities.fromJson(Map<String, dynamic> json) {
    final rawAdapters = json['adapters'];
    if (rawAdapters is! List) {
      throw const FormatException('Music capabilities adapters must be a list');
    }
    final adapters = rawAdapters
        .whereType<Map>()
        .map(
          (adapter) => MusicAdapterCapability.fromJson(
            Map<String, dynamic>.from(adapter),
          ),
        )
        .where((adapter) => adapter.id.isNotEmpty)
        .toList();
    final defaultProvider = json['default_provider']?.toString();
    return MusicCapabilities(
      defaultProvider: defaultProvider?.isEmpty == true
          ? null
          : defaultProvider,
      adapters: adapters,
      sources: _parseSourceWindows(json['sources']),
    );
  }

  MusicAdapterCapability? adapter(String? id) {
    if (id == null) return null;
    for (final adapter in adapters) {
      if (adapter.id == id) return adapter;
    }
    return null;
  }

  List<String> sourcesFor(String? provider) {
    if (provider == null) {
      final supported = <String>{};
      for (final adapter in adapters) {
        supported.addAll(adapter.sources);
      }
      return supported.toList();
    }
    return adapter(provider)?.sources ?? const [];
  }

  int pageSizeFor(String source) {
    return sources[source]?.maxCount ?? kDefaultSearchPageSize;
  }

  bool paginates(String source) {
    return sources[source]?.paginates ?? false;
  }
}

Map<String, SourceSearchWindow> _parseSourceWindows(Object? raw) {
  if (raw is! Map) return const {};
  final windows = <String, SourceSearchWindow>{};
  for (final entry in raw.entries) {
    final value = entry.value;
    if (value is! Map) continue;
    final key = entry.key.toString();
    if (key.isEmpty) continue;
    windows[key] = SourceSearchWindow.fromJson(
      Map<String, dynamic>.from(value),
    );
  }
  return windows;
}
