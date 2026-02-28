import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:navidrome_player/providers/providers.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/ui/screens/login/login_screen.dart';
import 'package:navidrome_player/ui/screens/home/home_screen.dart';

class NavidromePlayerApp extends ConsumerStatefulWidget {
  const NavidromePlayerApp({super.key});

  @override
  ConsumerState<NavidromePlayerApp> createState() => _NavidromePlayerAppState();
}

class _NavidromePlayerAppState extends ConsumerState<NavidromePlayerApp> {
  bool _initialized = false;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _initPlatform();
  }

  Future<void> _initPlatform() async {
    // macOS 窗口配置
    if (Platform.isMacOS) {
      await windowManager.ensureInitialized();
      await windowManager.setMinimumSize(const Size(400, 600));
      await windowManager.setSize(const Size(1000, 700));
      await windowManager.setTitle('Navidrome Player');
      await windowManager.show();
    }

    // 检查是否已有保存的服务器配置
    final config = ref.read(serverConfigProvider);
    if (config.isConfigured) {
      final client = ref.read(subsonicClientProvider);
      final ok = await client.ping();
      if (ok) {
        setState(() => _loggedIn = true);
      }
    }

    setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Navidrome Player',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_loggedIn) {
      return LoginScreen(
        onLoginSuccess: () => setState(() => _loggedIn = true),
      );
    }

    return const HomeScreen();
  }
}
