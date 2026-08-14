import 'package:flutter/material.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

/// 歌曲列表项组件
class SongTile extends StatelessWidget {
  final Song song;
  final VoidCallback? onTap;
  final VoidCallback? onMore;

  const SongTile({super.key, required this.song, this.onTap, this.onMore});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text(
          song.track?.toString() ?? '#',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${song.artist} · ${song.album}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (song.duration != null)
            Text(
              song.formattedDuration,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (onMore != null)
            IconButton(
              icon: const Icon(Icons.more_vert, size: 20),
              tooltip: S.of(context).tooltipMore,
              onPressed: onMore,
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}
