import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pour_flutter/config/tunables.dart';
import 'package:pour_flutter/main.dart';
import 'package:pour_flutter/models/cup_size_config.dart';
import 'package:pour_flutter/models/drink_model.dart';
import 'package:pour_flutter/providers/pour_state_provider.dart';

void main() {
  late ProviderContainer container;

  Future<void> pumpApp(WidgetTester tester) async {
    container = ProviderContainer();
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const PourApp()));
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> tearDownApp(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
    container.dispose();
  }

  PourState state() => container.read(pourStateProvider);

  Future<void> frames(WidgetTester tester, int n) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Offset bottleCenter(WidgetTester tester) => tester.getCenter(find.byType(PageView));

  test('every drink has a fizziness in 0..1', () {
    for (final d in kDrinks) {
      expect(d.fizziness, inInclusiveRange(0.0, 1.0), reason: d.id);
    }
  });

  test('emptying the cup or changing size clears foam', () {
    final c = ProviderContainer();
    final n = c.read(pourStateProvider.notifier);
    n.addFillFraction(0.5);
    n.setFoam(0.1);
    n.emptyCup();
    expect(c.read(pourStateProvider).foamLevel, 0);

    n.addFillFraction(0.5);
    n.setFoam(0.1);
    n.selectCupSize(CupSize.large);
    expect(c.read(pourStateProvider).foamLevel, 0);
    c.dispose();
  });

  testWidgets('a tap pour foams up, then the foam settles', (tester) async {
    await pumpApp(tester);
    await tester.tapAt(bottleCenter(tester));
    await frames(tester, 60); // ~1s: splash lands, foam forms
    final peak = state().foamLevel;
    expect(peak, greaterThan(0.03));

    await frames(tester, 180); // ~3s of settling
    expect(state().foamLevel, lessThan(peak * 0.2));
    await tearDownApp(tester);
  });

  testWidgets('a long full-flow hold overflows: spill, no perfect pour', (tester) async {
    await pumpApp(tester);
    final gesture = await tester.startGesture(bottleCenter(tester));
    await tester.pump(kHoldToPourDelay + const Duration(milliseconds: 20));

    var spilled = false;
    for (var i = 0; i < 400; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.text('OVERFLOW!').evaluate().isNotEmpty) {
        spilled = true;
        break;
      }
    }
    expect(spilled, isTrue);
    expect(state().fillLevel, lessThan(1.0), reason: 'foam spills before the liquid tops out');
    expect(state().fillLevel + state().foamLevel, lessThanOrEqualTo(1.0 + 1e-9));

    // The bottle pulls back on its own, even while still held.
    await tester.pump(kHoldTiltOutDuration + const Duration(milliseconds: 50));
    expect(state().isPouring, isFalse);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('PERFECT POUR'), findsNothing);
    await tearDownApp(tester);
  });

  testWidgets('pour, let it settle, then top up gently for a perfect pour', (tester) async {
    await pumpApp(tester);

    // First hold: get to ~70%.
    var gesture = await tester.startGesture(bottleCenter(tester));
    await tester.pump(kHoldToPourDelay + const Duration(milliseconds: 20));
    for (var i = 0; i < 400 && state().fillLevel < 0.70; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await frames(tester, 200); // tilt back + foam settles

    // Second, short hold stays at low flow (low foam) into the zone.
    gesture = await tester.startGesture(bottleCenter(tester));
    await tester.pump(kHoldToPourDelay + const Duration(milliseconds: 20));
    for (var i = 0; i < 400 && state().fillLevel < kPerfectPourMin + 0.02; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('OVERFLOW!'), findsNothing);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('PERFECT POUR'), findsOneWidget);
    await tearDownApp(tester);
  });
}

