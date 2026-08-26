import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

const playerPath = '/player';

bool _opening = false;

/// True when `/player` is already on the root stack (Android singleTop).
bool isPlayerRouteOnStack(GoRouter router) {
  if (router.state.uri.path == playerPath) return true;
  for (final match in router.routerDelegate.currentConfiguration.matches) {
    if (match.matchedLocation == playerPath) return true;
  }
  return false;
}

/// Opens the player page at most once. Extra taps reuse the existing route.
void openPlayer(BuildContext context) {
  if (_opening || !context.mounted) return;
  final router = GoRouter.maybeOf(context);
  if (router == null || isPlayerRouteOnStack(router)) return;
  _opening = true;
  try {
    router.push(playerPath);
  } catch (_) {
    _opening = false;
    rethrow;
  }
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _opening = false;
  });
}

@visibleForTesting
void debugResetPlayerNavigation() {
  _opening = false;
}
