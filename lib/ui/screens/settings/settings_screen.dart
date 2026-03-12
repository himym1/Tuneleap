import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:path_provider/path_provider.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  final VoidCallback onLogout;

  const SettingsScreen({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(serverConfigProvider);
    final themeMode = ref.watch(themeModeProvider);
    final appVersion = ref.watch(appVersionProvider);

    // 转换 ThemeMode 到 SegmentedButton 的 selected 值
    final selectedTheme = switch (themeMode) {
      ThemeMode.system => 'system',
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
    };

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 600;
          final spacing = isDesktop ? 24.0 : 16.0;
          final padding = isDesktop ? 32.0 : 16.0;

          return ListView(
            padding: EdgeInsets.all(padding),
            children: [
              // 标题
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    S.of(context).navSettings,
                    style: Theme.of(context).textTheme.settingsPageTitle,
                  ),
                  Text(
                    '${S.of(context).settingsVersion} $appVersion',
                    style: Theme.of(context).textTheme.settingsVersionLabel,
                  ),
                ],
              ),
              SizedBox(height: isDesktop ? 40 : 28),

              // 桌面端两列，移动端单列
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _SettingsSection(
                            title: S.of(context).settingsCurrentServer,
                            subtitle:
                                '${config.url}\n${S.of(context).settingsUser}: ${config.username}',
                          ),
                          SizedBox(height: spacing),
                          _SettingsSection(
                            title: S.of(context).settingsTheme,
                            subtitle:
                                '${S.of(context).settingsThemeSystem} / ${S.of(context).settingsThemeDark} / ${S.of(context).settingsThemeLight}',
                            trailing: SegmentedButton<String>(
                              segments: [
                                ButtonSegment(
                                  value: 'system',
                                  label: Text(
                                    S.of(context).settingsThemeSystem,
                                    style: Theme.of(context).textTheme.segmentLabel,
                                  ),
                                ),
                                ButtonSegment(
                                  value: 'light',
                                  label: Text(
                                    S.of(context).settingsThemeLight,
                                    style: Theme.of(context).textTheme.segmentLabel,
                                  ),
                                ),
                                ButtonSegment(
                                  value: 'dark',
                                  label: Text(
                                    S.of(context).settingsThemeDark,
                                    style: Theme.of(context).textTheme.segmentLabel,
                                  ),
                                ),
                              ],
                              selected: {selectedTheme},
                              onSelectionChanged: (value) {
                                final mode = switch (value.first) {
                                  'light' => ThemeMode.light,
                                  'dark' => ThemeMode.dark,
                                  _ => ThemeMode.system,
                                };
                                ref
                                    .read(themeModeProvider.notifier)
                                    .setMode(mode);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: spacing),
                    Expanded(
                      child: Column(
                        children: [
                          const _CacheSection(),
                          SizedBox(height: spacing),
                          _SettingsSection(
                            title: S.of(context).settingsAbout,
                            subtitle: S
                                .of(context)
                                .settingsAboutText(
                                  S.of(context).appName,
                                  appVersion,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else ...[
                _SettingsSection(
                  title: S.of(context).settingsCurrentServer,
                  subtitle:
                      '${config.url}\n${S.of(context).settingsUser}: ${config.username}',
                ),
                SizedBox(height: spacing),
                _SettingsSection(
                  title: S.of(context).settingsTheme,
                  subtitle:
                      '${S.of(context).settingsThemeSystem} / ${S.of(context).settingsThemeDark} / ${S.of(context).settingsThemeLight}',
                  trailing: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'system',
                        label: Text(
                          S.of(context).settingsThemeSystem,
                          style: Theme.of(context).textTheme.segmentLabel,
                        ),
                      ),
                      ButtonSegment(
                        value: 'light',
                        label: Text(
                          S.of(context).settingsThemeLight,
                          style: Theme.of(context).textTheme.segmentLabel,
                        ),
                      ),
                      ButtonSegment(
                        value: 'dark',
                        label: Text(
                          S.of(context).settingsThemeDark,
                          style: Theme.of(context).textTheme.segmentLabel,
                        ),
                      ),
                    ],
                    selected: {selectedTheme},
                    onSelectionChanged: (value) {
                      final mode = switch (value.first) {
                        'light' => ThemeMode.light,
                        'dark' => ThemeMode.dark,
                        _ => ThemeMode.system,
                      };
                      ref.read(themeModeProvider.notifier).setMode(mode);
                    },
                  ),
                ),
                SizedBox(height: spacing),
                const _CacheSection(),
                SizedBox(height: spacing),
                _SettingsSection(
                  title: S.of(context).settingsAbout,
                  subtitle: S
                      .of(context)
                      .settingsAboutText(S.of(context).appName, appVersion),
                ),
              ],
              SizedBox(height: spacing * 2),

              // 退出登录
              SizedBox(
                width: isDesktop ? 300 : double.infinity,
                child: Tooltip(
                  message: S.of(context).settingsLogout,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: Text(S.of(context).settingsLogout),
                          content: Text(S.of(context).settingsLogoutConfirm),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: Text(S.of(context).commonCancel),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: Text(S.of(context).commonConfirm),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await ref.read(serverConfigProvider.notifier).clear();
                        onLogout();
                      }
                    },
                    icon: Icon(Icons.logout, size: 18, color: context.colors.error),
                    label: Text(
                      S.of(context).settingsLogout,
                      style: TextStyle(color: context.colors.error),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      side: BorderSide(color: context.colors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CacheSection extends StatefulWidget {
  const _CacheSection();

  @override
  State<_CacheSection> createState() => _CacheSectionState();
}

class _CacheSectionState extends State<_CacheSection> {
  String _cacheSize = '';
  bool _clearing = false;
  bool _cacheInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cacheInitialized) return;
    _cacheInitialized = true;
    _cacheSize = S.of(context).settingsCacheCalculating;
    _calculateCacheSize();
  }

  Future<void> _calculateCacheSize() async {
    try {
      final dir = await getTemporaryDirectory();
      final size = await _dirSize(dir);
      if (!mounted) return;
      final s = S.of(context);
      setState(() {
        if (size < 1024 * 1024) {
          _cacheSize = s.commonSizeKb((size / 1024).toStringAsFixed(1));
        } else if (size < 1024 * 1024 * 1024) {
          _cacheSize = s.commonSizeMb(
            (size / (1024 * 1024)).toStringAsFixed(1),
          );
        } else {
          _cacheSize = s.commonSizeGb(
            (size / (1024 * 1024 * 1024)).toStringAsFixed(1),
          );
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _cacheSize = S.of(context).settingsCacheUnknown);
      }
    }
  }

  Future<int> _dirSize(Directory dir) async {
    int total = 0;
    try {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          total += await entity.length();
        }
      }
    } catch (e) {
      debugPrint('Failed to calculate cache size: $e');
    }
    return total;
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
          } catch (e) {
            debugPrint('Failed to delete cache entry: $e');
          }
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context).settingsCacheStorage,
                  style: Theme.of(context).textTheme.settingsSectionTitle,
                ),
                const SizedBox(height: 6),
                Text(
                  '${S.of(context).settingsCacheUsed}: $_cacheSize\n${S.of(context).settingsCacheMaxCache}: ${S.of(context).settingsUnlimited}',
                  style: Theme.of(context).textTheme.settingsSectionSubtitle,
                ),
              ],
            ),
          ),
          _clearing
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.colors.primary,
                  ),
                )
              : Tooltip(
                  message: S.of(context).settingsCacheClear,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: TextButton(
                      onPressed: _clearCache,
                      child: Text(S.of(context).settingsCacheClear),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SettingsSection({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.settingsSectionTitle,
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.settingsSectionSubtitle,
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
