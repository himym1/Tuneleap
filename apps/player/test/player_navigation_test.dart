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
}
