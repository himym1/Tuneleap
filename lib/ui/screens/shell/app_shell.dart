import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/api/models/song.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/services/update_checker.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/mini_player.dart';
import 'package:navidrome_player/ui/widgets/update_dialog.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

/// 响应式外壳 — 移动端 BottomNavigationBar / 桌面端侧边栏
class AppShell extends ConsumerStatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  StreamSubscription<Song?>? _songSub;

  @override
  void initState() {
    super.initState();
    // 监听当前歌曲变化，更新全局主题色
    final playerService = ref.read(audioPlayerServiceProvider);
    _songSub = playerService.currentSongStream.listen((song) {
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
    // 启动时静默检查更新
    _checkUpdateOnStartup();
  }

  Future<void> _checkUpdateOnStartup() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final info = await checkForUpdate();
    if (info == null || !mounted) return;
    final currentVersion = ref.read(appVersionProvider);
    if (!isNewerVersion(info.version, currentVersion)) return;
    UpdateDialog.show(context, info);
  }

  @override
  void dispose() {
    _songSub?.cancel();
    super.dispose();
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
  ];

  bool _isMobile(BuildContext context) =>
      AppBreakpoints.isMobile(MediaQuery.of(context).size.width);

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
              context.colors.background,
            ],
          ),
        ),
        child: SafeArea(bottom: false, child: widget.child),
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
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                decoration: BoxDecoration(
                  color: Color.lerp(
                    Theme.of(context).colorScheme.surfaceContainerHigh,
                    ref.watch(globalAccentColorProvider),
                    0.06,
                  )!.withValues(alpha: 0.95),
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.25),
                      width: 0.5,
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height: 50,
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
    return Semantics(
      button: true,
      label: item.labelOf(context),
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? item.activeIcon : item.icon,
              size: 20,
              color: selected
                  ? context.colors.primary
                  : context.colors.onSurfaceVariant,
            ),
            const SizedBox(height: 2),
            Text(
              item.labelOf(context),
              style: Theme.of(context).textTheme.chipLabel.copyWith(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected
                    ? context.colors.primary
                    : context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }

  // ─── 桌面端布局 ───────────────────────────────────────────────

  Widget _buildDesktopLayout() {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): () {
          // 如果焦点在文本输入框中，不拦截空格键
          final focus = FocusManager.instance.primaryFocus;
          if (focus != null) {
            final ctx = focus.context;
            if (ctx != null && ctx.findAncestorWidgetOfExactType<EditableText>() != null) {
              return;
            }
          }
          final ps = ref.read(audioPlayerServiceProvider);
          if (ps.currentSong != null) {
            ps.player.playing ? ps.pause() : ps.play();
          }
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): () {
          ref.read(audioPlayerServiceProvider).next();
        },
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): () {
          ref.read(audioPlayerServiceProvider).previous();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  ref.watch(globalAccentColorProvider).withValues(alpha: 0.15),
                  context.colors.background,
                ],
              ),
            ),
            child: Row(
              children: [
                _buildSidebar(context),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top,
                    ),
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: const MiniPlayer(
                  key: ValueKey('desktop-mini'),
                  alwaysVisible: true,
                ),
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final location = _currentPath(context);
    final accentColor = ref.watch(globalAccentColorProvider);
    final baseColor = context.colors.surfaceContainer;
    // 将 accent color 以 8% 的比例混入侧边栏背景
    final sidebarColor = Color.lerp(baseColor, accentColor, 0.08)!.withValues(alpha: 0.92);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 800),
          width: AppDimensions.sidebarWidth,
          decoration: BoxDecoration(
            color: sidebarColor,
            border: Border(
              right: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            children: [
              // 可滚动的导航区域
              Expanded(
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Logo + Refresh（顶部留出 macOS 标题栏空间）
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            20,
                            MediaQuery.of(context).padding.top + 24,
                            12,
                            24,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: context.colors.primarySoft,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.music_note,
                                  color: context.colors.primary,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                S.of(context).appShortName,
                                style: Theme.of(context).textTheme.sectionTitle
                                    .copyWith(
                                      fontSize: 16,
                                      color: context.colors.onSurface,
                                      letterSpacing: -0.5,
                                    ),
                              ),
                              const Spacer(),
                              _RefreshButton(),
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
              // 底部固定的设置按钮
              _buildDesktopNavItem(
                const _NavItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                  labelKey: 'settings',
                  path: '/settings',
                ),
                _isPathSelected('/settings', location),
                () => context.go('/settings'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 6, top: 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.sectionSubheader.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: context.colors.onSurfaceVariant,
          letterSpacing: 0.8,
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
      child: Tooltip(
        message: item.labelOf(context),
        waitDuration: const Duration(milliseconds: 500),
        child: Material(
          color: selected ? context.colors.primarySoftAlt : Colors.transparent,
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
                        ? context.colors.primary
                        : context.colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    item.labelOf(context),
                    style: Theme.of(context).textTheme.songSubtitle.copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected
                          ? context.colors.primary
                          : context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
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

/// 侧边栏刷新按钮 — 刷新所有缓存数据
class _RefreshButton extends ConsumerStatefulWidget {
  @override
  ConsumerState<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends ConsumerState<_RefreshButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    _controller.repeat();

    // 触发 Navidrome 扫描
    try {
      await ref.read(subsonicClientProvider).startScan(fullScan: true);
      // 等待扫描完成
      await Future.delayed(const Duration(seconds: 3));
    } catch (_) {}

    // 刷新所有缓存 provider
    ref.invalidate(newestAlbumsProvider);
    ref.invalidate(dailySongsProvider);
    ref.invalidate(recentAlbumsProvider);
    ref.invalidate(artistsProvider);
    ref.invalidate(genresProvider);
    ref.invalidate(radioStationsProvider);
    ref.invalidate(playlistsProvider);
    ref.invalidate(weatherProvider);
    ref.read(libraryProvider.notifier).refresh();

    // 等待核心数据加载完成
    try {
      await Future.wait([
        ref.read(newestAlbumsProvider.future),
        ref.read(artistsProvider.future),
      ]);
    } catch (_) {
      // 刷新失败时静默处理
    }

    _controller.stop();
    _controller.reset();
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: S.of(context).commonRefresh,
      child: InkWell(
        onTap: _onRefresh,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: RotationTransition(
            turns: _controller,
            child: Icon(
              Icons.refresh,
              size: 18,
              color: _refreshing
                  ? context.colors.primary
                  : context.colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
