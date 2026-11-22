import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Paints the liquid body inside its box, with a gentle sine-wave top
/// surface (instead of a flat line) plus a thin foam/highlight strip
/// riding along the crest of the wave. When [foamFraction] > 0, a bubbly
/// foam head is stacked on top of the liquid surface.
class LiquidSurfacePainter extends CustomPainter {
  /// 0..1 fill amount, relative to this painter's own [size].
  final double fillFraction;
  final Color liquidColor;
  final Color highlightColor;

  /// Continuously advancing phase (radians) that drives the wave motion.
  final double wavePhase;

  /// Foam head height, as a fraction of this painter's [size] height.
  final double foamFraction;
  final Color foamColor;

  const LiquidSurfacePainter({
    required this.fillFraction,
    required this.liquidColor,
    required this.highlightColor,
    required this.wavePhase,
    this.foamFraction = 0.0,
    this.foamColor = const Color(0xFFFFFFFF),
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

    _paintFoamHead(canvas, size, baseY, waveAt);
  }

  /// Foam head: from the liquid's wavy surface up to a lumpier, slower
  /// top edge, with a sprinkling of bubble rims for texture. Bubble
  /// positions are deterministic (index-hashed), drifting gently with
  /// [wavePhase], so they don't flicker frame to frame.
  void _paintFoamHead(Canvas canvas, Size size, double baseY, double Function(double) waveAt) {
    final foamH = foamFraction.clamp(0.0, 1.0) * size.height;
    if (foamH < 0.6) return;
    final top = baseY - foamH;

    double foamTopAt(double x) =>
        top + math.sin(x / 9 + wavePhase * 1.5) * 1.6 + math.sin(x / 4.3 - wavePhase) * 0.9;

    final head = Path()..moveTo(0, waveAt(0) + _foamThickness);
    head.lineTo(0, foamTopAt(0));
    for (double x = 0; x <= size.width; x += _step / 2) {
      head.lineTo(x, foamTopAt(x));
    }
    for (double x = size.width; x >= 0; x -= _step) {
      head.lineTo(x, waveAt(x) + _foamThickness);
    }
    head.close();

    canvas.drawPath(
      head,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [foamColor, Color.lerp(foamColor, highlightColor, 0.35)!.withValues(alpha: 0.92)],
        ).createShader(Rect.fromLTWH(0, top - 3, size.width, foamH + 6)),
    );

    final bubblePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Color.lerp(foamColor, highlightColor, 0.5)!.withValues(alpha: 0.55);
    final count = (size.width * foamH / 70).clamp(0, 60).toInt();
    for (var i = 0; i < count; i++) {
      final hx = _hash(i * 2 + 1);
      final hy = _hash(i * 2 + 7);
      final x = (hx * size.width + math.sin(wavePhase + i) * 1.5) % size.width;
      final y = top + 2 + hy * math.max(0.0, foamH - 3);
      canvas.drawCircle(Offset(x, y), 0.9 + _hash(i + 31) * 1.6, bubblePaint);
    }
  }

  static double _hash(int n) {
    final v = math.sin(n * 12.9898) * 43758.5453;
    return v - v.floorToDouble();
  }

  @override
  bool shouldRepaint(covariant LiquidSurfacePainter oldDelegate) {
    return oldDelegate.fillFraction != fillFraction ||
        oldDelegate.wavePhase != wavePhase ||
        oldDelegate.liquidColor != liquidColor ||
        oldDelegate.highlightColor != highlightColor ||
        oldDelegate.foamFraction != foamFraction ||
        oldDelegate.foamColor != foamColor;
  }
}
