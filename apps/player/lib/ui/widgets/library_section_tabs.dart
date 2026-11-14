import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/ui/widgets/segmented_control.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';

/// Shared primary navigation for every library section.
class LibrarySectionTabs extends StatelessWidget {
  const LibrarySectionTabs({super.key});

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final sections = [
      AppSegmentItem(value: '/library/songs', label: S.of(context).navSongs),
      AppSegmentItem(value: '/library/albums', label: S.of(context).navAlbums),
      AppSegmentItem(
        value: '/library/artists',
        label: S.of(context).navArtists,
      ),
    ];

    return Row(
      children: [
        Expanded(
          child: AppSegmentedControl<String>(
            items: sections,
            selected: path,
            onSelected: (target) => context.go(target),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: context.colors.subtleSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.colors.hairlineBorder,
              width: 0.8,
            ),
          ),
          child: PopupMenuButton<String>(
            tooltip: S.of(context).libraryBrowse,
            icon: const Icon(Icons.tune_rounded, size: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: context.push,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: '/library/genres',
                child: Text(S.of(context).navGenres),
              ),
              PopupMenuItem(
                value: '/library/album-artists',
                child: Text(S.of(context).navAlbumArtists),
              ),
              PopupMenuItem(
                value: '/library/radio',
                child: Text(S.of(context).navRadio),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
