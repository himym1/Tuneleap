import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:navidrome_player/api/media_request_headers.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';

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
    final generator = await PaletteGenerator.fromImageProvider(
      CachedNetworkImageProvider(url, headers: mediaRequestHeaders(url)),
      size: const Size(100, 100),
      timeout: const Duration(seconds: 5),
    );
    return generator.vibrantColor?.color ??
        generator.dominantColor?.color ??
        AppColors.primary;
  } catch (_) {
    return AppColors.primary;
  }
});
