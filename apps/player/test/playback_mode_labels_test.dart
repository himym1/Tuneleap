import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/l10n/app_localizations.dart';
import 'package:navidrome_player/player/audio_player_service.dart';
import 'package:navidrome_player/ui/widgets/playback_mode_listener.dart';

void main() {
  test('repeat icon only changes for single-track loop', () {
    expect(playbackRepeatIcon(PlaybackRepeatMode.off), Icons.repeat_rounded);
    expect(playbackRepeatIcon(PlaybackRepeatMode.all), Icons.repeat_rounded);
    expect(
      playbackRepeatIcon(PlaybackRepeatMode.one),
      Icons.repeat_one_rounded,
    );
  });

  testWidgets('tooltips name the current shuffle and repeat mode', (
    tester,
  ) async {
    late S l10n;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = S.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(playbackShuffleTooltip(l10n, false), '随机：关');
    expect(playbackShuffleTooltip(l10n, true), '随机：开');
    expect(playbackRepeatTooltip(l10n, PlaybackRepeatMode.off), '循环：关（播完即停）');
    expect(playbackRepeatTooltip(l10n, PlaybackRepeatMode.all), '循环：列表');
    expect(playbackRepeatTooltip(l10n, PlaybackRepeatMode.one), '循环：单曲');
  });

  test('selected mode style keeps a dark icon on a pale cover seed', () {
    const iconColor = Color(0xFF111827);
    final style = playbackModeButtonStyle(iconColor: iconColor);
    const selected = {WidgetState.selected};

    expect(style.foregroundColor!.resolve(selected), iconColor);
    expect(style.foregroundColor!.resolve(const {}), iconColor);

    final selectedBackground = style.backgroundColor!.resolve(selected)!;
    expect(selectedBackground.a, closeTo(0.12, 0.001));
    expect(selectedBackground.withValues(alpha: 1.0), iconColor);
    expect(style.backgroundColor!.resolve(const {}), Colors.transparent);
  });

  testWidgets('selected repeat-one icon stays readable on a white page', (
    tester,
  ) async {
    const iconColor = Color(0xFF111827);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFF5F0E6),
            brightness: Brightness.light,
          ),
        ),
        home: Scaffold(
          backgroundColor: Colors.white,
          body: PlaybackModeIconButton(
            selected: true,
            icon: Icons.repeat_one_rounded,
            tooltip: '循环：单曲',
            iconColor: iconColor,
            onPressed: () {},
          ),
        ),
      ),
    );

    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(
      button.style!.foregroundColor!.resolve({WidgetState.selected}),
      iconColor,
    );
    expect(find.byIcon(Icons.repeat_one_rounded), findsOneWidget);
  });
}
