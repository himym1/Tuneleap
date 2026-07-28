// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SEn extends S {
  SEn([String locale = 'en']) : super(locale);

  @override
  String get navHome => 'Home';

  @override
  String get navLibrary => 'Library';

  @override
  String get navSearch => 'Search';

  @override
  String get navPlaylists => 'Playlists';

  @override
  String get navSettings => 'Settings';

  @override
  String get navFavorites => 'Favorites';

  @override
  String get navDownloads => 'Downloads';

  @override
  String get navServers => 'Servers';

  @override
  String get navAudioQuality => 'Audio Quality';

  @override
  String get navScrobble => 'History';

  @override
  String get sidebarNav => 'NAV';

  @override
  String get sidebarMore => 'MORE';

  @override
  String get appName => 'Navidrome Player';

  @override
  String get appShortName => 'NP';

  @override
  String get loginSubtitle => 'Connect to your private music server';

  @override
  String get loginConnect => 'Connect';

  @override
  String get loginFieldsRequired => 'Please fill in all fields';

  @override
  String get loginFailed =>
      'Connection failed, please check server URL and credentials';

  @override
  String loginError(String error) {
    return 'Connection error: $error';
  }

  @override
  String get homeGreetingMorning => 'Good Morning ☀️';

  @override
  String get homeGreetingAfternoon => 'Good Afternoon 🌤';

  @override
  String get homeGreetingEvening => 'Good Evening 🌙';

  @override
  String get homePlayRandom => 'Shuffle Play';

  @override
  String get homeRecentAlbums => 'Recently Added';

  @override
  String get homeRandomAlbums => 'Discover';

  @override
  String get homeAlbums => 'Albums';

  @override
  String get homeSongs => 'Songs';

  @override
  String get homeArtists => 'Artists';

  @override
  String get libraryTabArtists => 'Artists';

  @override
  String get libraryTabAlbums => 'Albums';

  @override
  String get libraryTabSongs => 'Songs';

  @override
  String get libraryTitle => 'Library';

  @override
  String libraryAlbumCount(int count) {
    return '$count albums';
  }

  @override
  String get searchHint => 'Search songs, albums, artists…';

  @override
  String get searchNoResults => 'Try searching for your favorite music';

  @override
  String get searchResultArtists => 'Artists';

  @override
  String get searchResultAlbums => 'Albums';

  @override
  String get searchResultSongs => 'Songs';

  @override
  String get playerQueueTitle => 'Play Queue';

  @override
  String get playerLyrics => 'Lyrics';

  @override
  String get playerNoLyrics => 'No lyrics available';

  @override
  String get playerShowQueue => 'Show Queue';

  @override
  String get playerHideQueue => 'Hide Queue';

  @override
  String get playerSpeed => 'Playback Speed';

  @override
  String get playerNowPlaying => 'Now Playing';

  @override
  String get playerQueue => 'Queue';

  @override
  String get playerNext => 'Next';

  @override
  String get playerPrevious => 'Previous';

  @override
  String get playerPlayPause => 'Play / Pause';

  @override
  String get playerIdleTitle => 'Nothing playing';

  @override
  String get playerIdleSubtitle =>
      'Start playback from Home, Library, or Playlists';

  @override
  String get albumPlayAll => 'Play All';

  @override
  String get albumShufflePlay => 'Shuffle';

  @override
  String albumSongCount(int count) {
    return '$count songs';
  }

  @override
  String get artistPlayAll => 'Play All';

  @override
  String get artistAlbums => 'Albums';

  @override
  String artistAlbumCount(int count) {
    return '$count albums';
  }

  @override
  String get playlistsTitle => 'Playlists';

  @override
  String get playlistCreate => 'New Playlist';

  @override
  String get playlistRename => 'Rename';

  @override
  String get playlistDelete => 'Delete';

  @override
  String get playlistEdit => 'Edit';

  @override
  String get playlistSave => 'Save';

  @override
  String get playlistCancel => 'Cancel';

  @override
  String get playlistNameHint => 'Enter playlist name';

  @override
  String playlistSongCount(int count) {
    return '$count songs';
  }

  @override
  String get playlistEmpty => 'No playlists yet';

  @override
  String get playlistReorderHint => 'Long press to reorder, swipe to delete';

  @override
  String get favoritesTitle => 'Favorites';

  @override
  String get favoritesTabSongs => 'Songs';

  @override
  String get favoritesTabAlbums => 'Albums';

  @override
  String get favoritesTabArtists => 'Artists';

  @override
  String get favoritesEmpty => 'No favorites yet';

  @override
  String get downloadsTitle => 'Downloads';

  @override
  String get downloadsTotal => 'Total Tasks';

  @override
  String get downloadsCompleted => 'Completed';

  @override
  String get downloadsOfflineSongs => 'Offline Songs';

  @override
  String get downloadsEmpty => 'No downloads yet';

  @override
  String get downloadsClearCompleted => 'Clear Completed';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsServer => 'Server';

  @override
  String get settingsCurrentServer => 'Current Server';

  @override
  String get settingsLogout => 'Log Out';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeStyle => 'Theme style';

  @override
  String get settingsThemeClassic => 'Classic';

  @override
  String get settingsThemeAmoled => 'AMOLED';

  @override
  String get settingsThemeDynamic => 'Artwork';

  @override
  String get settingsAudioQuality => 'Audio Quality';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsVersion => 'Version';

  @override
  String get audioQualityTitle => 'Audio Quality';

  @override
  String get audioQualityOriginal => 'Original (Lossless)';

  @override
  String get audioQualityHigh => 'High Quality';

  @override
  String get audioQualityMedium => 'Medium Quality';

  @override
  String get audioQualityLow => 'Low Quality';

  @override
  String audioQualityKbps(int kbps) {
    return '$kbps kbps';
  }

  @override
  String audioQualityMp3Label(int kbps) {
    return 'MP3 ${kbps}k';
  }

  @override
  String get scrobbleTitle => 'Play History';

  @override
  String get scrobbleEmpty => 'No play history yet';

  @override
  String scrobblePlayCount(int count) {
    return 'Played $count times';
  }

  @override
  String get scrobbleSubtitle =>
      'Track your music taste · Auto scrobble to server';

  @override
  String get scrobbleSessionPlays => 'Session Plays';

  @override
  String get scrobbleUniqueArtists => 'Unique Artists';

  @override
  String get scrobbleUniqueAlbums => 'Unique Albums';

  @override
  String get scrobbleAutoDesc => 'Auto-scrobble after 50% or 4 min playback';

  @override
  String get scrobbleEnabled => 'Enabled';

  @override
  String get scrobbleRecentTitle => 'Recent Plays';

  @override
  String scrobbleRecentCount(int count) {
    return '$count tracks total';
  }

  @override
  String get scrobbleEmptyHint =>
      'No play history yet\nStart playing music to see it here';

  @override
  String get multiServerTitle => 'Server Management';

  @override
  String get multiServerAdd => 'Add Server';

  @override
  String get multiServerCurrent => 'Current';

  @override
  String get multiServerSwitch => 'Switch';

  @override
  String get multiServerDelete => 'Delete';

  @override
  String get multiServerEmpty => 'No additional servers';

  @override
  String get contextMenuPlay => 'Play';

  @override
  String get contextMenuPlayNext => 'Play Next';

  @override
  String get contextMenuAddQueue => 'Add to Queue';

  @override
  String get contextMenuAddPlaylist => 'Add to Playlist';

  @override
  String get contextMenuStar => 'Favorite';

  @override
  String get contextMenuDownload => 'Download';

  @override
  String get contextMenuImportNavidrome => 'Import to Navidrome';

  @override
  String get contextMenuAddedNext => 'Added to play next';

  @override
  String get contextMenuAddedQueue => 'Added to queue';

  @override
  String get contextMenuStarred => 'Added to favorites';

  @override
  String get contextMenuDownloading => 'Added to download queue';

  @override
  String get contextMenuImportingNavidrome => 'Importing to Navidrome...';

  @override
  String get contextMenuImportedNavidrome =>
      'Imported to Navidrome and scan triggered';

  @override
  String get contextMenuImportedNavidromePendingScan =>
      'Imported to Navidrome, waiting for auto scan';

  @override
  String get contextMenuImportNavidromeFailed =>
      'Failed to import to Navidrome';

  @override
  String get importDuplicateTitle => 'Song Already Exists';

  @override
  String importDuplicateMessage(String title, String artist) {
    return '\"$title\" by $artist already exists in your library. Import anyway?';
  }

  @override
  String get commonContinue => 'Continue';

  @override
  String get contextMenuQueueingNavidrome =>
      'Submitting to NAS download queue...';

  @override
  String get contextMenuQueuedNavidrome => 'Submitted to NAS download queue';

  @override
  String contextMenuAddedPlaylist(String name) {
    return 'Added to $name';
  }

  @override
  String get contextMenuSelectPlaylist => 'Select Playlist';

  @override
  String get contextMenuLoadFailed => 'Failed to load playlists';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonConfirm => 'OK';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonError => 'Error';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonRefresh => 'Refresh data';

  @override
  String get commonNoData => 'No data';

  @override
  String commonSongs(int count) {
    return '$count songs';
  }

  @override
  String commonSizeKb(String value) {
    return '$value KB';
  }

  @override
  String commonSizeMb(String value) {
    return '$value MB';
  }

  @override
  String commonSizeGb(String value) {
    return '$value GB';
  }

  @override
  String commonPercent(int value) {
    return '$value%';
  }

  @override
  String get commonAll => 'All';

  @override
  String get commonBack => 'Back';

  @override
  String get commonLoadFailed => 'Failed to load';

  @override
  String get commonUnknownArtist => 'Unknown Artist';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonNew => 'New';

  @override
  String get playerQueueEmpty => 'Queue is empty';

  @override
  String get playerNoContent => 'Nothing playing';

  @override
  String get playerNoContentHint =>
      'Select a song from library or search to start playing';

  @override
  String playerSpeedValue(double speed) {
    return '${speed}x';
  }

  @override
  String get playerUnfavorite => 'Remove from favorites';

  @override
  String get albumAddToQueue => 'Add to Queue';

  @override
  String get albumFavorite => 'Favorite Album';

  @override
  String get albumUnfavorite => 'Unfavorite';

  @override
  String get albumTitle => 'Title';

  @override
  String get albumDuration => 'Duration';

  @override
  String albumSongDuration(String year, int count, String duration) {
    return '$year · $count songs · $duration';
  }

  @override
  String get artistUnfavorited => 'Removed from favorites';

  @override
  String get downloadsUsedSpace => 'Used Space';

  @override
  String get downloadsQueue => 'Download Queue';

  @override
  String get downloadsHint => 'Select \"Download\" from song menu';

  @override
  String get downloadsPending => 'Pending';

  @override
  String get downloadsFailed => 'Failed';

  @override
  String get multiServerManage => 'Server Management';

  @override
  String multiServerCount(int count) {
    return '$count servers';
  }

  @override
  String get multiServerDeleteTitle => 'Delete Server';

  @override
  String multiServerDeleteConfirm(String name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get multiServerEdit => 'Edit Server';

  @override
  String get multiServerName => 'Server Name';

  @override
  String get multiServerNameHint => 'My Navidrome';

  @override
  String get multiServerUrl => 'Server URL';

  @override
  String get multiServerUsername => 'Username';

  @override
  String get multiServerPassword => 'Password';

  @override
  String get backendUrl => 'Online backend URL';

  @override
  String get backendUrlHint =>
      'Optional; defaults to the Navidrome host on port 8503';

  @override
  String get backendApiKey => 'Online backend API key';

  @override
  String get backendApiKeyHint =>
      'Stored separately from the Navidrome password';

  @override
  String get serverUrlExample => 'https://music.example.com';

  @override
  String get multiServerEmptyHint =>
      'No servers yet\nTap the button above to add one';

  @override
  String get searchAll => 'All';

  @override
  String get searchHintInput => 'Search songs, artists, albums...';

  @override
  String get searchPlaceholder => 'Enter keywords to search music';

  @override
  String get searchNoResult => 'No results found';

  @override
  String get searchResults => 'Search Results';

  @override
  String get libraryNoArtists => 'No artists';

  @override
  String get libraryNoAlbums => 'No albums';

  @override
  String get libraryNoSongs => 'No songs';

  @override
  String get audioQualityOriginalName => 'Original';

  @override
  String get audioQualityOriginalDesc => 'No transcoding';

  @override
  String get audioQualityMp3128Desc => 'Save bandwidth';

  @override
  String get audioQualitySelection => 'Quality Selection';

  @override
  String get playlistNameLabel => 'Playlist Name';

  @override
  String playlistCreated(String name) {
    return 'Created playlist \"$name\"';
  }

  @override
  String get playlistCreateFailed => 'Failed to create';

  @override
  String get playlistDeleteTitle => 'Delete Playlist';

  @override
  String playlistDeleteConfirm(String name) {
    return 'Are you sure you want to delete \"$name\"? This cannot be undone.';
  }

  @override
  String playlistDeleted(String name) {
    return 'Deleted \"$name\"';
  }

  @override
  String get playlistDeleteFailed => 'Failed to delete';

  @override
  String playlistCount(int count) {
    return '$count playlists';
  }

  @override
  String get playlistCreatedList => 'Created Lists';

  @override
  String get playlistEmptyTitle => 'No playlists yet';

  @override
  String get playlistEmptyHint => 'Create a playlist to organize your music';

  @override
  String playlistSongCountLabel(int count) {
    return '$count songs';
  }

  @override
  String get playlistPlay => 'Play';

  @override
  String get playlistListEmpty => 'Playlist is empty';

  @override
  String get playlistRenameTitle => 'Rename Playlist';

  @override
  String get playlistNewName => 'New Name';

  @override
  String songContextAddedToPlaylist(String name) {
    return 'Added to $name';
  }

  @override
  String get defaultServerName => 'My Server';

  @override
  String get navSongs => 'Songs';

  @override
  String get navAlbums => 'Albums';

  @override
  String get navArtists => 'Artists';

  @override
  String get navAlbumArtists => 'Album Artists';

  @override
  String get navGenres => 'Genres';

  @override
  String get navRadio => 'Radio';

  @override
  String get sidebarLibrary => 'LIBRARY';

  @override
  String get homeNewestAlbums => 'Latest Albums';

  @override
  String get homeDailyRecommend => 'For You';

  @override
  String get homeRecentlyPlayed => 'Recently Played';

  @override
  String get homeViewMore => 'More';

  @override
  String get libraryGenresTitle => 'Genres';

  @override
  String get libraryRadioTitle => 'Radio Stations';

  @override
  String get libraryRadioEmpty => 'No radio stations';

  @override
  String get libraryNoGenres => 'No genres';

  @override
  String get libraryAlbumArtistsTitle => 'Album Artists';

  @override
  String genreSongCount(int count) {
    return '$count songs';
  }

  @override
  String genreAlbumCount(int count) {
    return '$count albums';
  }

  @override
  String get contextMenuDelete => 'Delete Song';

  @override
  String contextMenuDeleteConfirm(String title, String artist) {
    return 'Delete \"$title\" ($artist) from server?\nThis cannot be undone.';
  }

  @override
  String get contextMenuDeleteSuccess => 'Deleted successfully';

  @override
  String get contextMenuDeleteError => 'Failed to delete';

  @override
  String get settingsUnlimited => 'Unlimited';

  @override
  String get settingsUser => 'User';

  @override
  String get settingsQuality => 'Quality';

  @override
  String get settingsMaxBitrate => 'Max bitrate';

  @override
  String settingsAboutText(String appName, String version) {
    return '$appName v$version\nCross-platform music client';
  }

  @override
  String get settingsLogoutConfirm => 'Are you sure you want to log out?';

  @override
  String get settingsCacheCalculating => 'Calculating...';

  @override
  String get settingsCacheUnknown => 'Unknown';

  @override
  String get settingsCacheCleared => 'Cache cleared';

  @override
  String get settingsCacheClearFailed => 'Clear failed';

  @override
  String get settingsCacheStorage => 'Cache & Storage';

  @override
  String get settingsCacheUsed => 'Used';

  @override
  String get settingsCacheMaxCache => 'Max cache';

  @override
  String get settingsCacheClear => 'Clear';

  @override
  String get searchBackendNavidrome => 'Navidrome';

  @override
  String get searchBackendNetease => 'Netease';

  @override
  String get searchBackendKuwo => 'Kuwo';

  @override
  String get searchBackendJoox => 'JOOX';

  @override
  String get searchFilterOnline => 'Online';

  @override
  String get searchSectionLocal => 'Local Results';

  @override
  String get searchSectionOnline => 'Online Results';

  @override
  String get playerShuffle => 'Shuffle';

  @override
  String get playerRepeat => 'Repeat';

  @override
  String get tooltipUnfavorite => 'Remove from favorites';

  @override
  String get tooltipPlay => 'Play';

  @override
  String get tooltipFavorite => 'Favorite';

  @override
  String get tooltipRemove => 'Remove';

  @override
  String get tooltipEdit => 'Edit';

  @override
  String get tooltipDelete => 'Delete';

  @override
  String get tooltipClear => 'Clear';

  @override
  String get tooltipBack => 'Back';

  @override
  String get tooltipMore => 'More';

  @override
  String get updateCheckUpdate => 'Check for Updates';

  @override
  String get updateChecking => 'Checking...';

  @override
  String updateNewVersion(String version) {
    return 'New version v$version available';
  }

  @override
  String get updateChangelog => 'Changelog';

  @override
  String get updateDownload => 'Download Update';

  @override
  String get updateInstall => 'Install Update';

  @override
  String get updateInstalling => 'Opening installer...';

  @override
  String get updateAlreadyDownloaded =>
      'Package already downloaded. You can install now without downloading again.';

  @override
  String get updateLatest => 'You\'re up to date';

  @override
  String get updateFailed => 'Update check failed, please try again';

  @override
  String get updateMacInstallHint =>
      'The DMG is open. Drag YinYue to Applications to finish updating.';

  @override
  String get contextMenuDeleteTitle => 'Confirm Delete';

  @override
  String get contextMenuDeleted => 'Deleted';

  @override
  String get contextMenuDeleteFailed => 'Delete failed, please try again';

  @override
  String get recommendationsTitle => 'Recommendations';

  @override
  String get recommendationsEmpty => 'No recommendations yet';

  @override
  String get recommendationsBackendMissing =>
      'Configure the backend to enable recommendations';

  @override
  String get recommendationsRetry => 'Retry';

  @override
  String get recommendationsDislike => 'Dislike';

  @override
  String get recommendationsImport => 'Import';

  @override
  String get recommendationsViewAll => 'View all';

  @override
  String get recommendationsSubtitle =>
      'Based on your recent listening and feedback';

  @override
  String get recommendationsModeAi => 'AI recommendations';

  @override
  String get recommendationsModeFallback => 'Rule-based recommendations';

  @override
  String get recommendationsSimilar => 'Similar';

  @override
  String get recommendationsExplore => 'Explore';

  @override
  String get recommendationsRefreshed => 'Recommendations updated';

  @override
  String get recommendationsRefreshing => 'Refreshing recommendations';

  @override
  String get settingsResetRecommendations => 'Reset recommendation preferences';

  @override
  String get settingsResetRecommendationsConfirm =>
      'Reset recommendation preferences? Songs, downloads, play history, and server settings are not affected.';

  @override
  String get settingsResetRecommendationsDone =>
      'Recommendation preferences reset';
}
