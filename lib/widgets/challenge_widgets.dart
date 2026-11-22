import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../config/tunables.dart';
import '../providers/challenge_provider.dart';
import 'pressable_scale.dart';

/// Free / Practice / Daily segmented switch under the nav bar.
class ModeSwitcher extends StatelessWidget {
  final ChallengeMode mode;
  final bool enabled;
  final Color accent;
  final ValueChanged<ChallengeMode> onChanged;

  const ModeSwitcher({
    super.key,
    required this.mode,
    required this.enabled,
    required this.accent,
    required this.onChanged,
  });

  static const _labels = {ChallengeMode.free: 'Free', ChallengeMode.practice: 'Practice', ChallengeMode.daily: 'Daily'};
  static const _icons = {
    ChallengeMode.free: Icons.water_drop_outlined,
    ChallengeMode.practice: Icons.track_changes_rounded,
    ChallengeMode.daily: Icons.calendar_today_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.5,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: ChallengeMode.values.map((m) {
            final selected = m == mode;
            return PressableScale(
              pressedScale: 0.95,
              onTap: enabled && !selected ? () => onChanged(m) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? accent.withValues(alpha: 0.9) : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: selected ? [BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 10)] : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_icons[m], size: 13, color: selected ? Colors.white : Colors.white60),
                    const SizedBox(width: 5),
                    Text(
                      _labels[m]!,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Dashed target line across the cup at [level] (0..1 of the fillable
/// height), with a "72%" tag hanging off the right wall. Drawn over the
/// cup's whole bounding box (same space as [CupFillGeometry]); slides to
/// each new target.
class TargetLine extends StatelessWidget {
  final double? level;
  final Color color;

  const TargetLine({super.key, required this.level, required this.color});

  @override
  Widget build(BuildContext context) {
    final visible = level != null;
    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: visible ? 1 : 0,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: level ?? 0.5),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutBack,
          builder: (context, l, _) => LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final h = c.maxHeight;
              final regionTop = CupFillGeometry.topY * h;
              final regionBottom = CupFillGeometry.bottomY * h;
              final y = regionBottom - l.clamp(0.0, 1.0) * (regionBottom - regionTop);
              final inset =
                  CupFillGeometry.bottomInset + (CupFillGeometry.topInset - CupFillGeometry.bottomInset) * l;
              final rightWall = w * (1 - inset);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _DashedLinePainter(y: y, inset: inset, color: color)),
                  ),
                  Positioned(
                    left: rightWall + 6,
                    top: y - 9,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)],
                      ),
                      child: Text(
                        '${((level ?? l) * 100).round()}%',
                        style: const TextStyle(
                          color: Color(0xFF0B0D10),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final double y;
  final double inset;
  final Color color;

  _DashedLinePainter({required this.y, required this.inset, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final left = size.width * inset - 4;
    final right = size.width * (1 - inset) + 4;
    final glow = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..strokeWidth = 5;
    canvas.drawLine(Offset(left, y), Offset(right, y), glow);
    final dash = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var x = left; x < right; x += 9) {
      canvas.drawLine(Offset(x, y), Offset((x + 5).clamp(left, right), y), dash);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter old) => old.y != y || old.inset != inset || old.color != color;
}

/// Round prompt shown under the cup while a round is in progress.
class ChallengeHud extends StatelessWidget {
  final ChallengeState state;

  const ChallengeHud({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final target = ((state.target ?? 0) * 100).round();
    final prefix = state.mode == ChallengeMode.daily ? 'ROUND ${state.round + 1}/$kDailyRounds  ·  ' : '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${prefix}FILL TO THE LINE: $target%',
          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.3),
        ),
        const SizedBox(height: 4),
        _StreakLine(streak: state.streak, best: state.bestStreak),
      ],
    );
  }
}

class _StreakLine extends StatelessWidget {
  final int streak;
  final int best;

  const _StreakLine({required this.streak, required this.best});

  @override
  Widget build(BuildContext context) {
    return Text(
      streak > 0 ? '🔥 $streak streak  ·  best $best' : 'GREAT or better builds a streak  ·  best $best',
      style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.6),
    );
  }
}

/// Result of the round just locked in: tier, points, and how far off.
class RoundResultCard extends StatelessWidget {
  final RoundResult result;
  final int streak;
  final int bestStreak;

  const RoundResultCard({super.key, required this.result, required this.streak, required this.bestStreak});

  @override
  Widget build(BuildContext context) {
    final tier = result.tier;
    final you = (result.level * 100).round();
    final target = (result.target * 100).round();
    final detail = result.spilled ? 'Over the rim - target was $target%' : 'You $you%  ·  Target $target%';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              tier.label,
              style: TextStyle(
                color: tier.color,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                shadows: [Shadow(color: tier.color.withValues(alpha: 0.6), blurRadius: 14)],
              ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '+${result.points}',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(detail, style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        _StreakLine(streak: streak, best: bestStreak),
      ],
    ).animate().scale(begin: const Offset(0.7, 0.7), duration: 300.ms, curve: Curves.easeOutBack).fadeIn(duration: 160.ms);
  }
}

/// End-of-Daily summary: total, a dot per round in its tier color, and
/// today's best.
class DailySummaryCard extends StatelessWidget {
  final ChallengeState state;

  const DailySummaryCard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'DAILY COMPLETE',
            style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.6),
          ),
          const SizedBox(height: 4),
          Text(
            '${state.dailyTotal} / ${kDailyRounds * 100}',
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final r in state.dailyResults)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: r.tier.color, shape: BoxShape.circle),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            state.newDailyBest ? '★ New best today!' : 'Best today: ${state.dailyBest ?? state.dailyTotal}',
            style: TextStyle(
              color: state.newDailyBest ? const Color(0xFFFFD54F) : Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ).animate().scale(begin: const Offset(0.85, 0.85), duration: 320.ms, curve: Curves.easeOutBack).fadeIn();
  }
}

/// Primary pill for LOCK IN / NEXT ROUND / PLAY AGAIN.
class ChallengeActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool visible;
  final Color accent;
  final VoidCallback onTap;

  const ChallengeActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.visible,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 220),
      child: IgnorePointer(
        ignoring: !visible,
        child: PressableScale(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
              boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 14)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
