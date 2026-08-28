import 'package:flutter/material.dart';
import 'package:navidrome_player/api/models/song.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/utils/import_duplicate.dart';

Future<ImportDuplicateDecision> showImportDuplicateDialog({
  required BuildContext context,
  required Song incoming,
  required List<ImportDuplicateCandidate> candidates,
  required ImportQualityInfo incomingQuality,
  String? preferredReplaceSongId,
}) async {
  if (candidates.isEmpty) return const ImportDuplicateDecision.cancel();
  return await showDialog<ImportDuplicateDecision>(
        context: context,
        builder: (dialogContext) => ImportDuplicateDialog(
          incoming: incoming,
          candidates: candidates,
          incomingQuality: incomingQuality,
          preferredReplaceSongId: preferredReplaceSongId,
        ),
      ) ??
      const ImportDuplicateDecision.cancel();
}

class ImportDuplicateDialog extends StatefulWidget {
  const ImportDuplicateDialog({
    required this.incoming,
    required this.candidates,
    required this.incomingQuality,
    this.preferredReplaceSongId,
    super.key,
  });

  final Song incoming;
  final List<ImportDuplicateCandidate> candidates;
  final ImportQualityInfo incomingQuality;
  final String? preferredReplaceSongId;

  @override
  State<ImportDuplicateDialog> createState() => _ImportDuplicateDialogState();
}

class _ImportDuplicateDialogState extends State<ImportDuplicateDialog> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = defaultImportDuplicateSelection(
      widget.candidates,
      preferredSongId: widget.preferredReplaceSongId,
    );
  }

  ImportDuplicateCandidate get _current => widget.candidates[_selected];

  ImportQualityCompare get _compare => compareImportQuality(
    incoming: widget.incomingQuality,
    local: localImportQuality(_current.song),
  );

  String _comparisonLabel(S l10n) {
    final delta = importQualityDeltaKbps(
      incoming: widget.incomingQuality,
      local: localImportQuality(_current.song),
    );
    return switch (_compare) {
      ImportQualityCompare.higher =>
        delta == null
            ? l10n.importDuplicateQualityHigher
            : l10n.importDuplicateQualityHigherBy(delta),
      ImportQualityCompare.lower =>
        delta == null
            ? l10n.importDuplicateQualityLower
            : l10n.importDuplicateQualityLowerBy(delta.abs()),
      ImportQualityCompare.similar => l10n.importDuplicateQualitySimilar,
      ImportQualityCompare.unknown => l10n.importDuplicateQualityUnknown,
      ImportQualityCompare.localAlreadyLossless =>
        l10n.importDuplicateQualityLocalLossless,
      ImportQualityCompare.bothLosslessUnknown =>
        l10n.importDuplicateQualityBothLossless,
      ImportQualityCompare.originalUsuallyHigher =>
        l10n.importDuplicateQualityOriginalLikelyHigher,
    };
  }

  Color _comparisonColor(ColorScheme colors) {
    return switch (_compare) {
      ImportQualityCompare.higher ||
      ImportQualityCompare.originalUsuallyHigher => colors.tertiary,
      ImportQualityCompare.lower => colors.error,
      ImportQualityCompare.similar ||
      ImportQualityCompare.unknown ||
      ImportQualityCompare.localAlreadyLossless ||
      ImportQualityCompare.bothLosslessUnknown => colors.onSurfaceVariant,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;

    return AlertDialog(
      title: Text(l10n.importDuplicateTitle),
      content: SizedBox(
        width: 460,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.importDuplicateCompareHint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppDimensions.itemGap),
                Text(
                  l10n.importDuplicateIncoming,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                _IncomingCard(
                  song: widget.incoming,
                  quality: formatImportQualityLabel(
                    widget.incomingQuality,
                    originalLabel: l10n.importDuplicateIncomingOriginal,
                    estimatedLabel: l10n.importDuplicateBitRateEstimated,
                  ),
                  comparison: _comparisonLabel(l10n),
                  comparisonColor: _comparisonColor(theme.colorScheme),
                ),
                const SizedBox(height: AppDimensions.itemGap),
                Text(
                  l10n.importDuplicateLocal,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                for (var i = 0; i < widget.candidates.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _LocalCandidateTile(
                    candidate: widget.candidates[i],
                    selected: i == _selected,
                    onTap: () => setState(() => _selected = i),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(context, const ImportDuplicateDecision.cancel()),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(context, const ImportDuplicateDecision.download()),
          child: Text(l10n.importDuplicateDownload),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            ImportDuplicateDecision.replace(_current.song.id),
          ),
          child: Text(l10n.importDuplicateReplace),
        ),
      ],
    );
  }
}

class _IncomingCard extends StatelessWidget {
  const _IncomingCard({
    required this.song,
    required this.quality,
    required this.comparison,
    required this.comparisonColor,
  });

  final Song song;
  final String quality;
  final String comparison;
  final Color comparisonColor;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
        borderRadius: BorderRadius.circular(AppDimensions.cardRadiusSmall),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(song.title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 2),
            Text(
              _incomingAlbumLine(l10n, song),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              _incomingQualityLine(l10n, song, quality),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              comparison,
              style: theme.textTheme.labelMedium?.copyWith(
                color: comparisonColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalCandidateTile extends StatelessWidget {
  const _LocalCandidateTile({
    required this.candidate,
    required this.selected,
    required this.onTap,
  });

  final ImportDuplicateCandidate candidate;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final theme = Theme.of(context);
    final song = candidate.song;
    final quality = localImportQualityLabel(song);
    final meta = [
      song.year?.toString(),
      song.formattedDuration.isEmpty ? null : song.formattedDuration,
      if (quality.isNotEmpty) quality,
    ].whereType<String>().join(' · ');

    return Material(
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: 0.12)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(AppDimensions.cardRadiusSmall),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadiusSmall),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 20,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song.title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      song.album.trim().isEmpty
                          ? l10n.importDuplicateUnknownAlbum
                          : song.album,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      meta.isEmpty ? l10n.importDuplicateUnknownMeta : meta,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _MatchBadge(match: candidate.match),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchBadge extends StatelessWidget {
  const _MatchBadge({required this.match});

  final ImportRecordingMatch match;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final theme = Theme.of(context);
    final (label, color) = switch (match) {
      ImportRecordingMatch.same => (
        l10n.importDuplicateSameVersion,
        theme.colorScheme.primary,
      ),
      ImportRecordingMatch.different => (
        l10n.importDuplicateDifferentVersion,
        theme.colorScheme.tertiary,
      ),
      ImportRecordingMatch.unknown => (
        l10n.importDuplicateUnknownVersion,
        theme.colorScheme.onSurfaceVariant,
      ),
    };
    return Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

String _incomingAlbumLine(S l10n, Song song) {
  final album = song.album.trim().isEmpty
      ? l10n.importDuplicateUnknownAlbum
      : song.album;
  return [
    song.artist,
    album,
  ].where((part) => part.trim().isNotEmpty).join(' · ');
}

String _incomingQualityLine(S l10n, Song song, String quality) {
  final duration = song.formattedDuration.isEmpty
      ? l10n.importDuplicateUnknownMeta
      : song.formattedDuration;
  return [
    duration,
    quality,
    ?song.sourceLabel,
  ].where((part) => part.trim().isNotEmpty).join(' · ');
}
