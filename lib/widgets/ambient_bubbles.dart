import 'dart:math' as math;
import 'package:flutter/material.dart';

class _AmbientBubble {
  final double startXFraction; // 0..1 across the full width
  final double size;
  final double riseDistance;
  final double delay;
  final double wobble;
  final double opacity;

  _AmbientBubble({
    required this.startXFraction,
    required this.size,
    required this.riseDistance,
    required this.delay,
    required this.wobble,
    required this.opacity,
  });
}

class _AmbientBatch {
  final AnimationController controller;
  final List<_AmbientBubble> bubbles;

  _AmbientBatch(this.controller, this.bubbles);
}

/// Full-screen carbonation ambiance, evoking a cold-drink-ad wash: a wide
/// spread of small bubbles rising slowly from the bottom of the screen,
/// synced to the same [spawnTrigger] as the background color wash.
class AmbientBubbles extends StatefulWidget {
  final int spawnTrigger;
  final Color color;

  const AmbientBubbles({super.key, required this.spawnTrigger, required this.color});

  @override
  State<AmbientBubbles> createState() => _AmbientBubblesState();
}

class _AmbientBubblesState extends State<AmbientBubbles> with TickerProviderStateMixin {
  final List<_AmbientBatch> _batches = [];
  final math.Random _random = math.Random();

  @override
  void didUpdateWidget(covariant AmbientBubbles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spawnTrigger != oldWidget.spawnTrigger) {
      _spawn();
    }
  }

  void _spawn() {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    final bubbles = List.generate(22, (i) {
      return _AmbientBubble(
        startXFraction: _random.nextDouble(),
        size: 3 + _random.nextDouble() * 7,
        riseDistance: 260 + _random.nextDouble() * 340,
        delay: _random.nextDouble() * 0.55,
        wobble: (_random.nextDouble() - 0.5) * 36,
        opacity: 0.25 + _random.nextDouble() * 0.35,
      );
    });
    final batch = _AmbientBatch(controller, bubbles);

    setState(() => _batches.add(batch));
    controller.forward();
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() => _batches.remove(batch));
        }
        controller.dispose();
      }
    });
  }

  @override
  void dispose() {
    for (final batch in _batches) {
      batch.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              for (final batch in _batches)
                AnimatedBuilder(
                  animation: batch.controller,
                  builder: (context, _) => Stack(
                    children: [
                      for (final bubble in batch.bubbles)
                        _buildBubble(batch.controller, bubble, constraints),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBubble(AnimationController controller, _AmbientBubble bubble, BoxConstraints constraints) {
    final t = ((controller.value - bubble.delay) / (1 - bubble.delay)).clamp(0.0, 1.0);
    final eased = Curves.easeOut.transform(t);
    final dy = -bubble.riseDistance * eased;
    final dx = math.sin(eased * math.pi * 1.4) * bubble.wobble;
    final fade = t <= 0 ? 0.0 : (1 - t).clamp(0.0, 1.0);

    return Positioned(
      left: bubble.startXFraction * constraints.maxWidth + dx,
      top: constraints.maxHeight + dy,
      child: Opacity(
        opacity: fade * bubble.opacity,
        child: Container(
          width: bubble.size,
          height: bubble.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: widget.color.withValues(alpha: 0.5), width: 0.6),
          ),
        ),
      ),
    );
  }
}
