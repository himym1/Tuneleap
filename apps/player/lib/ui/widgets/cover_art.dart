import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:navidrome_player/api/models/song.dart';
import 'package:navidrome_player/providers/audio_providers.dart';
import 'package:navidrome_player/api/media_request_headers.dart';

/// 封面图组件，带缓存、细腻边缘高光和可选环境投影
class CoverArt extends StatelessWidget {
  final String url;
  final double? size;
  final double borderRadius;
  final bool loading;
  final bool hasShadow;
  final Color? shadowColor;

  const CoverArt({
    super.key,
    required this.url,
    this.size,
    this.borderRadius = 10,
    this.loading = false,
    this.hasShadow = false,
    this.shadowColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final outlineColor = (isDark ? Colors.white : Colors.black).withValues(
      alpha: isDark ? 0.08 : 0.05,
    );

    Widget imageContent;
    if (url.isEmpty) {
      imageContent = loading
          ? _loadingPlaceholder(context)
          : _emptyPlaceholder(context);
    } else {
      imageContent = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: CachedNetworkImage(
          imageUrl: url,
          httpHeaders: mediaRequestHeaders(url),
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => _loadingPlaceholder(context),
          errorWidget: (context, url, error) => _emptyPlaceholder(context),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: (shadowColor ?? (isDark ? Colors.black : Colors.grey))
                      .withValues(alpha: isDark ? 0.40 : 0.20),
                  blurRadius: size != null ? (size! * 0.18).clamp(8, 36) : 20,
                  offset: Offset(
                    0,
                    size != null ? (size! * 0.06).clamp(3, 12) : 6,
                  ),
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          imageContent,
          // Specular subtle rim highlight
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(color: outlineColor, width: 0.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingPlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: colorScheme.surfaceContainerHighest,
      highlightColor: colorScheme.surfaceContainerHigh,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  Widget _emptyPlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.music_note_rounded,
        size: size == null ? 48 : (size! * 0.42).clamp(16, 56),
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
      ),
    );
  }
}

class ResolvedSongCoverArt extends ConsumerStatefulWidget {
  const ResolvedSongCoverArt({
    super.key,
    required this.song,
    this.size,
    this.borderRadius = 10,
    this.hasShadow = false,
    this.shadowColor,
  });

  final Song song;
  final double? size;
  final double borderRadius;
  final bool hasShadow;
  final Color? shadowColor;

  @override
  ConsumerState<ResolvedSongCoverArt> createState() =>
      _ResolvedSongCoverArtState();
}

class _ResolvedSongCoverArtState extends ConsumerState<ResolvedSongCoverArt> {
  late Future<String> _url;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ResolvedSongCoverArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.storageKey != widget.song.storageKey ||
        oldWidget.size != widget.size) {
      _resolve();
    }
  }

  void _resolve() {
    _url = ref
        .read(songMediaResolverProvider)
        .coverArtUrl(
          widget.song,
          size: (widget.size ?? 300).round().clamp(100, 1000),
        );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _url,
      builder: (context, snapshot) => CoverArt(
        url: snapshot.data ?? '',
        size: widget.size,
        borderRadius: widget.borderRadius,
        hasShadow: widget.hasShadow,
        shadowColor: widget.shadowColor,
        loading: snapshot.connectionState == ConnectionState.waiting,
      ),
    );
  }
}
