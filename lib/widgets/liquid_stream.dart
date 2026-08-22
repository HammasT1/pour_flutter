import 'package:flutter/material.dart';

/// A thin animated rounded rect representing the pour stream, fading in
/// from the bottle mouth down to the cup's current rim position. Its
/// length is passed in by the caller, already recalculated for the
/// active cup size.
class LiquidStream extends StatelessWidget {
  final bool visible;
  final double height;
  final Color color;
  final Color highlightColor;

  const LiquidStream({
    super.key,
    required this.visible,
    required this.height,
    required this.color,
    required this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: visible ? 1 : 0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          width: 7,
          height: visible ? height : height * 0.15,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [highlightColor.withValues(alpha: 0.9), color],
            ),
          ),
        ),
      ),
    );
  }
}
