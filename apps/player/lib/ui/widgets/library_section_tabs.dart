import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

/// Shared primary navigation for every library section.
class LibrarySectionTabs extends StatelessWidget {
  const LibrarySectionTabs({super.key});

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final sections = [
      (path: '/library/playlists', label: S.of(context).navPlaylists),
      (path: '/library/songs', label: S.of(context).navSongs),
      (path: '/library/albums', label: S.of(context).navAlbums),
      (path: '/library/artists', label: S.of(context).navArtists),
    ];

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 42,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                for (final section in sections)
                  Expanded(
                    child: _SectionTab(
                      label: section.label,
                      selected: path == section.path,
                      onTap: () => context.go(section.path),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        PopupMenuButton<String>(
          tooltip: S.of(context).libraryBrowse,
          icon: const Icon(Icons.tune, size: 21),
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
      ],
    );
  }
}

class _SectionTab extends StatelessWidget {
  const _SectionTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? Theme.of(context).colorScheme.surface
            : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
