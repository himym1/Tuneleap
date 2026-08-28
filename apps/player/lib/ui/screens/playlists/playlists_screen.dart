import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPlaylists = ref.watch(playlistsProvider);
    final isMobile = AppBreakpoints.isMobile(MediaQuery.of(context).size.width);
    final h = isMobile
        ? AppDimensions.paddingMobile
        : AppDimensions.paddingDesktop;

    if (isMobile) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          S.of(context).navPlaylists,
                          key: const Key('playlist-header-title'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.pageTitle.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          S
                              .of(context)
                              .playlistCount(asyncPlaylists.value?.length ?? 0),
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
                  IconButton.filledTonal(
                    key: const Key('playlist-create-button'),
                    tooltip: S.of(context).playlistCreate,
                    onPressed: () => _createPlaylist(context, ref),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: asyncPlaylists.when(
                loading: () => Center(
                  child: CircularProgressIndicator(
                    color: context.colors.primary,
                  ),
                ),
                error: (_, _) => Center(
                  child: Text(
                    S.of(context).commonLoadFailed,
                    style: Theme.of(context).textTheme.songSubtitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                data: (playlists) => RefreshIndicator(
                  onRefresh: () => _refreshPlaylists(ref),
                  child: playlists.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 160),
                            _buildEmptyState(context),
                          ],
                        )
                      : _buildPlaylistGrid(context, ref, playlists),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部
          Padding(
            padding: EdgeInsets.fromLTRB(h, h, h, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  S.of(context).navPlaylists,
                  style: Theme.of(context).textTheme.pageTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      S
                          .of(context)
                          .playlistCount(asyncPlaylists.value?.length ?? 0),
                      style: Theme.of(context).textTheme.chipLabel.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      onPressed: () => _createPlaylist(context, ref),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(S.of(context).commonNew),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 列表网格
          Expanded(
            child: asyncPlaylists.when(
              loading: () => Center(
                child: CircularProgressIndicator(color: context.colors.primary),
              ),
              error: (_, _) => Center(
                child: Text(
                  S.of(context).commonLoadFailed,
                  style: Theme.of(context).textTheme.songSubtitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              data: (playlists) => RefreshIndicator(
                onRefresh: () => _refreshPlaylists(ref),
                child: playlists.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 200),
                          _buildEmptyState(context),
                        ],
                      )
                    : _buildPlaylistGrid(context, ref, playlists),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshPlaylists(WidgetRef ref) async {
    ref.invalidate(playlistsProvider);
    await ref.read(playlistsProvider.future);
  }

  void _createPlaylist(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of(context).playlistCreate),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: S.of(context).playlistNameLabel,
          ),
          onSubmitted: (_) =>
              _submitCreate(ctx, context, ref, nameController.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () =>
                _submitCreate(ctx, context, ref, nameController.text),
            child: Text(S.of(context).commonCreate),
          ),
        ],
      ),
    );
  }

  Future<void> _submitCreate(
    BuildContext ctx,
    BuildContext screenContext,
    WidgetRef ref,
    String name,
  ) async {
    if (name.trim().isEmpty) return;
    Navigator.pop(ctx);
    try {
      final service = ref.read(playlistServiceProvider);
      await service.createPlaylist(name.trim());
      ref.invalidate(playlistsProvider);
      if (screenContext.mounted) {
        ScaffoldMessenger.of(screenContext).showSnackBar(
          SnackBar(content: Text(S.of(screenContext).playlistCreated(name))),
        );
      }
    } catch (e) {
      if (screenContext.mounted) {
        ScaffoldMessenger.of(screenContext).showSnackBar(
          SnackBar(content: Text(S.of(screenContext).playlistCreateFailed)),
        );
      }
    }
  }

  Future<void> _deletePlaylist(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of(context).playlistDeleteTitle),
        content: Text(S.of(context).playlistDeleteConfirm(playlist.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.error,
            ),
            child: Text(S.of(context).commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final service = ref.read(playlistServiceProvider);
      await service.deletePlaylist(playlist.id);
      ref.invalidate(playlistsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).playlistDeleted(playlist.name))),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).playlistDeleteFailed)),
        );
      }
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.queue_music_rounded,
            size: 64,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            S.of(context).playlistEmptyTitle,
            style: Theme.of(context).textTheme.sectionTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            S.of(context).playlistEmptyHint,
            style: Theme.of(context).textTheme.songSubtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistGrid(
    BuildContext context,
    WidgetRef ref,
    List<Playlist> playlists,
  ) {
    final client = ref.read(subsonicClientProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = AppBreakpoints.isMobile(constraints.maxWidth);
        if (isMobile) {
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final pl = playlists[index];
              return _PlaylistListTile(
                playlist: pl,
                coverUrl: client.coverArtUrl(pl.coverArt, size: 300),
                onTap: () => _openPlaylist(context, pl),
                onDelete: () => _deletePlaylist(context, ref, pl),
                onRename: () => _renamePlaylist(context, ref, pl),
              );
            },
          );
        }
        final crossAxisCount = (constraints.maxWidth / 260).floor().clamp(2, 5);
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.3,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
          ),
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            final pl = playlists[index];
            return _PlaylistCard(
              playlist: pl,
              coverUrl: client.coverArtUrl(pl.coverArt, size: 300),
              onTap: () => _openPlaylist(context, pl),
              onDelete: () => _deletePlaylist(context, ref, pl),
              onRename: () => _renamePlaylist(context, ref, pl),
            );
          },
        );
      },
    );
  }

  void _openPlaylist(BuildContext context, Playlist playlist) {
    context.push('/playlist/${Uri.encodeComponent(playlist.id)}');
  }

  Future<void> _renamePlaylist(
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
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(S.of(context).commonError)));
      }
    }
  }
}

