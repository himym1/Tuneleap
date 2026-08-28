import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/api/backend_client.dart';
import 'package:navidrome_player/api/models/library_audit.dart';

import 'audio_providers.dart';
import 'server_config_provider.dart';

const libraryAuditLowBitratePrefKey = 'library_audit_low_bitrate_kbps';
const libraryAuditSuspectLosslessPrefKey =
    'library_audit_suspect_lossless_kbps';
const libraryAuditDurationTolerancePrefKey =
    'library_audit_duration_tolerance_seconds';

class LibraryAuditReplaceTarget {
  const LibraryAuditReplaceTarget({
    required this.songId,
    required this.title,
    required this.artist,
  });

  final String songId;
  final String title;
  final String artist;

  String get searchQuery {
    return [title, artist].where((part) => part.trim().isNotEmpty).join(' ');
  }
}

class LibraryAuditReplaceSession {
  const LibraryAuditReplaceSession({required this.targets, this.index = 0});

  final List<LibraryAuditReplaceTarget> targets;
  final int index;

  LibraryAuditReplaceTarget get current => targets[index];

  int get total => targets.length;

  int get currentNumber => index + 1;

  bool get hasMore => index + 1 < targets.length;
}

class LibraryAuditState {
  const LibraryAuditState({
    this.snapshot = const LibraryAuditSnapshot(),
    this.findings = const [],
    this.filterCode,
    this.loading = false,
    this.error,
  });

  final LibraryAuditSnapshot snapshot;
  final List<LibraryAuditFinding> findings;
  final String? filterCode;
  final bool loading;
  final String? error;

  List<LibraryAuditFinding> get visibleFindings {
    final code = filterCode;
    if (code == null || code.isEmpty) return findings;
    return [
      for (final finding in findings)
        if (finding.codes.contains(code)) finding,
    ];
  }

  /// Quality defects when the "all" filter is active.
  List<LibraryAuditFinding> get qualityFindings => [
    for (final finding in findings)
      if (finding.hasQualityIssue) finding,
  ];

  /// Version-only rows (no quality defect) when the "all" filter is active.
  List<LibraryAuditFinding> get versionOnlyFindings => [
    for (final finding in findings)
      if (finding.isVersionOnly) finding,
  ];

  int get qualityIssueCount => qualityFindings.length;

  int get versionOnlyCount => versionOnlyFindings.length;

  bool get showGroupedFindings {
    final code = filterCode;
    return code == null || code.isEmpty;
  }

