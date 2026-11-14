import 'package:flutter/material.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/utils/playlist_track_filter.dart';

/// 持有歌单内搜索框，并把匹配到的原列表下标交给子树。
class PlaylistTrackQuery extends StatefulWidget {
  const PlaylistTrackQuery({
    super.key,
    required this.songs,
    required this.builder,
  });

  final List<Song> songs;
  final Widget Function(
    BuildContext context,
    TextEditingController controller,
    List<int> indexes,
  )
  builder;

  @override
  State<PlaylistTrackQuery> createState() => _PlaylistTrackQueryState();
}

class _PlaylistTrackQueryState extends State<PlaylistTrackQuery> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      _controller,
      playlistTrackMatchIndexes(widget.songs, _controller.text),
    );
  }
}

class PlaylistTrackSearchField extends StatelessWidget {
  const PlaylistTrackSearchField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final strings = S.of(context);
    final hasQuery = controller.text.trim().isNotEmpty;
    return TextField(
      key: const Key('playlist-track-search'),
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: strings.playlistTrackSearchHint,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: hasQuery
            ? IconButton(
                tooltip: strings.tooltipClear,
                onPressed: controller.clear,
                icon: const Icon(Icons.close_rounded),
              )
            : null,
      ),
    );
  }
}
