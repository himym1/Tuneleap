import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => _placeholder(context),
        errorWidget: (context, url, error) => _placeholder(context),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        Icons.album,
        size: size != null ? size! * 0.5 : 32,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
