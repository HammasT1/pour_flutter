import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../config/tunables.dart';

/// Ice cubes drawn over the cup's bounding box (same coordinate space as
/// [CupFillGeometry]). Each new cube falls in from above the rim with a
/// bounce; cubes rest on the bottom (stacking two per row) and float up
/// with the liquid once it's deep enough, bobbing gently. The part of a
/// cube under the surface is tinted with the liquid color.
///
/// Positions are recomputed every frame from the animated [level], so
/// cubes ride the liquid line as it rises - including while a cube is
/// still falling.
class IceLayer extends StatefulWidget {
  final int cubeCount;

  /// Animated liquid line (0..1 of the fillable height), ice included.
  final double level;
  final Color liquidColor;

  const IceLayer({super.key, required this.cubeCount, required this.level, required this.liquidColor});

  @override
  State<IceLayer> createState() => _IceLayerState();
}

class _IceLayerState extends State<IceLayer> with TickerProviderStateMixin {
  final List<AnimationController> _drops = [];
  late final AnimationController _bob = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void initState() {
    super.initState();
    _sync(animateNew: false);
  }

  @override
  void didUpdateWidget(covariant IceLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cubeCount != oldWidget.cubeCount) _sync(animateNew: true);
  }

  void _sync({required bool animateNew}) {
    while (_drops.length > widget.cubeCount) {
      _drops.removeLast().dispose();
    }
    while (_drops.length < widget.cubeCount) {
      final c = AnimationController(vsync: this, duration: kIceDropDuration);
      animateNew ? c.forward() : c.value = 1;
      _drops.add(c);
    }
    if (_drops.isEmpty) {
      _bob.stop();
    } else if (!_bob.isAnimating) {
      _bob.repeat();
    }
  }

  @override
  void dispose() {
    for (final c in _drops) {
      c.dispose();
    }
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_drops.isEmpty) return const SizedBox.expand();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([..._drops, _bob]),
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _IcePainter(
            drops: [for (final c in _drops) c.value],
            level: widget.level,
            bobPhase: _bob.value * 2 * math.pi,
            liquidColor: widget.liquidColor,
          ),
        ),
      ),
    );
  }
}

class _IcePainter extends CustomPainter {
  final List<double> drops; // drop progress per cube, 0..1
  final double level;
  final double bobPhase;
  final Color liquidColor;

  _IcePainter({required this.drops, required this.level, required this.bobPhase, required this.liquidColor});

  static double _hash(int n) {
    final v = math.sin(n * 78.233 + 1.7) * 43758.5453;
    return v - v.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final s = kIceCubeSize * w;
    final regionTop = CupFillGeometry.topY * h;
    final regionBottom = CupFillGeometry.bottomY * h;
    final surfaceY = regionBottom - level.clamp(0.0, 1.0) * (regionBottom - regionTop);
    final hasLiquid = level > 0.005;

    for (var i = 0; i < drops.length; i++) {
      final row = i ~/ 2;
      final left = i.isEven;
      final cx = w / 2 + (left ? -1 : 1) * s * 0.55 + (_hash(i) - 0.5) * s * 0.12;

      // Bottom edge of the cube: resting on the floor / the row below, or
      // floating with ~88% submerged (upper rows pile a bit higher).
      final restBottom = regionBottom - row * s * 0.9;
      final floatBottom = surfaceY + s * kIceSubmergedFraction - row * s * 0.32;
      final floating = hasLiquid && floatBottom < restBottom;
      var targetBottom = floating ? floatBottom : restBottom;

      var angle = (_hash(i + 11) - 0.5) * 0.5;
      if (floating) {
        targetBottom += math.sin(bobPhase + i * 1.7) * 1.2;
        angle += math.sin(bobPhase + i * 2.3) * 0.05;
      }

      // Fall in from above the rim, bouncing onto the target.
      final p = drops[i];
      final startBottom = regionTop - s * 0.6;
      final bottom = startBottom + (targetBottom - startBottom) * Curves.bounceOut.transform(p);
      angle += (1 - p) * 1.3 * (left ? 1 : -1);

      final center = Offset(cx, bottom - s / 2);
      final cube = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: s, height: s),
        Radius.circular(s * 0.2),
      );

      void inCubeSpace(void Function() draw) {
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(angle);
        draw();
        canvas.restore();
      }

      inCubeSpace(() {
        canvas.drawRRect(
          cube,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xB3FFFFFF), Color(0x66CFE9FF), Color(0x8CE6F4FF)],
            ).createShader(cube.outerRect),
        );
        // Frosted inner core + top-left glint.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(s * 0.04, s * 0.04), width: s * 0.5, height: s * 0.5),
            Radius.circular(s * 0.12),
          ),
          Paint()..color = const Color(0x33FFFFFF),
        );
        canvas.drawLine(
          Offset(-s * 0.3, -s * 0.32),
          Offset(-s * 0.05, -s * 0.32),
          Paint()
            ..color = const Color(0xCCFFFFFF)
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawRRect(
          cube,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1
            ..color = const Color(0xCCFFFFFF),
        );
      });

      // Below the surface the cube is seen through the drink.
      if (hasLiquid && surfaceY < center.dy + s) {
        canvas.save();
        canvas.clipRect(Rect.fromLTRB(0, surfaceY, w, h));
        inCubeSpace(() => canvas.drawRRect(cube, Paint()..color = liquidColor.withValues(alpha: 0.5)));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IcePainter old) => true;
}

