import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/utils/platform_utils.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/screens/login/login_screen.dart';
import 'package:navidrome_player/ui/screens/shell/app_shell.dart';
import 'package:navidrome_player/ui/screens/home/home_screen.dart';
import 'package:navidrome_player/ui/screens/recommendations/recommendations_screen.dart';
import 'package:navidrome_player/ui/screens/library/library_songs_screen.dart';
import 'package:navidrome_player/ui/screens/library/library_albums_screen.dart';
import 'package:navidrome_player/ui/screens/library/library_artists_screen.dart';
import 'package:navidrome_player/ui/screens/library/library_album_artists_screen.dart';
import 'package:navidrome_player/ui/screens/library/library_genres_screen.dart';
import 'package:navidrome_player/ui/screens/library/library_radio_screen.dart';
import 'package:navidrome_player/ui/screens/search/search_screen.dart';
import 'package:navidrome_player/ui/screens/player/player_screen.dart';
import 'package:navidrome_player/ui/screens/playlists/playlists_screen.dart';
import 'package:navidrome_player/ui/screens/settings/settings_screen.dart';
import 'package:navidrome_player/ui/screens/downloads/downloads_screen.dart';
import 'package:navidrome_player/ui/screens/scrobble/scrobble_screen.dart';
import 'package:navidrome_player/ui/screens/multi_server/multi_server_screen.dart';
import 'package:navidrome_player/ui/screens/album_detail/album_detail_screen.dart';
import 'package:navidrome_player/ui/screens/artist_detail/artist_detail_screen.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/l10n/localization_utils.dart';

/// FadeThrough transition: old page fades out completely, then new page fades in.
/// Avoids text overlap that occurs with simple FadeTransition.
Widget _fadeThroughTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return FadeTransition(
    opacity: CurvedAnimation(
      parent: animation,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    ),
    child: FadeTransition(
      opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(
          parent: secondaryAnimation,
          curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
        ),
      ),
      child: child,
    ),
  );
}

const _kFadeDuration = Duration(milliseconds: 250);

CustomTransitionPage<void> _detailSlidePage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
    transitionDuration: const Duration(milliseconds: 250),
  );
}

class NavidromePlayerApp extends ConsumerStatefulWidget {
  const NavidromePlayerApp({super.key});

  @override
  ConsumerState<NavidromePlayerApp> createState() => _NavidromePlayerAppState();
}

class _NavidromePlayerAppState extends ConsumerState<NavidromePlayerApp> {
  late final GoRouter _router;
  late final ProviderSubscription<AsyncValue<AuthStatus>> _authSubscription;
  final _authRefresh = ValueNotifier<int>(0);
  final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

  @override
  void initState() {
    super.initState();
    _router = _buildRouter();
    _authSubscription = ref.listenManual(authProvider, (previous, next) {
      _authRefresh.value++;
    });
    _initPlatform();
  }

  @override
  void dispose() {
    _authSubscription.close();
    _authRefresh.dispose();
    _router.dispose();
    super.dispose();
  }

  Future<void> _initPlatform() async {
    if (!isDesktop) return;
    final strings = systemLocalizations();
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(const Size(800, 600));
    await windowManager.setSize(const Size(1200, 800));
    await windowManager.setTitle(strings.appName);
    await windowManager.show();
  }

