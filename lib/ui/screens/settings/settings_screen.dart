import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/services/update_checker.dart';
import 'package:navidrome_player/ui/theme/app_dimensions.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/widgets/update_dialog.dart';
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
    final padding = AppBreakpoints.isMobile(MediaQuery.of(context).size.width)
        ? 16.0
        : 32.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: EdgeInsets.all(padding),
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
                        icon: Icons.dns_outlined,
                        title: config.url.isNotEmpty ? config.url : '未配置',
                        subtitle: config.username.isNotEmpty
                            ? '${S.of(context).settingsUser}: ${config.username}'
                            : null,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  _SectionLabel(S.of(context).recommendationsTitle),
                  _SettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.tune,
                        title: S.of(context).settingsResetRecommendations,
                        trailing: const Icon(Icons.chevron_right),
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

                  // ── 存储 ──
                  _SectionLabel(S.of(context).settingsCacheStorage),
                  const _CacheTile(),

                  const SizedBox(height: 24),

                  // ── 关于 ──
                  _SectionLabel(S.of(context).settingsAbout),
                  _SettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.info_outline,
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
                        apiKey: config.backendApiKey,
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // ── 退出 ──
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _confirmLogout(context, ref),
                      icon: Icon(
                        Icons.logout,
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
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
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
    return ListTile(
      leading: Icon(
        icon,
        size: 22,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
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
          icon: Icons.folder_outlined,
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

class _UpdateTile extends StatefulWidget {
  final String currentVersion;
  final int currentBuild;
  final String apiKey;

  const _UpdateTile({
    required this.currentVersion,
    required this.currentBuild,
    required this.apiKey,
  });

  @override
  State<_UpdateTile> createState() => _UpdateTileState();
}

class _UpdateTileState extends State<_UpdateTile> {
  bool _checking = false;
  String? _result;

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _result = null;
    });
    final info = await checkForUpdate(apiKey: widget.apiKey);
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
    if (hasNew) UpdateDialog.show(context, info, apiKey: widget.apiKey);
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
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _check,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      onTap: _checking ? null : _check,
    );
  }
}
