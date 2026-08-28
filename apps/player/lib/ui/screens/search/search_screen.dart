import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/ui/widgets/audio_visualizer_bars.dart';
import 'package:navidrome_player/ui/widgets/cloud_auth_dialog.dart';
import 'package:navidrome_player/ui/widgets/empty_state.dart';
import 'package:navidrome_player/ui/widgets/import_to_navidrome_button.dart';
import 'package:navidrome_player/ui/widgets/song_context_menu.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/utils/player_navigation.dart';
import 'package:navidrome_player/utils/song_identity.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _resultsScrollController = ScrollController();
  Timer? _debounce;
  String? _selectedSource;
  String? _lastProvider;
  List<String> _history = [];
  String? _appliedQuery;

  Future<void> _loadMore() async {
    final source = _currentSource(ref.read(effectiveOnlineSourcesProvider));
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
    _lastProvider = ref.read(effectiveOnlineSearchAdapterProvider);
    _loadHistory();
    final query = widget.initialQuery?.trim();
    if (query != null && query.isNotEmpty) {
      _appliedQuery = query;
      _searchController.text = query;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _doSearch();
      });
    }
  }

  @override
  void didUpdateWidget(SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final query = widget.initialQuery?.trim();
    if (query != null && query.isNotEmpty && query != _appliedQuery) {
      _appliedQuery = query;
      _searchController.text = query;
      _doSearch();
    }
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('search_history') ?? [];
    if (mounted) setState(() => _history = list);
  }

  Future<void> _saveHistory(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('search_history') ?? [];
    list.remove(trimmed);
    list.insert(0, trimmed);
    if (list.length > 15) list.removeLast();
    await prefs.setStringList('search_history', list);
    if (mounted) setState(() => _history = list);
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('search_history');
    if (mounted) setState(() => _history = []);
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
      HapticFeedback.lightImpact();
      _saveHistory(query);
      _searchAll(query);
    }
  }

  void _searchAll(String query) {
    final sources = ref.read(effectiveOnlineSourcesProvider);
    final selected = _currentSource(sources);
    for (final source in sources) {
      final notifier = ref.read(searchProvider(source).notifier);
      if (source == selected) {
        notifier.search(query);
      } else {
        notifier.clearResult();
      }
    }
  }

  void _onSourceSelected(String source) {
    setState(() => _selectedSource = source);
    if (_resultsScrollController.hasClients) {
      _resultsScrollController.jumpTo(0);
    }
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      unawaited(
        ref.read(searchProvider(source).notifier).searchIfAbsent(query),
      );
    }
  }

  void _clearAllResults() {
    for (final source in ref.read(effectiveOnlineSourcesProvider)) {
      ref.read(searchProvider(source).notifier).clearResult();
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    // Skip if IME is still composing (e.g. pinyin input not yet confirmed)
    if (_searchController.value.composing != TextRange.empty) return;
    _debounce = Timer(const Duration(milliseconds: 800), _doSearch);
  }

  void _syncProviderSelection(String? provider, List<String> sources) {
    if (_lastProvider == provider) return;
    _lastProvider = provider;
    _selectedSource = sources.isEmpty ? null : sources.first;
    if (_resultsScrollController.hasClients) {
      _resultsScrollController.jumpTo(0);
    }
    final query = _searchController.text.trim();
    if (query.isNotEmpty && sources.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchAll(query);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(effectiveOnlineSourcesProvider);
    final provider = ref.watch(effectiveOnlineSearchAdapterProvider);
    _syncProviderSelection(provider, sources);
    final selected = _currentSource(sources);
    final searchState = selected == null
        ? const SearchState()
        : ref.watch(searchProvider(selected));
    ref.listen<LibraryAuditReplaceSession?>(libraryAuditReplaceTargetProvider, (
      previous,
      next,
    ) {
      final query = next?.current.searchQuery.trim();
      if (query == null || query.isEmpty || query == _appliedQuery) return;
      _appliedQuery = query;
      _searchController.text = query;
      _doSearch();
    });
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
          if (ref.watch(libraryAuditReplaceTargetProvider)
              case final replaceSession?)
            Padding(
              padding: EdgeInsets.fromLTRB(h, 0, h, 12),
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  dense: true,
                  title: Text(
                    replaceSession.total > 1
                        ? S
                              .of(context)
                              .libraryAuditReplaceBannerQueued(
                                replaceSession.currentNumber,
                                replaceSession.total,
                                replaceSession.current.title,
                                replaceSession.current.artist,
                              )
                        : S
                              .of(context)
                              .libraryAuditReplaceBanner(
                                replaceSession.current.title,
                                replaceSession.current.artist,
                              ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => ref
                        .read(libraryAuditReplaceTargetProvider.notifier)
                        .clear(),
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: h),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, value, _) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Container(
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(
                      alpha: isDark ? 0.08 : 0.05,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withValues(
                        alpha: isDark ? 0.10 : 0.07,
                      ),
                      width: 0.8,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    autofocus: false,
                    textInputAction: TextInputAction.search,
                    onChanged: _onSearchChanged,
                    onSubmitted: (_) => _doSearch(),
                    decoration: InputDecoration(
                      hintText: S.of(context).searchHintInput,
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
                      ),
                      fillColor: Colors.transparent,
                      filled: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                      suffixIcon: value.text.isNotEmpty
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color:
                                          (isDark ? Colors.white : Colors.black)
                                              .withValues(alpha: 0.14),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  tooltip: S.of(context).tooltipClear,
                                  onPressed: () {
                                    _searchController.clear();
                                    _clearAllResults();
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 20,
                                  ),
                                  tooltip: S.of(context).navSearch,
                                  onPressed: _doSearch,
                                ),
                              ],
                            )
                          : null,
                    ),
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
                onSelected: _onSourceSelected,
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
      final failure = searchState.error!;
      final isAuth = failure == SearchFailure.authentication;
      final sourceLabel = source == null
          ? null
          : onlineSourceLabel(context, source);
      final message = switch (failure) {
        SearchFailure.authentication => S.of(context).searchAuthRequired,
        SearchFailure.rateLimited => S.of(context).searchRateLimited,
        SearchFailure.unavailable when sourceLabel != null =>
          S.of(context).searchSourceUnavailable(sourceLabel),
        SearchFailure.unavailable => S.of(context).searchServiceUnavailable,
        SearchFailure.unknown => S.of(context).searchFailedTryAgain,
      };
      return EmptyState(
        icon: isAuth ? Icons.lock_outline_rounded : Icons.error_outline_rounded,
        message: message,
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
        final isDark = Theme.of(context).brightness == Brightness.dark;
        if (_history.isNotEmpty) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '搜索历史',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      tooltip: '清空历史',
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _clearHistory();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in _history)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _searchController.text = tag;
                            _searchController.selection =
                                TextSelection.fromPosition(
                                  TextPosition(offset: tag.length),
                                );
                            _doSearch();
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: isDark ? 0.08 : 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: isDark ? 0.10 : 0.07),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        }
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_rounded,
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
        icon: Icons.search_off_rounded,
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
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(S.of(context).searchLoadMore),
                      )
                    : TextButton(
                        onPressed: _loadMore,
                        child: Text(S.of(context).searchLoadMore),
                      ),
              ),
            );
          }
          final song = searchState.songs[index];
          final replacing =
              ref.watch(libraryAuditReplaceTargetProvider) != null;
          return _SongResultTile(
            song: song,
            hideSourceChip: song.onlineSource == source,
            replaceMode: replacing,
            onTap: () async {
              try {
                final loaded = await ref
                    .read(audioPlayerServiceProvider)
                    .playAllAndConfirm(searchState.songs, startIndex: index);
                if (!context.mounted) return;
                if (loaded) {
                  openPlayer(context);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 42,
      child: Container(
        padding: const EdgeInsets.all(3.5),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withValues(
            alpha: isDark ? 0.08 : 0.05,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withValues(
              alpha: isDark ? 0.10 : 0.07,
            ),
            width: 0.8,
          ),
        ),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: sources.length,
          separatorBuilder: (_, _) => const SizedBox(width: 3),
          itemBuilder: (context, index) {
            final source = sources[index];
            final isSelected = source == selected;
            return Semantics(
              key: ValueKey('search-source-$source'),
              button: true,
              selected: isSelected,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelected(source);
                  },
                  borderRadius: BorderRadius.circular(8.5),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? const Color(0xFF2C2C2E) : Colors.white)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8.5),
                      border: isSelected
                          ? Border.all(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: isDark ? 0.18 : 0.06),
                              width: 0.8,
                            )
                          : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.40 : 0.10,
                                ),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.20 : 0.04,
                                ),
                                blurRadius: 1.5,
                                offset: const Offset(0, 0.5),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        onlineSourceLabel(context, source),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              letterSpacing: -0.2,
                              color: isSelected
                                  ? (isDark
                                        ? Colors.white
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface)
                                  : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withValues(alpha: 0.85),
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
  final bool replaceMode;
  final VoidCallback onTap;
  const _SongResultTile({
    required this.song,
    required this.onTap,
    this.hideSourceChip = false,
    this.replaceMode = false,
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
                  size: 44,
                  borderRadius: 8,
                  hasShadow: true,
                  loading: snapshot.connectionState == ConnectionState.waiting,
                ),
              ),
              title: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.songTitle.copyWith(
                  fontWeight: isPlaying ? FontWeight.w700 : FontWeight.w600,
                  color: isPlaying ? context.colors.primary : null,
                ),
              ),
              subtitle: Text(
                [
                  song.artist,
                  song.album,
                  if (song.duration != null && replaceMode)
                    song.formattedDuration,
                ].where((part) => part.trim().isNotEmpty).join(' · '),
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
                  if (isPlaying) ...[
                    StreamBuilder<bool>(
                      stream: playerService.playingStream,
                      builder: (context, playingSnap) => AudioVisualizerBars(
                        isPlaying: playingSnap.data ?? false,
                        size: 13,
                        color: context.colors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (song.isOnline &&
                      !hideSourceChip &&
                      song.onlineSource != null &&
                      !replaceMode)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: context.colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: context.colors.primary.withValues(alpha: 0.20),
                          width: 0.6,
                        ),
                      ),
                      child: Text(
                        onlineSourceLabel(context, song.onlineSource!),
                        style: Theme.of(context).textTheme.chipLabel.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: context.colors.primary,
                        ),
                      ),
                    ),
                  if (replaceMode && song.isOnline)
                    _ReplaceWithResultButton(song: song)
                  else if (song.duration != null)
                    Text(
                      song.formattedDuration,
                      style: Theme.of(context).textTheme.songSubtitle.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
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

class _ReplaceWithResultButton extends ConsumerStatefulWidget {
  const _ReplaceWithResultButton({required this.song});

  final Song song;

  @override
  ConsumerState<_ReplaceWithResultButton> createState() =>
      _ReplaceWithResultButtonState();
}

class _ReplaceWithResultButtonState
    extends ConsumerState<_ReplaceWithResultButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final active = ref.watch(
      nasImportQueueProvider.select(
        (tasks) => tasks.any(
          (task) =>
              task.isActive &&
              songWeakIdentity(task.song) == songWeakIdentity(widget.song),
        ),
      ),
    );
    return TextButton(
      onPressed: (_loading || active)
          ? null
          : () async {
              setState(() => _loading = true);
              await importOnlineSongToNavidrome(context, ref, widget.song);
              if (mounted) setState(() => _loading = false);
            },
      child: (_loading || active)
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(l10n.libraryAuditReplaceWithThis),
    );
  }
}
