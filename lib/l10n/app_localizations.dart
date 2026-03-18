import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S of(BuildContext context) {
    return Localizations.of<S>(context, S)!;
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @navHome.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get navHome;

  /// No description provided for @navLibrary.
  ///
  /// In zh, this message translates to:
  /// **'音乐库'**
  String get navLibrary;

  /// No description provided for @navSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get navSearch;

  /// No description provided for @navPlaylists.
  ///
  /// In zh, this message translates to:
  /// **'播放列表'**
  String get navPlaylists;

  /// No description provided for @navSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get navSettings;

  /// No description provided for @navFavorites.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get navFavorites;

  /// No description provided for @navDownloads.
  ///
  /// In zh, this message translates to:
  /// **'下载管理'**
  String get navDownloads;

  /// No description provided for @navServers.
  ///
  /// In zh, this message translates to:
  /// **'多服务器'**
  String get navServers;

  /// No description provided for @navAudioQuality.
  ///
  /// In zh, this message translates to:
  /// **'音质/均衡'**
  String get navAudioQuality;

  /// No description provided for @navScrobble.
  ///
  /// In zh, this message translates to:
  /// **'播放记录'**
  String get navScrobble;

  /// No description provided for @sidebarNav.
  ///
  /// In zh, this message translates to:
  /// **'导航'**
  String get sidebarNav;

  /// No description provided for @sidebarMore.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get sidebarMore;

  /// No description provided for @appName.
  ///
  /// In zh, this message translates to:
  /// **'音跃'**
  String get appName;

  /// No description provided for @appShortName.
  ///
  /// In zh, this message translates to:
  /// **'音跃'**
  String get appShortName;

  /// No description provided for @loginSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'连接你的私人音乐服务器'**
  String get loginSubtitle;

  /// No description provided for @loginConnect.
  ///
  /// In zh, this message translates to:
  /// **'连接'**
  String get loginConnect;

  /// No description provided for @loginFieldsRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写所有字段'**
  String get loginFieldsRequired;

  /// No description provided for @loginFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接失败，请检查服务器地址和凭据'**
  String get loginFailed;

  /// No description provided for @loginError.
  ///
  /// In zh, this message translates to:
  /// **'连接错误: {error}'**
  String loginError(String error);

  /// No description provided for @homeGreetingMorning.
  ///
  /// In zh, this message translates to:
  /// **'早上好 ☀️'**
  String get homeGreetingMorning;

  /// No description provided for @homeGreetingAfternoon.
  ///
  /// In zh, this message translates to:
  /// **'下午好 🌤'**
  String get homeGreetingAfternoon;

  /// No description provided for @homeGreetingEvening.
  ///
  /// In zh, this message translates to:
  /// **'晚上好 🌙'**
  String get homeGreetingEvening;

  /// No description provided for @homePlayRandom.
  ///
  /// In zh, this message translates to:
  /// **'随机播放'**
  String get homePlayRandom;

  /// No description provided for @homeRecentAlbums.
  ///
  /// In zh, this message translates to:
  /// **'最近添加'**
  String get homeRecentAlbums;

  /// No description provided for @homeRandomAlbums.
  ///
  /// In zh, this message translates to:
  /// **'随机推荐'**
  String get homeRandomAlbums;

  /// No description provided for @homeAlbums.
  ///
  /// In zh, this message translates to:
  /// **'专辑'**
  String get homeAlbums;

  /// No description provided for @homeSongs.
  ///
  /// In zh, this message translates to:
  /// **'歌曲'**
  String get homeSongs;

  /// No description provided for @homeArtists.
  ///
  /// In zh, this message translates to:
  /// **'艺术家'**
  String get homeArtists;

  /// No description provided for @libraryTabArtists.
  ///
  /// In zh, this message translates to:
  /// **'艺术家'**
  String get libraryTabArtists;

  /// No description provided for @libraryTabAlbums.
  ///
  /// In zh, this message translates to:
  /// **'专辑'**
  String get libraryTabAlbums;

  /// No description provided for @libraryTabSongs.
  ///
  /// In zh, this message translates to:
  /// **'歌曲'**
  String get libraryTabSongs;

  /// No description provided for @libraryTitle.
  ///
  /// In zh, this message translates to:
  /// **'音乐库'**
  String get libraryTitle;

  /// No description provided for @libraryAlbumCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 张专辑'**
  String libraryAlbumCount(int count);

  /// No description provided for @searchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索歌曲、专辑、艺术家…'**
  String get searchHint;

  /// No description provided for @searchNoResults.
  ///
  /// In zh, this message translates to:
  /// **'试试搜索你喜欢的音乐'**
  String get searchNoResults;

  /// No description provided for @searchResultArtists.
  ///
  /// In zh, this message translates to:
  /// **'艺术家'**
  String get searchResultArtists;

  /// No description provided for @searchResultAlbums.
  ///
  /// In zh, this message translates to:
  /// **'专辑'**
  String get searchResultAlbums;

  /// No description provided for @searchResultSongs.
  ///
  /// In zh, this message translates to:
  /// **'歌曲'**
  String get searchResultSongs;

  /// No description provided for @playerQueueTitle.
  ///
  /// In zh, this message translates to:
  /// **'播放队列'**
  String get playerQueueTitle;

  /// No description provided for @playerLyrics.
  ///
  /// In zh, this message translates to:
  /// **'歌词'**
  String get playerLyrics;

  /// No description provided for @playerNoLyrics.
  ///
  /// In zh, this message translates to:
  /// **'暂无歌词'**
  String get playerNoLyrics;

  /// No description provided for @playerShowQueue.
  ///
  /// In zh, this message translates to:
  /// **'显示队列'**
  String get playerShowQueue;

  /// No description provided for @playerHideQueue.
  ///
  /// In zh, this message translates to:
  /// **'隐藏队列'**
  String get playerHideQueue;

  /// No description provided for @playerSpeed.
  ///
  /// In zh, this message translates to:
  /// **'播放速度'**
  String get playerSpeed;

  /// No description provided for @playerNowPlaying.
  ///
  /// In zh, this message translates to:
  /// **'正在播放'**
  String get playerNowPlaying;

  /// No description provided for @playerQueue.
  ///
  /// In zh, this message translates to:
  /// **'队列'**
  String get playerQueue;

  /// No description provided for @playerNext.
  ///
  /// In zh, this message translates to:
  /// **'下一首'**
  String get playerNext;

  /// No description provided for @playerPrevious.
  ///
  /// In zh, this message translates to:
  /// **'上一首'**
  String get playerPrevious;

  /// No description provided for @playerPlayPause.
  ///
  /// In zh, this message translates to:
  /// **'播放 / 暂停'**
  String get playerPlayPause;

  /// No description provided for @playerIdleTitle.
  ///
  /// In zh, this message translates to:
  /// **'未在播放'**
  String get playerIdleTitle;

  /// No description provided for @playerIdleSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'从首页、音乐库或播放列表开始播放'**
  String get playerIdleSubtitle;

  /// No description provided for @albumPlayAll.
  ///
  /// In zh, this message translates to:
  /// **'播放全部'**
  String get albumPlayAll;

  /// No description provided for @albumShufflePlay.
  ///
  /// In zh, this message translates to:
  /// **'随机播放'**
  String get albumShufflePlay;

  /// No description provided for @albumSongCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 首歌曲'**
  String albumSongCount(int count);

  /// No description provided for @artistPlayAll.
  ///
  /// In zh, this message translates to:
  /// **'播放全部'**
  String get artistPlayAll;

  /// No description provided for @artistAlbums.
  ///
  /// In zh, this message translates to:
  /// **'专辑'**
  String get artistAlbums;

  /// No description provided for @artistAlbumCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 张专辑'**
  String artistAlbumCount(int count);

  /// No description provided for @playlistsTitle.
  ///
  /// In zh, this message translates to:
  /// **'播放列表'**
  String get playlistsTitle;

  /// No description provided for @playlistCreate.
  ///
  /// In zh, this message translates to:
  /// **'新建播放列表'**
  String get playlistCreate;

  /// No description provided for @playlistRename.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get playlistRename;

  /// No description provided for @playlistDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get playlistDelete;

  /// No description provided for @playlistEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get playlistEdit;

  /// No description provided for @playlistSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get playlistSave;

  /// No description provided for @playlistCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get playlistCancel;

  /// No description provided for @playlistNameHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入播放列表名称'**
  String get playlistNameHint;

  /// No description provided for @playlistSongCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 首'**
  String playlistSongCount(int count);

  /// No description provided for @playlistEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无播放列表'**
  String get playlistEmpty;

  /// No description provided for @playlistReorderHint.
  ///
  /// In zh, this message translates to:
  /// **'长按拖拽排序，左滑可删除'**
  String get playlistReorderHint;

  /// No description provided for @favoritesTitle.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get favoritesTitle;

  /// No description provided for @favoritesTabSongs.
  ///
  /// In zh, this message translates to:
  /// **'歌曲'**
  String get favoritesTabSongs;

  /// No description provided for @favoritesTabAlbums.
  ///
  /// In zh, this message translates to:
  /// **'专辑'**
  String get favoritesTabAlbums;

  /// No description provided for @favoritesTabArtists.
  ///
  /// In zh, this message translates to:
  /// **'艺术家'**
  String get favoritesTabArtists;

  /// No description provided for @favoritesEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无收藏'**
  String get favoritesEmpty;

  /// No description provided for @downloadsTitle.
  ///
  /// In zh, this message translates to:
  /// **'下载管理'**
  String get downloadsTitle;

  /// No description provided for @downloadsTotal.
  ///
  /// In zh, this message translates to:
  /// **'全部任务'**
  String get downloadsTotal;

  /// No description provided for @downloadsCompleted.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get downloadsCompleted;

  /// No description provided for @downloadsOfflineSongs.
  ///
  /// In zh, this message translates to:
  /// **'离线歌曲'**
  String get downloadsOfflineSongs;

  /// No description provided for @downloadsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无下载任务'**
  String get downloadsEmpty;

  /// No description provided for @downloadsClearCompleted.
  ///
  /// In zh, this message translates to:
  /// **'清除已完成'**
  String get downloadsClearCompleted;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// No description provided for @settingsServer.
  ///
  /// In zh, this message translates to:
  /// **'服务器'**
  String get settingsServer;

  /// No description provided for @settingsCurrentServer.
  ///
  /// In zh, this message translates to:
  /// **'当前服务器'**
  String get settingsCurrentServer;

  /// No description provided for @settingsLogout.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get settingsLogout;

  /// No description provided for @settingsTheme.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get settingsThemeLight;

  /// No description provided for @settingsAudioQuality.
  ///
  /// In zh, this message translates to:
  /// **'音质设置'**
  String get settingsAudioQuality;

  /// No description provided for @settingsAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get settingsAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get settingsVersion;

  /// No description provided for @audioQualityTitle.
  ///
  /// In zh, this message translates to:
  /// **'音质设置'**
  String get audioQualityTitle;

  /// No description provided for @audioQualityOriginal.
  ///
  /// In zh, this message translates to:
  /// **'原始品质（无损）'**
  String get audioQualityOriginal;

  /// No description provided for @audioQualityHigh.
  ///
  /// In zh, this message translates to:
  /// **'高品质'**
  String get audioQualityHigh;

  /// No description provided for @audioQualityMedium.
  ///
  /// In zh, this message translates to:
  /// **'中等品质'**
  String get audioQualityMedium;

  /// No description provided for @audioQualityLow.
  ///
  /// In zh, this message translates to:
  /// **'低品质'**
  String get audioQualityLow;

  /// No description provided for @audioQualityKbps.
  ///
  /// In zh, this message translates to:
  /// **'{kbps} kbps'**
  String audioQualityKbps(int kbps);

  /// No description provided for @audioQualityMp3Label.
  ///
  /// In zh, this message translates to:
  /// **'MP3 {kbps}k'**
  String audioQualityMp3Label(int kbps);

  /// No description provided for @scrobbleTitle.
  ///
  /// In zh, this message translates to:
  /// **'播放记录'**
  String get scrobbleTitle;

  /// No description provided for @scrobbleEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无播放记录'**
  String get scrobbleEmpty;

  /// No description provided for @scrobblePlayCount.
  ///
  /// In zh, this message translates to:
  /// **'播放 {count} 次'**
  String scrobblePlayCount(int count);

  /// No description provided for @scrobbleSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'记录你的音乐喜好 · 自动 Scrobble 到服务器'**
  String get scrobbleSubtitle;

  /// No description provided for @scrobbleSessionPlays.
  ///
  /// In zh, this message translates to:
  /// **'本次播放'**
  String get scrobbleSessionPlays;

  /// No description provided for @scrobbleUniqueArtists.
  ///
  /// In zh, this message translates to:
  /// **'不同艺术家'**
  String get scrobbleUniqueArtists;

  /// No description provided for @scrobbleUniqueAlbums.
  ///
  /// In zh, this message translates to:
  /// **'不同专辑'**
  String get scrobbleUniqueAlbums;

  /// No description provided for @scrobbleAutoDesc.
  ///
  /// In zh, this message translates to:
  /// **'播放超过 50% 或 4 分钟自动记录'**
  String get scrobbleAutoDesc;

  /// No description provided for @scrobbleEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已启用'**
  String get scrobbleEnabled;

  /// No description provided for @scrobbleRecentTitle.
  ///
  /// In zh, this message translates to:
  /// **'最近播放'**
  String get scrobbleRecentTitle;

  /// No description provided for @scrobbleRecentCount.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 首'**
  String scrobbleRecentCount(int count);

  /// No description provided for @scrobbleEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'暂无播放记录\n开始播放音乐后将在这里记录'**
  String get scrobbleEmptyHint;

  /// No description provided for @multiServerTitle.
  ///
  /// In zh, this message translates to:
  /// **'多服务器管理'**
  String get multiServerTitle;

  /// No description provided for @multiServerAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加服务器'**
  String get multiServerAdd;

  /// No description provided for @multiServerCurrent.
  ///
  /// In zh, this message translates to:
  /// **'当前'**
  String get multiServerCurrent;

  /// No description provided for @multiServerSwitch.
  ///
  /// In zh, this message translates to:
  /// **'切换'**
  String get multiServerSwitch;

  /// No description provided for @multiServerDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get multiServerDelete;

  /// No description provided for @multiServerEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无额外服务器'**
  String get multiServerEmpty;

  /// No description provided for @contextMenuPlay.
  ///
  /// In zh, this message translates to:
  /// **'播放'**
  String get contextMenuPlay;

  /// No description provided for @contextMenuPlayNext.
  ///
  /// In zh, this message translates to:
  /// **'播放下一首'**
  String get contextMenuPlayNext;

  /// No description provided for @contextMenuAddQueue.
  ///
  /// In zh, this message translates to:
  /// **'添加到队列'**
  String get contextMenuAddQueue;

  /// No description provided for @contextMenuAddPlaylist.
  ///
  /// In zh, this message translates to:
  /// **'添加到播放列表'**
  String get contextMenuAddPlaylist;

  /// No description provided for @contextMenuStar.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get contextMenuStar;

  /// No description provided for @contextMenuDownload.
  ///
  /// In zh, this message translates to:
  /// **'下载到本地'**
  String get contextMenuDownload;

  /// No description provided for @contextMenuImportNavidrome.
  ///
  /// In zh, this message translates to:
  /// **'导入到 Navidrome'**
  String get contextMenuImportNavidrome;

  /// No description provided for @contextMenuAddedNext.
  ///
  /// In zh, this message translates to:
  /// **'已添加到下一首播放'**
  String get contextMenuAddedNext;

  /// No description provided for @contextMenuAddedQueue.
  ///
  /// In zh, this message translates to:
  /// **'已添加到队列'**
  String get contextMenuAddedQueue;

  /// No description provided for @contextMenuStarred.
  ///
  /// In zh, this message translates to:
  /// **'已收藏'**
  String get contextMenuStarred;

  /// No description provided for @contextMenuDownloading.
  ///
  /// In zh, this message translates to:
  /// **'已加入下载队列'**
  String get contextMenuDownloading;

  /// No description provided for @contextMenuImportingNavidrome.
  ///
  /// In zh, this message translates to:
  /// **'正在导入到 Navidrome…'**
  String get contextMenuImportingNavidrome;

  /// No description provided for @contextMenuImportedNavidrome.
  ///
  /// In zh, this message translates to:
  /// **'已导入到 Navidrome 并触发扫描'**
  String get contextMenuImportedNavidrome;

  /// No description provided for @contextMenuImportedNavidromePendingScan.
  ///
  /// In zh, this message translates to:
  /// **'已导入到 Navidrome，等待自动扫描'**
  String get contextMenuImportedNavidromePendingScan;

  /// No description provided for @contextMenuImportNavidromeFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入到 Navidrome 失败'**
  String get contextMenuImportNavidromeFailed;

  /// No description provided for @contextMenuQueueingNavidrome.
  ///
  /// In zh, this message translates to:
  /// **'正在提交到 NAS 下载队列…'**
  String get contextMenuQueueingNavidrome;

  /// No description provided for @contextMenuQueuedNavidrome.
  ///
  /// In zh, this message translates to:
  /// **'已提交到 NAS 下载队列'**
  String get contextMenuQueuedNavidrome;

  /// No description provided for @contextMenuAddedPlaylist.
  ///
  /// In zh, this message translates to:
  /// **'已添加到 {name}'**
  String contextMenuAddedPlaylist(String name);

  /// No description provided for @contextMenuSelectPlaylist.
  ///
  /// In zh, this message translates to:
  /// **'选择播放列表'**
  String get contextMenuSelectPlaylist;

  /// No description provided for @contextMenuLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载播放列表失败'**
  String get contextMenuLoadFailed;

  /// No description provided for @commonCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get commonDelete;

  /// No description provided for @commonConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get commonConfirm;

  /// No description provided for @commonLoading.
  ///
  /// In zh, this message translates to:
  /// **'加载中...'**
  String get commonLoading;

  /// No description provided for @commonError.
  ///
  /// In zh, this message translates to:
  /// **'出错了'**
  String get commonError;

  /// No description provided for @commonRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get commonRetry;

  /// No description provided for @commonRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新数据'**
  String get commonRefresh;

  /// No description provided for @commonNoData.
  ///
  /// In zh, this message translates to:
  /// **'暂无数据'**
  String get commonNoData;

  /// No description provided for @commonSongs.
  ///
  /// In zh, this message translates to:
  /// **'{count} 首'**
  String commonSongs(int count);

  /// No description provided for @commonSizeKb.
  ///
  /// In zh, this message translates to:
  /// **'{value} KB'**
  String commonSizeKb(String value);

  /// No description provided for @commonSizeMb.
  ///
  /// In zh, this message translates to:
  /// **'{value} MB'**
  String commonSizeMb(String value);

  /// No description provided for @commonSizeGb.
  ///
  /// In zh, this message translates to:
  /// **'{value} GB'**
  String commonSizeGb(String value);

  /// No description provided for @commonPercent.
  ///
  /// In zh, this message translates to:
  /// **'{value}%'**
  String commonPercent(int value);

  /// No description provided for @commonAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get commonAll;

  /// No description provided for @commonBack.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get commonBack;

  /// No description provided for @commonLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get commonLoadFailed;

  /// No description provided for @commonUnknownArtist.
  ///
  /// In zh, this message translates to:
  /// **'未知艺术家'**
  String get commonUnknownArtist;

  /// No description provided for @commonCreate.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get commonCreate;

  /// No description provided for @commonNew.
  ///
  /// In zh, this message translates to:
  /// **'新建'**
  String get commonNew;

  /// No description provided for @playerQueueEmpty.
  ///
  /// In zh, this message translates to:
  /// **'队列为空'**
  String get playerQueueEmpty;

  /// No description provided for @playerNoContent.
  ///
  /// In zh, this message translates to:
  /// **'暂无播放内容'**
  String get playerNoContent;

  /// No description provided for @playerNoContentHint.
  ///
  /// In zh, this message translates to:
  /// **'从音乐库或搜索中选择歌曲开始播放'**
  String get playerNoContentHint;

  /// No description provided for @playerSpeedValue.
  ///
  /// In zh, this message translates to:
  /// **'{speed}x'**
  String playerSpeedValue(double speed);

  /// No description provided for @playerUnfavorite.
  ///
  /// In zh, this message translates to:
  /// **'取消收藏'**
  String get playerUnfavorite;

  /// No description provided for @albumAddToQueue.
  ///
  /// In zh, this message translates to:
  /// **'加入队列'**
  String get albumAddToQueue;

  /// No description provided for @albumFavorite.
  ///
  /// In zh, this message translates to:
  /// **'收藏专辑'**
  String get albumFavorite;

  /// No description provided for @albumUnfavorite.
  ///
  /// In zh, this message translates to:
  /// **'取消收藏'**
  String get albumUnfavorite;

  /// No description provided for @albumTitle.
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get albumTitle;

  /// No description provided for @albumDuration.
  ///
  /// In zh, this message translates to:
  /// **'时长'**
  String get albumDuration;

  /// No description provided for @albumSongDuration.
  ///
  /// In zh, this message translates to:
  /// **'{year} · {count} 首歌曲 · {duration}'**
  String albumSongDuration(String year, int count, String duration);

  /// No description provided for @artistUnfavorited.
  ///
  /// In zh, this message translates to:
  /// **'已取消收藏'**
  String get artistUnfavorited;

  /// No description provided for @downloadsUsedSpace.
  ///
  /// In zh, this message translates to:
  /// **'已用空间'**
  String get downloadsUsedSpace;

  /// No description provided for @downloadsQueue.
  ///
  /// In zh, this message translates to:
  /// **'下载队列'**
  String get downloadsQueue;

  /// No description provided for @downloadsHint.
  ///
  /// In zh, this message translates to:
  /// **'在歌曲菜单中选择\"下载\"'**
  String get downloadsHint;

  /// No description provided for @downloadsPending.
  ///
  /// In zh, this message translates to:
  /// **'等待中'**
  String get downloadsPending;

  /// No description provided for @downloadsFailed.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get downloadsFailed;

  /// No description provided for @multiServerManage.
  ///
  /// In zh, this message translates to:
  /// **'服务器管理'**
  String get multiServerManage;

  /// No description provided for @multiServerCount.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 个服务器'**
  String multiServerCount(int count);

  /// No description provided for @multiServerDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除服务器'**
  String get multiServerDeleteTitle;

  /// No description provided for @multiServerDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除「{name}」吗？'**
  String multiServerDeleteConfirm(String name);

  /// No description provided for @multiServerEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑服务器'**
  String get multiServerEdit;

  /// No description provided for @multiServerName.
  ///
  /// In zh, this message translates to:
  /// **'服务器名称'**
  String get multiServerName;

  /// No description provided for @multiServerNameHint.
  ///
  /// In zh, this message translates to:
  /// **'我的 Navidrome'**
  String get multiServerNameHint;

  /// No description provided for @multiServerUrl.
  ///
  /// In zh, this message translates to:
  /// **'服务器地址'**
  String get multiServerUrl;

  /// No description provided for @multiServerUsername.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get multiServerUsername;

  /// No description provided for @multiServerPassword.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get multiServerPassword;

  /// No description provided for @serverUrlExample.
  ///
  /// In zh, this message translates to:
  /// **'https://music.example.com'**
  String get serverUrlExample;

  /// No description provided for @multiServerEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'暂无服务器\n点击上方按钮添加'**
  String get multiServerEmptyHint;

  /// No description provided for @searchAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get searchAll;

  /// No description provided for @searchHintInput.
  ///
  /// In zh, this message translates to:
  /// **'搜索歌曲、艺术家、专辑...'**
  String get searchHintInput;

  /// No description provided for @searchPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'输入关键词搜索音乐'**
  String get searchPlaceholder;

  /// No description provided for @searchNoResult.
  ///
  /// In zh, this message translates to:
  /// **'无搜索结果'**
  String get searchNoResult;

  /// No description provided for @searchResults.
  ///
  /// In zh, this message translates to:
  /// **'搜索结果'**
  String get searchResults;

  /// No description provided for @libraryNoArtists.
  ///
  /// In zh, this message translates to:
  /// **'暂无艺术家'**
  String get libraryNoArtists;

  /// No description provided for @libraryNoAlbums.
  ///
  /// In zh, this message translates to:
  /// **'暂无专辑'**
  String get libraryNoAlbums;

  /// No description provided for @libraryNoSongs.
  ///
  /// In zh, this message translates to:
  /// **'暂无歌曲'**
  String get libraryNoSongs;

  /// No description provided for @audioQualityOriginalName.
  ///
  /// In zh, this message translates to:
  /// **'原始音质'**
  String get audioQualityOriginalName;

  /// No description provided for @audioQualityOriginalDesc.
  ///
  /// In zh, this message translates to:
  /// **'无转码'**
  String get audioQualityOriginalDesc;

  /// No description provided for @audioQualityMp3128Desc.
  ///
  /// In zh, this message translates to:
  /// **'节省流量'**
  String get audioQualityMp3128Desc;

  /// No description provided for @audioQualitySelection.
  ///
  /// In zh, this message translates to:
  /// **'音质选择'**
  String get audioQualitySelection;

  /// No description provided for @playlistNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'播放列表名称'**
  String get playlistNameLabel;

  /// No description provided for @playlistCreated.
  ///
  /// In zh, this message translates to:
  /// **'已创建播放列表 \"{name}\"'**
  String playlistCreated(String name);

  /// No description provided for @playlistCreateFailed.
  ///
  /// In zh, this message translates to:
  /// **'创建失败'**
  String get playlistCreateFailed;

  /// No description provided for @playlistDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除播放列表'**
  String get playlistDeleteTitle;

  /// No description provided for @playlistDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除\"{name}\"吗？此操作不可撤销。'**
  String playlistDeleteConfirm(String name);

  /// No description provided for @playlistDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除\"{name}\"'**
  String playlistDeleted(String name);

  /// No description provided for @playlistDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除失败'**
  String get playlistDeleteFailed;

  /// No description provided for @playlistCount.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 个播放列表'**
  String playlistCount(int count);

  /// No description provided for @playlistCreatedList.
  ///
  /// In zh, this message translates to:
  /// **'已创建的列表'**
  String get playlistCreatedList;

  /// No description provided for @playlistEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有播放列表'**
  String get playlistEmptyTitle;

  /// No description provided for @playlistEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'创建一个播放列表来整理你的音乐'**
  String get playlistEmptyHint;

  /// No description provided for @playlistSongCountLabel.
  ///
  /// In zh, this message translates to:
  /// **'{count} 首歌曲'**
  String playlistSongCountLabel(int count);

  /// No description provided for @playlistPlay.
  ///
  /// In zh, this message translates to:
  /// **'播放'**
  String get playlistPlay;

  /// No description provided for @playlistListEmpty.
  ///
  /// In zh, this message translates to:
  /// **'播放列表为空'**
  String get playlistListEmpty;

  /// No description provided for @playlistRenameTitle.
  ///
  /// In zh, this message translates to:
  /// **'重命名播放列表'**
  String get playlistRenameTitle;

  /// No description provided for @playlistNewName.
  ///
  /// In zh, this message translates to:
  /// **'新名称'**
  String get playlistNewName;

  /// No description provided for @songContextAddedToPlaylist.
  ///
  /// In zh, this message translates to:
  /// **'已添加到 {name}'**
  String songContextAddedToPlaylist(String name);

  /// No description provided for @defaultServerName.
  ///
  /// In zh, this message translates to:
  /// **'我的服务器'**
  String get defaultServerName;

  /// No description provided for @navSongs.
  ///
  /// In zh, this message translates to:
  /// **'歌曲'**
  String get navSongs;

  /// No description provided for @navAlbums.
  ///
  /// In zh, this message translates to:
  /// **'专辑'**
  String get navAlbums;

  /// No description provided for @navArtists.
  ///
  /// In zh, this message translates to:
  /// **'歌手'**
  String get navArtists;

  /// No description provided for @navAlbumArtists.
  ///
  /// In zh, this message translates to:
  /// **'专辑艺术家'**
  String get navAlbumArtists;

  /// No description provided for @navGenres.
  ///
  /// In zh, this message translates to:
  /// **'流派'**
  String get navGenres;

  /// No description provided for @navRadio.
  ///
  /// In zh, this message translates to:
  /// **'电台'**
  String get navRadio;

  /// No description provided for @sidebarLibrary.
  ///
  /// In zh, this message translates to:
  /// **'音乐库'**
  String get sidebarLibrary;

  /// No description provided for @homeNewestAlbums.
  ///
  /// In zh, this message translates to:
  /// **'最新专辑'**
  String get homeNewestAlbums;

  /// No description provided for @homeDailyRecommend.
  ///
  /// In zh, this message translates to:
  /// **'每日推荐'**
  String get homeDailyRecommend;

  /// No description provided for @homeRecentlyPlayed.
  ///
  /// In zh, this message translates to:
  /// **'最近播放'**
  String get homeRecentlyPlayed;

  /// No description provided for @homeViewMore.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get homeViewMore;

  /// No description provided for @libraryGenresTitle.
  ///
  /// In zh, this message translates to:
  /// **'流派'**
  String get libraryGenresTitle;

  /// No description provided for @libraryRadioTitle.
  ///
  /// In zh, this message translates to:
  /// **'网络电台'**
  String get libraryRadioTitle;

  /// No description provided for @libraryRadioEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无电台'**
  String get libraryRadioEmpty;

  /// No description provided for @libraryNoGenres.
  ///
  /// In zh, this message translates to:
  /// **'暂无流派'**
  String get libraryNoGenres;

  /// No description provided for @libraryAlbumArtistsTitle.
  ///
  /// In zh, this message translates to:
  /// **'专辑艺术家'**
  String get libraryAlbumArtistsTitle;

  /// No description provided for @genreSongCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 首歌曲'**
  String genreSongCount(int count);

  /// No description provided for @genreAlbumCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 张专辑'**
  String genreAlbumCount(int count);

  /// No description provided for @contextMenuDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除歌曲'**
  String get contextMenuDelete;

  /// No description provided for @contextMenuDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要从服务器删除「{title}」({artist})？\n此操作不可恢复。'**
  String contextMenuDeleteConfirm(String title, String artist);

  /// No description provided for @contextMenuDeleteSuccess.
  ///
  /// In zh, this message translates to:
  /// **'删除成功'**
  String get contextMenuDeleteSuccess;

  /// No description provided for @contextMenuDeleteError.
  ///
  /// In zh, this message translates to:
  /// **'删除失败'**
  String get contextMenuDeleteError;

  /// No description provided for @settingsUnlimited.
  ///
  /// In zh, this message translates to:
  /// **'无限制'**
  String get settingsUnlimited;

  /// No description provided for @settingsUser.
  ///
  /// In zh, this message translates to:
  /// **'用户'**
  String get settingsUser;

  /// No description provided for @settingsQuality.
  ///
  /// In zh, this message translates to:
  /// **'音质'**
  String get settingsQuality;

  /// No description provided for @settingsMaxBitrate.
  ///
  /// In zh, this message translates to:
  /// **'最大码率'**
  String get settingsMaxBitrate;

  /// No description provided for @settingsAboutText.
  ///
  /// In zh, this message translates to:
  /// **'{appName} v{version}\n跨平台音乐客户端'**
  String settingsAboutText(String appName, String version);

  /// No description provided for @settingsLogoutConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要退出登录吗？'**
  String get settingsLogoutConfirm;

  /// No description provided for @settingsCacheCalculating.
  ///
  /// In zh, this message translates to:
  /// **'计算中...'**
  String get settingsCacheCalculating;

  /// No description provided for @settingsCacheUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get settingsCacheUnknown;

  /// No description provided for @settingsCacheCleared.
  ///
  /// In zh, this message translates to:
  /// **'缓存已清除'**
  String get settingsCacheCleared;

  /// No description provided for @settingsCacheClearFailed.
  ///
  /// In zh, this message translates to:
  /// **'清除失败'**
  String get settingsCacheClearFailed;

  /// No description provided for @settingsCacheStorage.
  ///
  /// In zh, this message translates to:
  /// **'缓存与存储'**
  String get settingsCacheStorage;

  /// No description provided for @settingsCacheUsed.
  ///
  /// In zh, this message translates to:
  /// **'已使用'**
  String get settingsCacheUsed;

  /// No description provided for @settingsCacheMaxCache.
  ///
  /// In zh, this message translates to:
  /// **'最大缓存'**
  String get settingsCacheMaxCache;

  /// No description provided for @settingsCacheClear.
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get settingsCacheClear;

  /// No description provided for @searchBackendNavidrome.
  ///
  /// In zh, this message translates to:
  /// **'Navidrome'**
  String get searchBackendNavidrome;

  /// No description provided for @searchBackendNetease.
  ///
  /// In zh, this message translates to:
  /// **'网易云'**
  String get searchBackendNetease;

  /// No description provided for @searchBackendKuwo.
  ///
  /// In zh, this message translates to:
  /// **'酷我'**
  String get searchBackendKuwo;

  /// No description provided for @searchBackendJoox.
  ///
  /// In zh, this message translates to:
  /// **'JOOX'**
  String get searchBackendJoox;

  /// No description provided for @playerShuffle.
  ///
  /// In zh, this message translates to:
  /// **'随机播放'**
  String get playerShuffle;

  /// No description provided for @playerRepeat.
  ///
  /// In zh, this message translates to:
  /// **'循环播放'**
  String get playerRepeat;

  /// No description provided for @tooltipUnfavorite.
  ///
  /// In zh, this message translates to:
  /// **'取消收藏'**
  String get tooltipUnfavorite;

  /// No description provided for @tooltipPlay.
  ///
  /// In zh, this message translates to:
  /// **'播放'**
  String get tooltipPlay;

  /// No description provided for @tooltipFavorite.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get tooltipFavorite;

  /// No description provided for @tooltipRemove.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get tooltipRemove;

  /// No description provided for @tooltipEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get tooltipEdit;

  /// No description provided for @tooltipDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get tooltipDelete;

  /// No description provided for @tooltipClear.
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get tooltipClear;

  /// No description provided for @tooltipBack.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get tooltipBack;

  /// No description provided for @tooltipMore.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get tooltipMore;

  /// No description provided for @updateCheckUpdate.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get updateCheckUpdate;

  /// No description provided for @updateChecking.
  ///
  /// In zh, this message translates to:
  /// **'检查中...'**
  String get updateChecking;

  /// No description provided for @updateNewVersion.
  ///
  /// In zh, this message translates to:
  /// **'发现新版本 v{version}'**
  String updateNewVersion(String version);

  /// No description provided for @updateChangelog.
  ///
  /// In zh, this message translates to:
  /// **'更新内容'**
  String get updateChangelog;

  /// No description provided for @updateDownload.
  ///
  /// In zh, this message translates to:
  /// **'下载更新'**
  String get updateDownload;

  /// No description provided for @updateLatest.
  ///
  /// In zh, this message translates to:
  /// **'已是最新版本'**
  String get updateLatest;

  /// No description provided for @updateFailed.
  ///
  /// In zh, this message translates to:
  /// **'检查更新失败，请稍后重试'**
  String get updateFailed;

  /// No description provided for @contextMenuDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认删除'**
  String get contextMenuDeleteTitle;

  /// No description provided for @contextMenuDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除'**
  String get contextMenuDeleted;

  /// No description provided for @contextMenuDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除失败，请稍后重试'**
  String get contextMenuDeleteFailed;
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return SEn();
    case 'zh':
      return SZh();
  }

  throw FlutterError(
    'S.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
