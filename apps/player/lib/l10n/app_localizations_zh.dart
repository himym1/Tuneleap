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
  String get navPlaylists => '歌单';

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
  String get loginSubtitle => '输入账号密码即可，曲库与 Cloud 地址已内置';

  @override
  String get loginConnect => '连接';

  @override
  String get loginFieldsRequired => '请填写用户名和密码';

  @override
  String get loginFailed => '登录失败，请检查用户名和密码';

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
  String get playerMoreActions => '更多';

  @override
  String get playerClearQueue => '清空队列';

  @override
  String get playerClose => '关闭播放页';

  @override
  String get shortcutsTitle => '键盘快捷键';

  @override
  String get shortcutsPlayPause => '播放 / 暂停';

  @override
  String get shortcutsPrevious => '上一首';

  @override
  String get shortcutsNext => '下一首';

  @override
  String get shortcutsClosePlayer => '关闭正在播放';

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
  String get settingsThemeStyle => '主题风格';

  @override
  String get settingsThemeClassic => '经典';

  @override
  String get settingsThemeAmoled => '纯黑';

  @override
  String get settingsThemeDynamic => '封面取色';

  @override
  String get settingsAudioQuality => '音质设置';

  @override
  String get settingsAbout => '关于';

  @override
  String get settingsServerUnconfigured => '未配置';

  @override
  String get settingsTools => '工具';

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
  String get importDuplicateTitle => '歌曲已存在';

  @override
  String importDuplicateMessage(String title, String artist) {
    return '「$title」($artist) 在本地库中已存在，是否仍要导入？';
  }

  @override
  String get importAnyway => '仍然导入';

  @override
  String get importDuplicateCheckFailed => '无法核对 NAS 曲库，已停止导入';

  @override
  String get nasAgentConfigRequired => '请先登录 Cloud 后再导入或删除';

  @override
  String get commonContinue => '继续';

  @override
  String get contextMenuQueueingNavidrome => '正在提交到 NAS 下载队列…';

  @override
  String get contextMenuQueuedNavidrome => '已加入导入队列';

  @override
  String get nasImportViewQueue => '查看';

  @override
  String get contextMenuDeleting => '正在删除…';

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
  String get downloadsOfflineTab => '本机离线';

  @override
  String get downloadsNasImportTab => '导入曲库';

  @override
  String get downloadsNasImportHint => '在线歌曲点「+」加入导入队列';

  @override
  String get downloadsNasImportEmpty => '暂无导入任务';

  @override
  String get nasImportAlreadyQueued => '已在导入队列中';

  @override
  String get nasImportStageResolving => '准备中';

  @override
  String get nasImportStageUploading => '下载到 NAS';

  @override
  String get nasImportClearFinished => '清除已结束';

  @override
  String get nasImportErrorFailed => '导入失败';

  @override
  String get nasImportErrorTimeout => 'NAS 下载超时，等当前传输结束后再重试';

  @override
  String get nasImportErrorUnavailable => 'NAS 暂时不可用';

  @override
  String get nasImportErrorSlowUpstream => '源站线路太慢，重试会换一条 CDN';

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
  String get backendUrl => '云端 API 地址';

  @override
  String get backendUrlHint =>
      'navidrome-cloud 公网地址，例如 https://cloud.example.com';

  @override
  String get cloudAccount => 'Cloud 账号';

  @override
  String get cloudSignedIn => '已登录';

  @override
  String get cloudSignedOut => '未登录';

  @override
  String get cloudSignIn => '登录';

  @override
  String get cloudRegister => '注册';

  @override
  String get cloudUsername => 'Cloud 用户名';

  @override
  String get cloudCredential => 'Cloud 账号凭据';

  @override
  String get cloudSignOut => '退出 Cloud';

  @override
  String get cloudAuthFailed => 'Cloud 认证失败';

  @override
  String get cloudInvalidInput => '用户名至少 2 个字符，账号凭据至少 8 个字符';

  @override
  String get cloudInvalidCredentials => 'Cloud 用户名或账号凭据错误';

  @override
  String get cloudUsernameExists => '该 Cloud 用户名已存在，请直接登录或更换用户名';

  @override
  String get cloudNetworkError => '无法连接 Cloud，请检查网络后重试';

  @override
  String get cloudAuthRequired => '登录 Cloud 后加载推荐';

  @override
  String get searchAuthRequired => 'Cloud 登录已失效，请重新登录后再搜索';

  @override
  String get nasAgentUrl => 'NAS Agent 地址';

  @override
  String get nasAgentUrlHint => '导入/删除必填，请使用局域网地址，例如 http://192.168.1.10:8504';

  @override
  String get nasAgentKey => 'NAS Agent Key';

  @override
  String get nasAgentKeyHint => '仅用于局域网导入/删除';

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
  String searchError(String error) {
    return '搜索失败: $error';
  }

  @override
  String get searchRateLimited => '搜索请求过于频繁，请稍后重试。';

  @override
  String get searchServiceUnavailable => '当前搜索服务暂不可用。';

  @override
  String searchSourceUnavailable(String source) {
    return '$source搜索服务暂不可用。';
  }

  @override
  String get searchFailedTryAgain => '搜索失败，请重试。';

  @override
  String get searchResults => '搜索结果';

  @override
  String get searchLoadMore => '加载更多';

  @override
  String get searchLoadingMore => '加载中…';

  @override
  String get searchLoadMoreFailed => '下一页加载失败';

  @override
  String get searchPlaybackUnavailable => '当前歌曲暂时无法播放';

  @override
  String searchPlaybackFailed(String error) {
    return '播放失败: $error';
  }

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
  String get playlistAddSongs => '添加歌曲';

  @override
  String get playlistAddSongsTitle => '添加歌曲到歌单';

  @override
  String get playlistSearchSongsHint => '搜索本地曲库';

  @override
  String get playlistNoMatchingSongs => '没有匹配的歌曲';

  @override
  String get playlistAddSelected => '添加所选';

  @override
  String playlistSongsAdded(int count) {
    return '已添加 $count 首';
  }

  @override
  String get playlistRenameTitle => '重命名播放列表';

  @override
  String get playlistNewName => '新名称';

  @override
  String songContextAddedToPlaylist(String name) {
    return '已添加到 $name';
  }

  @override
  String get playlistSaveQueue => '将队列保存为歌单';

  @override
  String playlistQueueSaved(String name) {
    return '已将队列保存为「$name」';
  }

  @override
  String playlistQueueSavedSkipped(String name, int count) {
    return '已保存为「$name」，跳过 $count 首线上歌曲';
  }

  @override
  String get playlistQueueNoLocalSongs => '只有本地曲库歌曲可以保存到歌单';

  @override
  String get playlistQueueSaveFailed => '保存队列失败';

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
  String get libraryBrowse => '浏览音乐库';

  @override
  String get homeNewestAlbums => '最新专辑';

  @override
  String get homeDailyRecommend => '发现新音乐';

  @override
  String get homeRecentlyPlayed => '最近播放';

  @override
  String get homeYourMusic => '我的音乐';

  @override
  String get homeContinueListening => '继续听';

  @override
  String get homeLocalMix => '为你播放';

  @override
  String get homeShuffleLocal => '随机播放曲库';

  @override
  String get homeLocalPlaybackFailed => '无法开始本地播放';

  @override
  String get homeViewMore => '更多';

  @override
  String get homeRefreshed => '首页已刷新';

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
  String get searchBackendTencent => 'QQ';

  @override
  String get searchBackendKugou => '酷狗';

  @override
  String get searchBackendMigu => '咪咕';

  @override
  String get searchBackendKuwo => '酷我';

  @override
  String get searchBackendJoox => 'JOOX';

  @override
  String get settingsOnlineSources => '在线搜索源';

  @override
  String get settingsOnlineSourcesHint => '按平台分开搜索。请求仍走 Cloud，不用在 App 里填第三方密钥。';

  @override
  String get settingsOnlineSourcesKeepOne => '至少保留一个搜索源';

  @override
  String get settingsOnlineAdapter => '搜索 API';

  @override
  String get settingsOnlineAdapterAuto => '自动';

  @override
  String get settingsOnlineAdapterUnavailable => '无法加载 Cloud 搜索 API，已使用自动兼容模式。';

  @override
  String get searchFilterOnline => '在线';

  @override
  String get searchSectionLocal => '本地搜索结果';

  @override
  String get searchSectionOnline => '在线搜索结果';

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
  String get updateInstall => '立即安装';

  @override
  String get updateInstalling => '正在安装…';

  @override
  String get updateAlreadyDownloaded => '安装包已下载完成，可直接安装，无需重新下载。';

  @override
  String get updateLatest => '已是最新版本';

  @override
  String get updateFailed => '检查更新失败，请稍后重试';

  @override
  String get updateMacInstallHint => '安装包已打开。请把「音跃」拖进「应用程序」替换当前版本，然后重新打开。';

  @override
  String get updateWindowsInstallHint =>
      '安装包已打开。请解压后覆盖当前音跃目录，然后重新运行 navidrome_player.exe。';

  @override
  String get contextMenuDeleteTitle => '确认删除';

  @override
  String get contextMenuDeleted => '已删除';

  @override
  String get contextMenuDeleteFailed => '删除失败，请稍后重试';

  @override
  String get contextMenuDeleteNotFound => '曲库里找不到这首歌，请下拉刷新后再试';

  @override
  String contextMenuDeleteFailedReason(String reason) {
    return '删除失败：$reason';
  }

  @override
  String get recommendationsTitle => '推荐';

  @override
  String get recommendationsEmpty => '暂无推荐';

  @override
  String get recommendationsBackendMissing => '请先配置 Backend 以启用推荐';

  @override
  String get recommendationsRetry => '重试';

  @override
  String get recommendationsDislike => '不感兴趣';

  @override
  String get recommendationsImport => '导入';

  @override
  String get recommendationsViewAll => '查看全部';

  @override
  String get recommendationsSubtitle => '根据最近播放和你的反馈生成';

  @override
  String get recommendationsModeAi => 'AI 推荐';

  @override
  String get recommendationsModeFallback => '规则推荐';

  @override
  String get recommendationsSimilar => '相似推荐';

  @override
  String get recommendationsExplore => '探索推荐';

  @override
  String get recommendationsRefreshed => '推荐已更新';

  @override
  String get recommendationsRefreshing => '正在刷新推荐';

  @override
  String get settingsResetRecommendations => '重置推荐偏好';

  @override
  String get settingsResetRecommendationsConfirm =>
      '重置推荐偏好？歌曲、下载、播放历史和服务器配置不受影响。';

  @override
  String get settingsResetRecommendationsDone => '推荐偏好已重置';
}
