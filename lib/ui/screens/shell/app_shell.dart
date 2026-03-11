import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/api/models/song.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/mini_player.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

/// 响应式外壳 — 移动端 BottomNavigationBar / 桌面端侧边栏
class AppShell extends ConsumerStatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    // 监听当前歌曲变化，更新全局主题色
    final playerService = ref.read(audioPlayerServiceProvider);
    playerService.currentSongStream.listen((song) {
      if (song != null && mounted) {
        final resolver = ref.read(songMediaResolverProvider);
        resolver
            .coverArtUrl(song, size: 300)
            .then((coverUrl) {
              if (!mounted || coverUrl.isEmpty) return;
              ref.read(coverColorProvider(coverUrl).future).then((color) {
                if (mounted) {
                  ref.read(globalAccentColorProvider.notifier).setColor(color);
                }
              });
            })
            .catchError((_) {});
      }
    });
  }

  // 移动端底部导航（3 个 Tab）
  static const _mobileNavItems = [
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      labelKey: 'home',
      path: '/home',
    ),
    _NavItem(
      icon: Icons.library_music_outlined,
      activeIcon: Icons.library_music,
      labelKey: 'library',
      path: '/library/songs',
    ),
    _NavItem(
      icon: Icons.search_outlined,
      activeIcon: Icons.search,
      labelKey: 'search',
      path: '/search',
    ),
    _NavItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      labelKey: 'settings',
      path: '/settings',
    ),
  ];

  // PC 端导航项
  static const _navItems = [
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      labelKey: 'home',
      path: '/home',
    ),
    _NavItem(
      icon: Icons.search_outlined,
      activeIcon: Icons.search,
      labelKey: 'search',
      path: '/search',
    ),
    _NavItem(
      icon: Icons.favorite_border,
      activeIcon: Icons.favorite,
      labelKey: 'favorites',
      path: '/favorites',
    ),
  ];

  // PC 端音乐库子类
  static const _libraryItems = [
    _NavItem(
      icon: Icons.music_note_outlined,
      activeIcon: Icons.music_note,
      labelKey: 'songs',
      path: '/library/songs',
    ),
    _NavItem(
      icon: Icons.album_outlined,
      activeIcon: Icons.album,
      labelKey: 'albums',
      path: '/library/albums',
    ),
    _NavItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      labelKey: 'artists',
      path: '/library/artists',
    ),
    _NavItem(
      icon: Icons.people_outline,
      activeIcon: Icons.people,
      labelKey: 'albumArtists',
      path: '/library/album-artists',
    ),
    _NavItem(
      icon: Icons.category_outlined,
      activeIcon: Icons.category,
      labelKey: 'genres',
      path: '/library/genres',
    ),
    _NavItem(
      icon: Icons.radio_outlined,
      activeIcon: Icons.radio,
      labelKey: 'radio',
      path: '/library/radio',
    ),
  ];

  // PC 端更多功能
  static const _moreNavItems = [
    _NavItem(
      icon: Icons.download_outlined,
      activeIcon: Icons.download,
      labelKey: 'downloads',
      path: '/downloads',
    ),
    _NavItem(
      icon: Icons.dns_outlined,
      activeIcon: Icons.dns,
      labelKey: 'servers',
      path: '/servers',
    ),
    _NavItem(
      icon: Icons.history,
      activeIcon: Icons.history,
      labelKey: 'scrobble',
      path: '/scrobble',
    ),
    _NavItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      labelKey: 'settings',
      path: '/settings',
    ),
  ];

  bool _isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  String _currentPath(BuildContext context) =>
      GoRouterState.of(context).uri.toString();

  bool _isPathSelected(String itemPath, String currentPath) =>
      currentPath.startsWith(itemPath);

  @override
  Widget build(BuildContext context) {
    return _isMobile(context) ? _buildMobileLayout() : _buildDesktopLayout();
  }

  // ─── 移动端布局 ───────────────────────────────────────────────

  Widget _buildMobileLayout() {
    final playerService = ref.watch(audioPlayerServiceProvider);
    final location = _currentPath(context);

    int mobileIndex = 0;
    for (int i = 0; i < _mobileNavItems.length; i++) {
      if (_isPathSelected(_mobileNavItems[i].path, location) ||
          (i == 1 && location.startsWith('/library'))) {
        mobileIndex = i;
        break;
      }
    }

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ref.watch(globalAccentColorProvider).withValues(alpha: 0.15),
              AppColors.background,
            ],
          ),
        ),
        child: widget.child,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StreamBuilder<Song?>(
            stream: playerService.currentSongStream,
            builder: (context, snapshot) {
              final currentSong = snapshot.data ?? playerService.currentSong;
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) => SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: currentSong != null
                    ? const MiniPlayer(key: ValueKey('mini'))
                    : const SizedBox.shrink(key: ValueKey('empty')),
              );
            },
          ),
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHigh.withValues(alpha: 0.8),
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height: 62,
                    child: Row(
                      children: List.generate(_mobileNavItems.length, (i) {
                        final item = _mobileNavItems[i];
                        final selected = mobileIndex == i;
                        return Expanded(
                          child: _buildMobileTabItem(item, selected, () {
                            context.go(item.path);
                          }),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTabItem(_NavItem item, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? item.activeIcon : item.icon,
              size: 20,
              color: selected
                  ? AppColors.onEmphasis
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 2),
            Text(
              item.labelOf(context),
              style: Theme.of(context).textTheme.chipLabel.copyWith(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected
                    ? AppColors.onEmphasis
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 桌面端布局 ───────────────────────────────────────────────

  Widget _buildDesktopLayout() {
    final playerService = ref.watch(audioPlayerServiceProvider);
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ref.watch(globalAccentColorProvider).withValues(alpha: 0.15),
              AppColors.background,
            ],
          ),
        ),
        child: Row(
          children: [
            _buildSidebar(context),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: widget.child),
          ],
        ),
      ),
      bottomNavigationBar: StreamBuilder<Song?>(
        stream: playerService.currentSongStream,
        builder: (context, snapshot) {
          final currentSong = snapshot.data ?? playerService.currentSong;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: currentSong != null
                ? const MiniPlayer(key: ValueKey('mini'))
                : const SizedBox.shrink(key: ValueKey('empty')),
          );
        },
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final location = _currentPath(context);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: 200,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHigh.withValues(alpha: 0.85),
            border: Border(
              right: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.music_note,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        S.of(context).appShortName,
                        style: Theme.of(context).textTheme.sectionTitle.copyWith(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── NAV section ──
                _buildSectionHeader(S.of(context).sidebarNav),
                ..._navItems.map(
                  (item) => _buildDesktopNavItem(
                    item,
                    _isPathSelected(item.path, location),
                    () => context.go(item.path),
                  ),
                ),

                const SizedBox(height: 12),

                // ── LIBRARY section ──
                _buildSectionHeader(S.of(context).sidebarLibrary),
                ..._libraryItems.map(
                  (item) => _buildDesktopNavItem(
                    item,
                    _isPathSelected(item.path, location),
                    () => context.go(item.path),
                  ),
                ),

                const SizedBox(height: 12),

                // ── MORE section ──
                _buildSectionHeader(S.of(context).sidebarMore),
                ..._moreNavItems.map(
                  (item) => _buildDesktopNavItem(
                    item,
                    _isPathSelected(item.path, location),
                    () => context.go(item.path),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 6, top: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.sectionSubheader.copyWith(
          fontSize: 10,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildDesktopNavItem(
    _NavItem item,
    bool selected,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      child: Material(
        color: selected ? AppColors.primarySoftAlt : AppColors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  selected ? item.activeIcon : item.icon,
                  size: 18,
                  color: selected
                      ? AppColors.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Text(
                  item.labelOf(context),
                  style: Theme.of(context).textTheme.songSubtitle.copyWith(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? AppColors.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String labelKey;
  final String path;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.labelKey,
    required this.path,
  });

  String labelOf(BuildContext context) {
    final s = S.of(context);
    switch (labelKey) {
      case 'home':
        return s.navHome;
      case 'library':
        return s.navLibrary;
      case 'search':
        return s.navSearch;
      case 'playlists':
        return s.navPlaylists;
      case 'settings':
        return s.navSettings;
      case 'favorites':
        return s.navFavorites;
      case 'downloads':
        return s.navDownloads;
      case 'servers':
        return s.navServers;
      case 'audioQuality':
        return s.navAudioQuality;
      case 'scrobble':
        return s.navScrobble;
      case 'songs':
        return s.navSongs;
      case 'albums':
        return s.navAlbums;
      case 'artists':
        return s.navArtists;
      case 'albumArtists':
        return s.navAlbumArtists;
      case 'genres':
        return s.navGenres;
      case 'radio':
        return s.navRadio;
      default:
        return labelKey;
    }
  }
}
