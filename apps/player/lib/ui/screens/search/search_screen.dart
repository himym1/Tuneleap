import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/ui/widgets/cloud_auth_dialog.dart';
import 'package:navidrome_player/ui/widgets/empty_state.dart';
import 'package:navidrome_player/ui/widgets/song_context_menu.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _resultsScrollController = ScrollController();
  Timer? _debounce;
  String? _selectedSource;

  Future<void> _loadMore() async {
    final source = _currentSource(ref.read(onlineSourcePreferencesProvider));
    if (source == null) return;
    try {
      await ref.read(searchProvider(source).notifier).loadMore();
    } catch (_) {
      // The provider stores the error; the footer exposes an explicit retry.
    }
  }

  void _onResultsScrolled() {
    if (!_resultsScrollController.hasClients) return;
    _loadMoreNearBottom(_resultsScrollController.position);
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.depth == 0) {
      _loadMoreNearBottom(notification.metrics);
    }
    return false;
  }

  void _loadMoreNearBottom(ScrollMetrics metrics) {
    if (metrics.extentAfter < 320) unawaited(_loadMore());
  }

  String? _currentSource(List<String> sources) {
    if (sources.isEmpty) return null;
    if (_selectedSource != null && sources.contains(_selectedSource)) {
      return _selectedSource;
    }
    return sources.first;
  }

  @override
  void initState() {
    super.initState();
    _resultsScrollController.addListener(_onResultsScrolled);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    _resultsScrollController.dispose();
    super.dispose();
  }

  void _doSearch() {
    _debounce?.cancel();
    if (_resultsScrollController.hasClients) {
      _resultsScrollController.jumpTo(0);
    }
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _clearAllResults();
    } else {
      _searchAll(query);
    }
  }

  void _searchAll(String query) {
    for (final source in ref.read(onlineSourcePreferencesProvider)) {
      ref.read(searchProvider(source).notifier).search(query);
    }
  }

  void _clearAllResults() {
    for (final source in ref.read(onlineSourcePreferencesProvider)) {
      ref.read(searchProvider(source).notifier).clearResult();
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    // Skip if IME is still composing (e.g. pinyin input not yet confirmed)
    if (_searchController.value.composing != TextRange.empty) return;
    _debounce = Timer(const Duration(milliseconds: 800), _doSearch);
  }

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(onlineSourcePreferencesProvider);
    final selected = _currentSource(sources);
    final searchState = selected == null
        ? const SearchState()
        : ref.watch(searchProvider(selected));
    final isMobile = AppBreakpoints.isMobile(MediaQuery.of(context).size.width);
    final h = isMobile
        ? AppDimensions.paddingMobile
        : AppDimensions.paddingDesktop;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(h, h, h, 0),
            child: Text(
              S.of(context).navSearch,
              style: Theme.of(context).textTheme.pageTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: h),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, value, _) {
                return TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  autofocus: false,
                  textInputAction: TextInputAction.search,
                  onChanged: _onSearchChanged,
                  onSubmitted: (_) => _doSearch(),
                  decoration: InputDecoration(
                    hintText: S.of(context).searchHintInput,
                    prefixIcon: Icon(
                      Icons.search,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    suffixIcon: value.text.isNotEmpty
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                tooltip: S.of(context).tooltipClear,
                                onPressed: () {
                                  _searchController.clear();
                                  _clearAllResults();
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.search, size: 20),
                                tooltip: S.of(context).navSearch,
                                onPressed: _doSearch,
                              ),
                            ],
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
          if (sources.length > 1) ...[
            const SizedBox(height: 12),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: h),
              child: _SourceTabs(
                sources: sources,
                selected: selected,
                onSelected: (source) {
                  setState(() => _selectedSource = source);
                  if (_resultsScrollController.hasClients) {
                    _resultsScrollController.jumpTo(0);
                  }
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(child: _buildResults(searchState, selected)),
        ],
      ),
    );
  }

  Widget _buildResults(SearchState searchState, String? source) {
    if (searchState.searching && searchState.songs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (searchState.error != null && searchState.songs.isEmpty) {
      final raw = searchState.error!;
      final isAuth =
          raw.contains('401') ||
          raw.toLowerCase().contains('unauthorized') ||
          raw.toLowerCase().contains('invalid api key');
      return EmptyState(
        icon: isAuth ? Icons.lock_outline : Icons.error_outline,
        message: isAuth
            ? S.of(context).searchAuthRequired
            : S.of(context).searchError(raw),
        actionLabel: isAuth ? S.of(context).cloudSignIn : null,
        onAction: isAuth
            ? () async {
                final ok = await CloudAuthDialog.show(context);
                if (!ok || !mounted) return;
                final q = _searchController.text.trim();
                if (q.isNotEmpty) {
                  _searchAll(q);
                }
              }
            : null,
      );
    }

    if (searchState.songs.isEmpty && !searchState.searching) {
      if (_searchController.text.trim().isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search,
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                S.of(context).searchPlaceholder,
                style: Theme.of(context).textTheme.songSubtitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        );
      }
      return EmptyState(
        icon: Icons.search_off,
        message: S.of(context).searchNoResult,
      );
    }

    final showFooter =
        searchState.hasMore ||
        searchState.loadingMore ||
        searchState.error != null;
    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: ListView.builder(
        controller: _resultsScrollController,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        itemCount: searchState.songs.length + (showFooter ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == searchState.songs.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: searchState.loadingMore
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : searchState.error != null
                    ? OutlinedButton.icon(
                        onPressed: _loadMore,
                        icon: const Icon(Icons.refresh),
                        label: Text(S.of(context).searchLoadMore),
                      )
                    : const SizedBox.shrink(),
              ),
            );
          }
          final song = searchState.songs[index];
          return _SongResultTile(
            song: song,
            hideSourceChip: song.onlineSource == source,
            onTap: () async {
              try {
                final loaded = await ref
                    .read(audioPlayerServiceProvider)
                    .playSongAndConfirm(song);
                if (!context.mounted) return;
                if (loaded) {
                  context.push('/player');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(S.of(context).searchPlaybackUnavailable),
                    ),
                  );
                }
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(S.of(context).searchPlaybackFailed('$error')),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}

