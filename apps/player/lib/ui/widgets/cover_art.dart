import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:navidrome_player/api/models/song.dart';
import 'package:navidrome_player/providers/audio_providers.dart';
import 'package:navidrome_player/api/media_request_headers.dart';

/// 封面图组件，带缓存和 placeholder
class CoverArt extends StatelessWidget {
  final String url;
  final double? size;
  final double borderRadius;
  final bool loading;

  const CoverArt({
    super.key,
    required this.url,
    this.size,
    this.borderRadius = 8,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return loading
          ? _loadingPlaceholder(context)
          : _emptyPlaceholder(context);
    }
    return ClipRRect(
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
    this.borderRadius = 8,
  });

  final Song song;
  final double? size;
  final double borderRadius;

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
        loading: snapshot.connectionState == ConnectionState.waiting,
      ),
    );
  }
}
