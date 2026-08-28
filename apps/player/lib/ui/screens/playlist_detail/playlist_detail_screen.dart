import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/api/subsonic_client.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/ui/widgets/song_context_menu.dart';
import 'package:navidrome_player/utils/duration_format.dart';
import 'package:navidrome_player/utils/player_navigation.dart';

class PlaylistDetailScreen extends ConsumerWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(playlistDetailProvider(playlistId));

    if (detail.loading && detail.playlist == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final playlist = detail.playlist;
    if (playlist == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                S.of(context).commonLoadFailed,
                style: Theme.of(context).textTheme.songSubtitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _goBack(context),
                child: Text(S.of(context).commonBack),
              ),
            ],
          ),
        ),
      );
    }

    final client = ref.read(subsonicClientProvider);
    final songs = playlist.songs;
    final isMobile = AppBreakpoints.isMobile(MediaQuery.sizeOf(context).width);
    final padding = isMobile
        ? AppDimensions.paddingMobile
        : AppDimensions.paddingDesktop;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(playlistDetailProvider(playlistId).notifier).refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(padding, padding, padding, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      button: true,
                      label: S.of(context).tooltipBack,
                      child: InkWell(
                        onTap: () => _goBack(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_back_rounded,
                                size: 16,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                S.of(context).commonBack,
                                style: Theme.of(context).textTheme.songSubtitle
                                    .copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isMobile)
                      Column(
                        children: [
                          _cover(client, playlist, 200),
                          const SizedBox(height: 16),
                          _headerText(context, playlist),
                          const SizedBox(height: 16),
                          _actions(context, ref, playlist, songs),
                        ],
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _cover(client, playlist, 220),
                          const SizedBox(width: 28),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _headerText(context, playlist),
                                const SizedBox(height: 20),
                                _actions(context, ref, playlist, songs),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            if (songs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          S.of(context).playlistListEmpty,
                          style: Theme.of(context).textTheme.songSubtitle
                              .copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonalIcon(
                          key: const Key('playlist-empty-add-songs-button'),
                          onPressed: () => _addSongs(context, ref, playlist),
                          icon: const Icon(Icons.playlist_add_rounded),
                          label: Text(S.of(context).playlistAddSongs),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padding, 8, padding, 32),
                sliver: SliverReorderableList(
                  itemCount: songs.length,
                  onReorderItem: (oldIndex, newIndex) =>
                      _reorder(context, ref, playlist, oldIndex, newIndex),
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return Material(
                      key: ValueKey('${song.id}_$index'),
                      color: Colors.transparent,
                      child: ReorderableDelayedDragStartListener(
                        index: index,
                        child: SongContextMenu(
                          song: song,
                          onPlay: () => _playSongs(context, ref, songs, index),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              leading: CoverArt(
                                url: client.coverArtUrl(
                                  song.coverArt,
                                  size: 80,
                                ),
                                size: 44,
                                borderRadius: 6,
                              ),
                              title: Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.songTitle,
                              ),
                              subtitle: Text(
                                song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.songSubtitle
                                    .copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (song.duration != null)
                                    Text(
                                      formatDuration(song.duration!),
                                      style: Theme.of(context)
                                          .textTheme
                                          .songDuration
                                          .copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  IconButton(
                                    tooltip: S.of(context).commonDelete,
                                    onPressed: () => _removeSong(
                                      context,
                                      ref,
                                      playlist,
                                      index,
                                    ),
                                    icon: Icon(
                                      Icons.remove_circle_outline_rounded,
                                      size: 18,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: Icon(
                                      Icons.drag_handle_rounded,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () =>
                                  _playSongs(context, ref, songs, index),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cover(SubsonicClient client, Playlist playlist, double size) {
    final url = client.coverArtUrl(playlist.coverArt, size: 600);
    if ((playlist.songCount ?? playlist.songs.length) > 0 && url.isNotEmpty) {
      return CoverArt(url: url, size: size, borderRadius: 16, hasShadow: true);
    }
    return Builder(
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.queue_music_rounded,
            size: size * 0.4,
            color: colors.onSecondaryContainer,
          ),
        );
      },
    );
  }

  Widget _headerText(BuildContext context, Playlist playlist) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          playlist.name,
          style: Theme.of(context).textTheme.pageTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          S.of(context).commonSongs(playlist.songs.length),
          style: Theme.of(context).textTheme.songSubtitle.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _actions(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
    List<Song> songs,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: songs.isEmpty
              ? null
              : () => _playSongs(context, ref, songs, 0),
          icon: const Icon(Icons.play_arrow_rounded, size: 18),
          label: Text(S.of(context).playlistPlay),
        ),
        OutlinedButton.icon(
          key: const Key('playlist-add-songs-button'),
          onPressed: () => _addSongs(context, ref, playlist),
          icon: const Icon(Icons.playlist_add_rounded, size: 18),
          label: Text(S.of(context).playlistAddSongs),
        ),
        IconButton(
          tooltip: S.of(context).playlistRename,
          onPressed: () => _rename(context, ref, playlist),
          icon: const Icon(Icons.edit_rounded),
        ),
      ],
    );
  }

  void _goBack(BuildContext context) {
    if (GoRouter.of(context).canPop()) {
      context.pop();
    } else {
      context.go('/library/playlists');
    }
  }

  void _playSongs(
    BuildContext context,
    WidgetRef ref,
    List<Song> songs,
    int startIndex,
  ) {
    HapticFeedback.lightImpact();
    ref.read(audioPlayerServiceProvider).playAll(songs, startIndex: startIndex);
    openPlayer(context);
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
  ) async {
    final controller = TextEditingController(text: playlist.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of(context).playlistRename),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: S.of(context).playlistNameLabel,
          ),
          onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(S.of(context).commonSave),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == playlist.name) return;
    try {
      await ref
          .read(playlistServiceProvider)
          .updatePlaylist(playlist.id, name: name);
      ref.invalidate(playlistsProvider);
      await ref.read(playlistDetailProvider(playlistId).notifier).refresh();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(S.of(context).commonError)));
      }
    }
  }

  Future<void> _addSongs(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
  ) async {
    final service = ref.read(playlistServiceProvider);
    final client = ref.read(subsonicClientProvider);
    final selected = await showDialog<List<Song>>(
      context: context,
      builder: (pickerCtx) => _PlaylistSongPickerDialog(
        service: service,
        client: client,
        existingIds: playlist.songs.map((song) => song.id).toSet(),
      ),
    );
    if (selected == null || selected.isEmpty) return;
    final existing = playlist.songs.map((song) => song.id).toSet();
    final toAdd = [
      for (final song in selected)
        if (!existing.contains(song.id)) song,
    ];
    if (toAdd.isEmpty) return;
    try {
      await service.updatePlaylist(
        playlist.id,
        songIdsToAdd: [for (final song in toAdd) song.id],
      );
      ref.invalidate(playlistsProvider);
      await ref.read(playlistDetailProvider(playlistId).notifier).refresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context).playlistSongsAdded(toAdd.length)),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(S.of(context).commonError)));
      }
    }
  }

  Future<void> _removeSong(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
    int index,
  ) async {
    final songs = List<Song>.from(playlist.songs);
    try {
      await ref
          .read(playlistServiceProvider)
          .updatePlaylist(playlist.id, songIndexesToRemove: [index]);
      songs.removeAt(index);
      ref
          .read(playlistDetailProvider(playlistId).notifier)
          .setPlaylist(
            Playlist(
              id: playlist.id,
              name: playlist.name,
              songCount: songs.length,
              duration: playlist.duration,
              coverArt: playlist.coverArt,
              owner: playlist.owner,
              songs: songs,
            ),
          );
      ref.invalidate(playlistsProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(S.of(context).commonError)));
      }
    }
  }

  Future<void> _reorder(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
    int oldIndex,
    int newIndex,
  ) async {
    final previous = List<Song>.from(playlist.songs);
    final songs = List<Song>.from(previous);
    final song = songs.removeAt(oldIndex);
    songs.insert(newIndex, song);
    ref
        .read(playlistDetailProvider(playlistId).notifier)
        .setPlaylist(
          Playlist(
            id: playlist.id,
            name: playlist.name,
            songCount: songs.length,
            duration: playlist.duration,
            coverArt: playlist.coverArt,
            owner: playlist.owner,
            songs: songs,
          ),
        );
    try {
      await ref
          .read(playlistServiceProvider)
          .updatePlaylist(
            playlist.id,
            songIndexesToRemove: [for (var i = 0; i < previous.length; i++) i],
            songIdsToAdd: [for (final item in songs) item.id],
          );
      ref.invalidate(playlistsProvider);
    } catch (_) {
      ref
          .read(playlistDetailProvider(playlistId).notifier)
          .setPlaylist(
            Playlist(
              id: playlist.id,
              name: playlist.name,
              songCount: previous.length,
              duration: playlist.duration,
              coverArt: playlist.coverArt,
              owner: playlist.owner,
              songs: previous,
            ),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(S.of(context).commonError)));
      }
    }
  }
}

