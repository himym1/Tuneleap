import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:navidrome_player/ui/theme/app_color_loader.dart';
import 'package:navidrome_player/ui/theme/app_theme.dart';
import 'package:navidrome_player/utils/cover_color.dart';

const _fallback = Color(0xFF1E1B4B);
const _orangeAccent = Color(0xFFFF9A1F);
const _googleBlue = Color(0xFF4285F4);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initializeAppColors);

  test(
    'true grayscale cover keeps gray, not brand indigo or Google Blue',
    () async {
      final raster = _Raster(48, 48, const Color(0xFF808080))
        ..fillRect(0, 0, 24, 48, const Color(0xFF2A2A2A))
        ..fillRect(24, 0, 24, 48, const Color(0xFFD0D0D0));

      final seed = await raster.extract();
      expect(isAchromaticCoverSeed(seed), isTrue);
      expect(seed, isNot(_fallback));
      expect(seed, isNot(_googleBlue));
    },
  );

  test('JPEG-like green specks on grayscale do not become the theme', () async {
    final raster = _Raster(96, 96, const Color(0xFF6A6A6A))
      ..fillRect(0, 0, 48, 96, const Color(0xFF2C2C2C))
      ..fillRect(48, 0, 48, 96, const Color(0xFFC8C8C8));
    const specks = [
      (8, 10),
      (20, 22),
      (33, 14),
      (12, 60),
      (70, 18),
      (81, 44),
      (55, 70),
      (63, 82),
      (40, 40),
      (74, 8),
    ];
    for (final speck in specks) {
      raster.fillRect(speck.$1, speck.$2, 2, 2, const Color(0xFF6B8A68));
    }

    final seed = await raster.extract();
    expect(isAchromaticCoverSeed(seed), isTrue);
    expect(HSLColor.fromColor(seed).hue, isNot(inInclusiveRange(80, 160)));
  });

  test('a 1% orange speck is not enough to theme a gray cover', () async {
    final raster = _Raster(80, 80, const Color(0xFF6E6E6E))
      ..fillRect(36, 36, 8, 8, _orangeAccent);

    expect(isAchromaticCoverSeed(await raster.extract()), isTrue);
  });

  test('a substantial orange field stays in the warm family', () async {
    final raster = _Raster(64, 64, const Color(0xFF5A5A5A))
      ..fillRect(0, 0, 64, 28, _orangeAccent);

    final seed = await raster.extract();
    final hsl = HSLColor.fromColor(seed);

    expect(seed, isNot(_fallback));
    expect(hsl.hue, inInclusiveRange(15, 70));
  });

  test('uniform brown artwork stays in the earth-tone family', () async {
    const brown = Color(0xFF8B5A2B);
    final seed = await _Raster(32, 32, brown).extract();
    final hsl = HSLColor.fromColor(seed);

    expect(hsl.hue, inInclusiveRange(15, 50));
  });

  test('solid vivid color is preserved as the seed family', () async {
    const blue = Color(0xFF2563EB);
    final seed = await _Raster(24, 24, blue).extract();
    final hsl = HSLColor.fromColor(seed);

    expect(hsl.hue, inInclusiveRange(210, 260));
  });

  test('foregroundOn picks white on dark and dark on light', () {
    expect(foregroundOn(const Color(0xFF111111)), const Color(0xFFFFFFFF));
    expect(foregroundOn(const Color(0xFFF5F0E6)), const Color(0xDE000000));
  });

  test('empty or invalid buffers use the fallback', () async {
    expect(
      await extractCoverSeedColor(
        rgba: Uint8List(0),
        width: 0,
        height: 0,
        fallback: _fallback,
      ),
      _fallback,
    );
    expect(
      await extractCoverSeedColor(
        rgba: Uint8List(8),
        width: 4,
        height: 4,
        fallback: _fallback,
      ),
      _fallback,
    );
  });

  test('dynamic theme from a scored orange field stays warm', () async {
    final raster = _Raster(64, 64, const Color(0xFF5A5A5A))
      ..fillRect(0, 0, 64, 28, _orangeAccent);
    final theme = AppTheme.light(seedColor: await raster.extract());
    final primary = HSLColor.fromColor(theme.colorScheme.primary);

    expect(primary.hue, inInclusiveRange(10, 80));
  });

  test('a 6% red sticker does not paint a dark portrait pink', () async {
    const portrait = Color(0xFF2A2420);
    const sticker = Color(0xFFE53935);
    final raster = _Raster(80, 80, portrait)..fillRect(58, 4, 20, 20, sticker);
    final palette = await raster.extractPalette();
    final seed = Hct.fromInt(palette.seed.toARGB32());
    final accent = Hct.fromInt(palette.accent.toARGB32());
    final seedIsVividRed =
        seed.chroma >= 40 && (seed.hue < 20 || seed.hue > 340);

    expect(seedIsVividRed, isFalse);
    expect(accent.chroma, greaterThan(achromaticChromaCutoff));
    expect(accent.hue < 25 || accent.hue > 335, isTrue);
  });

  test('a large red field still themes the cover red', () async {
    const portrait = Color(0xFF2A2420);
    const red = Color(0xFFE53935);
    final raster = _Raster(80, 80, portrait)..fillRect(0, 0, 80, 28, red);
    final palette = await raster.extractPalette();

    expect(
      HSLColor.fromColor(palette.seed).hue,
      anyOf(lessThan(20), greaterThan(340)),
    );
    expect(
      HSLColor.fromColor(palette.accent).hue,
      anyOf(lessThan(20), greaterThan(340)),
    );
  });

  test('grayscale cover themes monochrome, not purple', () async {
    final raster = _Raster(48, 48, const Color(0xFF808080))
      ..fillRect(0, 0, 24, 48, const Color(0xFF2A2A2A))
      ..fillRect(24, 0, 24, 48, const Color(0xFFD0D0D0));
    final seed = await raster.extract();
    final theme = AppTheme.light(seedColor: seed);
    final primary = HSLColor.fromColor(theme.colorScheme.primary);

    expect(coverSchemeVariant(seed), DynamicSchemeVariant.monochrome);
    expect(primary.saturation, lessThan(0.12));
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

  Future<Color> extract() => extractCoverSeedColor(
    rgba: bytes,
    width: width,
    height: height,
    fallback: _fallback,
  );

  Future<CoverPalette> extractPalette() => extractCoverPalette(
    rgba: bytes,
    width: width,
    height: height,
    fallback: _fallback,
  );
}
