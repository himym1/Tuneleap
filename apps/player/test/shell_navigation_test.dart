import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/utils/shell_navigation.dart';

void main() {
  test('playlists and library are different shell branches', () {
    expect(shellBranchIndexForPath('/library/songs'), kLibraryBranch);
    expect(shellBranchIndexForPath('/library/albums'), kLibraryBranch);
    expect(shellBranchIndexForPath('/album/a1'), kLibraryBranch);
    expect(shellBranchIndexForPath('/library/playlists'), kPlaylistsBranch);
    expect(shellBranchIndexForPath('/playlist/p1'), kPlaylistsBranch);
    expect(shellBranchIndexForPath('/playlists'), kPlaylistsBranch);
    expect(shellBranchIndexForPath('/search'), kSearchBranch);
  });

  test(
    'tab roots use goBranch so library and playlists do not share a stack',
    () {
      expect(isShellTabRoot('/library'), isTrue);
      expect(isShellTabRoot('/library/songs'), isTrue);
      expect(isShellTabRoot('/library/playlists'), isTrue);
      expect(isShellTabRoot('/library/albums'), isFalse);
      expect(isShellTabRoot('/playlist/p1'), isFalse);
    },
  );

  testWidgets('opening playlists from library uses a dedicated branch', (
    tester,
  ) async {
    late StatefulNavigationShell shell;

    final router = GoRouter(
      initialLocation: '/library/songs',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            shell = navigationShell;
            return Scaffold(body: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) => const Text('home-root'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/library/songs',
                  builder: (context, state) => const Text('library-songs'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/search',
                  builder: (context, state) => const Text('search-root'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/settings',
                  builder: (context, state) => const Text('settings-root'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/library/playlists',
                  builder: (context, state) => const Text('playlists-root'),
                  routes: [
                    GoRoute(
                      path: 'detail/:id',
                      builder: (context, state) =>
                          Text('playlist-${state.pathParameters['id']}'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('library-songs'), findsOneWidget);
    expect(shell.currentIndex, kLibraryBranch);

    final playlistsBranch = shellBranchIndexForPath('/library/playlists')!;
    shell.goBranch(playlistsBranch);
    await tester.pumpAndSettle();
    expect(find.text('playlists-root'), findsOneWidget);
    expect(shell.currentIndex, kPlaylistsBranch);

    router.push('/library/playlists/detail/p1');
    await tester.pumpAndSettle();
    expect(find.text('playlist-p1'), findsOneWidget);

    shell.goBranch(kLibraryBranch);
    await tester.pumpAndSettle();
    expect(find.text('library-songs'), findsOneWidget);

    shell.goBranch(playlistsBranch);
    await tester.pumpAndSettle();
    expect(find.text('playlist-p1'), findsOneWidget);

    shell.goBranch(playlistsBranch, initialLocation: true);
    await tester.pumpAndSettle();
    expect(find.text('playlists-root'), findsOneWidget);
  });
}