  GoRouter _buildRouter() {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/home',
      refreshListenable: _authRefresh,
      redirect: (context, state) {
        return ref
            .read(authProvider)
            .when(
              data: (status) {
                final onLogin = state.uri.path == '/login';
                if (status == AuthStatus.unauthenticated && !onLogin) {
                  return '/login';
                }
                if (status == AuthStatus.authenticated && onLogin) {
                  return '/home';
                }
                return null;
              },
              loading: () => null,
              error: (_, _) => state.uri.path == '/login' ? null : '/login',
            );
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/player',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const PlayerScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(0, 1),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                            reverseCurve: Curves.easeInCubic,
                          ),
                        ),
                    child: child,
                  );
                },
          ),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AppShell(navigationShell: navigationShell),
          branches: [
            // 0 Home hub — recommendations and legacy playlist alias
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  pageBuilder: (context, state) => CustomTransitionPage(
                    key: state.pageKey,
                    child: const HomeScreen(),
                    transitionsBuilder: _fadeThroughTransition,
                    transitionDuration: _kFadeDuration,
                  ),
                  routes: [
                    GoRoute(
                      path: 'album/:id',
                      pageBuilder: (context, state) => _detailSlidePage(
                        key: state.pageKey,
                        child: AlbumDetailScreen(
                          albumId: state.pathParameters['id']!,
                        ),
                      ),
                    ),
                    GoRoute(
                      path: 'artist/:id',
                      pageBuilder: (context, state) => _detailSlidePage(
                        key: state.pageKey,
                        child: ArtistDetailScreen(
                          artistId: state.pathParameters['id']!,
                        ),
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: '/recommendations',
                  pageBuilder: (context, state) => CustomTransitionPage(
                    key: state.pageKey,
                    child: const RecommendationsScreen(),
                    transitionsBuilder: _fadeThroughTransition,
                    transitionDuration: _kFadeDuration,
                  ),
                ),
                GoRoute(
                  path: '/playlists',
                  redirect: (context, state) => '/library/playlists',
                ),
              ],
            ),
            // 1 Library — album/artist detail share this stack
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/library',
                  redirect: (context, state) => '/library/songs',
                ),
                GoRoute(
                  path: '/library/playlists',
                  pageBuilder: (context, state) => CustomTransitionPage(
                    key: state.pageKey,
                    child: const PlaylistsScreen(),
                    transitionsBuilder: _fadeThroughTransition,
                    transitionDuration: _kFadeDuration,
                  ),
                ),
                GoRoute(
                  path: '/library/songs',
                  pageBuilder: (context, state) => CustomTransitionPage(
                    key: state.pageKey,
                    child: const LibrarySongsScreen(),
                    transitionsBuilder: _fadeThroughTransition,
                    transitionDuration: _kFadeDuration,
                  ),
                ),
                GoRoute(
                  path: '/library/albums',
                  pageBuilder: (context, state) => CustomTransitionPage(
                    key: state.pageKey,
                    child: const LibraryAlbumsScreen(),
                    transitionsBuilder: _fadeThroughTransition,
                    transitionDuration: _kFadeDuration,
                  ),
                ),
                GoRoute(
                  path: '/library/artists',
                  pageBuilder: (context, state) => CustomTransitionPage(
                    key: state.pageKey,
                    child: const LibraryArtistsScreen(),
                    transitionsBuilder: _fadeThroughTransition,
                    transitionDuration: _kFadeDuration,
                  ),
                ),
                GoRoute(
                  path: '/library/album-artists',
                  pageBuilder: (context, state) => CustomTransitionPage(
                    key: state.pageKey,
                    child: const LibraryAlbumArtistsScreen(),
                    transitionsBuilder: _fadeThroughTransition,
                    transitionDuration: _kFadeDuration,
                  ),
                ),
                GoRoute(
                  path: '/library/genres',
                  pageBuilder: (context, state) => CustomTransitionPage(
                    key: state.pageKey,
                    child: const LibraryGenresScreen(),
                    transitionsBuilder: _fadeThroughTransition,
                    transitionDuration: _kFadeDuration,
                  ),
                ),
                GoRoute(
                  path: '/library/radio',
                  pageBuilder: (context, state) => CustomTransitionPage(
                    key: state.pageKey,
                    child: const LibraryRadioScreen(),
                    transitionsBuilder: _fadeThroughTransition,
                    transitionDuration: _kFadeDuration,
                  ),
                ),
                GoRoute(
                  path: '/album/:id',
                  pageBuilder: (context, state) => _detailSlidePage(
                    key: state.pageKey,
                    child: AlbumDetailScreen(
                      albumId: state.pathParameters['id']!,
                    ),
                  ),
                ),
                GoRoute(
                  path: '/artist/:id',
                  pageBuilder: (context, state) => _detailSlidePage(
                    key: state.pageKey,
                    child: ArtistDetailScreen(
                      artistId: state.pathParameters['id']!,
                    ),
                  ),
                ),
              ],
            ),
            // 2 Search
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/search',
                  pageBuilder: (context, state) => CustomTransitionPage(
                    key: state.pageKey,
                    child: const SearchScreen(),
                    transitionsBuilder: _fadeThroughTransition,
                    transitionDuration: _kFadeDuration,
                  ),
                ),
              ],
            ),
            // 3 Settings hub — tools share settings branch stack
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/settings',
                  pageBuilder: (context, state) => CustomTransitionPage(
                    key: state.pageKey,
                    child: const SettingsScreen(),
                    transitionsBuilder: _fadeThroughTransition,
                    transitionDuration: _kFadeDuration,
                  ),
                ),
                GoRoute(
                  path: '/downloads',
                  pageBuilder: (context, state) => CustomTransitionPage(
                    key: state.pageKey,
                    child: const DownloadsScreen(),
                    transitionsBuilder: _fadeThroughTransition,
                    transitionDuration: _kFadeDuration,
                  ),
                ),
                GoRoute(
                  path: '/servers',
                  pageBuilder: (context, state) => CustomTransitionPage(
                    key: state.pageKey,
                    child: const MultiServerScreen(),
                    transitionsBuilder: _fadeThroughTransition,
                    transitionDuration: _kFadeDuration,
                  ),
                ),
                GoRoute(
                  path: '/scrobble',
                  pageBuilder: (context, state) => CustomTransitionPage(
                    key: state.pageKey,
                    child: const ScrobbleScreen(),
                    transitionsBuilder: _fadeThroughTransition,
                    transitionDuration: _kFadeDuration,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final themePreset = ref.watch(themePresetProvider);
    final dynamicAccent = ref.watch(globalAccentColorProvider);
    final seedColor = themePreset == ThemePreset.dynamic ? dynamicAccent : null;
    final effectiveThemeMode = themePreset == ThemePreset.amoled
        ? ThemeMode.dark
        : themeMode;
    final lightTheme = AppTheme.light(seedColor: seedColor);
    final darkTheme = AppTheme.dark(
      seedColor: seedColor,
      amoled: themePreset == ThemePreset.amoled,
    );
    final auth = ref.watch(authProvider);

    if (auth.isLoading) {
      return MaterialApp(
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: effectiveThemeMode,
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp.router(
      onGenerateTitle: (context) => S.of(context).appName,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: effectiveThemeMode,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      routerConfig: _router,
    );
  }
}
