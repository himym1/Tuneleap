import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/services/sparkle_updater.dart';
import 'package:navidrome_player/services/update_checker.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/update_dialog.dart';
import 'package:navidrome_player/ui/widgets/responsive_content.dart';
import 'package:navidrome_player/ui/widgets/cloud_auth_dialog.dart';
import 'package:navidrome_player/ui/widgets/keyboard_shortcuts_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(serverConfigProvider);
    final themeMode = ref.watch(themeModeProvider);
    final themePreset = ref.watch(themePresetProvider);
    final appVersion = ref.watch(appVersionProvider);
    final appBuild = ref.watch(appBuildProvider);
    final cloudAuth = ref.watch(cloudAuthProvider);
    final cloudSession = cloudAuth.value;
    final isMobile = AppBreakpoints.isMobile(MediaQuery.of(context).size.width);
    final padding = isMobile
        ? AppDimensions.paddingMobile
        : AppDimensions.paddingDesktop;

    return ResponsivePageScaffold(
      body: ListView(
        padding: EdgeInsets.symmetric(vertical: padding),
        children: [
          Text(
            S.of(context).navSettings,
            style: Theme.of(context).textTheme.pageTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),

          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 账号 ──
                  _SectionLabel(S.of(context).settingsCurrentServer),
                  _SettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.dns_rounded,
                        title: config.url.isNotEmpty
                            ? config.url
                            : S.of(context).settingsServerUnconfigured,
                        subtitle: config.username.isNotEmpty
                            ? '${S.of(context).settingsUser}: ${config.username}'
                            : null,
                      ),
                      const Divider(height: 1, indent: 54),
                      _SettingsTile(
                        icon: Icons.cloud_outlined,
                        title: S.of(context).cloudAccount,
                        subtitle: cloudSession?.isAuthenticated == true
                            ? '${S.of(context).cloudSignedIn}: ${cloudSession!.username}'
                            : S.of(context).cloudSignedOut,
                        trailing: TextButton(
                          onPressed: cloudAuth.isLoading
                              ? null
                              : () async {
                                  if (cloudSession?.isAuthenticated == true) {
                                    await ref
                                        .read(cloudAuthProvider.notifier)
                                        .signOut();
                                    return;
                                  }
                                  final ok = await CloudAuthDialog.show(
                                    context,
                                  );
                                  if (ok && context.mounted) {
                                    await ref
                                        .read(recommendationProvider.notifier)
                                        .refresh();
                                  }
                                },
                          child: Text(
                            cloudSession?.isAuthenticated == true
                                ? S.of(context).cloudSignOut
                                : S.of(context).cloudSignIn,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  _SectionLabel(S.of(context).recommendationsTitle),
                  _SettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.tune_rounded,
                        title: S.of(context).settingsResetRecommendations,
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          final l10n = S.of(context);
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(l10n.settingsResetRecommendations),
                              content: Text(
                                l10n.settingsResetRecommendationsConfirm,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(l10n.commonCancel),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(l10n.commonConfirm),
                                ),
                              ],
                            ),
                          );
                          if (ok != true) return;
                          await ref
                              .read(recommendationProvider.notifier)
                              .reset();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.settingsResetRecommendationsDone,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  _SectionLabel(S.of(context).settingsOnlineSources),
                  _OnlineSearchSettingsCard(),

                  const SizedBox(height: 24),

                  // ── 外观 ──
                  _SectionLabel(S.of(context).settingsTheme),
                  _SettingsCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.palette_outlined,
                              size: 22,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: SegmentedButton<ThemeMode>(
                                segments: [
                                  ButtonSegment(
                                    value: ThemeMode.system,
                                    label: Text(
                                      S.of(context).settingsThemeSystem,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.segmentLabel,
                                    ),
                                  ),
                                  ButtonSegment(
                                    value: ThemeMode.light,
                                    label: Text(
                                      S.of(context).settingsThemeLight,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.segmentLabel,
                                    ),
                                  ),
                                  ButtonSegment(
                                    value: ThemeMode.dark,
                                    label: Text(
                                      S.of(context).settingsThemeDark,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.segmentLabel,
                                    ),
                                  ),
                                ],
                                selected: {themeMode},
                                onSelectionChanged: (value) {
                                  ref
                                      .read(themeModeProvider.notifier)
                                      .setMode(value.first);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, indent: 54),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Tooltip(
                              message: S.of(context).settingsThemeStyle,
                              child: Icon(
                                Icons.color_lens_outlined,
                                size: 22,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<ThemePreset>(
                                  value: themePreset,
                                  isExpanded: true,
                                  items: [
                                    DropdownMenuItem(
                                      value: ThemePreset.classic,
                                      child: Text(
                                        S.of(context).settingsThemeClassic,
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: ThemePreset.amoled,
                                      child: Text(
                                        S.of(context).settingsThemeAmoled,
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: ThemePreset.dynamic,
                                      child: Text(
                                        S.of(context).settingsThemeDynamic,
                                      ),
                                    ),
                                  ],
                                  onChanged: (preset) {
                                    if (preset == null) return;
                                    ref
                                        .read(themePresetProvider.notifier)
                                        .setPreset(preset);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  _SectionLabel(S.of(context).settingsTools),
                  _SettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.favorite_outline_rounded,
                        title: S.of(context).navFavorites,
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.go('/favorites'),
                      ),
                      const Divider(height: 1, indent: 54),
                      _SettingsTile(
                        icon: Icons.high_quality_rounded,
                        title: S.of(context).settingsAudioQuality,
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.go('/audio-quality'),
                      ),
                      const Divider(height: 1, indent: 54),
                      _SettingsTile(
                        icon: Icons.health_and_safety_outlined,
                        title: S.of(context).libraryAuditTitle,
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.go('/library-audit'),
                      ),
                      const Divider(height: 1, indent: 54),
                      _SettingsTile(
                        icon: Icons.download_rounded,
                        title: S.of(context).navDownloads,
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.go('/downloads'),
                      ),
                      const Divider(height: 1, indent: 54),
                      _SettingsTile(
                        icon: Icons.dns_rounded,
                        title: S.of(context).navServers,
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.go('/servers'),
                      ),
                      const Divider(height: 1, indent: 54),
                      _SettingsTile(
                        icon: Icons.history_rounded,
                        title: S.of(context).navScrobble,
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.go('/scrobble'),
                      ),
                      const Divider(height: 1, indent: 54),
                      _SettingsTile(
                        icon: Icons.keyboard_rounded,
                        title: S.of(context).shortcutsTitle,
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => KeyboardShortcutsDialog.show(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── 存储 ──
                  _SectionLabel(S.of(context).settingsCacheStorage),
                  const _CacheTile(),

                  const SizedBox(height: 24),

                  // ── 关于 ──
                  _SectionLabel(S.of(context).settingsAbout),
                  _SettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.info_outline_rounded,
                        title: '${S.of(context).appName} v$appVersion',
                        subtitle: S
                            .of(context)
                            .settingsAboutText(
                              S.of(context).appName,
                              appVersion,
                            ),
                      ),
                      const Divider(height: 1, indent: 54),
                      _UpdateTile(
                        currentVersion: appVersion,
                        currentBuild: appBuild,
                        updateOrigin: resolveCloudOrigin(config.backendUrl),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // ── 退出 ──
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _confirmLogout(context, ref),
                      icon: Icon(
                        Icons.logout_rounded,
                        size: 18,
                        color: context.colors.error,
                      ),
                      label: Text(
                        S.of(context).settingsLogout,
                        style: TextStyle(color: context.colors.error),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of(context).settingsLogout),
        content: Text(S.of(context).settingsLogoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.of(context).commonConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(authProvider.notifier).signOut();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(S.of(context).commonError)));
    }
  }
}

class _OnlineSearchSettingsCard extends ConsumerWidget {
  const _OnlineSearchSettingsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capabilities = ref.watch(musicCapabilitiesProvider);
    final selected = ref.watch(effectiveOnlineSearchAdapterProvider);
    final supported = ref.watch(supportedOnlineSourcesProvider);
    final adapters = capabilities.value?.adapters ?? const [];
    final selectedAvailable = adapters.any((adapter) => adapter.id == selected);

    return _SettingsCard(
      children: [
        ListTile(
          leading: Icon(
            Icons.hub_outlined,
            size: 22,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          title: Text(
            S.of(context).settingsOnlineAdapter,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: selected,
                isExpanded: true,
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      onlineAdapterLabel(context, null),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (selected != null && !selectedAvailable)
                    DropdownMenuItem<String?>(
                      value: selected,
                      child: Text(
                        onlineAdapterLabel(context, selected),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  for (final adapter in adapters)
                    DropdownMenuItem<String?>(
                      value: adapter.id,
                      child: Text(
                        onlineAdapterLabel(context, adapter.id),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: capabilities.isLoading
                    ? null
                    : (provider) async {
                        await ref
                            .read(onlineSearchAdapterProvider.notifier)
                            .setProvider(provider);
                        final nextCapabilities = ref
                            .read(musicCapabilitiesProvider)
                            .value;
                        final nextSupported = catalogSourcesSupportedBy(
                          nextCapabilities,
                          provider,
                        );
                        await ref
                            .read(onlineSourcePreferencesProvider.notifier)
                            .ensureAny(nextSupported);
                      },
              ),
            ),
          ),
        ),
        const Divider(height: 1, indent: 54),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            capabilities.hasError
                ? S.of(context).settingsOnlineAdapterUnavailable
                : S.of(context).settingsOnlineSourcesHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        for (final source in supported) ...[
          if (source != supported.first) const Divider(height: 1, indent: 54),
          _OnlineSourceToggle(source: source, requiredSources: supported),
        ],
      ],
    );
  }
}

class _OnlineSourceToggle extends ConsumerWidget {
  const _OnlineSourceToggle({
    required this.source,
    required this.requiredSources,
  });

  final String source;
  final List<String> requiredSources;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(onlineSourcePreferencesProvider).contains(source);
    return SwitchListTile(
      secondary: Icon(
        Icons.library_music_outlined,
        size: 22,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(
        onlineSourceLabel(context, source),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      value: enabled,
      onChanged: (value) async {
        final kept = await ref
            .read(onlineSourcePreferencesProvider.notifier)
            .setEnabled(
              source,
              enabled: value,
              requiredSources: requiredSources,
            );
        if (!kept && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.of(context).settingsOnlineSourcesKeepOne)),
          );
        }
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
    );
  }
}

// ── 分组标签 ──

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── 分组卡片容器 ──

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(
          alpha: isDark ? 0.08 : 0.04,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(
            alpha: isDark ? 0.10 : 0.06,
          ),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

// ── 通用设置行 ──

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withValues(
            alpha: isDark ? 0.10 : 0.06,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

// ── 缓存行 ──

class _CacheTile extends StatefulWidget {
  const _CacheTile();

  @override
  State<_CacheTile> createState() => _CacheTileState();
}

class _CacheTileState extends State<_CacheTile> {
  String _cacheSize = '';
  bool _clearing = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _cacheSize = S.of(context).settingsCacheCalculating;
    _calculateCacheSize();
  }

  Future<void> _calculateCacheSize() async {
    try {
      final dir = await getTemporaryDirectory();
      int total = 0;
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) total += await entity.length();
      }
      if (!mounted) return;
      final s = S.of(context);
      setState(() {
        if (total < 1024 * 1024) {
          _cacheSize = s.commonSizeKb((total / 1024).toStringAsFixed(1));
        } else if (total < 1024 * 1024 * 1024) {
          _cacheSize = s.commonSizeMb(
            (total / (1024 * 1024)).toStringAsFixed(1),
          );
        } else {
          _cacheSize = s.commonSizeGb(
            (total / (1024 * 1024 * 1024)).toStringAsFixed(1),
          );
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _cacheSize = S.of(context).settingsCacheUnknown);
      }
    }
  }

  Future<void> _clearCache() async {
    setState(() => _clearing = true);
    try {
      final dir = await getTemporaryDirectory();
      if (dir.existsSync()) {
        await for (final entity in dir.list()) {
          try {
            if (entity is File) {
              await entity.delete();
            } else if (entity is Directory) {
              await entity.delete(recursive: true);
            }
          } catch (_) {}
        }
      }
      await _calculateCacheSize();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context).settingsCacheCleared),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context).settingsCacheClearFailed),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      children: [
        _SettingsTile(
          icon: Icons.folder_rounded,
          title: _cacheSize,
          subtitle: S.of(context).settingsCacheUsed,
          trailing: _clearing
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.colors.primary,
                  ),
                )
              : TextButton(
                  onPressed: _clearCache,
                  child: Text(S.of(context).settingsCacheClear),
                ),
        ),
      ],
    );
  }
}

// ── 检查更新行 ──

class _UpdateTile extends ConsumerStatefulWidget {
  final String currentVersion;
  final int currentBuild;
  final String updateOrigin;

  const _UpdateTile({
    required this.currentVersion,
    required this.currentBuild,
    required this.updateOrigin,
  });

  @override
  ConsumerState<_UpdateTile> createState() => _UpdateTileState();
}

class _UpdateTileState extends ConsumerState<_UpdateTile> {
  bool _checking = false;
  String? _result;

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _result = null;
    });
    Future<String?> token({bool forceRefresh = false}) => ref
        .read(cloudAuthProvider.notifier)
        .getAccessToken(forceRefresh: forceRefresh);
    if (isSparkleSupported) {
      final access = await token();
      if (!mounted) return;
      if (access != null && access.isNotEmpty) {
        await SparkleUpdater.configure(
          feedURL: sparkleFeedURL(widget.updateOrigin),
          accessToken: access,
        );
      }
    }
    final info = await checkForUpdate(
      accessTokenProvider: token,
      updateOrigin: widget.updateOrigin,
    );
    if (!mounted) return;
    if (info == null) {
      setState(() {
        _checking = false;
        _result = 'failed';
      });
      return;
    }
    final hasNew = isNewerVersion(
      info.version,
      widget.currentVersion,
      remoteBuild: info.build,
      localBuild: widget.currentBuild,
    );
    setState(() {
      _checking = false;
      _result = hasNew ? info.version : 'latest';
    });
    if (!hasNew) return;
    if (isSparkleSupported && await SparkleUpdater.checkForUpdates()) {
      return;
    }
    if (!mounted) return;
    UpdateDialog.show(context, info);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    String subtitle = s.updateCheckUpdate;
    if (_result == 'latest') subtitle = s.updateLatest;
    if (_result == 'failed') subtitle = s.updateFailed;
    if (_result != null && _result != 'latest' && _result != 'failed') {
      subtitle = s.updateNewVersion(_result!);
    }

    return _SettingsTile(
      icon: Icons.system_update_outlined,
      title: s.updateCheckUpdate,
      subtitle: _result != null ? subtitle : null,
      trailing: _checking
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.colors.primary,
              ),
            )
          : IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: _check,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      onTap: _checking ? null : _check,
    );
  }
}
