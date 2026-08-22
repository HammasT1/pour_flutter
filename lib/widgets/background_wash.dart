import 'package:flutter/material.dart';

/// Full-screen color wash keyed to the active drink's brand color - a base
/// tint across the whole screen plus a brighter radial glow centered low
/// (like the light coming off a cold drink), so the *entire* stage reads
/// as the drink's color rather than just a soft glow near the cup.
///
/// [intensity] is 0..1: it ramps up to 1.0 while actively pouring, settles
/// to a lower ambient level while the cup still holds liquid (the wash
/// doesn't disappear just because the pour animation finished), and only
/// drops to 0 once the cup is genuinely empty again.
class BackgroundWash extends StatelessWidget {
  final double intensity;
  final Color color;

  const BackgroundWash({super.key, required this.intensity, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: intensity.clamp(0.0, 1.0),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOut,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.30),
                color.withValues(alpha: 0.20),
                color.withValues(alpha: 0.30),
              ],
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 0.5),
                radius: 1.15,
                colors: [color.withValues(alpha: 0.85), color.withValues(alpha: 0.0)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
