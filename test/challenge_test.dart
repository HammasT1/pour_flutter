import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pour_flutter/config/tunables.dart';
import 'package:pour_flutter/main.dart';
import 'package:pour_flutter/providers/challenge_provider.dart';
import 'package:pour_flutter/providers/pour_state_provider.dart';

void main() {
  final day = DateTime(2026, 11, 22);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('scoring', () {
    test('tiers by distance from target', () {
      expect(const RoundResult(target: 0.5, level: 0.505).tier, ChallengeTier.bullseye);
      expect(const RoundResult(target: 0.5, level: 0.48).tier, ChallengeTier.great);
      expect(const RoundResult(target: 0.5, level: 0.55).tier, ChallengeTier.good);
      expect(const RoundResult(target: 0.5, level: 0.41).tier, ChallengeTier.ok);
      expect(const RoundResult(target: 0.5, level: 0.2).tier, ChallengeTier.miss);
      expect(const RoundResult(target: 0.5, level: 0.5, spilled: true).tier, ChallengeTier.spilled);
    });

    test('points: 100 dead on, 0 when far off or spilled', () {
      expect(const RoundResult(target: 0.6, level: 0.6).points, 100);
      expect(const RoundResult(target: 0.6, level: 0.66).points, 50);
      expect(const RoundResult(target: 0.6, level: 0.2).points, 0);
      expect(const RoundResult(target: 0.6, level: 0.6, spilled: true).points, 0);
    });

    test('daily targets are the same all day, whole percents, in range', () {
      final a = ChallengeNotifier.dailyTargetsFor(day);
      final b = ChallengeNotifier.dailyTargetsFor(DateTime(2026, 11, 22, 23, 59));
      expect(a, b);
      expect(a, hasLength(kDailyRounds));
      expect(a, isNot(ChallengeNotifier.dailyTargetsFor(DateTime(2026, 11, 23))));
      for (final t in a) {
        expect(t, inInclusiveRange(kChallengeMinTarget, kChallengeMaxTarget));
        expect((t * 100 - (t * 100).round()).abs(), lessThan(1e-9));
      }
    });
  });

  group('rounds', () {
    late ChallengeNotifier n;
    ChallengeState s() => n.state;

    setUp(() => n = ChallengeNotifier(clock: () => day, random: math.Random(7)));
    tearDown(() => n.dispose());

    test('free mode has no target and always accepts pours', () {
      expect(s().target, isNull);
      expect(s().acceptingPours, isTrue);
    });

    test('lock in scores the round and stops pouring until next round', () {
      n.setMode(ChallengeMode.practice);
      final t = s().target!;
      n.lockIn(t);
      expect(s().result!.tier, ChallengeTier.bullseye);
      expect(s().acceptingPours, isFalse);
      n.lockIn(0.1); // ignored: already locked
      expect(s().result!.level, t);
      n.nextRound();
      expect(s().result, isNull);
      expect(s().acceptingPours, isTrue);
    });

    test('GREAT or better builds a streak; anything else resets it', () async {
      n.setMode(ChallengeMode.practice);
      for (var i = 0; i < 3; i++) {
        n.lockIn(s().target! + 0.02);
        n.nextRound();
      }
      expect(s().streak, 3);
      expect(s().bestStreak, 3);
      n.recordSpill(s().target!);
      expect(s().streak, 0);
      expect(s().bestStreak, 3);
      await Future<void>.delayed(Duration.zero);
      expect((await SharedPreferences.getInstance()).getInt('challenge.bestStreak'), 3);
    });

    test('daily runs 5 rounds then saves the best total for the day', () async {
      n.setMode(ChallengeMode.daily);
      expect(s().target, ChallengeNotifier.dailyTargetsFor(day).first);
      for (var i = 0; i < kDailyRounds; i++) {
        expect(s().round, i);
        n.lockIn(s().target!);
        if (i < kDailyRounds - 1) n.nextRound();
      }
      expect(s().dailyFinished, isTrue);
      expect(s().dailyTotal, 500);
      expect(s().newDailyBest, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect((await SharedPreferences.getInstance()).getInt('challenge.daily.20261122'), 500);

      // Replaying starts today's Daily over; a worse run keeps the best.
      n.nextRound();
      expect(s().dailyFinished, isFalse);
      for (var i = 0; i < kDailyRounds; i++) {
        n.lockIn(0.0);
        if (i < kDailyRounds - 1) n.nextRound();
      }
      expect(s().newDailyBest, isFalse);
      expect(s().dailyBest, 500);
    });

    test('bests load from storage', () async {
      SharedPreferences.setMockInitialValues({'challenge.bestStreak': 9, 'challenge.daily.20261122': 321});
      final loaded = ChallengeNotifier(clock: () => day);
      await Future<void>.delayed(Duration.zero);
      expect(loaded.state.bestStreak, 9);
      expect(loaded.state.dailyBest, 321);
      loaded.dispose();
    });
  });

  group('challenge UI', () {
    late ProviderContainer container;

    Future<void> pumpApp(WidgetTester tester) async {
      container = ProviderContainer(
        overrides: [
          challengeProvider.overrideWith((ref) => ChallengeNotifier(clock: () => day, random: math.Random(3))),
        ],
      );
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
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    testWidgets('practice: target shown, readout hidden, lock in scores, next round resets', (tester) async {
      await pumpApp(tester);
      await tapText(tester, 'Practice');

      final target = container.read(challengeProvider).target!;
      final pct = '${(target * 100).round()}%';
      expect(find.text(pct), findsOneWidget, reason: 'target tag on the cup');
      expect(find.textContaining('FILL TO THE LINE: $pct'), findsOneWidget);
      expect(find.textContaining('???'), findsOneWidget);

      container.read(pourStateProvider.notifier).addFillFraction(target);
      await tester.pump();
      await tapText(tester, 'LOCK IN');
      expect(find.text('BULLSEYE'), findsOneWidget);
      expect(find.text('+100'), findsOneWidget);
      expect(find.textContaining('???'), findsNothing, reason: 'amount revealed after lock in');

      await tapText(tester, 'NEXT ROUND');
      expect(container.read(pourStateProvider).fillLevel, 0);
      expect(container.read(challengeProvider).result, isNull);
      await tearDownApp(tester);
    });

    testWidgets('back to Free hides the target and restores normal play', (tester) async {
      await pumpApp(tester);
      await tapText(tester, 'Practice');
      await tapText(tester, 'Free');
      expect(find.textContaining('FILL TO THE LINE'), findsNothing);
      expect(find.text('TAP TO POUR  ·  HOLD FOR A PERFECT POUR'), findsOneWidget);
      await tearDownApp(tester);
    });
  });
}