class _PlaylistListTile extends StatelessWidget {
  const _PlaylistListTile({
    required this.playlist,
    required this.coverUrl,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
  });

  final Playlist playlist;
  final String coverUrl;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      leading: _PlaylistArtwork(
        playlist: playlist,
        coverUrl: coverUrl,
        size: 52,
        borderRadius: 10,
      ),
      title: Text(
        playlist.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.songTitle.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        S.of(context).playlistSongCountLabel(playlist.songCount ?? 0),
        style: Theme.of(context).textTheme.songSubtitle.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: _PlaylistMenu(
        key: ValueKey('playlist-menu-${playlist.id}'),
        onOpen: onTap,
        onRename: onRename,
        onDelete: onDelete,
      ),
      onTap: onTap,
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({
    required this.playlist,
    required this.coverUrl,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
  });

  final Playlist playlist;
  final String coverUrl;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: isDark ? 0.10 : 0.06,
              ),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: _PlaylistArtwork(
                    playlist: playlist,
                    coverUrl: coverUrl,
                    borderRadius: 0,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.songTitle
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            S
                                .of(context)
                                .playlistSongCountLabel(
                                  playlist.songCount ?? 0,
                                ),
                            style: Theme.of(context).textTheme.songSubtitle
                                .copyWith(
                                  fontSize: 12,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    _PlaylistMenu(
                      key: ValueKey('playlist-menu-${playlist.id}'),
                      onOpen: onTap,
                      onRename: onRename,
                      onDelete: onDelete,
                    ),
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

class _PlaylistArtwork extends StatelessWidget {
  const _PlaylistArtwork({
    required this.playlist,
    required this.coverUrl,
    this.size,
    this.borderRadius = 8,
  });

  final Playlist playlist;
  final String coverUrl;
  final double? size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    if ((playlist.songCount ?? playlist.songs.length) > 0 &&
        coverUrl.isNotEmpty) {
      return CoverArt(url: coverUrl, size: size, borderRadius: borderRadius);
    }
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.queue_music_rounded,
        size: size == null ? 48 : size! * 0.46,
        color: colors.onSecondaryContainer,
      ),
    );
  }
}

class _PlaylistMenu extends StatelessWidget {
  const _PlaylistMenu({
    super.key,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: S.of(context).tooltipMore,
      icon: Icon(
        Icons.more_vert_rounded,
        size: 20,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'open',
          child: _menuItem(Icons.edit_note_rounded, S.of(context).playlistEdit),
        ),
        PopupMenuItem(
          value: 'rename',
          child: _menuItem(
            Icons.drive_file_rename_outline_rounded,
            S.of(context).playlistRename,
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: _menuItem(
            Icons.delete_outline_rounded,
            S.of(context).commonDelete,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'open':
            onOpen();
          case 'rename':
            onRename();
          case 'delete':
            onDelete();
        }
      },
    );
  }

  Widget _menuItem(IconData icon, String label, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 12),
        Text(label, style: color == null ? null : TextStyle(color: color)),
      ],
    );
  }
}