class _PlaylistSongPickerDialog extends StatefulWidget {
  const _PlaylistSongPickerDialog({
    required this.service,
    required this.client,
    required this.existingIds,
  });

  final PlaylistService service;
  final SubsonicClient client;
  final Set<String> existingIds;

  @override
  State<_PlaylistSongPickerDialog> createState() =>
      _PlaylistSongPickerDialogState();
}

class _PlaylistSongPickerDialogState extends State<_PlaylistSongPickerDialog> {
  static const _pageSize = 50;

  final _searchController = TextEditingController();
  final _selected = <String, Song>{};
  List<Song> _songs = const [];
  bool _loading = true;
  Object? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSongs([String query = '']) async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final songs = await widget.service.searchSongs(
        query.trim().isEmpty ? '' : query.trim(),
        songCount: _pageSize,
        songOffset: 0,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _songs = songs;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      S.of(context).playlistAddSongsTitle,
                      style: Theme.of(
                        context,
                      ).textTheme.songTitle.copyWith(fontSize: 17),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                key: const Key('playlist-song-picker-search'),
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: S.of(context).playlistSearchSongsHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                ),
                textInputAction: TextInputAction.search,
                onChanged: _loadSongs,
                onSubmitted: _loadSongs,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Text(
                        S.of(context).commonLoadFailed,
                        style: Theme.of(context).textTheme.songSubtitle
                            .copyWith(color: colors.onSurfaceVariant),
                      ),
                    )
                  : _songs.isEmpty
                  ? Center(
                      child: Text(
                        S.of(context).playlistNoMatchingSongs,
                        style: Theme.of(context).textTheme.songSubtitle
                            .copyWith(color: colors.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _songs.length,
                      itemBuilder: (context, index) {
                        final song = _songs[index];
                        final alreadyInPlaylist = widget.existingIds.contains(
                          song.id,
                        );
                        final selected = _selected.containsKey(song.id);
                        return CheckboxListTile(
                          key: ValueKey('picker-song-${song.id}'),
                          value: alreadyInPlaylist ? true : selected,
                          onChanged: alreadyInPlaylist
                              ? null
                              : (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      _selected[song.id] = song;
                                    } else {
                                      _selected.remove(song.id);
                                    }
                                  });
                                },
                          secondary: CoverArt(
                            url: widget.client.coverArtUrl(
                              song.coverArt,
                              size: 80,
                            ),
                            size: 40,
                            borderRadius: 6,
                          ),
                          title: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.songTitle.copyWith(fontSize: 13),
                          ),
                          subtitle: Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.songSubtitle
                                .copyWith(
                                  fontSize: 11,
                                  color: colors.onSurfaceVariant,
                                ),
                          ),
                          controlAffinity: ListTileControlAffinity.trailing,
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Text(
                    '${_selected.length}',
                    style: Theme.of(context).textTheme.songSubtitle,
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(S.of(context).commonCancel),
                  ),
                  FilledButton(
                    key: const Key('playlist-song-picker-confirm'),
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.pop(
                            context,
                            _selected.values.toList(growable: false),
                          ),
                    child: Text(S.of(context).playlistAddSelected),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
