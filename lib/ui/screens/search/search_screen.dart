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

  Future<void> _loadMore() async {
    try {
      await ref.read(searchProvider.notifier).loadMore();
    } catch (_) {
      // The provider stores the error; the footer exposes an explicit retry.
    }
  }

  void _onResultsScrolled() {
    if (!_resultsScrollController.hasClients) return;
    if (_resultsScrollController.position.extentAfter < 240) {
      unawaited(_loadMore());
    }
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
      ref.read(searchProvider.notifier).clearResult();
    } else {
      ref.read(searchProvider.notifier).search(query);
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
    final searchState = ref.watch(searchProvider);
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  S.of(context).navSearch,
                  style: Theme.of(context).textTheme.pageTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // 搜索栏
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
                                  ref
                                      .read(searchProvider.notifier)
                                      .clearResult();
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
          const SizedBox(height: 12),
          // 结果
          Expanded(child: _buildResults(searchState)),
        ],
      ),
    );
  }

  Widget _buildResults(SearchState searchState) {
    if (searchState.searching) {
      return Center(child: const CircularProgressIndicator());
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
                  await ref.read(searchProvider.notifier).search(q);
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
    return ListView.builder(
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
          onTap: () {
            ref.read(audioPlayerServiceProvider).playSong(song);
            context.push('/player');
          },
        );
      },
    );
  }
}

class _SongResultTile extends ConsumerWidget {
  final Song song;
  final VoidCallback onTap;
  const _SongResultTile({required this.song, required this.onTap});

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
                  if (song.isOnline)
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
                        switch (song.onlineSource) {
                          'kuwo' => S.of(context).searchBackendKuwo,
                          'joox' => S.of(context).searchBackendJoox,
                          _ => S.of(context).searchBackendNetease,
                        },
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
