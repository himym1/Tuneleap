import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

/// Album-art seed from Material Color Utilities.
///
/// [QuantizerCelebi] clusters the image; [Score] ranks clusters for theming
/// and drops low-chroma / low-proportion colors (JPEG specks on grayscale).
const int _maxEdgeSamples = 160;
const int _maxClusters = 16;

/// Picks a Material seed from raw RGBA album-art pixels.
Future<Color> extractCoverSeedColor({
  required Uint8List rgba,
  required int width,
  required int height,
  required Color fallback,
}) async {
  if (width <= 0 || height <= 0 || rgba.length < width * height * 4) {
    return fallback;
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
  if (pixels.isEmpty) return fallback;

  final quantized = await QuantizerCelebi().quantize(pixels, _maxClusters);
  if (quantized.colorToCount.isEmpty) return fallback;

  final fallbackArgb = fallback.toARGB32();
  final ranked = Score.score(
    quantized.colorToCount,
    desired: 1,
    fallbackColorARGB: fallbackArgb,
  );
  if (ranked.isEmpty) return fallback;
  return Color(ranked.first);
}

/// Readable icon/text color on a cover-tinted background.
Color foregroundOn(Color background) {
  return background.computeLuminance() < 0.45
      ? const Color(0xFFFFFFFF)
      : const Color(0xDE000000);
}

Future<Color> extractCoverSeedColorFromImage(
  ui.Image image, {
  required Color fallback,
}) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (bytes == null) return fallback;
  return extractCoverSeedColor(
    rgba: bytes.buffer.asUint8List(),
    width: image.width,
    height: image.height,
    fallback: fallback,
  );
}

Future<Color> extractCoverSeedColorFromProvider(
  ImageProvider provider, {
  required Color fallback,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final info = await _resolveImage(provider).timeout(timeout);
  try {
    return await extractCoverSeedColorFromImage(info.image, fallback: fallback);
  } finally {
    info.dispose();
  }
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
