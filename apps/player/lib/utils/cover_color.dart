import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

/// Album-art seed from Material Color Utilities.
///
/// [QuantizerCelebi] clusters the image. [Score] ranks clusters, but its
/// default filter drops low-chroma colors (gray is chroma ≈ 0) and injects a
/// brand fallback — that is why a black-and-white cover became purple.
/// Gray is a valid seed: keep it, and theme with
/// [DynamicSchemeVariant.monochrome].
const int _maxEdgeSamples = 160;
const int _maxClusters = 16;

/// HCT chroma below this reads as gray. MCU [Score] itself cuts at 5; 12
/// also catches JPEG-tinted near-grays so [tonalSpot] cannot invent a hue.
const double achromaticChromaCutoff = 12;

/// MCU [Score] only drops colors below 1% of the image. A sticker-sized red
/// square on a dark portrait still wins, and light theme turns that into pink.
const double minThemeProportion = 0.08;

/// Smaller than this stays off the play button too — JPEG specks, not accents.
const double minAccentProportion = 0.03;

/// Atmosphere for the page plus a separate accent for controls.
class CoverPalette {
  const CoverPalette({required this.seed, required this.accent});

  /// Representative color: large areas of the cover, used for theme / wash.
  final Color seed;

  /// High-chroma graphic if it occupies enough of the cover; otherwise [seed].
  final Color accent;
}

/// True when [color] has no usable hue and should drive a monochrome scheme.
bool isAchromaticCoverSeed(Color color) {
  return Hct.fromInt(color.toARGB32()).chroma < achromaticChromaCutoff;
}

/// Material scheme for a cover seed: gray stays gray, color stays tonal.
DynamicSchemeVariant coverSchemeVariant(Color seed) {
  return isAchromaticCoverSeed(seed)
      ? DynamicSchemeVariant.monochrome
      : DynamicSchemeVariant.tonalSpot;
}

/// Picks a Material seed from raw RGBA album-art pixels.
Future<Color> extractCoverSeedColor({
  required Uint8List rgba,
  required int width,
  required int height,
  required Color fallback,
}) async {
  return (await extractCoverPalette(
    rgba: rgba,
    width: width,
    height: height,
    fallback: fallback,
  )).seed;
}

/// Atmosphere plus optional graphic accent from raw RGBA album-art pixels.
Future<CoverPalette> extractCoverPalette({
  required Uint8List rgba,
  required int width,
  required int height,
  required Color fallback,
}) async {
  if (width <= 0 || height <= 0 || rgba.length < width * height * 4) {
    return CoverPalette(seed: fallback, accent: fallback);
  }

  final stride = math.max(
    1,
    (math.max(width, height) / _maxEdgeSamples).ceil(),
  );
  final pixels = <int>[];
  for (var y = 0; y < height; y += stride) {
    for (var x = 0; x < width; x += stride) {
      final i = (y * width + x) * 4;
      if (rgba[i + 3] < 128) continue;
      pixels.add(
        0xFF000000 | (rgba[i] << 16) | (rgba[i + 1] << 8) | rgba[i + 2],
      );
    }
  }
  if (pixels.isEmpty) {
    return CoverPalette(seed: fallback, accent: fallback);
  }

  final quantized = await QuantizerCelebi().quantize(pixels, _maxClusters);
  if (quantized.colorToCount.isEmpty) {
    return CoverPalette(seed: fallback, accent: fallback);
  }

  final counts = quantized.colorToCount;
  var total = 0;
  for (final count in counts.values) {
    total += count;
  }
  if (total <= 0) {
    return CoverPalette(seed: fallback, accent: fallback);
  }

  final substantial = <int, int>{
    for (final entry in counts.entries)
      if (entry.value / total >= minThemeProportion) entry.key: entry.value,
  };
  final themeSource = substantial.isNotEmpty ? substantial : counts;
  final seed = _scoredOrDominant(themeSource);
  return CoverPalette(
    seed: seed,
    accent: _accentFromCounts(counts, total, seed),
  );
}

// Score's default filter drops chroma < 5 and injects [fallbackColorARGB].
// A sentinel keeps brand indigo out of grayscale covers.
const int _noColorfulSeed = 0x00000001;

Color _scoredOrDominant(Map<int, int> counts) {
  final colorful = Score.score(
    counts,
    desired: 1,
    fallbackColorARGB: _noColorfulSeed,
  );
  final winner = colorful.isEmpty ? _noColorfulSeed : colorful.first;
  if (winner != _noColorfulSeed &&
      Hct.fromInt(winner).chroma >= achromaticChromaCutoff) {
    return Color(winner);
  }
  return Color(_dominantArgb(counts));
}

Color _accentFromCounts(Map<int, int> counts, int total, Color seed) {
  final colorful = Score.score(
    counts,
    desired: 1,
    fallbackColorARGB: _noColorfulSeed,
  );
  final winner = colorful.isEmpty ? _noColorfulSeed : colorful.first;
  if (winner == _noColorfulSeed) return seed;
  if (Hct.fromInt(winner).chroma < achromaticChromaCutoff) return seed;
  final count = counts[winner] ?? 0;
  if (count / total < minAccentProportion) return seed;
  return Color(winner);
}

int _dominantArgb(Map<int, int> colorToCount) {
  var bestArgb = 0xFF6E6E6E;
  var bestCount = -1;
  for (final entry in colorToCount.entries) {
    if (entry.value > bestCount) {
      bestCount = entry.value;
      bestArgb = entry.key;
    }
  }
  return bestArgb;
}

/// Readable icon/text color on a cover-tinted background.
Color foregroundOn(Color background) {
  return background.computeLuminance() < 0.45
      ? const Color(0xFFFFFFFF)
      : const Color(0xDE000000);
}

Future<CoverPalette> extractCoverPaletteFromImage(
  ui.Image image, {
  required Color fallback,
}) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (bytes == null) return CoverPalette(seed: fallback, accent: fallback);
  return extractCoverPalette(
    rgba: bytes.buffer.asUint8List(),
    width: image.width,
    height: image.height,
    fallback: fallback,
  );
}

Future<Color> extractCoverSeedColorFromImage(
  ui.Image image, {
  required Color fallback,
}) async {
  return (await extractCoverPaletteFromImage(image, fallback: fallback)).seed;
}

Future<CoverPalette> extractCoverPaletteFromProvider(
  ImageProvider provider, {
  required Color fallback,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final info = await _resolveImage(provider).timeout(timeout);
  try {
    return await extractCoverPaletteFromImage(info.image, fallback: fallback);
  } finally {
    info.dispose();
  }
}

Future<Color> extractCoverSeedColorFromProvider(
  ImageProvider provider, {
  required Color fallback,
  Duration timeout = const Duration(seconds: 5),
}) async {
  return (await extractCoverPaletteFromProvider(
    provider,
    fallback: fallback,
    timeout: timeout,
  )).seed;
}

Future<ImageInfo> _resolveImage(ImageProvider provider) {
  final completer = Completer<ImageInfo>();
  final stream = provider.resolve(
    const ImageConfiguration(devicePixelRatio: 1),
  );
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      stream.removeListener(listener);
      if (!completer.isCompleted) completer.complete(info);
    },
    onError: (error, stack) {
      stream.removeListener(listener);
      if (!completer.isCompleted) {
        completer.completeError(error, stack);
      }
    },
  );
  stream.addListener(listener);
  return completer.future;
}
