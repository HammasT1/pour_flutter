import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pour_flutter/config/tunables.dart';
import 'package:pour_flutter/main.dart';
import 'package:pour_flutter/providers/pour_state_provider.dart';

void main() {
  late ProviderContainer container;

  Future<void> pumpApp(WidgetTester tester) async {
    container = ProviderContainer();
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const PourApp()));
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> tearDownApp(WidgetTester tester) async {
    // Let banners/tilt settle, then unmount so repeating animations stop.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
    container.dispose();
  }

  double fill() => container.read(pourStateProvider).fillLevel;

  // The active (centered) bottle sits in the middle of the carousel.
  Offset bottleCenter(WidgetTester tester) => tester.getCenter(find.byType(PageView));

  testWidgets('tap still pours one fixed amount', (tester) async {
    await pumpApp(tester);
    await tester.tapAt(bottleCenter(tester));
    for (var i = 0; i < 75; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(fill(), closeTo(kPourVolumeUnits / 250, 1e-9)); // medium cup
    expect(container.read(pourStateProvider).isPouring, isFalse);
    await tearDownApp(tester);
  });

  testWidgets('holding pours continuously; releasing in the zone is a perfect pour', (tester) async {
    await pumpApp(tester);
    final gesture = await tester.startGesture(bottleCenter(tester));
    await tester.pump(kHoldToPourDelay + const Duration(milliseconds: 20));
    expect(container.read(pourStateProvider).isPouring, isTrue);

    var frames = 0;
    while (fill() < kPerfectPourMin + 0.02 && frames < 600) {
      await tester.pump(const Duration(milliseconds: 16));
      frames++;
    }
    final released = fill();
    expect(released, inInclusiveRange(kPerfectPourMin, kPerfectPourMax));

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('PERFECT POUR'), findsOneWidget);
    expect(fill(), released, reason: 'flow stops on release');

    await tester.pump(kHoldTiltOutDuration + const Duration(milliseconds: 50));
    expect(container.read(pourStateProvider).isPouring, isFalse);
    await tearDownApp(tester);
  });

  testWidgets('releasing early is not a perfect pour', (tester) async {
    await pumpApp(tester);
    final gesture = await tester.startGesture(bottleCenter(tester));
    await tester.pump(kHoldToPourDelay + const Duration(milliseconds: 20));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 50));
    expect(fill(), greaterThan(0));
    expect(fill(), lessThan(kPerfectPourMin));
    expect(find.text('PERFECT POUR'), findsNothing);
    await tearDownApp(tester);
  });

  testWidgets('holding past the brim auto-stops at full', (tester) async {
    await pumpApp(tester);
    final gesture = await tester.startGesture(bottleCenter(tester));
    await tester.pump(kHoldToPourDelay + const Duration(milliseconds: 20));
    for (var i = 0; i < 400 && fill() < 0.999; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 50));
    expect(fill(), 1.0);
    expect(find.text('CUP FULL'), findsOneWidget);
    await gesture.up();
    await tester.pump(kHoldTiltOutDuration + const Duration(milliseconds: 50));
    expect(container.read(pourStateProvider).isPouring, isFalse);
    await tearDownApp(tester);
  });
}
