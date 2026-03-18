import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/models/models.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

class LibraryRadioScreen extends ConsumerStatefulWidget {
  const LibraryRadioScreen({super.key});

  @override
  ConsumerState<LibraryRadioScreen> createState() => _LibraryRadioScreenState();
}

class _LibraryRadioScreenState extends ConsumerState<LibraryRadioScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final stationsAsync = ref.watch(radioStationsProvider);
    final isMobile = AppBreakpoints.isMobile(MediaQuery.of(context).size.width);
    final h = isMobile ? AppDimensions.paddingMobile : AppDimensions.paddingDesktop;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(h, h, h, 16),
            child: Text(
              S.of(context).libraryRadioTitle,
              style: Theme.of(context).textTheme.pageTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(h, 0, h, 16),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: S.of(context).navSearch,
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: stationsAsync.when(
              loading: () => Center(
                child: const CircularProgressIndicator(),
              ),
              error: (_, _) => Center(
                child: Text(
                  S.of(context).libraryRadioEmpty,
                  style: Theme.of(context).textTheme.songSubtitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              data: (stations) {
                final filtered = _searchQuery.isEmpty
                    ? stations
                    : stations
                          .where(
                            (s) =>
                                s.name.toLowerCase().contains(
                                  _searchQuery.toLowerCase(),
                                ) ||
                                s.streamUrl.toLowerCase().contains(
                                  _searchQuery.toLowerCase(),
                                ),
                          )
                          .toList();
                return filtered.isEmpty
                    ? Center(
                        child: Text(
                          S.of(context).libraryRadioEmpty,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : _buildList(filtered);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<RadioStation> stations) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: stations.length,
      itemBuilder: (context, index) {
        final station = stations[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.colors.primarySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.radio, color: context.colors.primary),
          ),
          title: Text(
            station.name,
            style: Theme.of(context).textTheme.songTitle,
          ),
          subtitle: Text(
            station.streamUrl,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.songSubtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.play_circle_outline, size: 24),
                color: context.colors.primary,
                tooltip: S.of(context).tooltipPlay,
                onPressed: () {
                  // TODO: Implement radio stream playback
                },
              ),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        );
      },
    );
  }
}
