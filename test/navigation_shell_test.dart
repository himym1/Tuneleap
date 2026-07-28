import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('inactive main-tab branch keeps its location', (tester) async {
    late StatefulNavigationShell shell;

    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            shell = navigationShell;
            return Scaffold(
              body: navigationShell,
              bottomNavigationBar: NavigationBar(
                selectedIndex: navigationShell.currentIndex,
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
                  NavigationDestination(
                    icon: Icon(Icons.library_music),
                    label: 'Library',
                  ),
                ],
                onDestinationSelected: (index) {
                  navigationShell.goBranch(
                    index,
                    initialLocation: index == navigationShell.currentIndex,
                  );
                },
              ),
            );
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) => const Text('home-root'),
                  routes: [
                    GoRoute(
                      path: 'album/:id',
                      builder: (context, state) =>
                          Text('home-album-${state.pathParameters['id']}'),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/library',
                  builder: (context, state) => const Text('library-root'),
                  routes: [
                    GoRoute(
                      path: 'albums',
                      builder: (context, state) => const Text('library-albums'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('home-root'), findsOneWidget);

    router.go('/library/albums');
    await tester.pumpAndSettle();
    expect(find.text('library-albums'), findsOneWidget);
    expect(shell.currentIndex, 1);

    shell.goBranch(0);
    await tester.pumpAndSettle();
    expect(find.text('home-root'), findsOneWidget);
    expect(shell.currentIndex, 0);

    shell.goBranch(1);
    await tester.pumpAndSettle();
    expect(find.text('library-albums'), findsOneWidget);
    expect(shell.currentIndex, 1);
  });

  testWidgets('home album detail stays on home branch stack', (tester) async {
    late StatefulNavigationShell shell;

    final router = GoRouter(
      initialLocation: '/home',
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
                  routes: [
                    GoRoute(
                      path: 'album/:id',
                      builder: (context, state) =>
                          Text('home-album-${state.pathParameters['id']}'),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/library',
                  builder: (context, state) => const Text('library-root'),
                  routes: [
                    GoRoute(
                      path: 'album/:id',
                      builder: (context, state) =>
                          Text('library-album-${state.pathParameters['id']}'),
                    ),
                  ],
                ),
                GoRoute(
                  path: '/album/:id',
                  builder: (context, state) =>
                      Text('library-album-${state.pathParameters['id']}'),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.push('/home/album/42');
    await tester.pumpAndSettle();
    expect(find.text('home-album-42'), findsOneWidget);
    expect(shell.currentIndex, 0);

    shell.goBranch(1);
    await tester.pumpAndSettle();
    expect(shell.currentIndex, 1);

    shell.goBranch(0);
    await tester.pumpAndSettle();
    expect(find.text('home-album-42'), findsOneWidget);
    expect(shell.currentIndex, 0);
  });
}