class _SourceTabs extends StatelessWidget {
  const _SourceTabs({
    required this.sources,
    required this.selected,
    required this.onSelected,
  });

  final List<String> sources;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(3),
          itemCount: sources.length,
          separatorBuilder: (_, _) => const SizedBox(width: 2),
          itemBuilder: (context, index) {
            final source = sources[index];
            final isSelected = source == selected;
            return Semantics(
              button: true,
              selected: isSelected,
              child: Material(
                color: isSelected
                    ? Theme.of(context).colorScheme.surface
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                child: InkWell(
                  onTap: () => onSelected(source),
                  borderRadius: BorderRadius.circular(7),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Center(
                      child: Text(
                        onlineSourceLabel(context, source),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SongResultTile extends ConsumerWidget {
  final Song song;
  final bool hideSourceChip;
  final VoidCallback onTap;
  const _SongResultTile({
    required this.song,
    required this.onTap,
    this.hideSourceChip = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolver = ref.read(songMediaResolverProvider);
    final playerService = ref.read(audioPlayerServiceProvider);
    return StreamBuilder<Song?>(
      stream: playerService.currentSongStream,
      initialData: playerService.currentSong,
      builder: (context, snapshot) {
        final isPlaying =
            (snapshot.data ?? playerService.currentSong)?.id == song.id;
        return SongContextMenu(
          song: song,
          onPlay: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: isPlaying ? context.colors.primarySoft : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: FutureBuilder<String>(
                future: resolver.coverArtUrl(song, size: 100),
                builder: (context, snapshot) => CoverArt(
                  url: snapshot.data ?? '',
                  size: 40,
                  borderRadius: 6,
                ),
              ),
              title: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.songTitle.copyWith(
                  fontWeight: isPlaying ? FontWeight.w600 : null,
                  color: isPlaying ? context.colors.primary : null,
                ),
              ),
              subtitle: Text(
                '${song.artist} · ${song.album}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.songSubtitle.copyWith(
                  color: isPlaying
                      ? context.colors.primary.withValues(alpha: 0.7)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (song.isOnline &&
                      !hideSourceChip &&
                      song.onlineSource != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        onlineSourceLabel(context, song.onlineSource!),
                        style: Theme.of(context).textTheme.chipLabel.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (song.duration != null)
                    Text(
                      song.formattedDuration,
                      style: Theme.of(context).textTheme.songSubtitle.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              onTap: onTap,
            ),
          ),
        );
      },
    );
  }
}
