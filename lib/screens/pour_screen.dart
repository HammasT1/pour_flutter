import 'dart:math' as math;

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
import '../widgets/cup_extras_bar.dart';
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

  /// Result badge above the cup ("CUP FULL" / "PERFECT POUR" / "OVERFLOW").
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

  // ---- Foam & overflow ----
  /// Runs only while there is foam to simulate (pending, growing or
  /// settling), then stops itself.
  Ticker? _foamTicker;
  Duration _lastFoamTick = Duration.zero;
  double _pendingFoam = 0; // tap-pour foam still to form
  double _pendingFoamDelay = 0; // seconds before pending foam starts forming
  bool _spilledThisPour = false;
  bool _spillCooling = false; // one spill per animation, even if foam keeps pushing
  int _spillTrigger = 0;

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
    _foamTicker?.dispose();
    _pageController.dispose();
    _tiltController.dispose();
    super.dispose();
  }

  bool get _canStartPour {
    final state = ref.read(pourStateProvider);
    return !state.isPouring && state.effectiveLevel < 0.999;
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
    _spilledThisPour = false;
    HapticFeedback.mediumImpact();
    notifier.startPour();
    setState(() => _bubbleTrigger++);

    await _tiltController.animateTo(1, duration: const Duration(milliseconds: 400), curve: Curves.easeOutBack);
    if (!mounted) return;

    notifier.applyPourFill();
    setState(() => _streamVisible = true);

    // The splash foams up a moment after it lands.
    final burst = _activeDrink.fizziness * kTapFoamBurst;
    _pendingFoam += burst;
    _pendingFoamDelay = kTapFoamDelay.inMicroseconds / Duration.microsecondsPerSecond;
    _ensureFoamTicker();

    final after = ref.read(pourStateProvider);
    final willOverflow = after.effectiveLevel + after.foamLevel + _pendingFoam > 1.0 + kSpillTolerance;
    if (after.effectiveLevel >= 0.999 && !willOverflow) {
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
    _spilledThisPour = false;
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

    final notifier = ref.read(pourStateProvider.notifier);
    final before = ref.read(pourStateProvider).fillLevel;
    final level = notifier.addFillFraction(rate * dt);
    _holdPoured += level - before;

    // Pouring hard foams disproportionately more than pouring gently.
    final foamGen = _activeDrink.fizziness * kFoamGenRate * rate * rate * dt;
    notifier.setFoam(ref.read(pourStateProvider).foamLevel + foamGen);
    _ensureFoamTicker();

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

    if (_holding && ref.read(pourStateProvider).effectiveLevel >= 0.999) _finishHold();
  }

  DrinkModel get _activeDrink => kDrinks[ref.read(pourStateProvider).selectedDrinkIndex];

  void _ensureFoamTicker() {
    if (_foamTicker?.isActive ?? false) return;
    _foamTicker?.dispose();
    _lastFoamTick = Duration.zero;
    _foamTicker = createTicker(_onFoamTick)..start();
  }

  void _stopFoamTicker() {
    _foamTicker?.dispose();
    _foamTicker = null;
  }

  /// One foam step: form pending tap foam, settle, and check whether
  /// liquid + foam has gone over the rim.
  void _onFoamTick(Duration elapsed) {
    final dt = (elapsed - _lastFoamTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastFoamTick = elapsed;

    final state = ref.read(pourStateProvider);
    var foam = state.foamLevel;

    if (_pendingFoamDelay > 0) {
      _pendingFoamDelay -= dt;
    } else if (_pendingFoam > 0) {
      final formed = math.min(_pendingFoam, kTapFoamFormRate * dt);
      _pendingFoam -= formed;
      foam += formed;
    }

    foam -= foam * kFoamSettleRate * dt;

    final room = (1.0 - state.effectiveLevel).clamp(0.0, 1.0);
    if (foam > room + kSpillTolerance) {
      foam = room;
      _triggerSpill();
    }

    final notifier = ref.read(pourStateProvider.notifier);
    if (foam < 0.0005 && _pendingFoam <= 0 && !_holding) {
      notifier.setFoam(0);
      _stopFoamTicker();
      return;
    }
    notifier.setFoam(foam);
  }

  /// Foam went over the rim: play the spill, a "whoa" haptic, and end any
  /// hold in progress (a spilled pour can't be a perfect one).
  void _triggerSpill() {
    if (_spillCooling) return;
    _spillCooling = true;
    _spilledThisPour = true;
    _pendingFoam = 0;
    Future.delayed(kSpillDuration, () => _spillCooling = false);

    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 90), HapticFeedback.mediumImpact);
    Future.delayed(const Duration(milliseconds: 180), HapticFeedback.lightImpact);

    setState(() => _spillTrigger++);
    _showBanner(_PourBanner.overflow);
    if (_holding) _finishHold();
  }

  /// Ends a hold - on release, on cancel, or automatically when the cup
  /// tops out. Safe to call more than once per hold.
  Future<void> _finishHold() async {
    if (!_holding) return;
    _holding = false;
    _holdTicker?.dispose();
    _holdTicker = null;

    final level = ref.read(pourStateProvider).effectiveLevel;
    setState(() {
      _streamVisible = false;
      _holdFlow = 0;
    });

    if (_holdPoured > 0 && !_spilledThisPour) {
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
    if (state.isPouring || (state.fillLevel <= 0.0 && state.iceCubes == 0)) return;
    HapticFeedback.lightImpact();
    _pendingFoam = 0;
    ref.read(pourStateProvider.notifier).emptyCup();
  }

  /// Drops a cube in. It lands ~a third of the way through its fall:
  /// that's when it splashes (bubbles + haptic), kicks up a little foam
  /// in a fizzy drink, and - if the cup was already brim-full - spills.
  void _handleAddIce() {
    final notifier = ref.read(pourStateProvider.notifier);
    final before = ref.read(pourStateProvider).iceCubes;
    final spilled = notifier.addIce();
    if (ref.read(pourStateProvider).iceCubes == before) return;
    HapticFeedback.selectionClick();

    final landMs = (kIceDropDuration.inMilliseconds * kIceFirstContact).round();
    Future.delayed(Duration(milliseconds: landMs), () {
      if (!mounted) return;
      final s = ref.read(pourStateProvider);
      if (s.fillLevel <= 0.001) {
        HapticFeedback.lightImpact();
        return;
      }
      HapticFeedback.mediumImpact();
      setState(() => _bubbleTrigger++);
      if (spilled) {
        _triggerSpill();
      } else {
        _pendingFoam += _activeDrink.fizziness * kTapFoamBurst * 0.5;
        _pendingFoamDelay = 0;
        _ensureFoamTicker();
      }
    });
  }

  void _handleToggleStraw() {
    HapticFeedback.selectionClick();
    ref.read(pourStateProvider.notifier).toggleStraw();
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

    final fillDuration = _holdActive ? const Duration(milliseconds: 120) : const Duration(milliseconds: 900);

    // Full intensity while actively pouring; once the pour finishes the
    // wash settles to an ambient level rather than disappearing, for as
    // long as the cup still holds liquid. Only a genuinely empty cup
    // (fresh size, or never poured) drops it to zero.
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
                          fillLevel: state.effectiveLevel,
                          fillDuration: fillDuration,
                          showPerfectZone: _holdActive,
                          foamLevel: state.foamLevel,
                          spillTrigger: _spillTrigger,
                          iceCubes: state.iceCubes,
                          hasStraw: state.hasStraw,
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
                  CupExtrasBar(
                    iceCubes: state.iceCubes,
                    maxIceCubes: cupConfig.maxIceCubes,
                    hasStraw: state.hasStraw,
                    enabled: !state.isPouring,
                    accent: drink.screenColor,
                    onAddIce: _handleAddIce,
                    onToggleStraw: _handleToggleStraw,
                  ),
                  const SizedBox(height: 10),
                  EmptyCupButton(
                    visible: (state.fillLevel > 0.001 || state.iceCubes > 0) && !state.isPouring,
                    onTap: _handleEmptyCup,
                  ),
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

enum _PourBanner { full, perfect, overflow }

/// The pop-in badge above the cup. "PERFECT POUR" gets a white ring and
/// a shimmer sweep so it reads as a reward, not just a status;
/// "OVERFLOW!" gets a quick shake.
class _PourBannerBadge extends StatelessWidget {
  final _PourBanner banner;
  final Color color;

  const _PourBannerBadge({super.key, required this.banner, required this.color});

  @override
  Widget build(BuildContext context) {
    final perfect = banner == _PourBanner.perfect;
    final overflow = banner == _PourBanner.overflow;
    final label = switch (banner) {
      _PourBanner.perfect => 'PERFECT POUR',
      _PourBanner.overflow => 'OVERFLOW!',
      _PourBanner.full => 'CUP FULL',
    };
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
          if (perfect || overflow) ...[
            Icon(perfect ? Icons.auto_awesome : Icons.water_drop, size: 14, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Text(
            label,
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
    } else if (overflow) {
      animated = animated.shakeX(delay: 120.ms, duration: 420.ms, hz: 5, amount: 4);
    }
    return animated;
  }
}
