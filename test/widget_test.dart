import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pour_flutter/main.dart';

void main() {
  testWidgets('Pour screen renders the drink lineup and size selector', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: PourApp()));
    // The carousel and liquid layer use infinitely-repeating flutter_animate
    // effects, which schedule a zero-duration startup Timer. Give it a real
    // frame to fire before asserting or unmounting.
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('POUR'), findsOneWidget);
    expect(find.text('S'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('L'), findsOneWidget);

    // Unmount the tree so tickers/timers are disposed before the test
    // binding checks for pending timers at teardown.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