  LibraryAuditState copyWith({
    LibraryAuditSnapshot? snapshot,
    List<LibraryAuditFinding>? findings,
    String? filterCode,
    bool? loading,
    String? error,
    bool clearFilter = false,
    bool clearError = false,
  }) {
    return LibraryAuditState(
      snapshot: snapshot ?? this.snapshot,
      findings: findings ?? this.findings,
      filterCode: clearFilter ? null : (filterCode ?? this.filterCode),
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final libraryAuditRulesProvider =
    NotifierProvider<LibraryAuditRulesNotifier, LibraryAuditRules>(
      LibraryAuditRulesNotifier.new,
    );

class LibraryAuditRulesNotifier extends Notifier<LibraryAuditRules> {
  @override
  LibraryAuditRules build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return LibraryAuditRules.clamped(
      lowBitrateKbps:
          prefs.getInt(libraryAuditLowBitratePrefKey) ??
          LibraryAuditRules.defaultLowBitrateKbps,
      suspectLosslessKbps:
          prefs.getInt(libraryAuditSuspectLosslessPrefKey) ??
          LibraryAuditRules.defaultSuspectLosslessKbps,
      durationToleranceSeconds:
          prefs.getInt(libraryAuditDurationTolerancePrefKey) ??
          LibraryAuditRules.defaultDurationToleranceSeconds,
    );
  }

  Future<void> update({
    int? lowBitrateKbps,
    int? suspectLosslessKbps,
    int? durationToleranceSeconds,
  }) async {
    final next = LibraryAuditRules.clamped(
      lowBitrateKbps: lowBitrateKbps ?? state.lowBitrateKbps,
      suspectLosslessKbps: suspectLosslessKbps ?? state.suspectLosslessKbps,
      durationToleranceSeconds:
          durationToleranceSeconds ?? state.durationToleranceSeconds,
    );
    state = next;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(libraryAuditLowBitratePrefKey, next.lowBitrateKbps);
    await prefs.setInt(
      libraryAuditSuspectLosslessPrefKey,
      next.suspectLosslessKbps,
    );
    await prefs.setInt(
      libraryAuditDurationTolerancePrefKey,
      next.durationToleranceSeconds,
    );
  }
}

final libraryAuditReplaceTargetProvider =
    NotifierProvider<
      LibraryAuditReplaceTargetNotifier,
      LibraryAuditReplaceSession?
    >(LibraryAuditReplaceTargetNotifier.new);

class LibraryAuditReplaceTargetNotifier
    extends Notifier<LibraryAuditReplaceSession?> {
  @override
  LibraryAuditReplaceSession? build() {
    ref.watch(serverConfigProvider.select((config) => config.serverId));
    return null;
  }

  void setTarget(LibraryAuditReplaceTarget? target) {
    setQueue(target == null ? const [] : [target]);
  }

  void setQueue(List<LibraryAuditReplaceTarget> targets) {
    final cleaned = [
      for (final target in targets)
        if (target.songId.isNotEmpty) target,
    ];
    state = cleaned.isEmpty
        ? null
        : LibraryAuditReplaceSession(targets: cleaned);
  }

  LibraryAuditReplaceTarget? completeCurrent() {
    final session = state;
    if (session == null) return null;
    final nextIndex = session.index + 1;
    if (nextIndex >= session.targets.length) {
      state = null;
      return null;
    }
    state = LibraryAuditReplaceSession(
      targets: session.targets,
      index: nextIndex,
    );
    return state?.current;
  }

  void clear() => state = null;
}

final libraryAuditProvider =
    NotifierProvider<LibraryAuditNotifier, LibraryAuditState>(
      LibraryAuditNotifier.new,
    );

class LibraryAuditNotifier extends Notifier<LibraryAuditState> {
  Timer? _poll;

  BackendClient get _client => ref.read(backendClientProvider);

  @override
  LibraryAuditState build() {
    ref.onDispose(_stopPoll);
    ref.watch(serverConfigProvider.select((config) => config.serverId));
    return const LibraryAuditState();
  }

  Future<void> hydrate() async {
    if (state.loading ||
        state.snapshot.hasResult ||
        state.snapshot.isScanning) {
      return;
    }
    await refresh();
  }

  Future<void> refresh() async {
    if (!_client.canAuditLibrary) {
      state = state.copyWith(error: 'nas-required', loading: false);
      return;
    }
    state = state.copyWith(loading: true, clearError: true);
    try {
      final snapshot = await _client.getLibraryAudit();
      final findings = snapshot.hasResult || snapshot.isScanning
          ? await _client.getLibraryAuditFindings()
          : const <LibraryAuditFinding>[];
      state = state.copyWith(
        snapshot: snapshot,
        findings: findings,
        loading: false,
        clearError: true,
      );
      if (snapshot.isScanning) {
        _startPoll();
      } else {
        _stopPoll();
      }
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  Future<void> start() async {
    if (!_client.canAuditLibrary) {
      state = state.copyWith(error: 'nas-required');
      return;
    }
    state = state.copyWith(loading: true, clearError: true);
    try {
      final snapshot = await _client.startLibraryAudit(
        rules: ref.read(libraryAuditRulesProvider),
      );
      state = state.copyWith(
        snapshot: snapshot,
        findings: const [],
        loading: false,
        clearFilter: true,
        clearError: true,
      );
      _startPoll();
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  Future<void> startDeep({String scope = 'findings'}) async {
    if (!_client.canAuditLibrary) {
      state = state.copyWith(error: 'nas-required');
      return;
    }
    state = state.copyWith(loading: true, clearError: true);
    try {
      final snapshot = await _client.startLibraryAuditDeep(scope: scope);
      state = state.copyWith(
        snapshot: snapshot,
        loading: false,
        clearError: true,
      );
      _startPoll();
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  Future<void> cancel() async {
    if (!_client.canAuditLibrary) return;
    try {
      final snapshot = await _client.cancelLibraryAudit();
      state = state.copyWith(snapshot: snapshot, clearError: true);
      if (!snapshot.isScanning) {
        await refresh();
      }
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
  }

  void setFilter(String? code) {
    state = state.copyWith(filterCode: code, clearFilter: code == null);
  }

  void removeFinding(String songId) {
    removeFindings([songId]);
  }

  void removeFindings(Iterable<String> songIds) {
    final remove = songIds.toSet();
    if (remove.isEmpty) return;
    final remaining = [
      for (final finding in state.findings)
        if (!remove.contains(finding.songId)) finding,
    ];
    _applyFindings(remaining);
  }

  void _applyFindings(List<LibraryAuditFinding> remaining) {
    final snapshot = state.snapshot;
    final summary = snapshot.summary;
    state = state.copyWith(
      findings: remaining,
      snapshot: LibraryAuditSnapshot(
        active: snapshot.active,
        stage: snapshot.stage,
        scanned: snapshot.scanned,
        total: snapshot.total,
        error: snapshot.error,
        message: snapshot.message,
        summary: LibraryAuditSummary(
          scanned: summary.scanned,
          passed: summary.passed + (state.findings.length - remaining.length),
          issues: remaining.length,
          missing: remaining
              .where((item) => item.codes.contains(libraryAuditCodeMissing))
              .length,
          lowBitrate: remaining
              .where((item) => item.codes.contains(libraryAuditCodeLowBitrate))
              .length,
          suspectTranscode: remaining
              .where(
                (item) => item.codes.contains(libraryAuditCodeSuspectTranscode),
              )
              .length,
          duplicateVersion: remaining
              .where(
                (item) => item.codes.contains(libraryAuditCodeDuplicateVersion),
              )
              .length,
          lossyTranscode: remaining
              .where(
                (item) => item.codes.contains(libraryAuditCodeLossyTranscode),
              )
              .length,
          fakeHires: remaining
              .where((item) => item.codes.contains(libraryAuditCodeFakeHires))
              .length,
          deepFailed: remaining
              .where((item) => item.codes.contains(libraryAuditCodeDeepFailed))
              .length,
        ),
      ),
    );
  }

  void _startPoll() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_pollOnce());
    });
  }

  Future<void> _pollOnce() async {
    if (!_client.canAuditLibrary) {
      _stopPoll();
      return;
    }
    try {
      final snapshot = await _client.getLibraryAudit();
      final findings = snapshot.hasResult
          ? await _client.getLibraryAuditFindings()
          : state.findings;
      state = state.copyWith(
        snapshot: snapshot,
        findings: findings,
        clearError: true,
      );
      if (!snapshot.isScanning) {
        _stopPoll();
      }
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
  }

  void _stopPoll() {
    _poll?.cancel();
    _poll = null;
  }
}
