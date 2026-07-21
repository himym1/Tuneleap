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

  const CoverArt({
    super.key,
    required this.url,
    this.size,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return _placeholder(context);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: url,
        httpHeaders: mediaRequestHeaders(url),
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => _placeholder(context),
        errorWidget: (context, url, error) => _placeholder(context),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
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
      ),
    );
  }
}
