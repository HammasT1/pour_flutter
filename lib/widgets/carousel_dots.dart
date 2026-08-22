import 'package:flutter/material.dart';

/// Pill-style page indicator for the bottle carousel - the active dot
/// stretches into a short bar in the drink's color, the rest stay small
/// and dim.
class CarouselDots extends StatelessWidget {
  final int count;
  final int activeIndex;
  final Color color;

  const CarouselDots({super.key, required this.count, required this.activeIndex, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final active = i == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? color : Colors.white24,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