/// A striped bendy straw standing in the cup. Below the liquid line the
/// submerged part is drawn shifted sideways, slightly magnified and tinted
/// - the familiar "bent straw" refraction break - and that break point
/// climbs as the cup fills. Slides in/out when toggled.
class StrawLayer extends StatelessWidget {
  final bool visible;

  /// Animated liquid line (0..1 of the fillable height), ice included.
  final double level;
  final Color stripeColor;
  final Color liquidColor;

  const StrawLayer({
    super.key,
    required this.visible,
    required this.level,
    required this.stripeColor,
    required this.liquidColor,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: visible ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 420),
        curve: visible ? Curves.easeOutBack : Curves.easeIn,
        builder: (context, t, _) {
          if (t <= 0.001) return const SizedBox.expand();
          return CustomPaint(
            size: Size.infinite,
            painter: _StrawPainter(
              insertion: t,
              level: level,
              stripeColor: stripeColor,
              liquidColor: liquidColor,
            ),
          );
        },
      ),
    );
  }
}

class _StrawPainter extends CustomPainter {
  /// 0 = lifted out above the cup, 1 = fully in.
  final double insertion;
  final double level;
  final Color stripeColor;
  final Color liquidColor;

  _StrawPainter({required this.insertion, required this.level, required this.stripeColor, required this.liquidColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final lift = (1 - insertion) * h * 0.55;
    final opacity = insertion.clamp(0.0, 1.0);
    final sw = w * 0.045;

    // Centerline: long shaft from near the bottom out over the rim, an
    // elbow, then a short mouthpiece angled away from the pour stream.
    final base = Offset(w * 0.41, CupFillGeometry.bottomY * h - h * 0.03 - lift);
    final elbow = Offset(w * 0.66, -h * 0.09 - lift);
    final mouth = elbow + Offset(w * 0.13, -h * 0.045);

    final regionTop = CupFillGeometry.topY * h;
    final regionBottom = CupFillGeometry.bottomY * h;
    final surfaceY = regionBottom - level.clamp(0.0, 1.0) * (regionBottom - regionTop);

    // Where the shaft crosses the surface (if it does).
    final crossT = ((base.dy - surfaceY) / (base.dy - elbow.dy)).clamp(0.0, 1.0);
    final submerged = level > 0.02 && crossT > 0;
    final cross = Offset.lerp(base, elbow, crossT)!;

    final white = Color.fromRGBO(255, 255, 255, 0.95 * opacity);
    final stripe = stripeColor.withValues(alpha: 0.95 * opacity);

    void striped(Offset a, Offset b, double width, {double phase = 0}) {
      final len = (b - a).distance;
      if (len < 0.5) return;
      final base = Paint()
        ..color = white
        ..strokeWidth = width
        ..strokeCap = StrokeCap.butt;
      canvas.drawLine(a, b, base);
      final dir = (b - a) / len;
      final seg = width * 1.1;
      final stripePaint = Paint()
        ..color = stripe
        ..strokeWidth = width
        ..strokeCap = StrokeCap.butt;
      for (var d = phase % (seg * 2); d < len; d += seg * 2) {
        canvas.drawLine(a + dir * d, a + dir * math.min(len, d + seg), stripePaint);
      }
      // Soft edge highlight so it reads as a tube, not a flat ribbon.
      final normal = Offset(-dir.dy, dir.dx);
      canvas.drawLine(
        a + normal * width * 0.28,
        b + normal * width * 0.28,
        Paint()
          ..color = Color.fromRGBO(255, 255, 255, 0.35 * opacity)
          ..strokeWidth = width * 0.18,
      );
    }

    // Above the surface: the true shaft, elbow and mouthpiece.
    striped(submerged ? cross : base, elbow, sw, phase: submerged ? (cross - base).distance : 0);
    canvas.drawCircle(elbow, sw * 0.55, Paint()..color = white);
    for (var k = -1; k <= 1; k++) {
      final c = Offset.lerp(elbow, mouth, 0.12 + k * 0.08)!;
      canvas.drawCircle(c, sw * 0.52, Paint()..color = Color.fromRGBO(225, 225, 225, 0.9 * opacity));
    }
    striped(elbow, mouth, sw);

    // Below the surface: shifted + magnified, seen through the drink.
    if (submerged) {
      final shift = Offset(kStrawRefractionShift * w, 0);
      final a = base + shift;
      final b = cross + shift * 0.85;
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(0, surfaceY, w, h));
      striped(a, b, sw * 1.15);
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = liquidColor.withValues(alpha: 0.45 * opacity)
          ..strokeWidth = sw * 1.15,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _StrawPainter old) =>
      old.insertion != insertion ||
      old.level != level ||
      old.stripeColor != stripeColor ||
      old.liquidColor != liquidColor;
}
