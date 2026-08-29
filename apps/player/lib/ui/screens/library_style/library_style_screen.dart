import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

class LibraryStyleScreen extends ConsumerWidget {
  const LibraryStyleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = S.of(context);
    final state = ref.watch(libraryStyleProvider);
    final isMobile = AppBreakpoints.isMobile(MediaQuery.of(context).size.width);
    final h = isMobile
        ? AppDimensions.paddingMobile
        : AppDimensions.paddingDesktop;
    final canWrite = ref.watch(
      backendClientProvider.select((client) => client.canAuditLibrary),
    );
    final canLookup = ref.watch(
      backendClientProvider.select((client) => client.isConfigured),
    );
    ref.listen(serverConfigProvider.select((config) => config.serverId), (
      previous,
      next,
    ) {
      if (previous != next) {
        ref.read(libraryStyleProvider.notifier).reset();
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
                    l10n.libraryStyleTitle,
                    style: Theme.of(context).textTheme.pageTitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.libraryStyleSubtitle,
              style: Theme.of(context).textTheme.songSubtitle.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            if (state.stage == LibraryStyleStage.idle ||
                state.stage == LibraryStyleStage.analyzing)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton(
                    onPressed:
                        !canWrite || state.stage == LibraryStyleStage.analyzing
                        ? null
                        : () => ref
                              .read(libraryStyleProvider.notifier)
                              .analyze(missingOnly: true),
                    child: Text(l10n.libraryStyleAnalyzeMissing),
                  ),
                  FilledButton.tonal(
                    onPressed:
                        !canWrite || state.stage == LibraryStyleStage.analyzing
                        ? null
                        : () => ref
                              .read(libraryStyleProvider.notifier)
                              .analyze(missingOnly: false),
                    child: Text(l10n.libraryStyleAnalyzeAll),
                  ),
                ],
              ),
            if (state.stage == LibraryStyleStage.preview)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton(
                    onPressed: state.selectedWriteCount == 0
                        ? null
                        : () => ref
                              .read(libraryStyleProvider.notifier)
                              .applySelected(),
                    child: Text(
                      l10n.libraryStyleApply(state.selectedWriteCount),
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: () =>
                        ref.read(libraryStyleProvider.notifier).reset(),
                    child: Text(l10n.libraryStyleCancel),
                  ),
                ],
              ),
            if (state.stage == LibraryStyleStage.done)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton(
                    onPressed: () => context.go('/library-playlists'),
                    child: Text(l10n.libraryStyleOpenPlaylists),
                  ),
                  FilledButton.tonal(
                    onPressed: () =>
                        ref.read(libraryStyleProvider.notifier).reset(),
                    child: Text(l10n.libraryStyleDone),
                  ),
                ],
              ),
            if (!canWrite) ...[
              const SizedBox(height: 16),
              Text(
                l10n.libraryStyleNasRequired,
                style: Theme.of(context).textTheme.songSubtitle.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            if (canWrite && !canLookup) ...[
              const SizedBox(height: 16),
              Text(
                l10n.libraryStyleCloudRequired,
                style: Theme.of(context).textTheme.songSubtitle.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            if (state.error != null && state.error != 'nas-required') ...[
              const SizedBox(height: 16),
              Text(
                l10n.libraryStyleFailed(state.error!),
                style: Theme.of(context).textTheme.songSubtitle.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            if (state.stage == LibraryStyleStage.analyzing) ...[
              const SizedBox(height: 24),
              Text(
                state.total == 0
                    ? l10n.libraryStyleAnalyzing
                    : l10n.libraryStyleLookingUp(state.progress, state.total),
                style: Theme.of(context).textTheme.songSubtitle,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: state.total == 0 ? null : state.progress / state.total,
              ),
            ],
            if (state.stage == LibraryStyleStage.applying) ...[
              const SizedBox(height: 24),
              Text(
                l10n.libraryStyleApplying(state.progress, state.total),
                style: Theme.of(context).textTheme.songSubtitle,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: state.total == 0 ? null : state.progress / state.total,
              ),
            ],
            if (state.stage == LibraryStyleStage.preview ||
                state.stage == LibraryStyleStage.done) ...[
              const SizedBox(height: 24),
              if (isMobile)
                Column(
                  children: [
                    Row(
                      children: [
                        StatCard(
                          icon: Icons.label_outline_rounded,
                          label: l10n.libraryStyleSuggested,
                          value: '${state.suggestedItems.length}',
                        ),
                        const SizedBox(width: 12),
                        StatCard(
                          icon: Icons.inbox_outlined,
                          label: l10n.libraryStyleReview,
                          value: '${state.reviewItems.length}',
                        ),
                      ],
                    ),
                    if (state.stage == LibraryStyleStage.done) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          StatCard(
                            icon: Icons.check_circle_outline_rounded,
                            label: l10n.libraryStyleApplied,
                            value: '${state.applied}',
                          ),
                          const SizedBox(width: 12),
                          StatCard(
                            icon: Icons.error_outline_rounded,
                            label: l10n.libraryStyleFailedLabel,
                            value: '${state.failedIds.length}',
                          ),
                        ],
                      ),
                    ],
                  ],
                )
              else
                Row(
                  children: [
                    StatCard(
                      icon: Icons.label_outline_rounded,
                      label: l10n.libraryStyleSuggested,
                      value: '${state.suggestedItems.length}',
                    ),
                    const SizedBox(width: 12),
                    StatCard(
                      icon: Icons.inbox_outlined,
                      label: l10n.libraryStyleReview,
                      value: '${state.reviewItems.length}',
                    ),
                    if (state.stage == LibraryStyleStage.done) ...[
                      const SizedBox(width: 12),
                      StatCard(
                        icon: Icons.check_circle_outline_rounded,
                        label: l10n.libraryStyleApplied,
                        value: '${state.applied}',
                      ),
                      const SizedBox(width: 12),
                      StatCard(
                        icon: Icons.error_outline_rounded,
                        label: l10n.libraryStyleFailedLabel,
                        value: '${state.failedIds.length}',
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
                    label: l10n.libraryStyleSuggested,
                    selected: state.filter == LibraryStyleListFilter.suggested,
                    onTap: () => ref
                        .read(libraryStyleProvider.notifier)
                        .setFilter(LibraryStyleListFilter.suggested),
                  ),
                  AppFilterChip(
                    label: l10n.libraryStyleReview,
                    selected: state.filter == LibraryStyleListFilter.review,
                    onTap: () => ref
                        .read(libraryStyleProvider.notifier)
                        .setFilter(LibraryStyleListFilter.review),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (state.visibleItems.isEmpty)
                EmptyState(
                  icon: Icons.library_music_outlined,
                  message: state.filter == LibraryStyleListFilter.review
                      ? l10n.libraryStyleEmptyReview
                      : l10n.libraryStyleEmptySuggested,
                )
              else
                for (final item in state.visibleItems)
                  _StyleTile(
                    item: item,
                    failed: state.failedIds.contains(item.song.id),
                    applying: state.stage == LibraryStyleStage.applying,
                    writeImmediately: state.stage == LibraryStyleStage.done,
                  ),
            ],
            if (state.stage == LibraryStyleStage.idle)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: EmptyState(
                  icon: Icons.style_outlined,
                  message: l10n.libraryStyleIdle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StyleTile extends ConsumerWidget {
  const _StyleTile({
    required this.item,
    required this.failed,
    required this.applying,
    required this.writeImmediately,
  });

  final LibraryStyleItem item;
  final bool failed;
  final bool applying;
  final bool writeImmediately;

  Future<void> _play(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(audioPlayerServiceProvider).playSong(item.song);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).libraryAuditPlayFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

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
                selected: item.style == style,
                onTap: () => Navigator.of(context).pop(style),
              ),
          ],
        );
      },
    );
    if (chosen == null) return;
    final notifier = ref.read(libraryStyleProvider.notifier);
    if (writeImmediately) {
      await notifier.writeOne(item.song.id, chosen);
    } else {
      notifier.setStyle(item.song.id, chosen);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final deleted = await deleteLibrarySongsFromNavidrome(context, ref, [
      item.song,
    ]);
    if (!deleted) return;
    ref.read(libraryStyleProvider.notifier).removeSongs([item.song.id]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = S.of(context);
    final theme = Theme.of(context);
    final subtitle = [
      item.song.artist,
      ?item.style,
      if (failed) l10n.libraryStyleFailedLabel,
    ].where((part) => part.trim().isNotEmpty).join(' · ');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: item.isReview
          ? null
          : Checkbox(
              value: item.selected,
              onChanged: applying
                  ? null
                  : (_) => ref
                        .read(libraryStyleProvider.notifier)
                        .toggleSelected(item.song.id),
            ),
      title: Text(item.song.title, style: theme.textTheme.songTitle),
      subtitle: Text(subtitle, style: theme.textTheme.songSubtitle),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: l10n.libraryStylePlay,
            onPressed: applying ? null : () => _play(context, ref),
            icon: const Icon(Icons.play_arrow_rounded),
          ),
          IconButton(
            tooltip: l10n.libraryStyleAssign,
            onPressed: applying ? null : () => _assign(context, ref),
            icon: const Icon(Icons.label_outline_rounded),
          ),
          IconButton(
            tooltip: l10n.libraryStyleDelete,
            onPressed: applying ? null : () => _delete(context, ref),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}
