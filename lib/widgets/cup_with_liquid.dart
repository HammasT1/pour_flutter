import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../animations/cup_trapezoid_clipper.dart';
import '../animations/liquid_surface_painter.dart';
import '../config/tunables.dart';
import '../models/cup_size_config.dart';
import '../models/drink_model.dart';
import 'safe_asset_image.dart';

/// Stacks an animated liquid layer on top of the cup art, clipped to the
/// tapered fillable region defined in [CupFillGeometry]. cup.png is a
/// plain opaque cutout (no hollowed-out interior), so the liquid has to
/// be painted *in front* of it - at less than full opacity, so the cup
/// still reads as a slightly translucent plastic cup with liquid inside
/// rather than a flat color block sitting on top. The whole widget
/// re-scales via [AnimatedContainer] when [cupConfig] changes, and every
/// measurement below is re-derived from the current [LayoutBuilder]
/// constraints each frame - so switching S/M/L never misaligns the
/// liquid with the cup art.
class CupWithLiquid extends StatelessWidget {
  final DrinkModel drink;
  final CupSizeConfig cupConfig;
  final double fillLevel;

  const CupWithLiquid({
    super.key,
    required this.drink,
    required this.cupConfig,
    required this.fillLevel,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      width: cupConfig.displayWidth,
      height: cupConfig.displayHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          return Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: kCupOpacity,
                child: SafeAssetImage(
                  assetPath: kCupAssetPath,
                  fallbackIcon: Icons.local_cafe_outlined,
                  fallbackLabel: 'cup.png',
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fillLevel),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, animatedFill, _) {
                  return ClipPath(
                    clipper: const CupTrapezoidClipper(),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top: CupFillGeometry.topY * h,
                          height: (CupFillGeometry.bottomY - CupFillGeometry.topY) * h,
                          child: _LiquidLayer(fillFraction: animatedFill, drink: drink),
                        ),
                      ],
                    ),
                  );
                },
              ),
              // Diagonal glass-shine highlight, clipped to the same
              // verified fillable region so it can never bleed onto the
              // transparent canvas around the cup art.
              IgnorePointer(
                child: ClipPath(
                  clipper: const CupTrapezoidClipper(),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-1.0, -1.0),
                        end: Alignment(0.15, 0.55),
                        stops: [0.0, 0.45],
                        colors: [Color(0x2AFFFFFF), Color(0x00FFFFFF)],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LiquidLayer extends StatelessWidget {
  final double fillFraction;
  final DrinkModel drink;

  const _LiquidLayer({required this.fillFraction, required this.drink});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: const SizedBox.shrink()
          .animate(onPlay: (controller) => controller.repeat())
          .custom(
            duration: 2200.ms,
            builder: (context, t, child) => CustomPaint(
              size: Size.infinite,
              painter: LiquidSurfacePainter(
                fillFraction: fillFraction,
                liquidColor: drink.liquidColor,
                highlightColor: drink.highlightColor,
                wavePhase: t * 2 * math.pi,
              ),
            ),
          ),
    );
  }
}
