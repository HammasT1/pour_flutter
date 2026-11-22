import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../config/tunables.dart';
import '../models/cup_size_config.dart';
import '../models/drink_model.dart';
import '../providers/pour_state_provider.dart';
import '../widgets/ambient_bubbles.dart';
import '../widgets/background_wash.dart';
import '../widgets/bottle_carousel.dart';
import '../widgets/bubble_particles.dart';
import '../widgets/carousel_dots.dart';
import '../widgets/cup_size_selector.dart';
import '../widgets/cup_with_liquid.dart';
import '../widgets/empty_cup_button.dart';
import '../widgets/fill_readout.dart';
import '../widgets/liquid_stream.dart';
import '../widgets/pour_nav_bar.dart';

class PourScreen extends ConsumerStatefulWidget {
  const PourScreen({super.key});

  @override
  ConsumerState<PourScreen> createState() => _PourScreenState();
}

class _PourScreenState extends ConsumerState<PourScreen> with TickerProviderStateMixin {
  late final PageController _pageController;

  /// Bottle tilt as a fraction of [kMaxTiltAngle] (0 = upright, 1 = fully
  /// tipped). Unbounded so `easeOutBack` can overshoot past 1 for a
  /// springy tip. Shared by tap pours and hold pours.
  late final AnimationController _tiltController;
  late final Animation<double> _tiltAnimation;

  bool _streamVisible = false;
  int _bubbleTrigger = 0;

  /// Result badge above the cup ("CUP FULL" / "PERFECT POUR").
  _PourBanner? _banner;
  int _bannerSerial = 0;

