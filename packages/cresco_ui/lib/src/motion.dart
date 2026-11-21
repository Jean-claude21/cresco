import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Card entrance from DESIGN.md: rises 18 pt and fades in, staggered by [index].
/// Static when the system asks for reduced motion.
class FadeSlideIn extends StatelessWidget {
  const new({required this.child, super.key, this.index = 0});
  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 520 + 70 * index),
      curve: Interval((70 * index) / (520 + 70 * index), 1, curve: const Cubic(0.2, 0.8, 0.2, 1)),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

/// Score ring that fills up to [fraction] (0–1) on first display.
class ScoreRing extends StatelessWidget {
  const new({
    required this.fraction,
    required this.child,
    super.key,
    this.size = 112,
    this.stroke = 10,
    this.color = const Color(0xFFCDEB5A),
    this.track = const Color(0xFF2A2D27),
  });
  final double fraction;
  final Widget child;
  final double size;
  final double stroke;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    final target = fraction.clamp(0.0, 1.0);
    final still = MediaQuery.disableAnimationsOf(context);
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: still ? target : 0, end: target),
        duration: const Duration(milliseconds: 1400),
        curve: const Cubic(0.2, 0.8, 0.2, 1),
        builder: (context, v, child) => CustomPaint(
          painter: _RingPainter(v, stroke, color, track),
          child: child,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.stroke, this.color, this.track);
  final double value;
  final double stroke;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawArc(r, 0, math.pi * 2, false, paint..color = track)
      ..drawArc(r, -math.pi / 2, math.pi * 2 * value, false, paint..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color || old.track != track;
}
