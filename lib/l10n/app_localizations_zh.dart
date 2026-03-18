// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class SZh extends S {
  SZh([String locale = 'zh']) : super(locale);

  @override
  String get navHome => '首页';

  @override
  String get navLibrary => '音乐库';

  @override
  String get navSearch => '搜索';

  @override
  String get navPlaylists => '播放列表';

  @override
  String get navSettings => '设置';

  @override
  String get navFavorites => '收藏';

  @override
  String get navDownloads => '下载管理';

  @override
  String get navServers => '多服务器';

  @override
  String get navAudioQuality => '音质/均衡';

  @override
  String get navScrobble => '播放记录';

  @override
  String get sidebarNav => '导航';

  @override
  String get sidebarMore => '更多';

  @override
  String get appName => '音跃';

  @override
  String get appShortName => '音跃';

  @override
  String get loginSubtitle => '连接你的私人音乐服务器';

  @override
  String get loginConnect => '连接';

  @override
  String get loginFieldsRequired => '请填写所有字段';

  @override
  String get loginFailed => '连接失败，请检查服务器地址和凭据';

  @override
  String loginError(String error) {
    return '连接错误: $error';
  }

  @override
  String get homeGreetingMorning => '早上好 ☀️';

  @override
  String get homeGreetingAfternoon => '下午好 🌤';

  @override
  String get homeGreetingEvening => '晚上好 🌙';

  @override
  String get homePlayRandom => '随机播放';

  @override
  String get homeRecentAlbums => '最近添加';

  @override
  String get homeRandomAlbums => '随机推荐';

  @override
  String get homeAlbums => '专辑';

  @override
  String get homeSongs => '歌曲';

  @override
  String get homeArtists => '艺术家';

  @override
  String get libraryTabArtists => '艺术家';

  @override
  String get libraryTabAlbums => '专辑';

  @override
  String get libraryTabSongs => '歌曲';

  @override
  String get libraryTitle => '音乐库';

  @override
  String libraryAlbumCount(int count) {
    return '$count 张专辑';
  }

  @override
  String get searchHint => '搜索歌曲、专辑、艺术家…';

  @override
  String get searchNoResults => '试试搜索你喜欢的音乐';

  @override
  String get searchResultArtists => '艺术家';

  @override
  String get searchResultAlbums => '专辑';

  @override
  String get searchResultSongs => '歌曲';

  @override
  String get playerQueueTitle => '播放队列';

  @override
  String get playerLyrics => '歌词';

  @override
  String get playerNoLyrics => '暂无歌词';

  @override
  String get playerShowQueue => '显示队列';

  @override
  String get playerHideQueue => '隐藏队列';

  @override
  String get playerSpeed => '播放速度';

  @override
  String get playerNowPlaying => '正在播放';

  @override
  String get playerQueue => '队列';

  @override
  String get playerNext => '下一首';

  @override
  String get playerPrevious => '上一首';

  @override
  String get playerPlayPause => '播放 / 暂停';

  @override
  String get playerIdleTitle => '未在播放';

  @override
  String get playerIdleSubtitle => '从首页、音乐库或播放列表开始播放';

  @override
  String get albumPlayAll => '播放全部';

  @override
  String get albumShufflePlay => '随机播放';

  @override
  String albumSongCount(int count) {
    return '$count 首歌曲';
  }

  @override
  String get artistPlayAll => '播放全部';

  @override
  String get artistAlbums => '专辑';

  @override
  String artistAlbumCount(int count) {
    return '$count 张专辑';
  }

  @override
  String get playlistsTitle => '播放列表';

  @override
  String get playlistCreate => '新建播放列表';

  @override
  String get playlistRename => '重命名';

  @override
  String get playlistDelete => '删除';

  @override
  String get playlistEdit => '编辑';

  @override
  String get playlistSave => '保存';

  @override
  String get playlistCancel => '取消';

  @override
  String get playlistNameHint => '请输入播放列表名称';

  @override
  String playlistSongCount(int count) {
    return '$count 首';
  }

  @override
  String get playlistEmpty => '暂无播放列表';

  @override
  String get playlistReorderHint => '长按拖拽排序，左滑可删除';

  @override
  String get favoritesTitle => '收藏';

  @override
  String get favoritesTabSongs => '歌曲';

  @override
  String get favoritesTabAlbums => '专辑';

  @override
  String get favoritesTabArtists => '艺术家';

  @override
  String get favoritesEmpty => '暂无收藏';

  @override
  String get downloadsTitle => '下载管理';

  @override
  String get downloadsTotal => '全部任务';

  @override
  String get downloadsCompleted => '已完成';

  @override
  String get downloadsOfflineSongs => '离线歌曲';

  @override
  String get downloadsEmpty => '暂无下载任务';

  @override
  String get downloadsClearCompleted => '清除已完成';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsServer => '服务器';

  @override
  String get settingsCurrentServer => '当前服务器';

  @override
  String get settingsLogout => '退出登录';

  @override
  String get settingsTheme => '主题';

  @override
  String get settingsThemeSystem => '跟随系统';

  @override
  String get settingsThemeDark => '深色';

  @override
  String get settingsThemeLight => '浅色';

  @override
  String get settingsAudioQuality => '音质设置';

  @override
  String get settingsAbout => '关于';

  @override
  String get settingsVersion => '版本';

  @override
  String get audioQualityTitle => '音质设置';

  @override
  String get audioQualityOriginal => '原始品质（无损）';

  @override
  String get audioQualityHigh => '高品质';

  @override
  String get audioQualityMedium => '中等品质';

  @override
  String get audioQualityLow => '低品质';

  @override
  String audioQualityKbps(int kbps) {
    return '$kbps kbps';
  }

  @override
  String audioQualityMp3Label(int kbps) {
    return 'MP3 ${kbps}k';
  }

  @override
  String get scrobbleTitle => '播放记录';

  @override
  String get scrobbleEmpty => '暂无播放记录';

  @override
  String scrobblePlayCount(int count) {
    return '播放 $count 次';
  }

  @override
  String get scrobbleSubtitle => '记录你的音乐喜好 · 自动 Scrobble 到服务器';

  @override
  String get scrobbleSessionPlays => '本次播放';

  @override
  String get scrobbleUniqueArtists => '不同艺术家';

  @override
  String get scrobbleUniqueAlbums => '不同专辑';

  @override
  String get scrobbleAutoDesc => '播放超过 50% 或 4 分钟自动记录';

  @override
  String get scrobbleEnabled => '已启用';

  @override
  String get scrobbleRecentTitle => '最近播放';

  @override
  String scrobbleRecentCount(int count) {
    return '共 $count 首';
  }

  @override
  String get scrobbleEmptyHint => '暂无播放记录\n开始播放音乐后将在这里记录';

  @override
  String get multiServerTitle => '多服务器管理';

  @override
  String get multiServerAdd => '添加服务器';

  @override
  String get multiServerCurrent => '当前';

  @override
  String get multiServerSwitch => '切换';

  @override
  String get multiServerDelete => '删除';

  @override
  String get multiServerEmpty => '暂无额外服务器';

  @override
  String get contextMenuPlay => '播放';

  @override
  String get contextMenuPlayNext => '播放下一首';

  @override
  String get contextMenuAddQueue => '添加到队列';

  @override
  String get contextMenuAddPlaylist => '添加到播放列表';

  @override
  String get contextMenuStar => '收藏';

  @override
  String get contextMenuDownload => '下载到本地';

  @override
  String get contextMenuImportNavidrome => '导入到 Navidrome';

  @override
  String get contextMenuAddedNext => '已添加到下一首播放';

  @override
  String get contextMenuAddedQueue => '已添加到队列';

  @override
  String get contextMenuStarred => '已收藏';

  @override
  String get contextMenuDownloading => '已加入下载队列';

  @override
  String get contextMenuImportingNavidrome => '正在导入到 Navidrome…';

  @override
  String get contextMenuImportedNavidrome => '已导入到 Navidrome 并触发扫描';

  @override
  String get contextMenuImportedNavidromePendingScan => '已导入到 Navidrome，等待自动扫描';

  @override
  String get contextMenuImportNavidromeFailed => '导入到 Navidrome 失败';

  @override
  String get contextMenuQueueingNavidrome => '正在提交到 NAS 下载队列…';

  @override
  String get contextMenuQueuedNavidrome => '已提交到 NAS 下载队列';

  @override
  String contextMenuAddedPlaylist(String name) {
    return '已添加到 $name';
  }

  @override
  String get contextMenuSelectPlaylist => '选择播放列表';

  @override
  String get contextMenuLoadFailed => '加载播放列表失败';

  @override
  String get commonCancel => '取消';

  @override
  String get commonSave => '保存';

  @override
  String get commonDelete => '删除';

  @override
  String get commonConfirm => '确定';

  @override
  String get commonLoading => '加载中...';

  @override
  String get commonError => '出错了';

  @override
  String get commonRetry => '重试';

  @override
  String get commonRefresh => '刷新数据';

  @override
  String get commonNoData => '暂无数据';

  @override
  String commonSongs(int count) {
    return '$count 首';
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
  String get commonAll => '全部';

  @override
  String get commonBack => '返回';

  @override
  String get commonLoadFailed => '加载失败';

  @override
  String get commonUnknownArtist => '未知艺术家';

  @override
  String get commonCreate => '创建';

  @override
  String get commonNew => '新建';

  @override
  String get playerQueueEmpty => '队列为空';

  @override
  String get playerNoContent => '暂无播放内容';

  @override
  String get playerNoContentHint => '从音乐库或搜索中选择歌曲开始播放';

  @override
  String playerSpeedValue(double speed) {
    return '${speed}x';
  }

  @override
  String get playerUnfavorite => '取消收藏';

  @override
  String get albumAddToQueue => '加入队列';

  @override
  String get albumFavorite => '收藏专辑';

  @override
  String get albumUnfavorite => '取消收藏';

  @override
  String get albumTitle => '标题';

  @override
  String get albumDuration => '时长';

  @override
  String albumSongDuration(String year, int count, String duration) {
    return '$year · $count 首歌曲 · $duration';
  }

  @override
  String get artistUnfavorited => '已取消收藏';

  @override
  String get downloadsUsedSpace => '已用空间';

  @override
  String get downloadsQueue => '下载队列';

  @override
  String get downloadsHint => '在歌曲菜单中选择\"下载\"';

  @override
  String get downloadsPending => '等待中';

  @override
  String get downloadsFailed => '失败';

  @override
  String get multiServerManage => '服务器管理';

  @override
  String multiServerCount(int count) {
    return '共 $count 个服务器';
  }

  @override
  String get multiServerDeleteTitle => '删除服务器';

  @override
  String multiServerDeleteConfirm(String name) {
    return '确定要删除「$name」吗？';
  }

  @override
  String get multiServerEdit => '编辑服务器';

  @override
  String get multiServerName => '服务器名称';

  @override
  String get multiServerNameHint => '我的 Navidrome';

  @override
  String get multiServerUrl => '服务器地址';

  @override
  String get multiServerUsername => '用户名';

  @override
  String get multiServerPassword => '密码';

  @override
  String get serverUrlExample => 'https://music.example.com';

  @override
  String get multiServerEmptyHint => '暂无服务器\n点击上方按钮添加';

  @override
  String get searchAll => '全部';

  @override
  String get searchHintInput => '搜索歌曲、艺术家、专辑...';

  @override
  String get searchPlaceholder => '输入关键词搜索音乐';

  @override
  String get searchNoResult => '无搜索结果';

  @override
  String get searchResults => '搜索结果';

  @override
  String get libraryNoArtists => '暂无艺术家';

  @override
  String get libraryNoAlbums => '暂无专辑';

  @override
  String get libraryNoSongs => '暂无歌曲';

  @override
  String get audioQualityOriginalName => '原始音质';

  @override
  String get audioQualityOriginalDesc => '无转码';

  @override
  String get audioQualityMp3128Desc => '节省流量';

  @override
  String get audioQualitySelection => '音质选择';

  @override
  String get playlistNameLabel => '播放列表名称';

  @override
  String playlistCreated(String name) {
    return '已创建播放列表 \"$name\"';
  }

  @override
  String get playlistCreateFailed => '创建失败';

  @override
  String get playlistDeleteTitle => '删除播放列表';

  @override
  String playlistDeleteConfirm(String name) {
    return '确定要删除\"$name\"吗？此操作不可撤销。';
  }

  @override
  String playlistDeleted(String name) {
    return '已删除\"$name\"';
  }

  @override
  String get playlistDeleteFailed => '删除失败';

  @override
  String playlistCount(int count) {
    return '共 $count 个播放列表';
  }

  @override
  String get playlistCreatedList => '已创建的列表';

  @override
  String get playlistEmptyTitle => '还没有播放列表';

  @override
  String get playlistEmptyHint => '创建一个播放列表来整理你的音乐';

  @override
  String playlistSongCountLabel(int count) {
    return '$count 首歌曲';
  }

  @override
  String get playlistPlay => '播放';

  @override
  String get playlistListEmpty => '播放列表为空';

  @override
  String get playlistRenameTitle => '重命名播放列表';

  @override
  String get playlistNewName => '新名称';

  @override
  String songContextAddedToPlaylist(String name) {
    return '已添加到 $name';
  }

  @override
  String get defaultServerName => '我的服务器';

  @override
  String get navSongs => '歌曲';

  @override
  String get navAlbums => '专辑';

  @override
  String get navArtists => '歌手';

  @override
  String get navAlbumArtists => '专辑艺术家';

  @override
  String get navGenres => '流派';

  @override
  String get navRadio => '电台';

  @override
  String get sidebarLibrary => '音乐库';

  @override
  String get homeNewestAlbums => '最新专辑';

  @override
  String get homeDailyRecommend => '每日推荐';

  @override
  String get homeRecentlyPlayed => '最近播放';

  @override
  String get homeViewMore => '更多';

  @override
  String get libraryGenresTitle => '流派';

  @override
  String get libraryRadioTitle => '网络电台';

  @override
  String get libraryRadioEmpty => '暂无电台';

  @override
  String get libraryNoGenres => '暂无流派';

  @override
  String get libraryAlbumArtistsTitle => '专辑艺术家';

  @override
  String genreSongCount(int count) {
    return '$count 首歌曲';
  }

  @override
  String genreAlbumCount(int count) {
    return '$count 张专辑';
  }

  @override
  String get contextMenuDelete => '删除歌曲';

  @override
  String contextMenuDeleteConfirm(String title, String artist) {
    return '确定要从服务器删除「$title」($artist)？\n此操作不可恢复。';
  }

  @override
  String get contextMenuDeleteSuccess => '删除成功';

  @override
  String get contextMenuDeleteError => '删除失败';

  @override
  String get settingsUnlimited => '无限制';

  @override
  String get settingsUser => '用户';

  @override
  String get settingsQuality => '音质';

  @override
  String get settingsMaxBitrate => '最大码率';

  @override
  String settingsAboutText(String appName, String version) {
    return '$appName v$version\n跨平台音乐客户端';
  }

  @override
  String get settingsLogoutConfirm => '确定要退出登录吗？';

  @override
  String get settingsCacheCalculating => '计算中...';

  @override
  String get settingsCacheUnknown => '未知';

  @override
  String get settingsCacheCleared => '缓存已清除';

  @override
  String get settingsCacheClearFailed => '清除失败';

  @override
  String get settingsCacheStorage => '缓存与存储';

  @override
  String get settingsCacheUsed => '已使用';

  @override
  String get settingsCacheMaxCache => '最大缓存';

  @override
  String get settingsCacheClear => '清除';

  @override
  String get searchBackendNavidrome => 'Navidrome';

  @override
  String get searchBackendNetease => '网易云';

  @override
  String get searchBackendKuwo => '酷我';

  @override
  String get searchBackendJoox => 'JOOX';

  @override
  String get playerShuffle => '随机播放';

  @override
  String get playerRepeat => '循环播放';

  @override
  String get tooltipUnfavorite => '取消收藏';

  @override
  String get tooltipPlay => '播放';

  @override
  String get tooltipFavorite => '收藏';

  @override
  String get tooltipRemove => '移除';

  @override
  String get tooltipEdit => '编辑';

  @override
  String get tooltipDelete => '删除';

  @override
  String get tooltipClear => '清除';

  @override
  String get tooltipBack => '返回';

  @override
  String get tooltipMore => '更多';

  @override
  String get updateCheckUpdate => '检查更新';

  @override
  String get updateChecking => '检查中...';

  @override
  String updateNewVersion(String version) {
    return '发现新版本 v$version';
  }

  @override
  String get updateChangelog => '更新内容';

  @override
  String get updateDownload => '下载更新';

  @override
  String get updateLatest => '已是最新版本';

  @override
  String get updateFailed => '检查更新失败，请稍后重试';

  @override
  String get contextMenuDeleteTitle => '确认删除';

  @override
  String get contextMenuDeleted => '已删除';

  @override
  String get contextMenuDeleteFailed => '删除失败，请稍后重试';
}
