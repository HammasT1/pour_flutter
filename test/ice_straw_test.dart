import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pour_flutter/config/tunables.dart';
import 'package:pour_flutter/main.dart';
import 'package:pour_flutter/models/cup_size_config.dart';
import 'package:pour_flutter/providers/pour_state_provider.dart';

void main() {
  group('ice state', () {
    late ProviderContainer c;
    late PourStateNotifier n;
    PourState s() => c.read(pourStateProvider);

    setUp(() {
      c = ProviderContainer();
      n = c.read(pourStateProvider.notifier);
    });
    tearDown(() => c.dispose());

    test('cubes displace liquid once it is deep enough to float them', () {
      n.addIce();
      n.addIce();
      expect(s().iceDisplacement, 0, reason: 'no liquid, nothing displaced');
      n.addFillFraction(0.5);
      expect(s().iceDisplacement, closeTo(2 * kIceDisplacement, 1e-9));
      expect(s().effectiveLevel, closeTo(0.5 + 2 * kIceDisplacement, 1e-9));
    });

    test('ice leaves less room for liquid', () {
      n.addIce();
      n.addIce();
      n.addFillFraction(5);
      expect(s().fillLevel, closeTo(PourState.maxFillFor(2), 1e-9));
      expect(s().effectiveLevel, closeTo(1.0, 1e-9));
    });

    test('cube count is capped per cup size', () {
      for (var i = 0; i < 10; i++) {
        n.addIce();
      }
      expect(s().iceCubes, kCupSizes[CupSize.medium]!.maxIceCubes);
      n.selectCupSize(CupSize.small);
      expect(s().iceCubes, 0, reason: 'changing size starts fresh');
      for (var i = 0; i < 10; i++) {
        n.addIce();
      }
      expect(s().iceCubes, kCupSizes[CupSize.small]!.maxIceCubes);
    });

    test('ice into a brim-full cup spills the excess', () {
      n.addFillFraction(1.0);
      expect(n.addIce(), isTrue);
      expect(s().fillLevel, closeTo(PourState.maxFillFor(1), 1e-9));
      expect(s().effectiveLevel, closeTo(1.0, 1e-9));
    });

    test('emptying clears ice but keeps the straw', () {
      n.toggleStraw();
      n.addIce();
      n.emptyCup();
      expect(s().iceCubes, 0);
      expect(s().hasStraw, isTrue);
    });
  });

  group('ice & straw UI', () {
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

    Future<void> tapText(WidgetTester tester, String text) async {
      await tester.ensureVisible(find.text(text));
      await tester.pump();
      await tester.tap(find.text(text));
    }

    Future<void> frames(WidgetTester tester, int n) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    testWidgets('Ice button drops cubes and shows the count', (tester) async {
      await pumpApp(tester);
      await tapText(tester, 'Ice');
      await frames(tester, 60);
      expect(container.read(pourStateProvider).iceCubes, 1);
      expect(find.text('Ice 1/3'), findsOneWidget);
      expect(find.text('Empty cup'), findsOneWidget);
      await tearDownApp(tester);
    });

    testWidgets('dropping ice into a full cup overflows', (tester) async {
      await pumpApp(tester);
      container.read(pourStateProvider.notifier).addFillFraction(1.0);
      await tester.pump();
      await tapText(tester, 'Ice');
      await frames(tester, 30);
      expect(find.text('OVERFLOW!'), findsOneWidget);
      await tearDownApp(tester);
    });

    testWidgets('Straw toggles on and off', (tester) async {
      await pumpApp(tester);
      await tapText(tester, 'Straw');
      await frames(tester, 30);
      expect(container.read(pourStateProvider).hasStraw, isTrue);
      await tapText(tester, 'Straw');
      await frames(tester, 30);
      expect(container.read(pourStateProvider).hasStraw, isFalse);
      await tearDownApp(tester);
    });
  });
}
