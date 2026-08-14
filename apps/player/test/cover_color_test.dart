import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navidrome_player/ui/theme/app_color_loader.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/utils/cover_color.dart';

const _fallback = Color(0xFF1E1B4B);
const _orangeAccent = Color(0xFFFF9A1F);
const _beigeMud = Color(0xFFC4B5A0);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initializeAppColors);

  test('grayscale cover with a small orange highlight keeps the accent', () {
    final raster = _Raster(80, 80, const Color(0xFF6E6E6E))
      ..fillRect(36, 36, 8, 8, _orangeAccent)
      ..fillRect(38, 38, 4, 4, const Color(0xFFFFD54A));

    final seed = raster.extract();
    final hsl = HSLColor.fromColor(seed);

    expect(hsl.hue, inInclusiveRange(20, 60));
    expect(hsl.saturation, greaterThan(0.40));
    expect(seed, isNot(_fallback));
  });

  test('warm gray field does not beat a vivid center accent', () {
    final raster = _Raster(64, 64, _beigeMud)
      ..fillRect(28, 28, 8, 8, _orangeAccent);

    final seed = raster.extract();
    final hsl = HSLColor.fromColor(seed);

    expect(hsl.hue, inInclusiveRange(20, 55));
    expect(hsl.saturation, greaterThan(0.40));
  });

  test('true grayscale cover falls back instead of becoming beige', () {
    final raster = _Raster(48, 48, const Color(0xFF808080))
      ..fillRect(0, 0, 24, 48, const Color(0xFF2A2A2A))
      ..fillRect(24, 0, 24, 48, const Color(0xFFD0D0D0));

    expect(raster.extract(), _fallback);
  });

  test('uniform brown artwork stays in the earth-tone family', () {
    const brown = Color(0xFF8B5A2B);
    final seed = _Raster(32, 32, brown).extract();
    final hsl = HSLColor.fromColor(seed);

    expect(hsl.hue, inInclusiveRange(15, 45));
    expect(hsl.saturation, greaterThan(0.40));
  });

  test('solid vivid color is preserved as the seed family', () {
    const blue = Color(0xFF2563EB);
    final seed = _Raster(24, 24, blue).extract();
    final hsl = HSLColor.fromColor(seed);

    expect(hsl.hue, inInclusiveRange(210, 250));
    expect(hsl.saturation, greaterThan(0.40));
  });

  test('empty or invalid buffers use the fallback', () {
    expect(
      extractCoverSeedColor(
        rgba: Uint8List(0),
        width: 0,
        height: 0,
        fallback: _fallback,
      ),
      _fallback,
    );
    expect(
      extractCoverSeedColor(
        rgba: Uint8List(8),
        width: 4,
        height: 4,
        fallback: _fallback,
      ),
      _fallback,
    );
  });

  test('polish lifts a washed orange so Material seed stays warm', () {
    const washed = Color(0xFFD8B48A);
    final polished = polishCoverSeed(washed);
    final hsl = HSLColor.fromColor(polished);

    expect(hsl.saturation, greaterThanOrEqualTo(0.42));
    expect(hsl.lightness, inInclusiveRange(0.34, 0.58));
  });

  test('dynamic theme from the eye-cover seed stays amber, not taupe', () {
    final raster = _Raster(80, 80, const Color(0xFF5A5A5A))
      ..fillRect(37, 37, 6, 6, _orangeAccent);
    final theme = AppTheme.light(seedColor: raster.extract());
    final primary = HSLColor.fromColor(theme.colorScheme.primary);

    expect(primary.hue, inInclusiveRange(10, 70));
    expect(primary.saturation, greaterThan(0.20));
  });

  testWidgets('image decode path finds the orange pupil highlight', (
    tester,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 64, 64),
      Paint()..color = const Color(0xFF707070),
    );
    canvas.drawCircle(const Offset(32, 32), 5, Paint()..color = _orangeAccent);
    final image = await recorder.endRecording().toImage(64, 64);
    addTearDown(image.dispose);

    final seed = await extractCoverSeedColorFromImage(
      image,
      fallback: _fallback,
    );
    final hsl = HSLColor.fromColor(seed);

    expect(hsl.hue, inInclusiveRange(20, 60));
    expect(hsl.saturation, greaterThan(0.40));
  });
}

class _Raster {
  _Raster(this.width, this.height, Color fill)
    : bytes = Uint8List(width * height * 4) {
    fillRect(0, 0, width, height, fill);
  }

  final int width;
  final int height;
  final Uint8List bytes;

  void fillRect(int left, int top, int rectWidth, int rectHeight, Color color) {
    final argb = color.toARGB32();
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    final a = (argb >> 24) & 0xFF;
    for (var y = top; y < top + rectHeight; y++) {
      for (var x = left; x < left + rectWidth; x++) {
        final i = (y * width + x) * 4;
        bytes[i] = r;
        bytes[i + 1] = g;
        bytes[i + 2] = b;
        bytes[i + 3] = a;
      }
    }
  }

  Color extract() => extractCoverSeedColor(
    rgba: bytes,
    width: width,
    height: height,
    fallback: _fallback,
  );
}
