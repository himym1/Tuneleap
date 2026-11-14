import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';

/// 网易云歌单目录：推荐、精品、榜单、华语，以及按名字搜索。
class OnlinePlaylistsScreen extends ConsumerStatefulWidget {
  const OnlinePlaylistsScreen({super.key});

  @override
  ConsumerState<OnlinePlaylistsScreen> createState() =>
      _OnlinePlaylistsScreenState();
}

class _OnlinePlaylistsScreenState extends ConsumerState<OnlinePlaylistsScreen> {
  static const _sections = ['recommended', 'highquality', 'toplist', 'chinese'];

  final _searchController = TextEditingController();
  Timer? _debounce;
  String _section = 'recommended';
  String _query = '';
  List<OnlinePlaylistSummary> _items = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final section = _section;
    final query = _query;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = ref.read(backendClientProvider);
      final page = query.isEmpty
          ? await client.getOnlinePlaylists(section: section)
          : await client.searchOnlinePlaylists(query);
      if (!mounted || section != _section || query != _query) return;
      setState(() {
        _items = page.items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || section != _section || query != _query) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  void _selectSection(String section) {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _section = section;
      _query = '';
    });
    _load();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final next = value.trim();
      if (next == _query) return;
      setState(() => _query = next);
      _load();
    });
  }

  String _sectionLabel(S strings, String section) {
    return switch (section) {
      'highquality' => strings.onlinePlaylistsFeatured,
      'toplist' => strings.onlinePlaylistsCharts,
      'chinese' => strings.onlinePlaylistsChinese,
      _ => strings.onlinePlaylistsRecommended,
    };
  }

  @override
  Widget build(BuildContext context) {
    final strings = S.of(context);
    final isMobile = AppBreakpoints.isMobile(MediaQuery.sizeOf(context).width);
    final h = isMobile
        ? AppDimensions.paddingMobile
        : AppDimensions.paddingDesktop;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(h, h, h, 8),
            child: Row(
              children: [
                if (context.canPop())
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                Expanded(
                  child: Text(
                    strings.onlinePlaylistsTitle,
                    style: Theme.of(context).textTheme.pageTitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(h, 0, h, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: strings.onlinePlaylistsSearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: h),
              children: [
                for (final section in _sections)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_sectionLabel(strings, section)),
                      selected: _query.isEmpty && _section == section,
                      onSelected: (_) => _selectSection(section),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildBody(context, strings, h)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, S strings, double h) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: context.colors.primary),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(strings.commonLoadFailed),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(strings.commonRetry),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(child: Text(strings.onlinePlaylistsEmpty));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = AppBreakpoints.isMobile(constraints.maxWidth);
        if (isMobile) {
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(h, 0, h, 24),
            itemCount: _items.length,
            itemBuilder: (context, index) => _PlaylistTile(
              playlist: _items[index],
              onTap: () => _open(context, _items[index]),
            ),
          );
        }
        final crossAxisCount = (constraints.maxWidth / 220).floor().clamp(2, 6);
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(h, 0, h, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.72,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _items.length,
          itemBuilder: (context, index) => _PlaylistCard(
            playlist: _items[index],
            onTap: () => _open(context, _items[index]),
          ),
        );
      },
    );
  }

  void _open(BuildContext context, OnlinePlaylistSummary playlist) {
    context.push('/online-playlist/${Uri.encodeComponent(playlist.id)}');
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({required this.playlist, required this.onTap});

  final OnlinePlaylistSummary playlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CoverArt(
        url: playlist.coverUrl ?? '',
        size: 52,
        borderRadius: 10,
      ),
      title: Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: playlist.trackCount == null
          ? null
          : Text(S.of(context).playlistSongCountLabel(playlist.trackCount!)),
      onTap: onTap,
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({required this.playlist, required this.onTap});

  final OnlinePlaylistSummary playlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: LayoutBuilder(
                  builder: (context, constraints) => ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: CoverArt(
                      url: playlist.coverUrl ?? '',
                      size: constraints.maxWidth,
                      borderRadius: 0,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.songTitle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (playlist.trackCount != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        S
                            .of(context)
                            .playlistSongCountLabel(playlist.trackCount!),
                        style: Theme.of(context).textTheme.songSubtitle
                            .copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
