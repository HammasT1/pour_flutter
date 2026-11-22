import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../config/tunables.dart';

/// Overflow animation drawn over the cup's own bounding box: a foam cap
/// bulging over the rim, splash droplets, drips running down both outer
/// walls, and a small puddle spreading at the cup's foot. Bump
/// [spillTrigger] to play it (restarts if already playing).
///
/// Geometry comes from [CupFillGeometry], so it lines up with the glass
/// at every cup size.
class SpillOverlay extends StatefulWidget {
  final int spillTrigger;
  final Color liquidColor;
  final Color foamColor;

  const SpillOverlay({super.key, required this.spillTrigger, required this.liquidColor, required this.foamColor});

  @override
  State<SpillOverlay> createState() => _SpillOverlayState();
}

class _SpillOverlayState extends State<SpillOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: kSpillDuration);

  @override
  void didUpdateWidget(covariant SpillOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spillTrigger != oldWidget.spillTrigger) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          if (!_controller.isAnimating || t <= 0 || t >= 1) return const SizedBox.expand();
          return CustomPaint(
            size: Size.infinite,
            painter: _SpillPainter(t: t, liquidColor: widget.liquidColor, foamColor: widget.foamColor),
          );
        },
      ),
    );
  }
}

class _Drip {
  final bool left;
  final double delay; // 0..1 of the spill timeline
  final double reach; // how far down the wall it runs, 0..1
  final double width;

  const _Drip(this.left, this.delay, this.reach, this.width);
}

const List<_Drip> _drips = [
  _Drip(true, 0.05, 1.00, 4.2),
  _Drip(true, 0.16, 0.70, 3.0),
  _Drip(true, 0.28, 0.45, 2.4),
  _Drip(false, 0.08, 0.92, 4.0),
  _Drip(false, 0.20, 0.62, 2.8),
  _Drip(false, 0.33, 0.40, 2.2),
];

class _SpillPainter extends CustomPainter {
  final double t;
  final Color liquidColor;
  final Color foamColor;

  _SpillPainter({required this.t, required this.liquidColor, required this.foamColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rimY = CupFillGeometry.topY * h;
    final footY = CupFillGeometry.bottomY * h;
    final rimL = CupFillGeometry.topInset * w;
    final rimR = w - rimL;
    final footL = CupFillGeometry.bottomInset * w;
    final footR = w - footL;
    final fadeOut = t > 0.72 ? 1 - (t - 0.72) / 0.28 : 1.0;

    // 1. Foam cap bulging over the rim: swells fast, then slumps.
    final capT = (t / 0.5).clamp(0.0, 1.0);
    final capH = math.sin(capT * math.pi) * h * 0.07;
    if (capH > 0.5) {
      final cap = Path()..moveTo(rimL - 3, rimY + 2);
      const bumps = 7;
      for (var i = 0; i <= bumps; i++) {
        final x = rimL - 3 + (rimR - rimL + 6) * i / bumps;
        final bump = capH * (0.75 + 0.25 * math.sin(i * 1.9 + t * 9));
        cap.quadraticBezierTo(x - (rimR - rimL) / bumps / 2, rimY - bump * 1.15, x, rimY - bump * 0.6);
      }
      cap.lineTo(rimR + 3, rimY + 2);
      cap.close();
      canvas.drawPath(cap, Paint()..color = foamColor.withValues(alpha: 0.95));
    }

    // 2. Splash droplets flung off the rim on a short arc.
    final splashT = (t / 0.4).clamp(0.0, 1.0);
    if (splashT < 1) {
      final dropPaint = Paint()..color = liquidColor.withValues(alpha: 0.85 * (1 - splashT));
      for (var i = 0; i < 6; i++) {
        final left = i.isEven;
        final originX = left ? rimL : rimR;
        final spread = 6.0 + i * 3.5;
        final dx = (left ? -1 : 1) * spread * splashT;
        final dy = -14 * splashT + 34 * splashT * splashT;
        canvas.drawCircle(Offset(originX + dx, rimY + dy), 1.6 + (i % 3) * 0.6, dropPaint);
      }
    }

    // 3. Drips running down the outside of each wall, thick head + tail.
    final dripColor = Color.lerp(liquidColor, foamColor, 0.3)!.withValues(alpha: 0.9 * fadeOut);
    for (final d in _drips) {
      final p = Curves.easeIn.transform(((t - d.delay) / 0.55).clamp(0.0, 1.0)) * d.reach;
      if (p <= 0) continue;
      Offset along(double f) {
        final x0 = d.left ? rimL - 2 : rimR + 2;
        final x1 = d.left ? footL - 2 : footR + 2;
        return Offset(x0 + (x1 - x0) * f, rimY + (footY - rimY) * f);
      }

      final head = along(p);
      final tail = along(math.max(0.0, p - 0.22));
      canvas.drawLine(
        tail,
        head,
        Paint()
          ..color = dripColor
          ..strokeWidth = d.width
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(head, d.width * 0.85, Paint()..color = dripColor);
    }

    // 4. Puddle spreading at the foot once the first drips land.
    final puddleT = ((t - 0.35) / 0.4).clamp(0.0, 1.0);
    if (puddleT > 0) {
      final puddleW = (footR - footL + 26) * Curves.easeOut.transform(puddleT);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(w / 2, footY + h * 0.05), width: puddleW, height: 5 + 3 * puddleT),
        Paint()..color = liquidColor.withValues(alpha: 0.55 * fadeOut),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpillPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.liquidColor != liquidColor || oldDelegate.foamColor != foamColor;
}
