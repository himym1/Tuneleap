import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/api/models/song.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/cover_art.dart';
import 'package:navidrome_player/ui/widgets/empty_state.dart';
import 'package:navidrome_player/ui/widgets/song_context_menu.dart';
import 'package:navidrome_player/ui/widgets/app_segmented_tab_bar.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _albumScrollController = ScrollController();
  final _songScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _albumScrollController.addListener(_onAlbumScroll);
    _songScrollController.addListener(_onSongScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _albumScrollController.dispose();
    _songScrollController.dispose();
    super.dispose();
  }

  void _onAlbumScroll() {
    if (_albumScrollController.position.pixels >
        _albumScrollController.position.maxScrollExtent - 200) {
      ref.read(libraryProvider.notifier).loadMoreAlbums();
    }
  }

  void _onSongScroll() {
    if (_songScrollController.position.pixels >
        _songScrollController.position.maxScrollExtent - 200) {
      ref.read(libraryProvider.notifier).loadMoreSongs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lib = ref.watch(libraryProvider);
    final isMobile = AppBreakpoints.isMobile(MediaQuery.of(context).size.width);
    final h = isMobile ? AppDimensions.paddingMobile : AppDimensions.paddingDesktop;

    final tabBar = AppSegmentedTabBar(
      controller: _tabController,
      tabs: [
        Tab(text: S.of(context).libraryTabArtists),
        Tab(text: S.of(context).libraryTabAlbums),
        Tab(text: S.of(context).libraryTabSongs),
      ],
    );

    final tabContent = lib.loading
        ? Center(child: const CircularProgressIndicator())
        : TabBarView(
            controller: _tabController,
            children: [
              _buildArtistList(lib),
              _buildAlbumGrid(lib),
              _buildSongList(lib),
            ],
          );

    if (isMobile) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              pinned: true,
              floating: true,
              snap: true,
              expandedHeight: 100,
              toolbarHeight: 0,
              backgroundColor: Theme.of(context).colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    S.of(context).navLibrary,
                    style: Theme.of(context).textTheme.pageTitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: Theme.of(context).colorScheme.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: tabBar,
                ),
              ),
            ),
          ],
          body: tabContent,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(h, h, h, 0),
            child: Text(
              S.of(context).navLibrary,
              style: Theme.of(context).textTheme.pageTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: h),
            child: tabBar,
          ),
          const SizedBox(height: 8),
          Expanded(child: tabContent),
        ],
      ),
    );
  }

  Widget _buildArtistList(LibraryState lib) {
    final artists = lib.artists;
    if (artists.isEmpty) {
      return EmptyState(
        icon: Icons.person_outline,
        message: S.of(context).libraryNoArtists,
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(libraryProvider.notifier).refresh(),
      child: ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        final client = ref.read(subsonicClientProvider);
        final coverUrl = client.coverArtUrl(artist.coverArt, size: 100);
        return Container(
          margin: const EdgeInsets.only(bottom: 2),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHigh,
              backgroundImage: coverUrl.isNotEmpty
                  ? NetworkImage(coverUrl)
                  : null,
              child: coverUrl.isEmpty
                  ? Icon(
                      Icons.person,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 20,
                    )
                  : null,
            ),
            title: Text(
              artist.name,
              style: Theme.of(context).textTheme.songTitle,
            ),
            subtitle: Text(
              S.of(context).artistAlbumCount(artist.albumCount ?? 0),
              style: Theme.of(context).textTheme.songSubtitle.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: IconButton(
                  icon: const Icon(Icons.play_circle_outline, size: 22),
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  tooltip: S.of(context).tooltipPlay,
                  onPressed: () => ref.read(libraryProvider.notifier).playArtist(artist),
                ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            onTap: () => context.push('/artist/${artist.id}'),
          ),
        );
      },
    ),
    );
  }

  Widget _buildAlbumGrid(LibraryState lib) {
    final albums = lib.albums;
    if (albums.isEmpty) {
      return EmptyState(
        icon: Icons.album_outlined,
        message: S.of(context).libraryNoAlbums,
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(libraryProvider.notifier).refresh(),
      child: LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 180).floor().clamp(2, 6);
        return GridView.builder(
          controller: _albumScrollController,
          padding: const EdgeInsets.all(24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.78,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount:
              albums.length + (lib.hasMoreAlbums ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= albums.length) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                ),
              );
            }
            final album = albums[index];
            final client = ref.read(subsonicClientProvider);
            return Semantics(
              button: true,
              label: album.artist == null || album.artist!.isEmpty
                  ? album.name
                  : '${album.name} · ${album.artist!}',
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => context.push('/album/${album.id}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: CoverArt(
                          url: client.coverArtUrl(album.coverArt, size: 300),
                          borderRadius: 10,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        album.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.songSubtitle.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (album.artist != null)
                        Text(
                          album.artist!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.songSubtitle.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
    );
  }

  Widget _buildSongList(LibraryState lib) {
    final songs = lib.songs;
    if (songs.isEmpty) {
      return EmptyState(
        icon: Icons.music_note_outlined,
        message: S.of(context).libraryNoSongs,
      );
    }
    final client = ref.read(subsonicClientProvider);
    final playerService = ref.read(audioPlayerServiceProvider);
    return RefreshIndicator(
      onRefresh: () => ref.read(libraryProvider.notifier).refresh(),
      child: StreamBuilder<Song?>(
      stream: playerService.currentSongStream,
      initialData: playerService.currentSong,
      builder: (context, snapshot) {
        final currentSong = snapshot.data ?? playerService.currentSong;
        return ListView.builder(
      controller: _songScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: songs.length + (lib.hasMoreSongs ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= songs.length) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
          );
        }
        final song = songs[index];
        final isPlaying = currentSong?.id == song.id;
        return SongContextMenu(
          song: song,
          onPlay: () {
            ref
                .read(audioPlayerServiceProvider)
                .playAll(songs, startIndex: index);
          },
          child: Container(
            decoration: BoxDecoration(
              color: isPlaying ? context.colors.primarySoft : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              leading: CoverArt(
                url: client.coverArtUrl(song.coverArt, size: 80),
                size: 44,
                borderRadius: 6,
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
              trailing: song.duration != null
                  ? Text(
                      song.formattedDuration,
                      style: Theme.of(context).textTheme.songSubtitle.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    )
                  : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              onTap: () {
                ref
                    .read(audioPlayerServiceProvider)
                    .playAll(songs, startIndex: index);
              },
            ),
          ),
        );
      },
    );
      },
    ),
    );
  }
}
