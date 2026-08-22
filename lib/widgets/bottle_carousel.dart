import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/drink_model.dart';
import 'pressable_scale.dart';
import 'safe_asset_image.dart';

/// PageView-driven carousel: the center bottle renders full size and
/// sharp, side bottles shrink and dim based on distance from center.
/// Drag anywhere to slide between drinks; tapping the centered bottle
/// pours it, and tapping a side bottle brings it to center (a mouse
/// drag also works - see [PourScrollBehavior] in main.dart, which is
/// what actually makes web/desktop mouse-dragging possible at all).
class BottleCarousel extends StatelessWidget {
  final PageController controller;
  final int activeIndex;
  final Animation<double> tiltAnimation;
  final bool isPouring;
  final ValueChanged<int> onPageSettled;
  final VoidCallback onTapActiveBottle;

  const BottleCarousel({
    super.key,
    required this.controller,
    required this.activeIndex,
    required this.tiltAnimation,
    required this.isPouring,
    required this.onPageSettled,
    required this.onTapActiveBottle,
  });

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: controller,
      itemCount: kDrinks.length,
      padEnds: true,
      physics: isPouring ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
      onPageChanged: onPageSettled,
      itemBuilder: (context, index) {
        final drink = kDrinks[index];
        final isActive = index == activeIndex;

        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            var page = activeIndex.toDouble();
            if (controller.hasClients && controller.page != null) {
              page = controller.page!;
            }
            final delta = (page - index).clamp(-1.0, 1.0);
            final proximity = 1 - delta.abs();
            final scale = 0.72 + 0.28 * proximity;
            final opacity = 0.4 + 0.6 * proximity;

            return Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: PressableScale(
                  pressedScale: 0.95,
                  onTap: isActive
                      ? onTapActiveBottle
                      : () => controller.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 380),
                          curve: Curves.easeOutCubic,
                        ),
                  child: child!,
                ),
              ),
            );
          },
          child: _Bottle(drink: drink, index: index, isActive: isActive, tiltAnimation: tiltAnimation),
        );
      },
    );
  }
}

class _Bottle extends StatelessWidget {
  final DrinkModel drink;
  final int index;
  final bool isActive;
  final Animation<double> tiltAnimation;

  const _Bottle({required this.drink, required this.index, required this.isActive, required this.tiltAnimation});

  @override
  Widget build(BuildContext context) {
    Widget bottle = SizedBox(
      height: 200,
      child: SafeAssetImage(
        assetPath: drink.assetPath,
        fallbackIcon: Icons.local_drink_outlined,
        fallbackLabel: drink.name,
      ),
    );

    if (isActive) {
      bottle = AnimatedBuilder(
        animation: tiltAnimation,
        builder: (context, child) => Transform.rotate(
          angle: tiltAnimation.value,
          alignment: const Alignment(-0.2, 0.95),
          child: child,
        ),
        child: bottle,
      );
    }

    // The bottle bobs (floats) via a paint-time transform, but the shadow
    // below it stays put in normal layout flow - that mismatch is what
    // sells the "floating" look instead of the whole group just sliding.
    final bobbingBottle = bottle
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(begin: 0, end: -10, duration: (1400 + index * 130).ms, curve: Curves.easeInOut);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        bobbingBottle,
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 64,
          height: 12,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(30)),
            gradient: RadialGradient(colors: [Color(0x5A000000), Color(0x00000000)]),
          ),
        ),
      ],
    );
  }
}
