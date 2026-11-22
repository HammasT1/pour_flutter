import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/tunables.dart';

enum ChallengeMode { free, practice, daily }

/// How close a locked-in pour landed to the target, best first.
enum ChallengeTier {
  bullseye('BULLSEYE', Color(0xFFFFD54F)),
  great('GREAT', Color(0xFF69F0AE)),
  good('GOOD', Color(0xFF40C4FF)),
  ok('OK', Color(0xFFB0BEC5)),
  miss('MISS', Color(0xFFFF8A80)),
  spilled('SPILLED', Color(0xFFFF5252));

  final String label;
  final Color color;
  const ChallengeTier(this.label, this.color);

  /// GREAT or better keeps the streak alive.
  bool get extendsStreak => this == bullseye || this == great;

  static ChallengeTier forError(double error) {
    if (error <= kChallengeBullseye) return bullseye;
    if (error <= kChallengeGreat) return great;
    if (error <= kChallengeGood) return good;
    if (error <= kChallengeOk) return ok;
    return miss;
  }
}

@immutable
class RoundResult {
  final double target;

  /// Liquid line when locked in (or when it spilled).
  final double level;
  final bool spilled;

  const RoundResult({required this.target, required this.level, this.spilled = false});

  double get error => (level - target).abs();

  ChallengeTier get tier => spilled ? ChallengeTier.spilled : ChallengeTier.forError(error);

  /// 100 for a dead-on pour, falling linearly to 0 at [kChallengeZeroPointsError].
  int get points => spilled ? 0 : (100 * (1 - error / kChallengeZeroPointsError)).clamp(0, 100).round();
}

@immutable
class ChallengeState {
  final ChallengeMode mode;

  /// Current round's target liquid line (0..1); null in free mode.
  final double? target;

  /// 0-based round index (Daily runs [kDailyRounds] rounds).
  final int round;

  /// The current round's result once locked in / spilled.
  final RoundResult? result;

  /// Results so far in this Daily run.
  final List<RoundResult> dailyResults;

  final int streak;
  final int bestStreak;

  /// Best Daily total for today (persisted), null if not played today.
  final int? dailyBest;

  /// True when the just-finished Daily run beat the previous best.
  final bool newDailyBest;

  const ChallengeState({
    this.mode = ChallengeMode.free,
    this.target,
    this.round = 0,
    this.result,
    this.dailyResults = const [],
    this.streak = 0,
    this.bestStreak = 0,
    this.dailyBest,
    this.newDailyBest = false,
  });

  bool get isChallenge => mode != ChallengeMode.free;

  bool get dailyFinished => mode == ChallengeMode.daily && dailyResults.length >= kDailyRounds;

  int get dailyTotal => dailyResults.fold(0, (sum, r) => sum + r.points);

  /// Pouring is allowed in free mode, or mid-round before locking in.
  bool get acceptingPours => !isChallenge || (target != null && result == null);

  ChallengeState copyWith({
    ChallengeMode? mode,
    double? Function()? target,
    int? round,
    RoundResult? Function()? result,
    List<RoundResult>? dailyResults,
    int? streak,
    int? bestStreak,
    int? Function()? dailyBest,
    bool? newDailyBest,
  }) {
    return ChallengeState(
      mode: mode ?? this.mode,
      target: target != null ? target() : this.target,
      round: round ?? this.round,
      result: result != null ? result() : this.result,
      dailyResults: dailyResults ?? this.dailyResults,
      streak: streak ?? this.streak,
      bestStreak: bestStreak ?? this.bestStreak,
      dailyBest: dailyBest != null ? dailyBest() : this.dailyBest,
      newDailyBest: newDailyBest ?? this.newDailyBest,
    );
  }
}

/// Runs Practice / Daily rounds. The pour screen owns the cup: it empties
/// it before calling [setMode] / [nextRound], and reports the liquid line
/// via [lockIn] / [recordSpill].
class ChallengeNotifier extends StateNotifier<ChallengeState> {
  ChallengeNotifier({DateTime Function()? clock, math.Random? random})
    : _clock = clock ?? DateTime.now,
      _random = random ?? math.Random(),
      super(const ChallengeState()) {
    _load();
  }

