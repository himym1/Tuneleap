import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/media_request_headers.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/utils/cover_color.dart';

// ============================================================
// 封面取色 — 从封面 URL 提取主色调
// ============================================================

/// 从封面图 URL 异步提取主色，供播放器动态主题使用。
/// 用 FutureProvider.family 以 URL 为 key 自动缓存，切歌时自动失效/重建。
final coverColorProvider = FutureProvider.family<Color, String>((
  ref,
  url,
) async {
  if (url.isEmpty) return AppColors.primary;
  try {
    return await extractCoverSeedColorFromProvider(
      CachedNetworkImageProvider(url, headers: mediaRequestHeaders(url)),
      fallback: AppColors.primary,
    );
  } catch (_) {
    return AppColors.primary;
  }
});
