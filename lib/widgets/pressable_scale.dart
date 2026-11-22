import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Wraps [child] in a single [RawGestureDetector] that fires [onTap] (and
/// optionally [onHoldStart] / [onHoldEnd]) and drives a quick press-down
/// scale for tactile feedback - deliberately one detector (not extra ones
/// layered on top of an existing tap handler) so it's safe to drop into
/// places like the bottle carousel where an additional competing
/// recognizer could interfere with the PageView's own drag gesture.
///
/// Tap and hold share the gesture arena: releasing before [holdDelay]
/// is a tap, staying down past it is a hold, and moving past touch slop
/// before either resolves hands the gesture to the PageView drag.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onHoldStart;

  /// Called when a hold ends - on release, and defensively on cancel, so
  /// callers must tolerate it firing without a matching [onHoldStart].
  final VoidCallback? onHoldEnd;
  final Duration holdDelay;
  final double pressedScale;

  const PressableScale({
    super.key,
    required this.child,
    required this.onTap,
    this.onHoldStart,
    this.onHoldEnd,
    this.holdDelay = const Duration(milliseconds: 180),
    this.pressedScale = 0.92,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  void _endHold() {
    _setPressed(false);
    widget.onHoldEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final gestures = <Type, GestureRecognizerFactory>{
      if (widget.onTap != null)
        TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
          () => TapGestureRecognizer(debugOwner: this),
          (r) => r
            ..onTap = widget.onTap
            ..onTapDown = ((_) => _setPressed(true))
            ..onTapUp = ((_) => _setPressed(false))
            ..onTapCancel = (() => _setPressed(false)),
        ),
      if (widget.onHoldStart != null)
        LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(duration: widget.holdDelay, debugOwner: this),
          (r) => r
            ..onLongPressStart = ((_) {
              _setPressed(true);
              widget.onHoldStart?.call();
            })
            ..onLongPressEnd = ((_) => _endHold())
            ..onLongPressCancel = _endHold,
        ),
    };

    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: gestures,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
