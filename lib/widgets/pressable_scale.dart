import 'package:flutter/material.dart';

/// Wraps [child] in a single [GestureDetector] that both fires [onTap]
/// and drives a quick press-down scale for tactile feedback - deliberately
/// a single recognizer (not an extra one layered on top of an existing
/// tap handler) so it's safe to drop into places like the bottle carousel
/// where an additional competing recognizer could interfere with the
/// PageView's own drag gesture.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const PressableScale({super.key, required this.child, required this.onTap, this.pressedScale = 0.92});

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: interactive ? (_) => _setPressed(true) : null,
      onTapUp: interactive ? (_) => _setPressed(false) : null,
      onTapCancel: interactive ? () => _setPressed(false) : null,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