  // ---- Hold-to-pour state ----
  bool _holding = false;
  bool _holdActive = false; // true from hold start until the bottle is upright again
  Ticker? _holdTicker;
  Duration _lastHoldTick = Duration.zero;
  double _holdFlow = 0; // 0..1 eased flow ramp, drives stream width
  double _holdPoured = 0; // fraction poured during the current hold
  int _lastHapticMs = 0;
  int _lastBubbleMs = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.55);
    _tiltController = AnimationController.unbounded(vsync: this);
    _tiltAnimation = _tiltController.drive(Tween(begin: 0.0, end: kMaxTiltAngle));
  }

  @override
  void dispose() {
    _holdTicker?.dispose();
    _pageController.dispose();
    _tiltController.dispose();
    super.dispose();
  }

  bool get _canStartPour {
    final state = ref.read(pourStateProvider);
    return !state.isPouring && state.fillLevel < 0.999;
  }

  void _showBanner(_PourBanner banner) {
    final serial = ++_bannerSerial;
    setState(() => _banner = banner);
    Future.delayed(const Duration(milliseconds: 1700), () {
      if (mounted && serial == _bannerSerial) setState(() => _banner = null);
    });
  }

  /// Quick tap: one fixed-volume pour (the original interaction).
  Future<void> _handleTapPour() async {
    if (!_canStartPour) return;
    final notifier = ref.read(pourStateProvider.notifier);
    HapticFeedback.mediumImpact();
    notifier.startPour();
    setState(() => _bubbleTrigger++);

    await _tiltController.animateTo(1, duration: const Duration(milliseconds: 400), curve: Curves.easeOutBack);
    if (!mounted) return;

    notifier.applyPourFill();
    setState(() => _streamVisible = true);
    if (ref.read(pourStateProvider).fillLevel >= 0.999) {
      HapticFeedback.heavyImpact();
      _showBanner(_PourBanner.full);
    }

    await Future.delayed(const Duration(milliseconds: 230));
    if (!mounted) return;
    setState(() => _streamVisible = false);

    await _tiltController.animateTo(0, duration: const Duration(milliseconds: 270), curve: Curves.easeIn);
    if (!mounted) return;
    notifier.endPour();
  }

  /// Hold: tip the bottle, then pour continuously until release (or the
  /// cup tops out). The flow ramps up the longer the hold lasts.
  Future<void> _handleHoldStart() async {
    if (_holding || !_canStartPour) return;
    _holding = true;
    _holdPoured = 0;
    _holdFlow = 0;
    final notifier = ref.read(pourStateProvider.notifier);
    HapticFeedback.mediumImpact();
    notifier.startPour();
    setState(() {
      _holdActive = true;
      _bubbleTrigger++;
    });

    await _tiltController.animateTo(1, duration: kHoldTiltInDuration, curve: Curves.easeOutBack);
    // Released while the bottle was still tipping: _finishHold already
    // took over (and interrupting the tilt means this await may never
    // resume at all).
    if (!mounted || !_holding) return;

    setState(() => _streamVisible = true);
    _lastHoldTick = Duration.zero;
    _lastHapticMs = 0;
    _lastBubbleMs = 0;
    _holdTicker = createTicker(_onHoldTick)..start();
  }

  void _onHoldTick(Duration elapsed) {
    if (!_holding) return;
    final dt = (elapsed - _lastHoldTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastHoldTick = elapsed;

    final ms = elapsed.inMilliseconds;
    final ramp = (ms / kHoldFlowRampDuration.inMilliseconds).clamp(0.0, 1.0);
    final flow = Curves.easeIn.transform(ramp);
    final rate = kHoldFlowStartRate + (kHoldFlowMaxRate - kHoldFlowStartRate) * flow;

    final before = ref.read(pourStateProvider).fillLevel;
    final level = ref.read(pourStateProvider.notifier).addFillFraction(rate * dt);
    _holdPoured += level - before;

    // A light tick that speeds up with the flow, so the pour is felt.
    final hapticGap = (170 - 80 * flow).round();
    if (ms - _lastHapticMs >= hapticGap) {
      _lastHapticMs = ms;
      HapticFeedback.selectionClick();
    }
    final spawnBubbles = ms - _lastBubbleMs >= 380;
    if (spawnBubbles) _lastBubbleMs = ms;

    setState(() {
      _holdFlow = flow;
      if (spawnBubbles) _bubbleTrigger++;
    });

    if (level >= 0.999) _finishHold();
  }

  /// Ends a hold - on release, on cancel, or automatically when the cup
  /// tops out. Safe to call more than once per hold.
  Future<void> _finishHold() async {
    if (!_holding) return;
    _holding = false;
    _holdTicker?.dispose();
    _holdTicker = null;

    final level = ref.read(pourStateProvider).fillLevel;
    setState(() {
      _streamVisible = false;
      _holdFlow = 0;
    });

    if (_holdPoured > 0) {
      if (level >= 0.999) {
        HapticFeedback.heavyImpact();
        _showBanner(_PourBanner.full);
      } else if (level >= kPerfectPourMin && level <= kPerfectPourMax) {
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 90), HapticFeedback.mediumImpact);
        setState(() => _bubbleTrigger++);
        _showBanner(_PourBanner.perfect);
      }
    }

    await _tiltController.animateTo(0, duration: kHoldTiltOutDuration, curve: Curves.easeIn);
    if (!mounted) return;
    ref.read(pourStateProvider.notifier).endPour();
    setState(() => _holdActive = false);
  }

  void _handleEmptyCup() {
    final state = ref.read(pourStateProvider);
    if (state.isPouring || state.fillLevel <= 0.0) return;
    HapticFeedback.lightImpact();
    ref.read(pourStateProvider.notifier).emptyCup();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pourStateProvider);
    final drink = kDrinks[state.selectedDrinkIndex];
    final cupConfig = kCupSizes[state.selectedCupSize]!;

    // The stage always matches the *current* cup size (animated below) -
    // no space is reserved up front for a bigger size that isn't showing,
    // so the bottle, selector and cup stay visually close together.
    final stageHeight = cupConfig.displayHeight + kPourStreamAreaHeight;
    final rimFromStageBottom = cupConfig.displayHeight * (1 - CupFillGeometry.topY);
    final streamLength = kPourStreamAreaHeight - 8;

    // Full intensity while actively pouring; once the pour finishes the
    // wash settles to an ambient level rather than disappearing, for as
    // long as the cup still holds liquid. Only a genuinely empty cup
    // (fresh size, or never poured) drops it to zero.
    final fillDuration = _holdActive ? const Duration(milliseconds: 120) : const Duration(milliseconds: 900);

    final washIntensity = state.isPouring
        ? 1.0
        : (state.fillLevel > 0.001 ? kWashAmbientIntensity : 0.0);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D10),
      body: Stack(
        children: [
          Positioned.fill(
            child: BackgroundWash(intensity: washIntensity, color: drink.screenColor),
          ),
          Positioned.fill(
            child: AmbientBubbles(spawnTrigger: _bubbleTrigger, color: drink.screenColor),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: PourNavBar(drink: drink),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 230,
                    child: BottleCarousel(
                      controller: _pageController,
                      activeIndex: state.selectedDrinkIndex,
                      tiltAnimation: _tiltAnimation,
                      isPouring: state.isPouring,
                      onPageSettled: (index) {
                        HapticFeedback.selectionClick();
                        ref.read(pourStateProvider.notifier).selectDrink(index);
                      },
                      onTapActiveBottle: _handleTapPour,
                      onHoldActiveBottleStart: _handleHoldStart,
                      onHoldActiveBottleEnd: _finishHold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  CarouselDots(
                    count: kDrinks.length,
                    activeIndex: state.selectedDrinkIndex,
                    color: drink.screenColor,
                  ),
                  const SizedBox(height: 10),
                  const CupSizeSelector(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeOutBack,
                    height: stageHeight,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      clipBehavior: Clip.none,
                      children: [
                        // Grounding shadow, drawn first so it sits behind
                        // the cup.
                        Positioned(
                          bottom: -4,
                          child: Container(
                            width: cupConfig.displayWidth * 0.78,
                            height: 16,
                            decoration: const BoxDecoration(
                              borderRadius: BorderRadius.all(Radius.circular(40)),
                              gradient: RadialGradient(colors: [Color(0x66000000), Color(0x00000000)]),
                            ),
                          ),
                        ),
                        CupWithLiquid(
                          drink: drink,
                          cupConfig: cupConfig,
                          fillLevel: state.fillLevel,
                          fillDuration: fillDuration,
                          showPerfectZone: _holdActive,
                        ),
                        Positioned(
                          bottom: rimFromStageBottom - 4,
                          child: LiquidStream(
                            visible: _streamVisible,
                            height: streamLength,
                            color: drink.liquidColor,
                            highlightColor: drink.highlightColor,
                            width: _holdActive
                                ? kHoldStreamMinWidth + (kHoldStreamMaxWidth - kHoldStreamMinWidth) * _holdFlow
                                : kTapStreamWidth,
                          ),
                        ),
                        Positioned(
                          bottom: rimFromStageBottom - 8,
                          child: SizedBox(
                            width: 70,
                            height: 110,
                            child: BubbleField(
                              spawnTrigger: _bubbleTrigger,
                              color: drink.highlightColor,
                              originX: 35,
                              originY: 90,
                            ),
                          ),
                        ),
                        if (_banner != null)
                          Positioned(
                            top: 6,
                            child: IgnorePointer(
                              child: _PourBannerBadge(
                                key: ValueKey(_bannerSerial),
                                banner: _banner!,
                                color: drink.screenColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  FillReadout(
                    fillLevel: state.fillLevel,
                    capacityUnits: cupConfig.capacityUnits,
                    duration: fillDuration,
                  ),
                  const SizedBox(height: 6),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: state.fillLevel <= 0.001 && !state.isPouring ? 1 : 0,
                    child: const Text(
                      'TAP TO POUR  ·  HOLD FOR A PERFECT POUR',
                      style: TextStyle(
                        color: Colors.white30,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  EmptyCupButton(visible: state.fillLevel > 0.001 && !state.isPouring, onTap: _handleEmptyCup),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _PourBanner { full, perfect }

/// The pop-in badge above the cup. "PERFECT POUR" gets a white ring and
/// a shimmer sweep so it reads as a reward, not just a status.
class _PourBannerBadge extends StatelessWidget {
  final _PourBanner banner;
  final Color color;

  const _PourBannerBadge({super.key, required this.banner, required this.color});

  @override
  Widget build(BuildContext context) {
    final perfect = banner == _PourBanner.perfect;
    Widget badge = Container(
      padding: EdgeInsets.symmetric(horizontal: perfect ? 18 : 16, vertical: perfect ? 7 : 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: perfect ? Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.4) : null,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: perfect ? 24 : 16, spreadRadius: 1)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (perfect) ...[const Icon(Icons.auto_awesome, size: 14, color: Colors.white), const SizedBox(width: 6)],
          Text(
            perfect ? 'PERFECT POUR' : 'CUP FULL',
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5),
          ),
        ],
      ),
    );

    var animated = badge
        .animate()
        .scale(begin: const Offset(0.6, 0.6), end: const Offset(1, 1), duration: 320.ms, curve: Curves.easeOutBack)
        .fadeIn(duration: 180.ms);
    if (perfect) {
      animated = animated.shimmer(delay: 260.ms, duration: 900.ms, color: Colors.white.withValues(alpha: 0.7));
    }
    return animated;
  }
}
