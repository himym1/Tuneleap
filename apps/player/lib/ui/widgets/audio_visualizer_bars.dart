import 'dart:math';
import 'package:flutter/material.dart';

/// 微型律动声波动效 — 类似 Apple Music / Spotify 正在播放指示器
class AudioVisualizerBars extends StatefulWidget {
  final bool isPlaying;
  final Color? color;
  final double size;

  const AudioVisualizerBars({
    super.key,
    this.isPlaying = true,
    this.color,
    this.size = 14,
  });

  @override
  State<AudioVisualizerBars> createState() => _AudioVisualizerBarsState();
}

class _AudioVisualizerBarsState extends State<AudioVisualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat();
    if (!widget.isPlaying) _controller.stop();
  }

  @override
  void didUpdateWidget(AudioVisualizerBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.color ?? Theme.of(context).colorScheme.primary;
    final width = widget.size;
    final barWidth = width / 5;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value * 2 * pi;
        final h1 = widget.isPlaying
            ? (sin(t) * 0.35 + 0.65).clamp(0.2, 1.0)
            : 0.4;
        final h2 = widget.isPlaying
            ? (sin(t + 2.0) * 0.4 + 0.6).clamp(0.2, 1.0)
            : 0.8;
        final h3 = widget.isPlaying
            ? (sin(t + 4.0) * 0.35 + 0.65).clamp(0.2, 1.0)
            : 0.5;

        return SizedBox(
          width: width,
          height: width,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar(barWidth, width * h1, themeColor),
              _buildBar(barWidth, width * h2, themeColor),
              _buildBar(barWidth, width * h3, themeColor),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBar(double width, double height, Color color) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(width / 2),
      ),
    );
  }
}
