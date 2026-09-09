const kHomeBranch = 0;
const kLibraryBranch = 1;
const kSearchBranch = 2;
const kSettingsBranch = 3;
const kPlaylistsBranch = 4;

String _pathWithoutQuery(String path) => path.split('?').first;

int? shellBranchIndexForPath(String path) {
  final uri = _pathWithoutQuery(path);
  if (uri == '/recommendations' || uri == '/home' || uri.startsWith('/home/')) {
    return kHomeBranch;
  }
  if (uri == '/playlists' ||
      uri.startsWith('/library/playlists') ||
      uri.startsWith('/playlist/')) {
    return kPlaylistsBranch;
  }
  if (uri.startsWith('/library') ||
      uri.startsWith('/album/') ||
      uri.startsWith('/artist/')) {
    return kLibraryBranch;
  }
  if (uri == '/search' || uri.startsWith('/search/')) return kSearchBranch;
  if (uri == '/settings' ||
      uri == '/downloads' ||
      uri == '/servers' ||
      uri == '/scrobble' ||
      uri == '/favorites' ||
      uri == '/audio-quality' ||
      uri == '/library-audit' ||
      uri == '/library-styles' ||
      uri == '/library-playlists') {
    return kSettingsBranch;
  }
  return null;
}

/// Bottom/sidebar destinations that restore a branch instead of replacing
/// sibling routes inside the library stack.
bool isShellTabRoot(String path) {
  return path == '/home' ||
      path == '/library' ||
      path == '/library/songs' ||
      path == '/search' ||
      path == '/settings' ||
      path == '/library/playlists';
}
