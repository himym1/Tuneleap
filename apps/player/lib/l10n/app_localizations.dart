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
  /// **'歌单'**
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
  /// **'输入账号密码即可，曲库与 Cloud 地址已内置'**
  String get loginSubtitle;

  /// No description provided for @loginConnect.
  ///
  /// In zh, this message translates to:
  /// **'连接'**
  String get loginConnect;

  /// No description provided for @loginFieldsRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写用户名和密码'**
  String get loginFieldsRequired;

  /// No description provided for @loginFailed.
  ///
  /// In zh, this message translates to:
  /// **'登录失败，请检查用户名和密码'**
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

  /// No description provided for @playerMoreActions.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get playerMoreActions;

  /// No description provided for @playerClearQueue.
  ///
  /// In zh, this message translates to:
  /// **'清空队列'**
  String get playerClearQueue;

  /// No description provided for @playerClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭播放页'**
  String get playerClose;

  /// No description provided for @shortcutsTitle.
  ///
  /// In zh, this message translates to:
  /// **'键盘快捷键'**
  String get shortcutsTitle;

  /// No description provided for @shortcutsPlayPause.
  ///
  /// In zh, this message translates to:
  /// **'播放 / 暂停'**
  String get shortcutsPlayPause;

  /// No description provided for @shortcutsPrevious.
  ///
  /// In zh, this message translates to:
  /// **'上一首'**
  String get shortcutsPrevious;

  /// No description provided for @shortcutsNext.
  ///
  /// In zh, this message translates to:
  /// **'下一首'**
  String get shortcutsNext;

  /// No description provided for @shortcutsClosePlayer.
  ///
  /// In zh, this message translates to:
  /// **'关闭正在播放'**
  String get shortcutsClosePlayer;

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

  /// No description provided for @settingsThemeStyle.
  ///
  /// In zh, this message translates to:
  /// **'主题风格'**
  String get settingsThemeStyle;

  /// No description provided for @settingsThemeClassic.
  ///
  /// In zh, this message translates to:
  /// **'经典'**
  String get settingsThemeClassic;

  /// No description provided for @settingsThemeAmoled.
  ///
  /// In zh, this message translates to:
  /// **'纯黑'**
  String get settingsThemeAmoled;

  /// No description provided for @settingsThemeDynamic.
  ///
  /// In zh, this message translates to:
  /// **'封面取色'**
  String get settingsThemeDynamic;

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

  /// No description provided for @settingsServerUnconfigured.
  ///
  /// In zh, this message translates to:
  /// **'未配置'**
  String get settingsServerUnconfigured;

  /// No description provided for @settingsTools.
  ///
  /// In zh, this message translates to:
  /// **'工具'**
  String get settingsTools;

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

  /// No description provided for @importDuplicateTitle.
  ///
  /// In zh, this message translates to:
  /// **'歌曲已存在'**
  String get importDuplicateTitle;

  /// No description provided for @importDuplicateMessage.
  ///
  /// In zh, this message translates to:
  /// **'「{title}」({artist}) 在本地库中已存在，是否仍要导入？'**
  String importDuplicateMessage(String title, String artist);

  /// No description provided for @importAnyway.
  ///
  /// In zh, this message translates to:
  /// **'仍然导入'**
  String get importAnyway;

  /// No description provided for @importDuplicateCompareHint.
  ///
  /// In zh, this message translates to:
  /// **'对照两边音质，再决定替换、另下一份或取消。'**
  String get importDuplicateCompareHint;

  /// No description provided for @importDuplicateIncoming.
  ///
  /// In zh, this message translates to:
  /// **'将要下载'**
  String get importDuplicateIncoming;

  /// No description provided for @importDuplicateLocal.
  ///
  /// In zh, this message translates to:
  /// **'本地曲库'**
  String get importDuplicateLocal;

  /// No description provided for @importDuplicateSameVersion.
  ///
  /// In zh, this message translates to:
  /// **'同一版本'**
  String get importDuplicateSameVersion;

  /// No description provided for @importDuplicateDifferentVersion.
  ///
  /// In zh, this message translates to:
  /// **'不同版本'**
  String get importDuplicateDifferentVersion;

  /// No description provided for @importDuplicateUnknownVersion.
  ///
  /// In zh, this message translates to:
  /// **'无法判断'**
  String get importDuplicateUnknownVersion;

  /// No description provided for @importDuplicateDownload.
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get importDuplicateDownload;

  /// No description provided for @importDuplicateReplace.
  ///
  /// In zh, this message translates to:
  /// **'替换'**
  String get importDuplicateReplace;

  /// No description provided for @importDuplicateIncomingOriginal.
  ///
  /// In zh, this message translates to:
  /// **'原始 · 未转码'**
  String get importDuplicateIncomingOriginal;

  /// No description provided for @importDuplicateBitRateEstimated.
  ///
  /// In zh, this message translates to:
  /// **'约 {kbps} kbps'**
  String importDuplicateBitRateEstimated(int kbps);

  /// No description provided for @importDuplicateQualityHigher.
  ///
  /// In zh, this message translates to:
  /// **'比选中本地更高'**
  String get importDuplicateQualityHigher;

  /// No description provided for @importDuplicateQualityHigherBy.
  ///
  /// In zh, this message translates to:
  /// **'比选中本地高 {kbps} kbps'**
  String importDuplicateQualityHigherBy(int kbps);

  /// No description provided for @importDuplicateQualityLower.
  ///
  /// In zh, this message translates to:
  /// **'比选中本地更低'**
  String get importDuplicateQualityLower;

  /// No description provided for @importDuplicateQualityLowerBy.
  ///
  /// In zh, this message translates to:
  /// **'比选中本地低 {kbps} kbps'**
  String importDuplicateQualityLowerBy(int kbps);

  /// No description provided for @importDuplicateQualitySimilar.
  ///
  /// In zh, this message translates to:
  /// **'与选中本地相近'**
  String get importDuplicateQualitySimilar;

  /// No description provided for @importDuplicateQualityUnknown.
  ///
  /// In zh, this message translates to:
  /// **'无法对比具体码率'**
  String get importDuplicateQualityUnknown;

  /// No description provided for @importDuplicateQualityLocalLossless.
  ///
  /// In zh, this message translates to:
  /// **'本地已是无损，无法对比码率'**
  String get importDuplicateQualityLocalLossless;

  /// No description provided for @importDuplicateQualityBothLossless.
  ///
  /// In zh, this message translates to:
  /// **'都是无损，待下载码率未知'**
  String get importDuplicateQualityBothLossless;

  /// No description provided for @importDuplicateQualityOriginalLikelyHigher.
  ///
  /// In zh, this message translates to:
  /// **'原始音质通常高于本地有损'**
  String get importDuplicateQualityOriginalLikelyHigher;

  /// No description provided for @importDuplicateUnknownAlbum.
  ///
  /// In zh, this message translates to:
  /// **'未知专辑'**
  String get importDuplicateUnknownAlbum;

  /// No description provided for @importDuplicateUnknownMeta.
  ///
  /// In zh, this message translates to:
  /// **'—'**
  String get importDuplicateUnknownMeta;

  /// No description provided for @importDuplicateCheckFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法核对 NAS 曲库，已停止导入'**
  String get importDuplicateCheckFailed;

  /// No description provided for @nasAgentConfigRequired.
  ///
  /// In zh, this message translates to:
  /// **'请先登录 Cloud 后再导入或删除'**
  String get nasAgentConfigRequired;

  /// No description provided for @commonContinue.
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get commonContinue;

  /// No description provided for @contextMenuQueueingNavidrome.
  ///
  /// In zh, this message translates to:
  /// **'正在提交到 NAS 下载队列…'**
  String get contextMenuQueueingNavidrome;

  /// No description provided for @contextMenuQueuedNavidrome.
  ///
  /// In zh, this message translates to:
  /// **'已加入导入队列'**
  String get contextMenuQueuedNavidrome;

  /// No description provided for @nasImportViewQueue.
  ///
  /// In zh, this message translates to:
  /// **'查看'**
  String get nasImportViewQueue;

  /// No description provided for @contextMenuDeleting.
  ///
  /// In zh, this message translates to:
  /// **'正在删除…'**
  String get contextMenuDeleting;

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

  /// No description provided for @downloadsOfflineTab.
  ///
  /// In zh, this message translates to:
  /// **'本机离线'**
  String get downloadsOfflineTab;

  /// No description provided for @downloadsNasImportTab.
  ///
  /// In zh, this message translates to:
  /// **'导入曲库'**
  String get downloadsNasImportTab;

  /// No description provided for @downloadsNasImportHint.
  ///
  /// In zh, this message translates to:
  /// **'在线歌曲点「+」加入导入队列'**
  String get downloadsNasImportHint;

  /// No description provided for @downloadsNasImportEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无导入任务'**
  String get downloadsNasImportEmpty;

  /// No description provided for @nasImportAlreadyQueued.
  ///
  /// In zh, this message translates to:
  /// **'已在导入队列中'**
  String get nasImportAlreadyQueued;

  /// No description provided for @nasImportStageResolving.
  ///
  /// In zh, this message translates to:
  /// **'准备中'**
  String get nasImportStageResolving;

  /// No description provided for @nasImportStageUploading.
  ///
  /// In zh, this message translates to:
  /// **'下载到 NAS'**
  String get nasImportStageUploading;

  /// No description provided for @nasImportClearFinished.
  ///
  /// In zh, this message translates to:
  /// **'清除已结束'**
  String get nasImportClearFinished;

  /// No description provided for @nasImportErrorFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入失败'**
  String get nasImportErrorFailed;

  /// No description provided for @nasImportErrorTimeout.
  ///
  /// In zh, this message translates to:
  /// **'NAS 下载超时，等当前传输结束后再重试'**
  String get nasImportErrorTimeout;

  /// No description provided for @nasImportErrorUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'NAS 暂时不可用'**
  String get nasImportErrorUnavailable;

  /// No description provided for @nasImportErrorSlowUpstream.
  ///
  /// In zh, this message translates to:
  /// **'几条线路都太慢，稍后再试或点重试再换节点'**
  String get nasImportErrorSlowUpstream;

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

  /// No description provided for @backendUrl.
  ///
  /// In zh, this message translates to:
  /// **'云端 API 地址'**
  String get backendUrl;

  /// No description provided for @backendUrlHint.
  ///
  /// In zh, this message translates to:
  /// **'navidrome-cloud 公网地址，例如 https://cloud.example.com'**
  String get backendUrlHint;

  /// No description provided for @cloudAccount.
  ///
  /// In zh, this message translates to:
  /// **'Cloud 账号'**
  String get cloudAccount;

  /// No description provided for @cloudSignedIn.
  ///
  /// In zh, this message translates to:
  /// **'已登录'**
  String get cloudSignedIn;

  /// No description provided for @cloudSignedOut.
  ///
  /// In zh, this message translates to:
  /// **'未登录'**
  String get cloudSignedOut;

  /// No description provided for @cloudSignIn.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get cloudSignIn;

  /// No description provided for @cloudRegister.
  ///
  /// In zh, this message translates to:
  /// **'注册'**
  String get cloudRegister;

  /// No description provided for @cloudUsername.
  ///
  /// In zh, this message translates to:
  /// **'Cloud 用户名'**
  String get cloudUsername;

  /// No description provided for @cloudCredential.
  ///
  /// In zh, this message translates to:
  /// **'Cloud 账号凭据'**
  String get cloudCredential;

  /// No description provided for @cloudSignOut.
  ///
  /// In zh, this message translates to:
  /// **'退出 Cloud'**
  String get cloudSignOut;

  /// No description provided for @cloudAuthFailed.
  ///
  /// In zh, this message translates to:
  /// **'Cloud 认证失败'**
  String get cloudAuthFailed;

  /// No description provided for @cloudInvalidInput.
  ///
  /// In zh, this message translates to:
  /// **'用户名至少 2 个字符，账号凭据至少 8 个字符'**
  String get cloudInvalidInput;

  /// No description provided for @cloudInvalidCredentials.
  ///
  /// In zh, this message translates to:
  /// **'Cloud 用户名或账号凭据错误'**
  String get cloudInvalidCredentials;

  /// No description provided for @cloudUsernameExists.
  ///
  /// In zh, this message translates to:
  /// **'该 Cloud 用户名已存在，请直接登录或更换用户名'**
  String get cloudUsernameExists;

  /// No description provided for @cloudNetworkError.
  ///
  /// In zh, this message translates to:
  /// **'无法连接 Cloud，请检查网络后重试'**
  String get cloudNetworkError;

  /// No description provided for @cloudAuthRequired.
  ///
  /// In zh, this message translates to:
  /// **'登录 Cloud 后加载推荐'**
  String get cloudAuthRequired;

  /// No description provided for @searchAuthRequired.
  ///
  /// In zh, this message translates to:
  /// **'Cloud 登录已失效，请重新登录后再搜索'**
  String get searchAuthRequired;

  /// No description provided for @nasAgentUrl.
  ///
  /// In zh, this message translates to:
  /// **'NAS Agent 地址'**
  String get nasAgentUrl;

  /// No description provided for @nasAgentUrlHint.
  ///
  /// In zh, this message translates to:
  /// **'导入/删除必填，请使用局域网地址，例如 http://192.168.1.10:8504'**
  String get nasAgentUrlHint;

  /// No description provided for @nasAgentKey.
  ///
  /// In zh, this message translates to:
  /// **'NAS Agent Key'**
  String get nasAgentKey;

  /// No description provided for @nasAgentKeyHint.
  ///
  /// In zh, this message translates to:
  /// **'仅用于局域网导入/删除'**
  String get nasAgentKeyHint;

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

  /// No description provided for @searchError.
  ///
  /// In zh, this message translates to:
  /// **'搜索失败: {error}'**
  String searchError(String error);

  /// No description provided for @searchRateLimited.
  ///
  /// In zh, this message translates to:
  /// **'搜索请求过于频繁，请稍后重试。'**
  String get searchRateLimited;

  /// No description provided for @searchServiceUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'当前搜索服务暂不可用。'**
  String get searchServiceUnavailable;

  /// No description provided for @searchSourceUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'{source}搜索服务暂不可用。'**
  String searchSourceUnavailable(String source);

  /// No description provided for @searchFailedTryAgain.
  ///
  /// In zh, this message translates to:
  /// **'搜索失败，请重试。'**
  String get searchFailedTryAgain;

  /// No description provided for @searchResults.
  ///
  /// In zh, this message translates to:
  /// **'搜索结果'**
  String get searchResults;

  /// No description provided for @searchLoadMore.
  ///
  /// In zh, this message translates to:
  /// **'加载更多'**
  String get searchLoadMore;

  /// No description provided for @searchLoadingMore.
  ///
  /// In zh, this message translates to:
  /// **'加载中…'**
  String get searchLoadingMore;

  /// No description provided for @searchLoadMoreFailed.
  ///
  /// In zh, this message translates to:
  /// **'下一页加载失败'**
  String get searchLoadMoreFailed;

  /// No description provided for @searchPlaybackUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'当前歌曲暂时无法播放'**
  String get searchPlaybackUnavailable;

  /// No description provided for @searchPlaybackFailed.
  ///
  /// In zh, this message translates to:
  /// **'播放失败: {error}'**
  String searchPlaybackFailed(String error);

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

  /// No description provided for @playlistAddSongs.
  ///
  /// In zh, this message translates to:
  /// **'添加歌曲'**
  String get playlistAddSongs;

  /// No description provided for @playlistAddSongsTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加歌曲到歌单'**
  String get playlistAddSongsTitle;

  /// No description provided for @playlistSearchSongsHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索本地曲库'**
  String get playlistSearchSongsHint;

  /// No description provided for @playlistNoMatchingSongs.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的歌曲'**
  String get playlistNoMatchingSongs;

  /// No description provided for @playlistAddSelected.
  ///
  /// In zh, this message translates to:
  /// **'添加所选'**
  String get playlistAddSelected;

  /// No description provided for @playlistSongsAdded.
  ///
  /// In zh, this message translates to:
  /// **'已添加 {count} 首'**
  String playlistSongsAdded(int count);

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

  /// No description provided for @playlistSaveQueue.
  ///
  /// In zh, this message translates to:
  /// **'将队列保存为歌单'**
  String get playlistSaveQueue;

  /// No description provided for @playlistQueueSaved.
  ///
  /// In zh, this message translates to:
  /// **'已将队列保存为「{name}」'**
  String playlistQueueSaved(String name);

  /// No description provided for @playlistQueueSavedSkipped.
  ///
  /// In zh, this message translates to:
  /// **'已保存为「{name}」，跳过 {count} 首线上歌曲'**
  String playlistQueueSavedSkipped(String name, int count);

  /// No description provided for @playlistQueueNoLocalSongs.
  ///
  /// In zh, this message translates to:
  /// **'只有本地曲库歌曲可以保存到歌单'**
  String get playlistQueueNoLocalSongs;

  /// No description provided for @playlistQueueSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存队列失败'**
  String get playlistQueueSaveFailed;

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

  /// No description provided for @libraryBrowse.
  ///
  /// In zh, this message translates to:
  /// **'浏览音乐库'**
  String get libraryBrowse;

  /// No description provided for @homeNewestAlbums.
  ///
  /// In zh, this message translates to:
  /// **'最新专辑'**
  String get homeNewestAlbums;

  /// No description provided for @homeNewestSongs.
  ///
  /// In zh, this message translates to:
  /// **'最新歌曲'**
  String get homeNewestSongs;

  /// No description provided for @homeDailyRecommend.
  ///
  /// In zh, this message translates to:
  /// **'发现新音乐'**
  String get homeDailyRecommend;

  /// No description provided for @homeRecentlyPlayed.
  ///
  /// In zh, this message translates to:
  /// **'最近播放'**
  String get homeRecentlyPlayed;

  /// No description provided for @homeYourMusic.
  ///
  /// In zh, this message translates to:
  /// **'我的音乐'**
  String get homeYourMusic;

  /// No description provided for @homeContinueListening.
  ///
  /// In zh, this message translates to:
  /// **'继续听'**
  String get homeContinueListening;

  /// No description provided for @homeLocalMix.
  ///
  /// In zh, this message translates to:
  /// **'为你播放'**
  String get homeLocalMix;

  /// No description provided for @homeShuffleLocal.
  ///
  /// In zh, this message translates to:
  /// **'随机播放曲库'**
  String get homeShuffleLocal;

  /// No description provided for @homeLocalPlaybackFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法开始本地播放'**
  String get homeLocalPlaybackFailed;

  /// No description provided for @homeViewMore.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get homeViewMore;

  /// No description provided for @homeRefreshed.
  ///
  /// In zh, this message translates to:
  /// **'首页已刷新'**
  String get homeRefreshed;

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

  /// No description provided for @searchBackendTencent.
  ///
  /// In zh, this message translates to:
  /// **'QQ'**
  String get searchBackendTencent;

  /// No description provided for @searchBackendKugou.
  ///
  /// In zh, this message translates to:
  /// **'酷狗'**
  String get searchBackendKugou;

  /// No description provided for @searchBackendMigu.
  ///
  /// In zh, this message translates to:
  /// **'咪咕'**
  String get searchBackendMigu;

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

  /// No description provided for @settingsOnlineSources.
  ///
  /// In zh, this message translates to:
  /// **'在线搜索源'**
  String get settingsOnlineSources;

  /// No description provided for @settingsOnlineSourcesHint.
  ///
  /// In zh, this message translates to:
  /// **'按平台分开搜索。请求仍走 Cloud，不用在 App 里填第三方密钥。'**
  String get settingsOnlineSourcesHint;

  /// No description provided for @settingsOnlineSourcesKeepOne.
  ///
  /// In zh, this message translates to:
  /// **'至少保留一个搜索源'**
  String get settingsOnlineSourcesKeepOne;

  /// No description provided for @settingsOnlineAdapter.
  ///
  /// In zh, this message translates to:
  /// **'搜索 API'**
  String get settingsOnlineAdapter;

  /// No description provided for @settingsOnlineAdapterAuto.
  ///
  /// In zh, this message translates to:
  /// **'自动'**
  String get settingsOnlineAdapterAuto;

  /// No description provided for @settingsOnlineAdapterUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'无法加载 Cloud 搜索 API，已使用自动兼容模式。'**
  String get settingsOnlineAdapterUnavailable;

  /// No description provided for @searchFilterOnline.
  ///
  /// In zh, this message translates to:
  /// **'在线'**
  String get searchFilterOnline;

  /// No description provided for @searchSectionLocal.
  ///
  /// In zh, this message translates to:
  /// **'本地搜索结果'**
  String get searchSectionLocal;

  /// No description provided for @searchSectionOnline.
  ///
  /// In zh, this message translates to:
  /// **'在线搜索结果'**
  String get searchSectionOnline;

  /// No description provided for @playerShuffle.
  ///
  /// In zh, this message translates to:
  /// **'随机播放'**
  String get playerShuffle;

  /// No description provided for @playerShuffleOff.
  ///
  /// In zh, this message translates to:
  /// **'随机：关'**
  String get playerShuffleOff;

  /// No description provided for @playerShuffleOn.
  ///
  /// In zh, this message translates to:
  /// **'随机：开'**
  String get playerShuffleOn;

  /// No description provided for @playerRepeat.
  ///
  /// In zh, this message translates to:
  /// **'循环播放'**
  String get playerRepeat;

  /// No description provided for @playerRepeatOff.
  ///
  /// In zh, this message translates to:
  /// **'循环：关（播完即停）'**
  String get playerRepeatOff;

  /// No description provided for @playerRepeatAll.
  ///
  /// In zh, this message translates to:
  /// **'循环：列表'**
  String get playerRepeatAll;

  /// No description provided for @playerRepeatOne.
  ///
  /// In zh, this message translates to:
  /// **'循环：单曲'**
  String get playerRepeatOne;

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

  /// No description provided for @updateInstall.
  ///
  /// In zh, this message translates to:
  /// **'立即安装'**
  String get updateInstall;

  /// No description provided for @updateInstalling.
  ///
  /// In zh, this message translates to:
  /// **'正在安装…'**
  String get updateInstalling;

  /// No description provided for @updateAlreadyDownloaded.
  ///
  /// In zh, this message translates to:
  /// **'安装包已下载完成，可直接安装，无需重新下载。'**
  String get updateAlreadyDownloaded;

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

  /// No description provided for @updateMacInstallHint.
  ///
  /// In zh, this message translates to:
  /// **'安装包已打开。请把「音跃」拖进「应用程序」替换当前版本，然后重新打开。'**
  String get updateMacInstallHint;

  /// No description provided for @updateWindowsInstallHint.
  ///
  /// In zh, this message translates to:
  /// **'安装包已打开。请解压后覆盖当前音跃目录，然后重新运行 navidrome_player.exe。'**
  String get updateWindowsInstallHint;

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

  /// No description provided for @contextMenuDeleteNotFound.
  ///
  /// In zh, this message translates to:
  /// **'曲库里找不到这首歌，请下拉刷新后再试'**
  String get contextMenuDeleteNotFound;

  /// No description provided for @contextMenuDeleteFailedReason.
  ///
  /// In zh, this message translates to:
  /// **'删除失败：{reason}'**
  String contextMenuDeleteFailedReason(String reason);

  /// No description provided for @recommendationsTitle.
  ///
  /// In zh, this message translates to:
  /// **'推荐'**
  String get recommendationsTitle;

  /// No description provided for @recommendationsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无推荐'**
  String get recommendationsEmpty;

  /// No description provided for @recommendationsBackendMissing.
  ///
  /// In zh, this message translates to:
  /// **'请先配置 Backend 以启用推荐'**
  String get recommendationsBackendMissing;

  /// No description provided for @recommendationsRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get recommendationsRetry;

  /// No description provided for @recommendationsDislike.
  ///
  /// In zh, this message translates to:
  /// **'不感兴趣'**
  String get recommendationsDislike;

  /// No description provided for @recommendationsImport.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get recommendationsImport;

  /// No description provided for @recommendationsViewAll.
  ///
  /// In zh, this message translates to:
  /// **'查看全部'**
  String get recommendationsViewAll;

  /// No description provided for @recommendationsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'根据最近播放和你的反馈生成'**
  String get recommendationsSubtitle;

  /// No description provided for @recommendationsModeAi.
  ///
  /// In zh, this message translates to:
  /// **'AI 推荐'**
  String get recommendationsModeAi;

  /// No description provided for @recommendationsModeFallback.
  ///
  /// In zh, this message translates to:
  /// **'规则推荐'**
  String get recommendationsModeFallback;

  /// No description provided for @recommendationsSimilar.
  ///
  /// In zh, this message translates to:
  /// **'相似推荐'**
  String get recommendationsSimilar;

  /// No description provided for @recommendationsExplore.
  ///
  /// In zh, this message translates to:
  /// **'探索推荐'**
  String get recommendationsExplore;

  /// No description provided for @recommendationsRefreshed.
  ///
  /// In zh, this message translates to:
  /// **'推荐已更新'**
  String get recommendationsRefreshed;

  /// No description provided for @recommendationsRefreshing.
  ///
  /// In zh, this message translates to:
  /// **'正在刷新推荐'**
  String get recommendationsRefreshing;

  /// No description provided for @settingsResetRecommendations.
  ///
  /// In zh, this message translates to:
  /// **'重置推荐偏好'**
  String get settingsResetRecommendations;

  /// No description provided for @settingsResetRecommendationsConfirm.
  ///
  /// In zh, this message translates to:
  /// **'重置推荐偏好？歌曲、下载、播放历史和服务器配置不受影响。'**
  String get settingsResetRecommendationsConfirm;

  /// No description provided for @settingsResetRecommendationsDone.
  ///
  /// In zh, this message translates to:
  /// **'推荐偏好已重置'**
  String get settingsResetRecommendationsDone;

  /// No description provided for @libraryAuditTitle.
  ///
  /// In zh, this message translates to:
  /// **'曲库体检'**
  String get libraryAuditTitle;

  /// No description provided for @libraryAuditSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'先快扫格式、码率和标签，再可选深扫假无损。结果分成「音质问题」「元数据」和「不同版本」。不会自动删歌或替换。'**
  String get libraryAuditSubtitle;

  /// No description provided for @libraryAuditStart.
  ///
  /// In zh, this message translates to:
  /// **'开始体检'**
  String get libraryAuditStart;

  /// No description provided for @libraryAuditDeepStart.
  ///
  /// In zh, this message translates to:
  /// **'深扫问题项'**
  String get libraryAuditDeepStart;

  /// No description provided for @libraryAuditCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get libraryAuditCancel;

  /// No description provided for @libraryAuditScanning.
  ///
  /// In zh, this message translates to:
  /// **'正在扫描 {scanned}/{total}'**
  String libraryAuditScanning(int scanned, int total);

  /// No description provided for @libraryAuditDeepScanning.
  ///
  /// In zh, this message translates to:
  /// **'正在深扫 {scanned}/{total}'**
  String libraryAuditDeepScanning(int scanned, int total);

  /// No description provided for @libraryAuditIdle.
  ///
  /// In zh, this message translates to:
  /// **'尚未体检。开始后会列出可疑文件，再由你决定删除或替换。'**
  String get libraryAuditIdle;

  /// No description provided for @libraryAuditEmptyIssues.
  ///
  /// In zh, this message translates to:
  /// **'这次没有发现问题。'**
  String get libraryAuditEmptyIssues;

  /// No description provided for @libraryAuditEmptyQuality.
  ///
  /// In zh, this message translates to:
  /// **'没有音质问题。'**
  String get libraryAuditEmptyQuality;

  /// No description provided for @libraryAuditEmptyVersions.
  ///
  /// In zh, this message translates to:
  /// **'没有不同版本。'**
  String get libraryAuditEmptyVersions;

  /// No description provided for @libraryAuditEmptyMetadata.
  ///
  /// In zh, this message translates to:
  /// **'没有元数据问题。'**
  String get libraryAuditEmptyMetadata;

  /// No description provided for @libraryAuditPassed.
  ///
  /// In zh, this message translates to:
  /// **'通过'**
  String get libraryAuditPassed;

  /// No description provided for @libraryAuditIssues.
  ///
  /// In zh, this message translates to:
  /// **'问题'**
  String get libraryAuditIssues;

  /// No description provided for @libraryAuditQualityIssues.
  ///
  /// In zh, this message translates to:
  /// **'音质问题'**
  String get libraryAuditQualityIssues;

  /// No description provided for @libraryAuditMetadataIssues.
  ///
  /// In zh, this message translates to:
  /// **'元数据'**
  String get libraryAuditMetadataIssues;

  /// No description provided for @libraryAuditVersionOnly.
  ///
  /// In zh, this message translates to:
  /// **'不同版本'**
  String get libraryAuditVersionOnly;

  /// No description provided for @libraryAuditSectionQuality.
  ///
  /// In zh, this message translates to:
  /// **'音质问题'**
  String get libraryAuditSectionQuality;

  /// No description provided for @libraryAuditSectionMetadata.
  ///
  /// In zh, this message translates to:
  /// **'元数据'**
  String get libraryAuditSectionMetadata;

  /// No description provided for @libraryAuditSectionMetadataHint.
  ///
  /// In zh, this message translates to:
  /// **'空标签、乱码、缺封面/曲序/年份/歌词，或文件内嵌标签和曲库不一致。单曲没有曲序不算问题。'**
  String get libraryAuditSectionMetadataHint;

  /// No description provided for @libraryAuditSectionVersions.
  ///
  /// In zh, this message translates to:
  /// **'不同版本（音质正常）'**
  String get libraryAuditSectionVersions;

  /// No description provided for @libraryAuditSectionVersionsHint.
  ///
  /// In zh, this message translates to:
  /// **'同名同歌手但时长不同。频谱正常或未标假无损，可以都留着。'**
  String get libraryAuditSectionVersionsHint;

  /// No description provided for @libraryAuditQualityOk.
  ///
  /// In zh, this message translates to:
  /// **'音质正常'**
  String get libraryAuditQualityOk;

  /// No description provided for @libraryAuditScanned.
  ///
  /// In zh, this message translates to:
  /// **'已扫描'**
  String get libraryAuditScanned;

  /// No description provided for @libraryAuditFilterAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get libraryAuditFilterAll;

  /// No description provided for @libraryAuditCodeMissing.
  ///
  /// In zh, this message translates to:
  /// **'文件缺失'**
  String get libraryAuditCodeMissing;

  /// No description provided for @libraryAuditCodeLowBitrate.
  ///
  /// In zh, this message translates to:
  /// **'低码率'**
  String get libraryAuditCodeLowBitrate;

  /// No description provided for @libraryAuditCodeSuspectTranscode.
  ///
  /// In zh, this message translates to:
  /// **'可疑假无损'**
  String get libraryAuditCodeSuspectTranscode;

  /// No description provided for @libraryAuditCodeDuplicateVersion.
  ///
  /// In zh, this message translates to:
  /// **'不同版本'**
  String get libraryAuditCodeDuplicateVersion;

  /// No description provided for @libraryAuditCodeLossyTranscode.
  ///
  /// In zh, this message translates to:
  /// **'频谱像有损'**
  String get libraryAuditCodeLossyTranscode;

  /// No description provided for @libraryAuditCodeFakeHires.
  ///
  /// In zh, this message translates to:
  /// **'假 Hi-Res'**
  String get libraryAuditCodeFakeHires;

  /// No description provided for @libraryAuditCodeDeepFailed.
  ///
  /// In zh, this message translates to:
  /// **'深扫失败'**
  String get libraryAuditCodeDeepFailed;

  /// No description provided for @libraryAuditCodeMissingTitle.
  ///
  /// In zh, this message translates to:
  /// **'缺歌名'**
  String get libraryAuditCodeMissingTitle;

  /// No description provided for @libraryAuditCodeMissingArtist.
  ///
  /// In zh, this message translates to:
  /// **'缺歌手'**
  String get libraryAuditCodeMissingArtist;

  /// No description provided for @libraryAuditCodeMissingAlbum.
  ///
  /// In zh, this message translates to:
  /// **'缺专辑'**
  String get libraryAuditCodeMissingAlbum;

  /// No description provided for @libraryAuditCodeSuspiciousText.
  ///
  /// In zh, this message translates to:
  /// **'疑似乱码'**
  String get libraryAuditCodeSuspiciousText;

  /// No description provided for @libraryAuditCodeMissingCover.
  ///
  /// In zh, this message translates to:
  /// **'缺封面'**
  String get libraryAuditCodeMissingCover;

  /// No description provided for @libraryAuditCodeMissingTrack.
  ///
  /// In zh, this message translates to:
  /// **'缺曲序'**
  String get libraryAuditCodeMissingTrack;

  /// No description provided for @libraryAuditCodeMissingYear.
  ///
  /// In zh, this message translates to:
  /// **'缺年份'**
  String get libraryAuditCodeMissingYear;

  /// No description provided for @libraryAuditCodeMissingLyrics.
  ///
  /// In zh, this message translates to:
  /// **'缺歌词'**
  String get libraryAuditCodeMissingLyrics;

  /// No description provided for @libraryAuditCodeTagMismatch.
  ///
  /// In zh, this message translates to:
  /// **'标签不一致'**
  String get libraryAuditCodeTagMismatch;

  /// No description provided for @libraryAuditDeepErrorUnresolved.
  ///
  /// In zh, this message translates to:
  /// **'找不到可解码的文件'**
  String get libraryAuditDeepErrorUnresolved;

  /// No description provided for @libraryAuditDeepErrorSampleRate.
  ///
  /// In zh, this message translates to:
  /// **'读不到有效采样率，文件可能已损坏或不是音频'**
  String get libraryAuditDeepErrorSampleRate;

  /// No description provided for @libraryAuditDeepErrorDecode.
  ///
  /// In zh, this message translates to:
  /// **'无法解码这段音频'**
  String get libraryAuditDeepErrorDecode;

  /// No description provided for @libraryAuditDeepErrorTooShort.
  ///
  /// In zh, this message translates to:
  /// **'音频太短，无法做频谱'**
  String get libraryAuditDeepErrorTooShort;

  /// No description provided for @libraryAuditDeepErrorUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'格式不受支持'**
  String get libraryAuditDeepErrorUnsupported;

  /// No description provided for @libraryAuditDeepErrorUnknown.
  ///
  /// In zh, this message translates to:
  /// **'深扫失败，原因不明'**
  String get libraryAuditDeepErrorUnknown;

  /// No description provided for @libraryAuditCutoff.
  ///
  /// In zh, this message translates to:
  /// **'高频截止约 {hz} Hz'**
  String libraryAuditCutoff(int hz);

  /// No description provided for @libraryAuditReplace.
  ///
  /// In zh, this message translates to:
  /// **'替换'**
  String get libraryAuditReplace;

  /// No description provided for @libraryAuditReplaceHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索后导入即可替换「{title}」'**
  String libraryAuditReplaceHint(String title);

  /// No description provided for @libraryAuditReplaceBanner.
  ///
  /// In zh, this message translates to:
  /// **'选择一首搜索结果，用来替换「{title}」· {artist}'**
  String libraryAuditReplaceBanner(String title, String artist);

  /// No description provided for @libraryAuditReplaceWithThis.
  ///
  /// In zh, this message translates to:
  /// **'用这首替换'**
  String get libraryAuditReplaceWithThis;

  /// No description provided for @libraryAuditNasRequired.
  ///
  /// In zh, this message translates to:
  /// **'曲库体检需要能连上 NAS Agent'**
  String get libraryAuditNasRequired;

  /// No description provided for @libraryAuditFailed.
  ///
  /// In zh, this message translates to:
  /// **'体检失败：{reason}'**
  String libraryAuditFailed(String reason);

  /// No description provided for @libraryAuditQuality.
  ///
  /// In zh, this message translates to:
  /// **'{format} · {kbps} kbps'**
  String libraryAuditQuality(String format, int kbps);

  /// No description provided for @libraryAuditRulesTitle.
  ///
  /// In zh, this message translates to:
  /// **'体检阈值'**
  String get libraryAuditRulesTitle;

  /// No description provided for @libraryAuditRulesLowBitrate.
  ///
  /// In zh, this message translates to:
  /// **'有损低于 {kbps} kbps 记为低码率'**
  String libraryAuditRulesLowBitrate(int kbps);

  /// No description provided for @libraryAuditRulesSuspect.
  ///
  /// In zh, this message translates to:
  /// **'无损低于 {kbps} kbps 记为可疑假无损'**
  String libraryAuditRulesSuspect(int kbps);

  /// No description provided for @libraryAuditRulesDuration.
  ///
  /// In zh, this message translates to:
  /// **'时长相差超过 {seconds} 秒记为不同版本'**
  String libraryAuditRulesDuration(int seconds);

  /// No description provided for @libraryAuditSelect.
  ///
  /// In zh, this message translates to:
  /// **'多选'**
  String get libraryAuditSelect;

  /// No description provided for @libraryAuditSelectAll.
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get libraryAuditSelectAll;

  /// No description provided for @libraryAuditDoneSelecting.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get libraryAuditDoneSelecting;

  /// No description provided for @libraryAuditSelected.
  ///
  /// In zh, this message translates to:
  /// **'已选 {count} 首'**
  String libraryAuditSelected(int count);

  /// No description provided for @libraryAuditDeleteSelectedConfirm.
  ///
  /// In zh, this message translates to:
  /// **'从曲库删除选中的 {count} 首？不会自动替换。'**
  String libraryAuditDeleteSelectedConfirm(int count);

  /// No description provided for @libraryAuditReplaceSelectedHint.
  ///
  /// In zh, this message translates to:
  /// **'将按顺序搜索并替换选中的 {count} 首，每首仍需确认。'**
  String libraryAuditReplaceSelectedHint(int count);

  /// No description provided for @libraryAuditBatchDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除 {count} 首'**
  String libraryAuditBatchDeleted(int count);

  /// No description provided for @libraryAuditPlayFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法播放这首歌'**
  String get libraryAuditPlayFailed;

  /// No description provided for @libraryAuditOpenAlbum.
  ///
  /// In zh, this message translates to:
  /// **'专辑'**
  String get libraryAuditOpenAlbum;

  /// No description provided for @libraryStyleTitle.
  ///
  /// In zh, this message translates to:
  /// **'流派整理'**
  String get libraryStyleTitle;

  /// No description provided for @libraryStyleSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'Cloud 用 iTunes 和 MusicBrainz 查流派，预览后再写入 14 个封闭风格。「未标」只查没有流派的歌；「全部」会重查已有标签（含华语流行），较慢。与是否在歌单无关。不会自动建歌单。'**
  String get libraryStyleSubtitle;

  /// No description provided for @libraryStyleAnalyzeMissing.
  ///
  /// In zh, this message translates to:
  /// **'分析未标流派'**
  String get libraryStyleAnalyzeMissing;

  /// No description provided for @libraryStyleAnalyzeAll.
  ///
  /// In zh, this message translates to:
  /// **'分析全部'**
  String get libraryStyleAnalyzeAll;

  /// No description provided for @libraryStyleApply.
  ///
  /// In zh, this message translates to:
  /// **'写入 {count} 首'**
  String libraryStyleApply(int count);

  /// No description provided for @libraryStyleCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get libraryStyleCancel;

  /// No description provided for @libraryStyleDone.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get libraryStyleDone;

  /// No description provided for @libraryStyleNasRequired.
  ///
  /// In zh, this message translates to:
  /// **'流派整理需要能连上 NAS Agent'**
  String get libraryStyleNasRequired;

  /// No description provided for @libraryStyleCloudRequired.
  ///
  /// In zh, this message translates to:
  /// **'查流派需要已登录的 Cloud。没有 Cloud 时只会用标题规则，欧美歌多半会进待审。'**
  String get libraryStyleCloudRequired;

  /// No description provided for @libraryStyleFailed.
  ///
  /// In zh, this message translates to:
  /// **'整理失败：{reason}'**
  String libraryStyleFailed(String reason);

  /// No description provided for @libraryStyleAnalyzing.
  ///
  /// In zh, this message translates to:
  /// **'正在分析曲库…'**
  String get libraryStyleAnalyzing;

  /// No description provided for @libraryStyleLookingUp.
  ///
  /// In zh, this message translates to:
  /// **'正在查询流派 {progress}/{total}'**
  String libraryStyleLookingUp(int progress, int total);

  /// No description provided for @libraryStyleApplying.
  ///
  /// In zh, this message translates to:
  /// **'正在写入 {progress}/{total}'**
  String libraryStyleApplying(int progress, int total);

  /// No description provided for @libraryStyleSuggested.
  ///
  /// In zh, this message translates to:
  /// **'建议'**
  String get libraryStyleSuggested;

  /// No description provided for @libraryStyleReview.
  ///
  /// In zh, this message translates to:
  /// **'待审'**
  String get libraryStyleReview;

  /// No description provided for @libraryStyleApplied.
  ///
  /// In zh, this message translates to:
  /// **'已写入'**
  String get libraryStyleApplied;

  /// No description provided for @libraryStyleFailedLabel.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get libraryStyleFailedLabel;

  /// No description provided for @libraryStyleEmptySuggested.
  ///
  /// In zh, this message translates to:
  /// **'没有可写入的建议。'**
  String get libraryStyleEmptySuggested;

  /// No description provided for @libraryStyleEmptyReview.
  ///
  /// In zh, this message translates to:
  /// **'没有待审歌曲。'**
  String get libraryStyleEmptyReview;

  /// No description provided for @libraryStyleIdle.
  ///
  /// In zh, this message translates to:
  /// **'选择分析范围。标题里很明确的先用本地规则，其余走 Cloud 查询。指定流派只是覆盖，不是来源。'**
  String get libraryStyleIdle;

  /// No description provided for @libraryStylePlay.
  ///
  /// In zh, this message translates to:
  /// **'播放'**
  String get libraryStylePlay;

  /// No description provided for @libraryStyleAssign.
  ///
  /// In zh, this message translates to:
  /// **'指定流派'**
  String get libraryStyleAssign;

  /// No description provided for @libraryStyleDelete.
  ///
  /// In zh, this message translates to:
  /// **'从曲库删除'**
  String get libraryStyleDelete;

  /// No description provided for @libraryStyleOpenPlaylists.
  ///
  /// In zh, this message translates to:
  /// **'去生成风格歌单'**
  String get libraryStyleOpenPlaylists;

  /// No description provided for @libraryPlaylistTitle.
  ///
  /// In zh, this message translates to:
  /// **'歌单整理'**
  String get libraryPlaylistTitle;

  /// No description provided for @libraryPlaylistSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'按已经写入的流派标签生成 14 个风格歌单。没有标签的进待审。同名歌单只追加，不覆盖。'**
  String get libraryPlaylistSubtitle;

  /// No description provided for @libraryPlaylistAnalyzeMissing.
  ///
  /// In zh, this message translates to:
  /// **'分析未入歌单'**
  String get libraryPlaylistAnalyzeMissing;

  /// No description provided for @libraryPlaylistAnalyzeAll.
  ///
  /// In zh, this message translates to:
  /// **'按流派重算'**
  String get libraryPlaylistAnalyzeAll;

  /// No description provided for @libraryPlaylistApply.
  ///
  /// In zh, this message translates to:
  /// **'写入 {count} 首到歌单'**
  String libraryPlaylistApply(int count);

  /// No description provided for @libraryPlaylistFailed.
  ///
  /// In zh, this message translates to:
  /// **'歌单整理失败：{reason}'**
  String libraryPlaylistFailed(String reason);

  /// No description provided for @libraryPlaylistApplying.
  ///
  /// In zh, this message translates to:
  /// **'正在写入歌单 {progress}/{total}'**
  String libraryPlaylistApplying(int progress, int total);

  /// No description provided for @libraryPlaylistLists.
  ///
  /// In zh, this message translates to:
  /// **'歌单'**
  String get libraryPlaylistLists;

  /// No description provided for @libraryPlaylistEmptyLists.
  ///
  /// In zh, this message translates to:
  /// **'没有可写入的风格歌单。先做流派整理，或处理待审。'**
  String get libraryPlaylistEmptyLists;

  /// No description provided for @libraryPlaylistIdle.
  ///
  /// In zh, this message translates to:
  /// **'歌单只认已经写进文件的流派。先做流派整理并扫库，再来生成列表。'**
  String get libraryPlaylistIdle;

  /// No description provided for @libraryPlaylistNew.
  ///
  /// In zh, this message translates to:
  /// **'新建'**
  String get libraryPlaylistNew;

  /// No description provided for @libraryPlaylistExisting.
  ///
  /// In zh, this message translates to:
  /// **'已有 {count} 首'**
  String libraryPlaylistExisting(int count);

  /// No description provided for @libraryPlaylistAddCount.
  ///
  /// In zh, this message translates to:
  /// **'将加入 {count} 首'**
  String libraryPlaylistAddCount(int count);

  /// No description provided for @libraryPlaylistAssign.
  ///
  /// In zh, this message translates to:
  /// **'指定到歌单'**
  String get libraryPlaylistAssign;

  /// No description provided for @libraryAuditReplaceBannerQueued.
  ///
  /// In zh, this message translates to:
  /// **'第 {current}/{total} 首：选择结果替换「{title}」· {artist}'**
  String libraryAuditReplaceBannerQueued(
    int current,
    int total,
    String title,
    String artist,
  );
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
