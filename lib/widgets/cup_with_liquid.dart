import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../animations/cup_trapezoid_clipper.dart';
import '../animations/liquid_surface_painter.dart';
import '../config/tunables.dart';
import '../models/cup_size_config.dart';
import '../models/drink_model.dart';
import 'safe_asset_image.dart';
import 'challenge_widgets.dart';
import 'ice_and_straw.dart';
import 'spill_overlay.dart';

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

  /// How long the liquid takes to ease to a new [fillLevel]. Long for a
  /// tap pour (one visible "glug"), short during hold-to-pour so the
  /// liquid tracks the live level the player is judging.
  final Duration fillDuration;

  /// Shows the perfect-pour band near the brim (during a hold-to-pour).
  final bool showPerfectZone;

  /// Foam head height on top of the liquid (fraction of fillable height).
  final double foamLevel;

  /// Bump to play the overflow animation.
  final int spillTrigger;

  /// Ice cubes in the cup, and whether the straw is in.
  final int iceCubes;
  final bool hasStraw;

  /// Challenge target line (0..1 of the fillable height); null hides it.
  final double? targetLevel;
  final Color targetColor;

  const CupWithLiquid({
    super.key,
    required this.drink,
    required this.cupConfig,
    required this.fillLevel,
    this.fillDuration = const Duration(milliseconds: 900),
    this.showPerfectZone = false,
    this.foamLevel = 0.0,
    this.spillTrigger = 0,
    this.iceCubes = 0,
    this.hasStraw = false,
    this.targetLevel,
    this.targetColor = const Color(0xFFFFFFFF),
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
            // The straw sticks up out of the cup and falling ice starts
            // above the rim, so don't clip to the cup's box.
            clipBehavior: Clip.none,
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
                duration: fillDuration,
                curve: Curves.easeOutCubic,
                builder: (context, animatedFill, _) {
                  final liquid = ClipPath(
                    clipper: const CupTrapezoidClipper(),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top: CupFillGeometry.topY * h,
                          height: (CupFillGeometry.bottomY - CupFillGeometry.topY) * h,
                          child: _LiquidLayer(fillFraction: animatedFill, foamFraction: foamLevel, drink: drink),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: CupFillGeometry.topY * h,
                          height: (CupFillGeometry.bottomY - CupFillGeometry.topY) * h,
                          child: _PerfectZoneBand(
                            visible: showPerfectZone,
                            inZone: animatedFill >= kPerfectPourMin && animatedFill <= kPerfectPourMax,
                          ),
                        ),
                      ],
                    ),
                  );
                  // Straw and ice ride the same animated liquid line so the
                  // refraction break and floating cubes track the surface.
                  return Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      liquid,
                      StrawLayer(
                        visible: hasStraw,
                        level: animatedFill,
                        stripeColor: drink.screenColor,
                        liquidColor: drink.liquidColor,
                      ),
                      IceLayer(cubeCount: iceCubes, level: animatedFill, liquidColor: drink.liquidColor),
                    ],
                  );
                },
              ),
              TargetLine(level: targetLevel, color: targetColor),
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
              SpillOverlay(spillTrigger: spillTrigger, liquidColor: drink.liquidColor, foamColor: drink.foamColor),
            ],
          );
        },
      ),
    );
  }
}

class _LiquidLayer extends StatelessWidget {
  final double fillFraction;
  final double foamFraction;
  final DrinkModel drink;

  const _LiquidLayer({required this.fillFraction, required this.foamFraction, required this.drink});

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
                // Foam can't rise past the rim of the fillable region.
                foamFraction: foamFraction.clamp(0.0, 1.0 - fillFraction.clamp(0.0, 1.0)),
                foamColor: drink.foamColor,
              ),
            ),
          ),
    );
  }
}

/// Faint band marking the perfect-pour window near the brim, positioned
/// in the same fill-fraction space as [LiquidSurfacePainter] (0 = bottom
/// of the fillable region, 1 = top). Brightens while the liquid sits in
/// the window, so the player knows when to let go.
class _PerfectZoneBand extends StatelessWidget {
  final bool visible;
  final bool inZone;

  const _PerfectZoneBand({required this.visible, required this.inZone});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: visible ? 1 : 0,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final regionH = constraints.maxHeight;
            final top = (1 - kPerfectPourMax) * regionH;
            final height = (kPerfectPourMax - kPerfectPourMin) * regionH;
            final line = Colors.white.withValues(alpha: inZone ? 0.95 : 0.45);
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: top,
                  height: height,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: inZone ? 0.28 : 0.10),
                      border: Border.symmetric(horizontal: BorderSide(color: line, width: 1)),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
