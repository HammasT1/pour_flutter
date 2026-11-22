import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/drink_model.dart';

/// The drink's name in a color-matched pill - small in the nav bar, large
/// as the showcase title. Both are Heroes with the same tag; use
/// [flightShuttle] so the text scales smoothly in flight instead of
/// reflowing between the two font sizes.
class DrinkBadge extends StatelessWidget {
  final DrinkModel drink;

  /// 1.0 = nav bar size.
  final double scale;
  final bool showChevron;

  const DrinkBadge({super.key, required this.drink, this.scale = 1.0, this.showChevron = false});

  static Widget flightShuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromContext,
    BuildContext toContext,
  ) {
    final hero = (direction == HeroFlightDirection.push ? toContext.widget : fromContext.widget) as Hero;
    return Material(
      type: MaterialType.transparency,
      child: FittedBox(fit: BoxFit.contain, child: hero.child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 7 * scale),
        decoration: BoxDecoration(
          color: drink.screenColor,
          borderRadius: BorderRadius.circular(16 * scale),
          boxShadow: [BoxShadow(color: drink.screenColor.withValues(alpha: 0.5), blurRadius: 10 * scale)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                  drink.name.toUpperCase(),
                  key: ValueKey(drink.id),
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 11 * scale,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1 * scale,
                  ),
                )
                .animate(key: ValueKey('${drink.id}-badge'))
                .fadeIn(duration: 220.ms)
                .slideX(begin: 0.25, end: 0, duration: 220.ms, curve: Curves.easeOut),
            if (showChevron) ...[
              SizedBox(width: 3 * scale),
              Icon(Icons.chevron_right_rounded, size: 14 * scale, color: Colors.white.withValues(alpha: 0.85)),
            ],
          ],
        ),
      ),
    );
  }
}
