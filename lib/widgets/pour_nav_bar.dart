import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/drink_model.dart';

/// Top nav bar: a translucent glass pill with the "POUR" wordmark
/// (gradient-accented display font) on the left and the active drink's
/// name as a color-matched badge on the right. The gradient and badge
/// color both animate to the current drink's [DrinkModel.screenColor].
class PourNavBar extends StatelessWidget {
  final DrinkModel drink;

  const PourNavBar({super.key, required this.drink});

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
          AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: drink.screenColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: drink.screenColor.withValues(alpha: 0.5), blurRadius: 10)],
            ),
            child: Text(
                  drink.name.toUpperCase(),
                  key: ValueKey(drink.id),
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                )
                .animate(key: ValueKey('${drink.id}-badge'))
                .fadeIn(duration: 220.ms)
                .slideX(begin: 0.25, end: 0, duration: 220.ms, curve: Curves.easeOut),
          ),
        ],
      ),
    );
  }
}
