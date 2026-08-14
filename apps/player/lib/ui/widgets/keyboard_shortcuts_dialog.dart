import 'package:flutter/material.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/utils/platform_utils.dart';

class KeyboardShortcutsDialog extends StatelessWidget {
  const KeyboardShortcutsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const KeyboardShortcutsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final mod = isMacOS ? '⌘' : 'Ctrl';
    final rows = [
      (s.shortcutsPlayPause, 'Space'),
      (s.shortcutsPrevious, 'Alt + ←'),
      (s.shortcutsNext, 'Alt + →'),
      (s.navHome, '$mod + 1'),
      (s.navLibrary, '$mod + 2'),
      (s.navSearch, '$mod + 3 / $mod + F'),
      (s.navPlaylists, '$mod + 4'),
      (s.navSettings, '$mod + 5'),
      (s.playerNowPlaying, '$mod + P'),
      (s.shortcutsClosePlayer, 'Esc'),
      (s.shortcutsTitle, '$mod + /'),
    ];

    return AlertDialog(
      title: Text(s.shortcutsTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(row.$1)),
                    Text(
                      row.$2,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.commonCancel),
        ),
      ],
    );
  }
}
