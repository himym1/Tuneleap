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
  const MusicCapabilities({required this.adapters, this.defaultProvider});

  final String? defaultProvider;
  final List<MusicAdapterCapability> adapters;

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
}
