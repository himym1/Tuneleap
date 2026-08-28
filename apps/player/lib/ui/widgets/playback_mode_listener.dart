import 'dart:async';

import 'package:flutter/material.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/player/audio_player_service.dart';

/// Selected-mode style that stays readable on cover-tinted palettes.
///
/// Material 3 [IconButton.isSelected] defaults to `secondaryContainer` /
/// `onSecondaryContainer`. A pale album seed makes that a white glyph on a
/// light pill — the loop button vanishing on light covers.
ButtonStyle playbackModeButtonStyle({required Color iconColor}) {
  return IconButton.styleFrom(
    foregroundColor: iconColor,
    disabledForegroundColor: iconColor.withValues(alpha: 0.38),
  ).copyWith(
    foregroundColor: WidgetStateProperty.all(iconColor),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return iconColor.withValues(alpha: 0.12);
      }
      return Colors.transparent;
    }),
    overlayColor: WidgetStateProperty.resolveWith((states) {
      return iconColor.withValues(
        alpha: states.contains(WidgetState.pressed) ? 0.16 : 0.08,
      );
    }),
  );
}

class PlaybackModeIconButton extends StatelessWidget {
  const PlaybackModeIconButton({
    super.key,
    required this.selected,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.iconColor,
    this.size = 22,
    this.padding,
    this.constraints,
  });

  final bool selected;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color iconColor;
  final double size;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      isSelected: selected,
      style: playbackModeButtonStyle(iconColor: iconColor),
      icon: Icon(icon, size: size),
      tooltip: tooltip,
      onPressed: onPressed,
      padding: padding,
      constraints: constraints,
    );
  }
}

class PlaybackModeListener extends StatefulWidget {
  const PlaybackModeListener({
    required this.playerService,
    required this.builder,
    super.key,
  });

  final AudioPlayerService playerService;
  final Widget Function(
    BuildContext context,
    bool shuffle,
    PlaybackRepeatMode repeatMode,
  )
  builder;

  @override
  State<PlaybackModeListener> createState() => _PlaybackModeListenerState();
}

class _PlaybackModeListenerState extends State<PlaybackModeListener> {
  StreamSubscription<(bool, PlaybackRepeatMode)>? _sub;
  late bool _shuffle;
  late PlaybackRepeatMode _repeatMode;

  @override
  void initState() {
    super.initState();
    _shuffle = widget.playerService.shuffle;
    _repeatMode = widget.playerService.repeatMode;
    _sub = widget.playerService.playbackModeStream.listen((mode) {
      if (!mounted) return;
      setState(() {
        _shuffle = mode.$1;
        _repeatMode = mode.$2;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _shuffle, _repeatMode);
  }
}

String playbackShuffleTooltip(S l10n, bool enabled) {
  return enabled ? l10n.playerShuffleOn : l10n.playerShuffleOff;
}

String playbackRepeatTooltip(S l10n, PlaybackRepeatMode mode) {
  return switch (mode) {
    PlaybackRepeatMode.off => l10n.playerRepeatOff,
    PlaybackRepeatMode.all => l10n.playerRepeatAll,
    PlaybackRepeatMode.one => l10n.playerRepeatOne,
  };
}

IconData playbackRepeatIcon(PlaybackRepeatMode mode) {
  return mode == PlaybackRepeatMode.one
      ? Icons.repeat_one_rounded
      : Icons.repeat_rounded;
}
