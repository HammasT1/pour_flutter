import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pour_flutter/main.dart';
import 'package:pour_flutter/models/drink_model.dart';
import 'package:pour_flutter/providers/pour_state_provider.dart';
import 'package:pour_flutter/screens/drink_detail_screen.dart';

void main() {
  late ProviderContainer container;

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> frames(WidgetTester tester, [int n = 45]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
    container = ProviderContainer();
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const PourApp()));
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> tearDownApp(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
    container.dispose();
  }

  Future<void> openDetails(WidgetTester tester) async {
    final name = kDrinks[container.read(pourStateProvider).selectedDrinkIndex].name.toUpperCase();
    await tester.tap(find.text(name));
    await frames(tester);
  }

  int selected() => container.read(pourStateProvider).selectedDrinkIndex;

  testWidgets('badge opens the showcase with the bottle and badge as Heroes', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('FANTA ORANGE'));
    await tester.pump(); // route pushed
    await tester.pump(const Duration(milliseconds: 100)); // mid-flight
    expect(tester.takeException(), isNull);

    await frames(tester);
    expect(find.byType(DrinkDetailScreen), findsOneWidget);
    expect(find.text('POUR THIS'), findsOneWidget);
    expect(find.text('1 / ${kDrinks.length}'), findsOneWidget);
    final heroTags = tester.widgetList<Hero>(find.byType(Hero)).map((h) => h.tag).toSet();
    expect(heroTags, containsAll([kDrinks[0].bottleHeroTag, kDrinks[0].badgeHeroTag]));
    await tearDownApp(tester);
  });

  testWidgets('arrows move between drinks; POUR THIS selects and returns', (tester) async {
    await pumpApp(tester);
    await openDetails(tester);

    await tester.tap(find.bySemanticsLabel('Next drink'));
    await frames(tester);
    expect(find.text('2 / ${kDrinks.length}'), findsOneWidget);
    expect(find.text(kDrinks[1].name.toUpperCase()), findsOneWidget);

    await tester.tap(find.text('POUR THIS'));
    await frames(tester, 60);
    expect(find.byType(DrinkDetailScreen), findsNothing);
    expect(selected(), 1);
    expect(tester.takeException(), isNull);
    await tearDownApp(tester);
  });

  testWidgets('previous wraps around; back leaves the selection alone', (tester) async {
    await pumpApp(tester);
    await openDetails(tester);

    await tester.tap(find.bySemanticsLabel('Previous drink'));
    await frames(tester);
    expect(find.text('${kDrinks.length} / ${kDrinks.length}'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Back'));
    await frames(tester, 60);
    expect(find.byType(DrinkDetailScreen), findsNothing);
    expect(selected(), 0);
    expect(tester.takeException(), isNull);
    await tearDownApp(tester);
  });

  testWidgets('quick back-and-forth then pop does not clash Hero tags', (tester) async {
    await pumpApp(tester);
    await openDetails(tester);
    await tester.tap(find.bySemanticsLabel('Next drink'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.bySemanticsLabel('Previous drink'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.text('POUR THIS'));
    await frames(tester, 60);
    expect(tester.takeException(), isNull);
    expect(selected(), 0);
    await tearDownApp(tester);
  });
}
