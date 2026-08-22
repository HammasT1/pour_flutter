import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Paints the liquid body inside its box, with a gentle sine-wave top
/// surface (instead of a flat line) plus a thin foam/highlight strip
/// riding along the crest of the wave.
class LiquidSurfacePainter extends CustomPainter {
  /// 0..1 fill amount, relative to this painter's own [size].
  final double fillFraction;
  final Color liquidColor;
  final Color highlightColor;

  /// Continuously advancing phase (radians) that drives the wave motion.
  final double wavePhase;

  const LiquidSurfacePainter({
    required this.fillFraction,
    required this.liquidColor,
    required this.highlightColor,
    required this.wavePhase,
  });

  static const double _waveLength = 34.0;
  static const double _step = 4.0;
  static const double _foamThickness = 3.5;

  @override
  void paint(Canvas canvas, Size size) {
    final fraction = fillFraction.clamp(0.0, 1.0);
    if (fraction <= 0.001) return;

    final waveAmplitude = 2.5 + 2.5 * fraction;
    final baseY = size.height * (1 - fraction);

    double waveAt(double x) =>
        baseY + math.sin((x / _waveLength) + wavePhase) * waveAmplitude;

    final body = Path()..moveTo(0, size.height + 4);
    body.lineTo(0, waveAt(0));
    for (double x = 0; x <= size.width; x += _step) {
      body.lineTo(x, waveAt(x));
    }
    body.lineTo(size.width, size.height + 4);
    body.close();

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [liquidColor.withValues(alpha: 0.9), liquidColor],
      ).createShader(Rect.fromLTWH(0, baseY, size.width, size.height - baseY + 4));
    canvas.drawPath(body, bodyPaint);

    final foam = Path()..moveTo(0, waveAt(0));
    for (double x = 0; x <= size.width; x += _step) {
      foam.lineTo(x, waveAt(x));
    }
    for (double x = size.width; x >= 0; x -= _step) {
      foam.lineTo(x, waveAt(x) + _foamThickness);
    }
    foam.close();
    canvas.drawPath(foam, Paint()..color = highlightColor.withValues(alpha: 0.8));
  }

  @override
  bool shouldRepaint(covariant LiquidSurfacePainter oldDelegate) {
    return oldDelegate.fillFraction != fillFraction ||
        oldDelegate.wavePhase != wavePhase ||
        oldDelegate.liquidColor != liquidColor ||
        oldDelegate.highlightColor != highlightColor;
  }
}
