import 'package:flutter/material.dart';

import 'pressable_scale.dart';

/// Small pill button that lets the user dump the current cup and start
/// over without having to switch cup sizes. Fades in only once there's
/// actually something to empty.
class EmptyCupButton extends StatelessWidget {
  final bool visible;
  final VoidCallback? onTap;

  const EmptyCupButton({super.key, required this.visible, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 220),
      child: IgnorePointer(
        ignoring: !visible,
        child: PressableScale(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded, size: 14, color: Colors.white70),
                SizedBox(width: 6),
                Text(
                  'Empty cup',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
