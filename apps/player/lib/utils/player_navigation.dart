import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

const playerPath = '/player';

bool _opening = false;

bool _isPlayerPath(String path) =>
    path == playerPath || path.startsWith('$playerPath/');

/// True when `/player` is already on the root stack (Android singleTop).
bool isPlayerRouteOnStack(GoRouter router) {
  if (_isPlayerPath(router.state.uri.path)) return true;
  for (final match in router.routerDelegate.currentConfiguration.matches) {
    if (_isPlayerPath(match.matchedLocation)) return true;
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

String playerArtistPath(String artistId) =>
    '$playerPath/artist/${Uri.encodeComponent(artistId)}';

String playerAlbumPath(String albumId) =>
    '$playerPath/album/${Uri.encodeComponent(albumId)}';

/// Opens artist/album from the full player. Library IDs stay on the player
/// stack so back returns to the player instead of the library tab.
void openLibraryItemFromPlayer(
  BuildContext context, {
  required bool artist,
  required String id,
  required String label,
  required bool isOnline,
}) {
  if (id.isNotEmpty && !isOnline) {
    context.push(artist ? playerArtistPath(id) : playerAlbumPath(id));
    return;
  }
  if (label.isEmpty) return;
  if (context.canPop()) context.pop();
  context.go('/search?q=${Uri.encodeComponent(label)}');
}

@visibleForTesting
void debugResetPlayerNavigation() {
  _opening = false;
}
