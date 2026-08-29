import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/api/models/song.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/app_filter_chip.dart';
import 'package:navidrome_player/ui/widgets/delete_from_navidrome.dart';
import 'package:navidrome_player/ui/widgets/empty_state.dart';
import 'package:navidrome_player/ui/widgets/responsive_content.dart';
import 'package:navidrome_player/ui/widgets/stat_card.dart';
import 'package:navidrome_player/utils/library_style.dart';
import 'package:navidrome_player/utils/library_style_playlists.dart';

class LibraryPlaylistOrganizeScreen extends ConsumerWidget {
  const LibraryPlaylistOrganizeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = S.of(context);
    final state = ref.watch(libraryPlaylistOrganizeProvider);
    final isMobile = AppBreakpoints.isMobile(MediaQuery.of(context).size.width);
    final h = isMobile
        ? AppDimensions.paddingMobile
        : AppDimensions.paddingDesktop;
    ref.listen(serverConfigProvider.select((config) => config.serverId), (
      previous,
      next,
    ) {
      if (previous != next) {
        ref.read(libraryPlaylistOrganizeProvider.notifier).reset();
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/settings');
      },
      child: ResponsivePageScaffold(
        body: ListView(
          padding: EdgeInsets.fromLTRB(0, h, 0, h),
          children: [
            Row(
              children: [
                if (isMobile)
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                    ),
                    onPressed: () => context.go('/settings'),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                Expanded(
                  child: Text(
                    l10n.libraryPlaylistTitle,
                    style: Theme.of(context).textTheme.pageTitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.libraryPlaylistSubtitle,
              style: Theme.of(context).textTheme.songSubtitle.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            if (state.stage == LibraryPlaylistStage.idle ||
                state.stage == LibraryPlaylistStage.analyzing)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton(
                    onPressed: state.stage == LibraryPlaylistStage.analyzing
                        ? null
                        : () => ref
                              .read(libraryPlaylistOrganizeProvider.notifier)
                              .analyze(onlyMissing: true),
                    child: Text(l10n.libraryPlaylistAnalyzeMissing),
                  ),
                  FilledButton.tonal(
                    onPressed: state.stage == LibraryPlaylistStage.analyzing
                        ? null
                        : () => ref
                              .read(libraryPlaylistOrganizeProvider.notifier)
                              .analyze(onlyMissing: false),
                    child: Text(l10n.libraryPlaylistAnalyzeAll),
                  ),
                ],
              ),
            if (state.stage == LibraryPlaylistStage.preview)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton(
                    onPressed: state.draft.addCount == 0
                        ? null
                        : () => ref
                              .read(libraryPlaylistOrganizeProvider.notifier)
                              .applySelected(),
                    child: Text(
                      l10n.libraryPlaylistApply(state.draft.addCount),
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: () => ref
                        .read(libraryPlaylistOrganizeProvider.notifier)
                        .reset(),
                    child: Text(l10n.libraryStyleCancel),
                  ),
                ],
              ),
            if (state.stage == LibraryPlaylistStage.done)
              FilledButton.tonal(
                onPressed: () =>
                    ref.read(libraryPlaylistOrganizeProvider.notifier).reset(),
                child: Text(l10n.libraryStyleDone),
              ),
            if (state.error != null) ...[
              const SizedBox(height: 16),
              Text(
                l10n.libraryPlaylistFailed(state.error!),
                style: Theme.of(context).textTheme.songSubtitle.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            if (state.stage == LibraryPlaylistStage.analyzing) ...[
              const SizedBox(height: 24),
              Text(
                l10n.libraryStyleAnalyzing,
                style: Theme.of(context).textTheme.songSubtitle,
              ),
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
            if (state.stage == LibraryPlaylistStage.applying) ...[
              const SizedBox(height: 24),
              Text(
                l10n.libraryPlaylistApplying(state.progress, state.total),
                style: Theme.of(context).textTheme.songSubtitle,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: state.total == 0 ? null : state.progress / state.total,
              ),
            ],
            if (state.stage == LibraryPlaylistStage.preview ||
                state.stage == LibraryPlaylistStage.done) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  StatCard(
                    icon: Icons.queue_music_outlined,
                    label: l10n.libraryPlaylistLists,
                    value: '${state.draft.buckets.length}',
                  ),
                  const SizedBox(width: 12),
                  StatCard(
                    icon: Icons.inbox_outlined,
                    label: l10n.libraryStyleReview,
                    value: '${state.draft.leftover.length}',
                  ),
                  if (state.stage == LibraryPlaylistStage.done) ...[
                    const SizedBox(width: 12),
                    StatCard(
                      icon: Icons.check_circle_outline_rounded,
                      label: l10n.libraryStyleApplied,
                      value: '${state.appliedLists}',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AppFilterChip(
                    label: l10n.libraryPlaylistLists,
                    selected: state.filter == LibraryPlaylistFilter.lists,
                    onTap: () => ref
                        .read(libraryPlaylistOrganizeProvider.notifier)
                        .setFilter(LibraryPlaylistFilter.lists),
                  ),
                  AppFilterChip(
                    label: l10n.libraryStyleReview,
                    selected: state.filter == LibraryPlaylistFilter.leftover,
                    onTap: () => ref
                        .read(libraryPlaylistOrganizeProvider.notifier)
                        .setFilter(LibraryPlaylistFilter.leftover),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (state.filter == LibraryPlaylistFilter.lists)
                if (state.draft.buckets.isEmpty)
                  EmptyState(
                    icon: Icons.queue_music_outlined,
                    message: l10n.libraryPlaylistEmptyLists,
                  )
                else
                  for (final bucket in state.draft.buckets)
                    _BucketTile(
                      bucket: bucket,
                      failed: state.failedLists.contains(bucket.name),
                      applying: state.stage == LibraryPlaylistStage.applying,
                    )
              else if (state.draft.leftover.isEmpty)
                EmptyState(
                  icon: Icons.inbox_outlined,
                  message: l10n.libraryStyleEmptyReview,
                )
              else
                for (final song in state.draft.leftover)
                  _LeftoverTile(
                    song: song,
                    applying: state.stage == LibraryPlaylistStage.applying,
                  ),
            ],
            if (state.stage == LibraryPlaylistStage.idle)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: EmptyState(
                  icon: Icons.queue_music_outlined,
                  message: l10n.libraryPlaylistIdle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BucketTile extends ConsumerWidget {
  const _BucketTile({
    required this.bucket,
    required this.failed,
    required this.applying,
  });

  final StylePlaylistBucket bucket;
  final bool failed;
  final bool applying;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = S.of(context);
    final detail = [
      bucket.isNew
          ? l10n.libraryPlaylistNew
          : l10n.libraryPlaylistExisting(bucket.alreadyIn),
      l10n.libraryPlaylistAddCount(bucket.toAdd.length),
      if (failed) l10n.libraryStyleFailedLabel,
    ].join(' · ');
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: bucket.selected,
      onChanged: applying
          ? null
          : (_) => ref
                .read(libraryPlaylistOrganizeProvider.notifier)
                .toggleBucket(bucket.name),
      title: Text(bucket.name, style: Theme.of(context).textTheme.songTitle),
      subtitle: Text(detail, style: Theme.of(context).textTheme.songSubtitle),
    );
  }
}

class _LeftoverTile extends ConsumerWidget {
  const _LeftoverTile({required this.song, required this.applying});

  final Song song;
  final bool applying;

  Future<void> _assign(BuildContext context, WidgetRef ref) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return ListView(
          children: [
            for (final style in libraryStyleNames)
              ListTile(
                title: Text(style),
                onTap: () => Navigator.of(context).pop(style),
              ),
          ],
        );
      },
    );
    if (chosen == null) return;
    await ref
        .read(libraryPlaylistOrganizeProvider.notifier)
        .assignLeftover(song, chosen);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = S.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(song.title, style: Theme.of(context).textTheme.songTitle),
      subtitle: Text(
        [
          song.artist,
          ?song.genre,
        ].where((part) => part.trim().isNotEmpty).join(' · '),
        style: Theme.of(context).textTheme.songSubtitle,
      ),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: l10n.libraryStylePlay,
            onPressed: applying
                ? null
                : () async {
                    try {
                      await ref.read(audioPlayerServiceProvider).playSong(song);
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.libraryAuditPlayFailed),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
            icon: const Icon(Icons.play_arrow_rounded),
          ),
          IconButton(
            tooltip: l10n.libraryPlaylistAssign,
            onPressed: applying ? null : () => _assign(context, ref),
            icon: const Icon(Icons.playlist_add_rounded),
          ),
          IconButton(
            tooltip: l10n.libraryStyleDelete,
            onPressed: applying
                ? null
                : () async {
                    final deleted = await deleteLibrarySongsFromNavidrome(
                      context,
                      ref,
                      [song],
                    );
                    if (!deleted) return;
                    ref
                        .read(libraryPlaylistOrganizeProvider.notifier)
                        .removeSongs([song.id]);
                  },
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}
