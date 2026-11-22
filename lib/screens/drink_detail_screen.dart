import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/drink_model.dart';
import '../widgets/drink_badge.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/safe_asset_image.dart';

/// Showcase for one drink, opened from the nav bar badge. The bottle and
/// name badge are Heroes that fly in from the pour screen. Arrows (or a
/// horizontal swipe) move between drinks along a shared X axis, and
/// "Pour this" selects the shown drink and flies it back to the carousel.
class DrinkDetailScreen extends StatefulWidget {
  final int initialIndex;

  /// Called with the shown drink's index right before popping via
  /// "Pour this", so the carousel is already on it when the Hero lands.
  final ValueChanged<int> onPour;

  const DrinkDetailScreen({super.key, required this.initialIndex, required this.onPour});

  @override
  State<DrinkDetailScreen> createState() => _DrinkDetailScreenState();
}

class _DrinkDetailScreenState extends State<DrinkDetailScreen> {
  late int _index = widget.initialIndex;
  bool _reverse = false;

  DrinkModel get _drink => kDrinks[_index];

  void _go(int delta) {
    final next = (_index + delta) % kDrinks.length;
    HapticFeedback.selectionClick();
    setState(() {
      _reverse = delta < 0;
      _index = next < 0 ? next + kDrinks.length : next;
    });
  }

  void _pour() {
    HapticFeedback.mediumImpact();
    widget.onPour(_index);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final drink = _drink;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D10),
      body: Stack(
        children: [
          // Brand-color glow behind the bottle, cross-fading per drink.
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 450),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.25),
                  radius: 0.95,
                  colors: [drink.screenColor.withValues(alpha: 0.55), const Color(0x000B0D10)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
                  child: Row(
                    children: [
                      _RoundButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back',
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      Text(
                        '${_index + 1} / ${kDrinks.length}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragEnd: (d) {
                      final v = d.primaryVelocity ?? 0;
                      if (v.abs() > 250) _go(v < 0 ? 1 : -1);
                    },
                    child: PageTransitionSwitcher(
                      reverse: _reverse,
                      duration: const Duration(milliseconds: 420),
                      transitionBuilder: (child, primary, secondary) => SharedAxisTransition(
                        animation: primary,
                        secondaryAnimation: secondary,
                        transitionType: SharedAxisTransitionType.horizontal,
                        fillColor: Colors.transparent,
                        // Only the incoming page takes part in Hero flights,
                        // so a quick back-and-forth can't leave two Heroes
                        // with the same tag on screen.
                        child: AnimatedBuilder(
                          animation: secondary,
                          builder: (context, c) =>
                              HeroMode(enabled: secondary.status == AnimationStatus.dismissed, child: c!),
                          child: child,
                        ),
                      ),
                      child: _DrinkShowcase(key: ValueKey(drink.id), drink: drink),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                  child: Row(
                    children: [
                      _RoundButton(icon: Icons.chevron_left_rounded, tooltip: 'Previous drink', onTap: () => _go(-1)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PressableScale(
                          onTap: _pour,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 320),
                            height: 50,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: drink.screenColor,
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                              boxShadow: [BoxShadow(color: drink.screenColor.withValues(alpha: 0.5), blurRadius: 18)],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.local_drink_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'POUR THIS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _RoundButton(icon: Icons.chevron_right_rounded, tooltip: 'Next drink', onTap: () => _go(1)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrinkShowcase extends StatelessWidget {
  final DrinkModel drink;

  const _DrinkShowcase({super.key, required this.drink});

  @override
  Widget build(BuildContext context) {
    // Content after the Heroes eases in on a short stagger, once the
    // bottle has (mostly) landed.
    Widget stagger(Widget w, int i) => w
        .animate()
        .fadeIn(delay: (220 + i * 70).ms, duration: 300.ms)
        .slideY(begin: 0.15, end: 0, delay: (220 + i * 70).ms, duration: 300.ms, curve: Curves.easeOutCubic);

    return LayoutBuilder(
      builder: (context, c) {
        final bottleH = (c.maxHeight * 0.52).clamp(160.0, 340.0);
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: bottleH,
                  child: Hero(
                    tag: drink.bottleHeroTag,
                    child: SafeAssetImage(
                      assetPath: drink.assetPath,
                      fallbackIcon: Icons.local_drink_outlined,
                      fallbackLabel: drink.name,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Hero(
                  tag: drink.badgeHeroTag,
                  flightShuttleBuilder: DrinkBadge.flightShuttle,
                  child: DrinkBadge(drink: drink, scale: 2.0),
                ),
                const SizedBox(height: 22),
                stagger(_FizzMeter(drink: drink), 0),
                const SizedBox(height: 16),
                stagger(
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Swatch(label: 'Liquid', color: drink.liquidColor),
                      _Swatch(label: 'Foam', color: drink.foamColor),
                      _Swatch(label: 'Brand', color: drink.screenColor),
                    ],
                  ),
                  1,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FizzMeter extends StatelessWidget {
  final DrinkModel drink;

  const _FizzMeter({required this.drink});

  @override
  Widget build(BuildContext context) {
    final pct = (drink.fizziness * 100).round();
    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'FIZZ',
                style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4),
              ),
              const Spacer(),
              Text(
                '$pct%',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(height: 8, color: Colors.white.withValues(alpha: 0.1)),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: drink.fizziness),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => FractionallySizedBox(
                    widthFactor: v,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [drink.highlightColor, drink.screenColor]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final String label;
  final Color color;

  const _Swatch({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 10)],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.1),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _RoundButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: PressableScale(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
