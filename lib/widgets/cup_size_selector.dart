import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cup_size_config.dart';
import '../providers/pour_state_provider.dart';
import 'pressable_scale.dart';

/// Three chip/pill buttons (S / M / L). Selecting one resizes the cup via
/// [CupWithLiquid]'s own AnimatedContainer and resets fillLevel to 0
/// (handled in the notifier) - switching size always starts empty.
class CupSizeSelector extends ConsumerWidget {
  const CupSizeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pourStateProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: CupSize.values.map((size) {
        final config = kCupSizes[size]!;
        final selected = state.selectedCupSize == size;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: PressableScale(
            onTap: state.isPouring
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    ref.read(pourStateProvider.notifier).selectCupSize(size);
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: selected ? Colors.white : Colors.white24),
              ),
              child: Text(
                config.label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0.5,
                  color: selected ? const Color(0xFF0B0D10) : Colors.white70,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
