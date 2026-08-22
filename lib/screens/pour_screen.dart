import 'package:flutter/material.dart';
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
  late final AnimationController _tiltController;
  late final Animation<double> _tiltAnimation;

  bool _streamVisible = false;
  bool _showFullBanner = false;
  int _bubbleTrigger = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.55);
    _tiltController = AnimationController(vsync: this, duration: kTiltDuration);
    _tiltAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: kMaxTiltAngle).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem(tween: ConstantTween(kMaxTiltAngle), weight: 25),
      TweenSequenceItem(
        tween: Tween(begin: kMaxTiltAngle, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_tiltController);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tiltController.dispose();
    super.dispose();
  }

  Future<void> _handlePour() async {
    final state = ref.read(pourStateProvider);
    if (state.isPouring || state.fillLevel >= 0.999) return;

    final notifier = ref.read(pourStateProvider.notifier);
    HapticFeedback.mediumImpact();
    notifier.startPour();
    setState(() => _bubbleTrigger++);

    var streamStarted = false;
    var streamEnded = false;
    void listener() {
      final v = _tiltController.value;
      if (!streamStarted && v > 0.32) {
        streamStarted = true;
        notifier.applyPourFill();
        final justFilled = ref.read(pourStateProvider).fillLevel >= 0.999;
        if (mounted) {
          setState(() {
            _streamVisible = true;
            if (justFilled) _showFullBanner = true;
          });
        }
        if (justFilled) {
          HapticFeedback.heavyImpact();
          Future.delayed(const Duration(milliseconds: 1700), () {
            if (mounted) setState(() => _showFullBanner = false);
          });
        }
      }
      if (streamStarted && !streamEnded && v > 0.72) {
        streamEnded = true;
        if (mounted) setState(() => _streamVisible = false);
      }
    }

    _tiltController.addListener(listener);
    await _tiltController.forward(from: 0);
    _tiltController.removeListener(listener);

    notifier.endPour();
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
                      onTapActiveBottle: _handlePour,
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
                        CupWithLiquid(drink: drink, cupConfig: cupConfig, fillLevel: state.fillLevel),
                        Positioned(
                          bottom: rimFromStageBottom - 4,
                          child: LiquidStream(
                            visible: _streamVisible,
                            height: streamLength,
                            color: drink.liquidColor,
                            highlightColor: drink.highlightColor,
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
                        if (_showFullBanner)
                          Positioned(
                            top: 6,
                            child: IgnorePointer(
                              child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: drink.screenColor,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: drink.screenColor.withValues(alpha: 0.6),
                                          blurRadius: 16,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: const Text(
                                      'CUP FULL',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  )
                                  .animate()
                                  .scale(
                                    begin: const Offset(0.6, 0.6),
                                    end: const Offset(1, 1),
                                    duration: 320.ms,
                                    curve: Curves.easeOutBack,
                                  )
                                  .fadeIn(duration: 180.ms),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  FillReadout(fillLevel: state.fillLevel, capacityUnits: cupConfig.capacityUnits),
                  const SizedBox(height: 10),
                  EmptyCupButton(
                    visible: state.fillLevel > 0.001 && !state.isPouring,
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
