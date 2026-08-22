import 'dart:math' as math;
import 'package:flutter/material.dart';

class _Bubble {
  final double startX;
  final double size;
  final double riseDistance;
  final double delay;
  final double wobble;

  _Bubble({
    required this.startX,
    required this.size,
    required this.riseDistance,
    required this.delay,
    required this.wobble,
  });
}

class _BubbleBatch {
  final AnimationController controller;
  final List<_Bubble> bubbles;

  _BubbleBatch(this.controller, this.bubbles);
}

/// Lightweight, self-disposing bubble particle field. Bump [spawnTrigger]
/// to spawn a fresh batch near the cup's current top edge; each batch
/// gets its own [AnimationController] that disposes itself once its
/// bubbles have fully risen and faded out.
class BubbleField extends StatefulWidget {
  final int spawnTrigger;
  final Color color;
  final double originX;
  final double originY;

  const BubbleField({
    super.key,
    required this.spawnTrigger,
    required this.color,
    required this.originX,
    required this.originY,
  });

  @override
  State<BubbleField> createState() => _BubbleFieldState();
}

class _BubbleFieldState extends State<BubbleField> with TickerProviderStateMixin {
  final List<_BubbleBatch> _batches = [];
  final math.Random _random = math.Random();

  @override
  void didUpdateWidget(covariant BubbleField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spawnTrigger != oldWidget.spawnTrigger) {
      _spawn();
    }
  }

  void _spawn() {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    final bubbles = List.generate(8, (i) {
      return _Bubble(
        startX: (_random.nextDouble() - 0.5) * 46,
        size: 4 + _random.nextDouble() * 5,
        riseDistance: 46 + _random.nextDouble() * 44,
        delay: _random.nextDouble() * 0.35,
        wobble: (_random.nextDouble() - 0.5) * 18,
      );
    });
    final batch = _BubbleBatch(controller, bubbles);

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
      child: Stack(
        children: [
          for (final batch in _batches)
            AnimatedBuilder(
              animation: batch.controller,
              builder: (context, _) => Stack(
                children: [
                  for (final bubble in batch.bubbles)
                    _buildBubble(batch.controller, bubble),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBubble(AnimationController controller, _Bubble bubble) {
    final t = ((controller.value - bubble.delay) / (1 - bubble.delay)).clamp(0.0, 1.0);
    final eased = Curves.easeOut.transform(t);
    final dy = -bubble.riseDistance * eased;
    final dx = bubble.startX + math.sin(eased * math.pi * 1.6) * bubble.wobble * 0.3;
    final opacity = t <= 0 ? 0.0 : (1 - t).clamp(0.0, 1.0);

    return Positioned(
      left: widget.originX + dx,
      top: widget.originY + dy,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: bubble.size,
          height: bubble.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}
