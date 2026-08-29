// Barrel file — 统一导出所有 provider 模块
//
// 外部只需 `import 'package:navidrome_player/providers/providers.dart';`
// 即可访问所有 provider，无需修改现有 import 路径。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';

export 'server_config_provider.dart';
export 'auth_provider.dart';
export 'cloud_auth_provider.dart';
export 'audio_providers.dart';
export 'theme_provider.dart';
export 'download_provider.dart';
export 'navidrome_import_provider.dart';
export 'nas_import_queue_provider.dart';
export 'navidrome_delete_provider.dart';
export 'cover_color_provider.dart';
export 'library_cache_provider.dart';
export 'playlist_provider.dart';
export 'playlist_detail_provider.dart';
export 'search_provider.dart';
export 'online_source_preferences.dart';
export 'library_provider.dart';
export 'library_search_provider.dart';
export 'album_detail_provider.dart';
export 'weather_provider.dart';
export 'recommendation_provider.dart';
export 'library_audit_provider.dart';
export 'library_style_provider.dart';
export 'library_playlist_organize_provider.dart';

final appVersionProvider = Provider<String>(
  (ref) => throw UnimplementedError('Must be overridden in ProviderScope'),
);

final appBuildProvider = Provider<int>(
  (ref) => throw UnimplementedError('Must be overridden in ProviderScope'),
);

// ============================================================
// 全局主题色 — 跟随当前播放歌曲的封面色
// ============================================================

final globalAccentColorProvider =
    NotifierProvider<GlobalAccentColorNotifier, Color>(
      GlobalAccentColorNotifier.new,
    );

class GlobalAccentColorNotifier extends Notifier<Color> {
  @override
  Color build() => AppColors.primary;

  void setColor(Color color) => state = color;

  void clear() => state = AppColors.primary;
}
