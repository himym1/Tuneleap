import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Album-art seed extraction.
///
/// `palette_generator`'s vibrant → muted → dominant fallback misses small
/// saturated accents (a pupil highlight on a grayscale cover) after the image
/// is resized to 100×100. Those covers then collapse to a warm gray, and
/// [ColorScheme.fromSeed] turns that gray into beige / brown chrome.
///
/// This sampler keeps original pixels (stride only, no box-filter resize),
/// scores hue buckets by saturation, and refuses near-gray seeds.
const int _hueBins = 24;
const double _vividSaturation = 0.28;
const double _mutedSaturation = 0.16;
const double _minLightness = 0.08;
const double _maxLightness = 0.92;
const int _targetSamples = 192;
const int _minAccentPixels = 6;
const double _minAccentRatio = 0.0004;

/// Picks a Material seed from raw RGBA album-art pixels.
Color extractCoverSeedColor({
  required Uint8List rgba,
  required int width,
  required int height,
  required Color fallback,
}) {
  if (width <= 0 || height <= 0 || rgba.length < width * height * 4) {
    return fallback;
  }

  final vivid = List<_HueBin>.generate(_hueBins, (_) => _HueBin());
  final muted = List<_HueBin>.generate(_hueBins, (_) => _HueBin());
  final stride = math.max(1, math.max(width, height) ~/ _targetSamples);
  var sampled = 0;

  for (var y = 0; y < height; y += stride) {
    for (var x = 0; x < width; x += stride) {
      final i = (y * width + x) * 4;
      if (rgba[i + 3] < 128) continue;
      sampled++;
      final color = Color.fromARGB(255, rgba[i], rgba[i + 1], rgba[i + 2]);
      final hsl = HSLColor.fromColor(color);
      if (hsl.lightness < _minLightness || hsl.lightness > _maxLightness) {
        continue;
      }
      if (hsl.saturation < _mutedSaturation) continue;

      final weight =
          math.pow(hsl.saturation, 2.2).toDouble() *
          _lightnessWeight(hsl.lightness) *
          _centerWeight(x, y, width, height);
      final bin = ((hsl.hue / 360.0) * _hueBins).floor() % _hueBins;
      muted[bin].add(color, weight);
      if (hsl.saturation >= _vividSaturation) {
        vivid[bin].add(color, weight);
      }
    }
  }

  final accent = _pickBin(vivid, sampled) ?? _pickBin(muted, sampled);
  if (accent == null) return fallback;
  return polishCoverSeed(accent);
}

/// Tightens a seed so Material 3 does not collapse it into taupe.
Color polishCoverSeed(Color color) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withSaturation(hsl.saturation.clamp(0.42, 0.88))
      .withLightness(hsl.lightness.clamp(0.34, 0.58))
      .toColor();
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

double _lightnessWeight(double lightness) {
  return math.max(0.15, 1.0 - (lightness - 0.5).abs() * 1.2);
}

double _centerWeight(int x, int y, int width, int height) {
  final dx = (x + 0.5) / width - 0.5;
  final dy = (y + 0.5) / height - 0.5;
  return 1.25 - (dx * dx + dy * dy);
}

Color? _pickBin(List<_HueBin> bins, int sampled) {
  final minCount = math.max(
    _minAccentPixels,
    (sampled * _minAccentRatio).round(),
  );
  var bestIndex = -1;
  var bestScore = 0.0;
  for (var i = 0; i < bins.length; i++) {
    if (bins[i].count < minCount) continue;
    final prev = bins[(i - 1 + _hueBins) % _hueBins].weight;
    final next = bins[(i + 1) % _hueBins].weight;
    final score = bins[i].weight + 0.4 * prev + 0.4 * next;
    if (score > bestScore) {
      bestScore = score;
      bestIndex = i;
    }
  }
  if (bestIndex < 0) return null;
  return bins[bestIndex].toColor();
}

class _HueBin {
  double r = 0;
  double g = 0;
  double b = 0;
  double weight = 0;
  int count = 0;

  void add(Color color, double weight) {
    r += color.r * weight;
    g += color.g * weight;
    b += color.b * weight;
    this.weight += weight;
    count++;
  }

  Color? toColor() {
    if (weight <= 0) return null;
    return Color.from(
      alpha: 1,
      red: (r / weight).clamp(0.0, 1.0),
      green: (g / weight).clamp(0.0, 1.0),
      blue: (b / weight).clamp(0.0, 1.0),
    );
  }
}
