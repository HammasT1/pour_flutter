import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/tunables.dart';
import '../models/cup_size_config.dart';

@immutable
class PourState {
  final int selectedDrinkIndex;
  final CupSize selectedCupSize;

  /// 0.0-1.0, relative to the *current* cup size's capacity.
  final double fillLevel;
  final bool isPouring;

  const PourState({
    this.selectedDrinkIndex = 0,
    this.selectedCupSize = CupSize.medium,
    this.fillLevel = 0.0,
    this.isPouring = false,
  });

  PourState copyWith({
    int? selectedDrinkIndex,
    CupSize? selectedCupSize,
    double? fillLevel,
    bool? isPouring,
  }) {
    return PourState(
      selectedDrinkIndex: selectedDrinkIndex ?? this.selectedDrinkIndex,
      selectedCupSize: selectedCupSize ?? this.selectedCupSize,
      fillLevel: fillLevel ?? this.fillLevel,
      isPouring: isPouring ?? this.isPouring,
    );
  }
}

class PourStateNotifier extends StateNotifier<PourState> {
  PourStateNotifier() : super(const PourState());

  void selectDrink(int index) {
    if (state.isPouring || index == state.selectedDrinkIndex) return;
    state = state.copyWith(selectedDrinkIndex: index);
  }

  /// Switching size always starts the cup empty again - no size-swap
  /// mid-pour (guarded by `isPouring`), and no carrying fill level across
  /// sizes since capacity has changed.
  void selectCupSize(CupSize size) {
    if (state.isPouring || size == state.selectedCupSize) return;
    state = state.copyWith(selectedCupSize: size, fillLevel: 0.0);
  }

  void startPour() {
    if (state.isPouring) return;
    state = state.copyWith(isPouring: true);
  }

  /// Adds a fixed pour volume, expressed as a fraction of the *current*
  /// cup size's capacity - so the same tap fills a bigger cup by a
  /// proportionally smaller amount.
  void applyPourFill() {
    final capacity = kCupSizes[state.selectedCupSize]!.capacityUnits;
    final delta = kPourVolumeUnits / capacity;
    final next = (state.fillLevel + delta).clamp(0.0, 1.0);
    state = state.copyWith(fillLevel: next);
  }

  void endPour() {
    state = state.copyWith(isPouring: false);
  }

  /// Empties the current cup without changing its size - lets the user
  /// start over on the same size instead of only being able to reset by
  /// switching sizes.
  void emptyCup() {
    if (state.isPouring || state.fillLevel <= 0.0) return;
    state = state.copyWith(fillLevel: 0.0);
  }
}

final pourStateProvider = StateNotifierProvider<PourStateNotifier, PourState>(
  (ref) => PourStateNotifier(),
);
