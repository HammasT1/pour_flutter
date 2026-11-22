import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/drink_model.dart';
import 'drink_badge.dart';
import 'pressable_scale.dart';

/// Top nav bar: a translucent glass pill with the "POUR" wordmark
/// (gradient-accented display font) on the left and the active drink's
/// name as a color-matched badge on the right. The gradient and badge
/// color both animate to the current drink's [DrinkModel.screenColor].
/// Tapping the badge opens the drink showcase (the badge is a Hero, so it
/// flies into the showcase's title).
class PourNavBar extends StatelessWidget {
  final DrinkModel drink;
  final VoidCallback? onDrinkTap;

  const PourNavBar({super.key, required this.drink, this.onDrinkTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [drink.screenColor.withValues(alpha: 0.28), Colors.white.withValues(alpha: 0.04)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(color: drink.screenColor.withValues(alpha: 0.22), blurRadius: 24, spreadRadius: -6),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) =>
                LinearGradient(colors: [Colors.white, drink.screenColor]).createShader(bounds),
            child: Text(
              'POUR',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
              ),
            ),
          ),
          PressableScale(
            onTap: onDrinkTap,
            pressedScale: 0.94,
            child: Hero(
              tag: drink.badgeHeroTag,
              flightShuttleBuilder: DrinkBadge.flightShuttle,
              child: DrinkBadge(drink: drink, showChevron: true),
            ),
          ),
        ],
      ),
    );
  }
}
