import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/utils/player_navigation.dart';

GoRouter _router() {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (_, _) => const Text('home')),
      GoRoute(path: '/player', builder: (_, _) => const Text('player')),
    ],
  );
}

GoRouter _playerStackRouter() {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (_, _) => const Text('home')),
      GoRoute(
        path: '/player',
        builder: (_, _) => const Text('player'),
        routes: [
          GoRoute(
            path: 'artist/:id',
            builder: (_, state) =>
                Text('player-artist-${state.pathParameters['id']}'),
          ),
          GoRoute(
            path: 'album/:id',
            builder: (_, state) =>
                Text('player-album-${state.pathParameters['id']}'),
          ),
        ],
      ),
      GoRoute(
        path: '/artist/:id',
        builder: (_, state) =>
            Text('library-artist-${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/album/:id',
        builder: (_, state) =>
            Text('library-album-${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/search',
        builder: (_, state) =>
            Text('search-${state.uri.queryParameters['q'] ?? ''}'),
      ),
    ],
  );
}

void main() {
  setUp(debugResetPlayerNavigation);
  tearDown(debugResetPlayerNavigation);

  testWidgets('openPlayer pushes only one player page', (tester) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    final context = tester.element(find.text('home'));
    openPlayer(context);
    openPlayer(context);
    await tester.pumpAndSettle();

    expect(find.text('player'), findsOneWidget);
    expect(isPlayerRouteOnStack(router), isTrue);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(isPlayerRouteOnStack(router), isFalse);
  });

  testWidgets('openPlayer is a no-op when player is already open', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    final home = tester.element(find.text('home'));
    openPlayer(home);
    await tester.pumpAndSettle();

    openPlayer(tester.element(find.text('player')));
    await tester.pumpAndSettle();

    expect(find.text('player'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('artist opened from player pops back to the player', (
    tester,
  ) async {
    final router = _playerStackRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    openPlayer(tester.element(find.text('home')));
    await tester.pumpAndSettle();
    expect(find.text('player'), findsOneWidget);

    openLibraryItemFromPlayer(
      tester.element(find.text('player')),
      artist: true,
      id: 'a1',
      label: 'Artist',
      isOnline: false,
    );
    await tester.pumpAndSettle();
    expect(find.text('player-artist-a1'), findsOneWidget);
    expect(find.text('library-artist-a1'), findsNothing);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('player'), findsOneWidget);
    expect(isPlayerRouteOnStack(router), isTrue);
  });

  testWidgets('album opened from player pops back to the player', (
    tester,
  ) async {
    final router = _playerStackRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    openPlayer(tester.element(find.text('home')));
    await tester.pumpAndSettle();

    openLibraryItemFromPlayer(
      tester.element(find.text('player')),
      artist: false,
      id: 'al1',
      label: 'Album',
      isOnline: false,
    );
    await tester.pumpAndSettle();
    expect(find.text('player-album-al1'), findsOneWidget);
    expect(find.text('library-album-al1'), findsNothing);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('player'), findsOneWidget);
  });

  testWidgets('openPlayer is a no-op on nested player artist', (tester) async {
    final router = _playerStackRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    openPlayer(tester.element(find.text('home')));
    await tester.pumpAndSettle();
    openLibraryItemFromPlayer(
      tester.element(find.text('player')),
      artist: true,
      id: 'a1',
      label: 'Artist',
      isOnline: false,
    );
    await tester.pumpAndSettle();

    openPlayer(tester.element(find.text('player-artist-a1')));
    await tester.pumpAndSettle();
    expect(find.text('player-artist-a1'), findsOneWidget);
    expect(find.text('player'), findsNothing);
  });
}