  final DateTime Function() _clock;
  final math.Random _random;
  List<double> _dailyTargets = const [];

  static const _bestStreakKey = 'challenge.bestStreak';
  static String _dailyKey(DateTime d) => 'challenge.daily.${dayStamp(d)}';

  /// yyyymmdd, used both as the Daily seed and its storage key.
  static int dayStamp(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  /// Today's targets - the same for everyone on the same date.
  static List<double> dailyTargetsFor(DateTime day) {
    final rng = math.Random(dayStamp(day));
    return List.generate(kDailyRounds, (_) => _randomTarget(rng));
  }

  static double _randomTarget(math.Random rng) {
    final pct = (kChallengeMinTarget * 100).round() +
        rng.nextInt(((kChallengeMaxTarget - kChallengeMinTarget) * 100).round() + 1);
    return pct / 100;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      // Merge rather than overwrite: a round may have finished (and set
      // a new best) while storage was still loading.
      final storedDaily = prefs.getInt(_dailyKey(_clock()));
      final currentDaily = state.dailyBest;
      state = state.copyWith(
        bestStreak: math.max(prefs.getInt(_bestStreakKey) ?? 0, state.bestStreak),
        dailyBest: () => storedDaily == null
            ? currentDaily
            : (currentDaily == null ? storedDaily : math.max(storedDaily, currentDaily)),
      );
    } catch (_) {
      // Storage unavailable: bests just won't persist this session.
    }
  }

  Future<void> _save(void Function(SharedPreferences p) write) async {
    try {
      write(await SharedPreferences.getInstance());
    } catch (_) {}
  }

  void setMode(ChallengeMode mode) {
    switch (mode) {
      case ChallengeMode.free:
        state = state.copyWith(mode: mode, target: () => null, result: () => null, round: 0);
      case ChallengeMode.practice:
        state = state.copyWith(mode: mode, target: () => _randomTarget(_random), result: () => null, round: 0);
      case ChallengeMode.daily:
        _dailyTargets = dailyTargetsFor(_clock());
        state = state.copyWith(
          mode: mode,
          target: () => _dailyTargets.first,
          result: () => null,
          round: 0,
          dailyResults: const [],
          newDailyBest: false,
        );
    }
  }

  void lockIn(double level) => _finishRound(RoundResult(target: state.target!, level: level));

  void recordSpill(double level) => _finishRound(RoundResult(target: state.target!, level: level, spilled: true));

  void _finishRound(RoundResult r) {
    if (!state.isChallenge || state.target == null || state.result != null) return;
    final streak = r.tier.extendsStreak ? state.streak + 1 : 0;
    final best = math.max(streak, state.bestStreak);
    if (best > state.bestStreak) _save((p) => p.setInt(_bestStreakKey, best));

    var next = state.copyWith(result: () => r, streak: streak, bestStreak: best);
    if (state.mode == ChallengeMode.daily) {
      next = next.copyWith(dailyResults: [...state.dailyResults, r]);
      if (next.dailyFinished) {
        final total = next.dailyTotal;
        final isBest = state.dailyBest == null || total > state.dailyBest!;
        if (isBest) _save((p) => p.setInt(_dailyKey(_clock()), total));
        next = next.copyWith(newDailyBest: isBest, dailyBest: () => isBest ? total : state.dailyBest);
      }
    }
    state = next;
  }

  /// Starts the next round (cup already emptied by the caller). After the
  /// last Daily round, this replays today's Daily from the top.
  void nextRound() {
    switch (state.mode) {
      case ChallengeMode.free:
        return;
      case ChallengeMode.practice:
        state = state.copyWith(target: () => _randomTarget(_random), result: () => null, round: state.round + 1);
      case ChallengeMode.daily:
        if (state.dailyFinished) {
          setMode(ChallengeMode.daily);
          return;
        }
        final round = state.round + 1;
        state = state.copyWith(target: () => _dailyTargets[round], result: () => null, round: round);
    }
  }
}

final challengeProvider = StateNotifierProvider<ChallengeNotifier, ChallengeState>((ref) => ChallengeNotifier());
