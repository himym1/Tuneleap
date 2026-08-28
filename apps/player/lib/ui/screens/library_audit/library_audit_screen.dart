import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/api/models/library_audit.dart';
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

class LibraryAuditScreen extends ConsumerStatefulWidget {
  const LibraryAuditScreen({super.key});

  @override
  ConsumerState<LibraryAuditScreen> createState() => _LibraryAuditScreenState();
}

class _LibraryAuditScreenState extends ConsumerState<LibraryAuditScreen> {
  final Set<String> _selected = {};
  bool _selecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(libraryAuditProvider.notifier).hydrate();
    });
  }

  String _codeLabel(S l10n, String code) {
    return switch (code) {
      libraryAuditCodeMissing => l10n.libraryAuditCodeMissing,
      libraryAuditCodeLowBitrate => l10n.libraryAuditCodeLowBitrate,
      libraryAuditCodeSuspectTranscode => l10n.libraryAuditCodeSuspectTranscode,
      libraryAuditCodeDuplicateVersion => l10n.libraryAuditCodeDuplicateVersion,
      libraryAuditCodeLossyTranscode => l10n.libraryAuditCodeLossyTranscode,
      libraryAuditCodeFakeHires => l10n.libraryAuditCodeFakeHires,
      libraryAuditCodeDeepFailed => l10n.libraryAuditCodeDeepFailed,
      _ => code,
    };
  }

  String? _deepErrorLabel(S l10n, LibraryAuditFinding finding) {
    final code = finding.deepError?.trim();
    if (code == null || code.isEmpty) return null;
    return switch (code) {
      'unresolved_path' => l10n.libraryAuditDeepErrorUnresolved,
      'invalid_sample_rate' => l10n.libraryAuditDeepErrorSampleRate,
      'decode_failed' => l10n.libraryAuditDeepErrorDecode,
      'too_short' => l10n.libraryAuditDeepErrorTooShort,
      'unsupported_format' => l10n.libraryAuditDeepErrorUnsupported,
      _ => l10n.libraryAuditDeepErrorUnknown,
    };
  }

  String? _qualityLabel(S l10n, LibraryAuditFinding finding) {
    final format = finding.suffix.trim().toUpperCase();
    final rate = finding.bitRate;
    if (format.isNotEmpty && rate != null && rate > 0) {
      return l10n.libraryAuditQuality(format, rate);
    }
    if (format.isNotEmpty) return format;
    if (rate != null && rate > 0) return '$rate kbps';
    return null;
  }

  List<LibraryAuditFinding> _selectedFindings(LibraryAuditState state) {
    return [
      for (final finding in state.visibleFindings)
        if (_selected.contains(finding.songId)) finding,
    ];
  }

  Widget _buildFindingTile(
    S l10n,
    LibraryAuditFinding finding, {
    bool versionOnly = false,
  }) {
    return _FindingTile(
      finding: finding,
      selecting: _selecting,
      selected: _selected.contains(finding.songId),
      qualityLabel: _qualityLabel(l10n, finding),
      cutoffLabel: finding.cutoffHz == null
          ? null
          : l10n.libraryAuditCutoff(finding.cutoffHz!.round()),
      deepErrorLabel: _deepErrorLabel(l10n, finding),
      codeLabels: [
        if (versionOnly) l10n.libraryAuditQualityOk,
        for (final code in finding.codes) _codeLabel(l10n, code),
      ],
      onToggle: () => setState(() {
        if (_selected.contains(finding.songId)) {
          _selected.remove(finding.songId);
        } else {
          _selected.add(finding.songId);
        }
      }),
      onPlay: () => _play(finding),
      onOpenAlbum: () => _openAlbum(finding),
      onDelete: () => _deleteFindings([finding]),
      onReplace: finding.hasQualityIssue
          ? () => _replaceFindings([finding])
          : null,
    );
  }

  void _clearSelection() {
    setState(() {
      _selected.clear();
      _selecting = false;
    });
  }

  Future<Song> _resolveSong(LibraryAuditFinding finding) async {
    try {
      return await ref.read(subsonicClientProvider).getSong(finding.songId);
    } catch (_) {
      return finding.toSong();
    }
  }

  Future<void> _play(LibraryAuditFinding finding) async {
    try {
      final song = await _resolveSong(finding);
      await ref.read(audioPlayerServiceProvider).playSong(song);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).libraryAuditPlayFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openAlbum(LibraryAuditFinding finding) async {
    var albumId = finding.albumId;
    if (albumId.isEmpty) {
      try {
        albumId = (await _resolveSong(finding)).albumId;
      } catch (_) {}
    }
    if (albumId.isEmpty || !mounted) return;
    context.go('/album/${Uri.encodeComponent(albumId)}');
  }

  Future<void> _replaceFindings(List<LibraryAuditFinding> findings) async {
    final targets = [
      for (final finding in findings)
        if (finding.searchQuery().isNotEmpty)
          LibraryAuditReplaceTarget(
            songId: finding.songId,
            title: finding.title,
            artist: finding.artist,
          ),
    ];
    if (targets.isEmpty) return;
    ref.read(libraryAuditReplaceTargetProvider.notifier).setQueue(targets);
    _clearSelection();
    if (!mounted) return;
    context.go(
      '/search?q=${Uri.encodeQueryComponent(targets.first.searchQuery)}',
    );
  }

  Future<void> _deleteFindings(List<LibraryAuditFinding> findings) async {
    if (findings.isEmpty) return;
    final deleted = await deleteLibrarySongsFromNavidrome(context, ref, [
      for (final finding in findings) finding.toSong(),
    ]);
    if (!deleted) return;
    ref.read(libraryAuditProvider.notifier).removeFindings([
      for (final finding in findings) finding.songId,
    ]);
    _clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final state = ref.watch(libraryAuditProvider);
    final snapshot = state.snapshot;
    final rules = ref.watch(libraryAuditRulesProvider);
    final isMobile = AppBreakpoints.isMobile(MediaQuery.of(context).size.width);
    final h = isMobile
        ? AppDimensions.paddingMobile
        : AppDimensions.paddingDesktop;
    final canAudit = ref.watch(
      backendClientProvider.select((client) => client.canAuditLibrary),
    );
    ref.listen(serverConfigProvider.select((config) => config.serverId), (
      previous,
      next,
    ) {
      if (previous != next) {
        _clearSelection();
        ref.read(libraryAuditProvider.notifier).refresh();
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
                    l10n.libraryAuditTitle,
                    style: Theme.of(context).textTheme.pageTitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                if (snapshot.hasResult && state.visibleFindings.isNotEmpty)
                  TextButton(
                    onPressed: snapshot.isScanning
                        ? null
                        : () => setState(() {
                            _selecting = !_selecting;
                            if (!_selecting) _selected.clear();
                          }),
                    child: Text(
                      _selecting
                          ? l10n.libraryAuditDoneSelecting
                          : l10n.libraryAuditSelect,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.libraryAuditSubtitle,
              style: Theme.of(context).textTheme.songSubtitle.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _RulesPanel(
              rules: rules,
              enabled: canAudit && !snapshot.isScanning && !state.loading,
              onChanged: (next) => ref
                  .read(libraryAuditRulesProvider.notifier)
                  .update(
                    lowBitrateKbps: next.lowBitrateKbps,
                    suspectLosslessKbps: next.suspectLosslessKbps,
                    durationToleranceSeconds: next.durationToleranceSeconds,
                  ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (snapshot.isScanning)
                  FilledButton.tonal(
                    onPressed: state.loading
                        ? null
                        : () =>
                              ref.read(libraryAuditProvider.notifier).cancel(),
                    child: Text(l10n.libraryAuditCancel),
                  )
                else ...[
                  FilledButton(
                    onPressed: !canAudit || state.loading
                        ? null
                        : () {
                            _clearSelection();
                            ref.read(libraryAuditProvider.notifier).start();
                          },
                    child: Text(l10n.libraryAuditStart),
                  ),
                  if (snapshot.hasResult)
                    FilledButton.tonal(
                      onPressed:
                          !canAudit || state.loading || state.findings.isEmpty
                          ? null
                          : () => ref
                                .read(libraryAuditProvider.notifier)
                                .startDeep(),
                      child: Text(l10n.libraryAuditDeepStart),
                    ),
                ],
              ],
            ),
            if (!canAudit) ...[
              const SizedBox(height: 16),
              Text(
                l10n.libraryAuditNasRequired,
                style: Theme.of(context).textTheme.songSubtitle.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            if (state.error != null && state.error != 'nas-required') ...[
              const SizedBox(height: 16),
              Text(
                l10n.libraryAuditFailed(state.error!),
                style: Theme.of(context).textTheme.songSubtitle.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            if (snapshot.isScanning) ...[
              const SizedBox(height: 24),
              Text(
                snapshot.isDeepScanning
                    ? l10n.libraryAuditDeepScanning(
                        snapshot.scanned,
                        snapshot.total,
                      )
                    : l10n.libraryAuditScanning(
                        snapshot.scanned,
                        snapshot.total,
                      ),
                style: Theme.of(context).textTheme.songSubtitle,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: snapshot.fraction),
            ],
            if (snapshot.hasResult) ...[
              const SizedBox(height: 24),
              if (isMobile)
                Column(
                  children: [
                    Row(
                      children: [
                        StatCard(
                          icon: Icons.check_circle_outline_rounded,
                          label: l10n.libraryAuditPassed,
                          value: '${snapshot.summary.passed}',
                        ),
                        const SizedBox(width: 12),
                        StatCard(
                          icon: Icons.report_gmailerrorred_outlined,
                          label: l10n.libraryAuditQualityIssues,
                          value: '${state.qualityIssueCount}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        StatCard(
                          icon: Icons.library_music_outlined,
                          label: l10n.libraryAuditVersionOnly,
                          value: '${state.versionOnlyCount}',
                        ),
                        const SizedBox(width: 12),
                        StatCard(
                          icon: Icons.album_outlined,
                          label: l10n.libraryAuditScanned,
                          value: '${snapshot.summary.scanned}',
                        ),
                      ],
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    StatCard(
                      icon: Icons.check_circle_outline_rounded,
                      label: l10n.libraryAuditPassed,
                      value: '${snapshot.summary.passed}',
                    ),
                    const SizedBox(width: 12),
                    StatCard(
                      icon: Icons.report_gmailerrorred_outlined,
                      label: l10n.libraryAuditQualityIssues,
                      value: '${state.qualityIssueCount}',
                    ),
                    const SizedBox(width: 12),
                    StatCard(
                      icon: Icons.library_music_outlined,
                      label: l10n.libraryAuditVersionOnly,
                      value: '${state.versionOnlyCount}',
                    ),
                    const SizedBox(width: 12),
                    StatCard(
                      icon: Icons.album_outlined,
                      label: l10n.libraryAuditScanned,
                      value: '${snapshot.summary.scanned}',
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AppFilterChip(
                    label: l10n.libraryAuditFilterAll,
                    selected: state.filterCode == null,
                    onTap: () =>
                        ref.read(libraryAuditProvider.notifier).setFilter(null),
                  ),
                  for (final code in [
                    libraryAuditCodeMissing,
                    libraryAuditCodeLowBitrate,
                    libraryAuditCodeSuspectTranscode,
                    libraryAuditCodeLossyTranscode,
                    libraryAuditCodeFakeHires,
                    libraryAuditCodeDeepFailed,
                    libraryAuditCodeDuplicateVersion,
                  ])
                    AppFilterChip(
                      label: _codeLabel(l10n, code),
                      selected: state.filterCode == code,
                      onTap: () => ref
                          .read(libraryAuditProvider.notifier)
                          .setFilter(code),
                    ),
                ],
              ),
              if (_selecting) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(l10n.libraryAuditSelected(_selected.length)),
                    TextButton(
                      onPressed: () => setState(() {
                        _selected
                          ..clear()
                          ..addAll([
                            for (final finding in state.visibleFindings)
                              finding.songId,
                          ]);
                      }),
                      child: Text(l10n.libraryAuditSelectAll),
                    ),
                    TextButton(
                      onPressed: _selected.isEmpty
                          ? null
                          : () => _deleteFindings(_selectedFindings(state)),
                      child: Text(l10n.commonDelete),
                    ),
                    TextButton(
                      onPressed: _selected.isEmpty
                          ? null
                          : () => _replaceFindings(_selectedFindings(state)),
                      child: Text(l10n.libraryAuditReplace),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              if (state.visibleFindings.isEmpty)
                EmptyState(
                  icon: Icons.verified_outlined,
                  message: l10n.libraryAuditEmptyIssues,
                )
              else if (state.showGroupedFindings) ...[
                _SectionHeader(
                  title: l10n.libraryAuditSectionQuality,
                  count: state.qualityFindings.length,
                ),
                if (state.qualityFindings.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      l10n.libraryAuditEmptyQuality,
                      style: Theme.of(context).textTheme.songSubtitle.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  for (final finding in state.qualityFindings)
                    _buildFindingTile(l10n, finding),
                const SizedBox(height: 8),
                _SectionHeader(
                  title: l10n.libraryAuditSectionVersions,
                  count: state.versionOnlyFindings.length,
                  hint: l10n.libraryAuditSectionVersionsHint,
                ),
                if (state.versionOnlyFindings.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      l10n.libraryAuditEmptyVersions,
                      style: Theme.of(context).textTheme.songSubtitle.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  for (final finding in state.versionOnlyFindings)
                    _buildFindingTile(l10n, finding, versionOnly: true),
              ] else
                for (final finding in state.visibleFindings)
                  _buildFindingTile(
                    l10n,
                    finding,
                    versionOnly: finding.isVersionOnly,
                  ),
            ] else if (!snapshot.isScanning && !state.loading)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: EmptyState(
                  icon: Icons.health_and_safety_outlined,
                  message: l10n.libraryAuditIdle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RulesPanel extends StatefulWidget {
  const _RulesPanel({
    required this.rules,
    required this.enabled,
    required this.onChanged,
  });

  final LibraryAuditRules rules;
  final bool enabled;
  final ValueChanged<LibraryAuditRules> onChanged;

  @override
  State<_RulesPanel> createState() => _RulesPanelState();
}

class _RulesPanelState extends State<_RulesPanel> {
  late LibraryAuditRules _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.rules;
  }

  @override
  void didUpdateWidget(covariant _RulesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rules.lowBitrateKbps != widget.rules.lowBitrateKbps ||
        oldWidget.rules.suspectLosslessKbps !=
            widget.rules.suspectLosslessKbps ||
        oldWidget.rules.durationToleranceSeconds !=
            widget.rules.durationToleranceSeconds) {
      _draft = widget.rules;
    }
  }

  void _setDraft(LibraryAuditRules next) {
    setState(() => _draft = next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 4),
        title: Text(
          l10n.libraryAuditRulesTitle,
          style: theme.textTheme.titleSmall,
        ),
        children: [
          _RuleSlider(
            label: l10n.libraryAuditRulesLowBitrate(_draft.lowBitrateKbps),
            value: _draft.lowBitrateKbps.toDouble(),
            min: LibraryAuditRules.minLowBitrateKbps.toDouble(),
            max: LibraryAuditRules.maxLowBitrateKbps.toDouble(),
            divisions:
                (LibraryAuditRules.maxLowBitrateKbps -
                    LibraryAuditRules.minLowBitrateKbps) ~/
                8,
            enabled: widget.enabled,
            onChanged: (value) => _setDraft(
              LibraryAuditRules.clamped(
                lowBitrateKbps: value.round(),
                suspectLosslessKbps: _draft.suspectLosslessKbps,
                durationToleranceSeconds: _draft.durationToleranceSeconds,
              ),
            ),
            onChangeEnd: (_) => widget.onChanged(_draft),
          ),
          _RuleSlider(
            label: l10n.libraryAuditRulesSuspect(_draft.suspectLosslessKbps),
            value: _draft.suspectLosslessKbps.toDouble(),
            min: LibraryAuditRules.minSuspectLosslessKbps.toDouble(),
            max: LibraryAuditRules.maxSuspectLosslessKbps.toDouble(),
            divisions:
                (LibraryAuditRules.maxSuspectLosslessKbps -
                    LibraryAuditRules.minSuspectLosslessKbps) ~/
                25,
            enabled: widget.enabled,
            onChanged: (value) => _setDraft(
              LibraryAuditRules.clamped(
                lowBitrateKbps: _draft.lowBitrateKbps,
                suspectLosslessKbps: value.round(),
                durationToleranceSeconds: _draft.durationToleranceSeconds,
              ),
            ),
            onChangeEnd: (_) => widget.onChanged(_draft),
          ),
          _RuleSlider(
            label: l10n.libraryAuditRulesDuration(
              _draft.durationToleranceSeconds,
            ),
            value: _draft.durationToleranceSeconds.toDouble(),
            min: LibraryAuditRules.minDurationToleranceSeconds.toDouble(),
            max: LibraryAuditRules.maxDurationToleranceSeconds.toDouble(),
            divisions:
                LibraryAuditRules.maxDurationToleranceSeconds -
                LibraryAuditRules.minDurationToleranceSeconds,
            enabled: widget.enabled,
            onChanged: (value) => _setDraft(
              LibraryAuditRules.clamped(
                lowBitrateKbps: _draft.lowBitrateKbps,
                suspectLosslessKbps: _draft.suspectLosslessKbps,
                durationToleranceSeconds: value.round(),
              ),
            ),
            onChangeEnd: (_) => widget.onChanged(_draft),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count, this.hint});

  final String title;
  final int count;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title · $count',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (hint != null && hint!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              style: theme.textTheme.songSubtitle.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RuleSlider extends StatelessWidget {
  const _RuleSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.enabled,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.songSubtitle.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: enabled ? onChanged : null,
          onChangeEnd: enabled ? onChangeEnd : null,
        ),
      ],
    );
  }
}

class _FindingTile extends StatelessWidget {
  const _FindingTile({
    required this.finding,
    required this.codeLabels,
    required this.selecting,
    required this.selected,
    required this.onToggle,
    required this.onPlay,
    required this.onOpenAlbum,
    required this.onDelete,
    this.qualityLabel,
    this.cutoffLabel,
    this.deepErrorLabel,
    this.onReplace,
  });

  final LibraryAuditFinding finding;
  final String? qualityLabel;
  final String? cutoffLabel;
  final String? deepErrorLabel;
  final List<String> codeLabels;
  final bool selecting;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onPlay;
  final VoidCallback onOpenAlbum;
  final VoidCallback onDelete;
  final VoidCallback? onReplace;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selecting) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 2),
                  child: Icon(
                    selected
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 22,
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              Expanded(
                child: InkWell(
                  onTap: selecting ? onToggle : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        finding.title.isEmpty ? finding.songId : finding.title,
                        style: theme.textTheme.songTitle.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (finding.artist.isNotEmpty) finding.artist,
                          if (finding.album.isNotEmpty) finding.album,
                          if (qualityLabel != null) qualityLabel,
                          if (cutoffLabel != null) cutoffLabel,
                        ].join(' · '),
                        style: theme.textTheme.songSubtitle.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final label in codeLabels)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.primarySoftAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    label,
                    style: theme.textTheme.chipLabel.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          if (deepErrorLabel != null) ...[
            const SizedBox(height: 8),
            Text(
              deepErrorLabel!,
              style: theme.textTheme.songSubtitle.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Wrap(
            children: [
              TextButton(onPressed: onPlay, child: Text(l10n.contextMenuPlay)),
              TextButton(
                onPressed: onOpenAlbum,
                child: Text(l10n.libraryAuditOpenAlbum),
              ),
              TextButton(
                onPressed: onDelete,
                child: Text(l10n.contextMenuDelete),
              ),
              if (onReplace != null)
                TextButton(
                  onPressed: onReplace,
                  child: Text(l10n.libraryAuditReplace),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
