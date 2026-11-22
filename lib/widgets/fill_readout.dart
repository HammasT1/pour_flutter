import 'package:flutter/material.dart';

/// Small "180 / 250 ml" readout under the cup, counting up in sync with
/// the liquid's own fill animation rather than jumping straight to the
/// new value.
class FillReadout extends StatelessWidget {
  final double fillLevel;
  final double capacityUnits;

  /// Shortened during a hold-to-pour so the number tracks the live level.
  final Duration duration;

  /// Hides the amount (challenge rounds are judged by eye).
  final bool concealed;

  const FillReadout({
    super.key,
    required this.fillLevel,
    required this.capacityUnits,
    this.duration = const Duration(milliseconds: 900),
    this.concealed = false,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: fillLevel.clamp(0.0, 1.0)),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedFill, _) {
        final ml = concealed ? '???' : '${(animatedFill * capacityUnits).round()}';
        return Text(
          '$ml / ${capacityUnits.round()} ml',
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        );
      },
    );
  }
}
