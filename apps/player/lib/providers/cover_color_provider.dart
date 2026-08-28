import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/media_request_headers.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/utils/cover_color.dart';

// ============================================================
// 封面取色 — 从封面 URL 提取主色调
// ============================================================

/// Atmosphere + graphic accent from a cover URL. Cached by URL.
final coverPaletteProvider = FutureProvider.family<CoverPalette, String>((
  ref,
  url,
) async {
  if (url.isEmpty) {
    return CoverPalette(seed: AppColors.primary, accent: AppColors.primary);
  }
  try {
    return await extractCoverPaletteFromProvider(
      CachedNetworkImageProvider(url, headers: mediaRequestHeaders(url)),
      fallback: AppColors.primary,
    );
  } catch (_) {
    return CoverPalette(seed: AppColors.primary, accent: AppColors.primary);
  }
});

/// Cover atmosphere only. Used as the dynamic theme seed.
final coverColorProvider = FutureProvider.family<Color, String>((
  ref,
  url,
) async {
  return (await ref.watch(coverPaletteProvider(url).future)).seed;
});
