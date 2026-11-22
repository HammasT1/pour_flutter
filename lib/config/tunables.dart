/// ---------------------------------------------------------------------
/// TUNABLE CONSTANTS
///
/// Everything in this file describes geometry or timing that depends on
/// the visual shape of the provided art (cup.png, bottle PNGs). They are
/// grouped here so they can be re-tuned in one place once real assets are
/// dropped in, without hunting through widget code.
/// ---------------------------------------------------------------------
library;

/// Path to the single shared cup asset used for all three CupSizes.
const String kCupAssetPath = 'assets/cup/cup.png';

/// Width / height ratio used to size the cup's bounding box on screen.
/// MUST match the real cup.png's own width/height ratio (not just the
/// cup's silhouette) - the box is what `BoxFit.contain` fits the image
/// into, so any mismatch here letterboxes the image inside the box and
/// throws off every fractional measurement below. The current cup.png is
/// a plain 800x800 square canvas, hence 1.0. If you swap in art with a
/// different canvas size, update this to that image's width/height.
const double kCupAspectRatio = 1.0;

/// Base (Medium, scale 1.0) on-screen height in logical pixels of the
/// cup's bounding box. Small / Large are derived from this via their
/// `scale` factor in [CupSizeConfig].
const double kCupBaseDisplayHeight = 230.0;

/// Fractional geometry (0.0-1.0) of the *fillable* liquid region relative
/// to the cup image's own bounding box - i.e. where the glass walls
/// actually sit inside the PNG's transparent canvas.
///
/// Measured directly off the current cup.png's alpha channel: the cup's
/// opaque pixels span roughly y=[0.07, 0.89] and taper from ~60% of the
/// canvas width at the rim opening down to a narrow foot at the base. If
/// you swap in new art, re-measure (e.g. find the alpha bounding box, and
/// the left/right opaque bounds at a couple of chosen top/bottom rows)
/// rather than guessing - a few percent of error here is what makes
/// liquid spill outside the glass walls.
///
/// - [topY] / [bottomY]: where the liquid surface starts/stops vertically
///   - just inside the rim opening, and well above the base foot (not at
///   the very bottom of the opaque bbox, which narrows to a sliver).
/// - [topInset] / [bottomInset]: how far the glass walls sit from the
///   left/right edges of the bounding box at [topY] and [bottomY].
class CupFillGeometry {
  const CupFillGeometry._();

  static const double topY = 0.13;
  static const double bottomY = 0.83;
  static const double topInset = 0.20;
  static const double bottomInset = 0.30;
}

/// Vertical space (logical px) reserved above the cup, at the current cup
/// size, for the pour stream to fall through.
const double kPourStreamAreaHeight = 64.0;

/// Bottle tilt-to-pour tuning. Positive angle = clockwise rotation, which
/// (combined with the pivot alignment in BottleCarousel) swings the
/// bottle's mouth down and toward the cup.
const double kMaxTiltAngle = 0.88; // radians

/// Liquid poured per tap, in the same "units" as
/// CupSizeConfig.capacityUnits. Kept roughly constant per tap so a bigger
/// cup visibly needs more pours to fill.
const double kPourVolumeUnits = 90.0;

/// How long the active bottle must be held before a tap turns into a
/// continuous hold-to-pour. Short enough to feel instant, long enough
/// that a quick tap (and a horizontal carousel drag) still wins.
const Duration kHoldToPourDelay = Duration(milliseconds: 180);

/// Time for the bottle to tip into pouring position at the start of a
/// hold, and to return upright after release.
const Duration kHoldTiltInDuration = Duration(milliseconds: 320);
const Duration kHoldTiltOutDuration = Duration(milliseconds: 300);

/// Hold-to-pour flow rate, as a fraction of the *current* cup's capacity
/// per second. Expressed relative to capacity (not in ml) so the
/// perfect-pour window is equally fair on every cup size. The flow eases
/// from [kHoldFlowStartRate] up to [kHoldFlowMaxRate] over
/// [kHoldFlowRampDuration] - the longer you hold, the harder it pours.
const double kHoldFlowStartRate = 0.20;
const double kHoldFlowMaxRate = 0.48;
const Duration kHoldFlowRampDuration = Duration(milliseconds: 1600);

/// Pour stream width (logical px) at the start of a hold and at full
/// flow. A tap pour uses [kTapStreamWidth].
const double kHoldStreamMinWidth = 5.0;
const double kHoldStreamMaxWidth = 12.0;
const double kTapStreamWidth = 7.0;

/// Releasing a hold-pour with the cup between these fill levels (0..1)
/// counts as a "perfect pour". The cup actually topping out (>= 0.999)
/// is a full cup, not a perfect one.
const double kPerfectPourMin = 0.90;
const double kPerfectPourMax = 0.99;

/// Background wash opacity (0..1) while the cup holds liquid but isn't
/// actively being poured into - the wash ramps up to full intensity
/// during the pour animation itself, then settles here rather than
/// fading back to neutral, so the screen keeps the drink's color for as
/// long as there's something in the cup.
const double kWashAmbientIntensity = 0.6;

/// Opacity applied to the cup art itself, so it reads as a slightly
/// translucent plastic cup rather than a flat opaque white shape - lets
/// the background wash and the liquid underneath show through a bit.
const double kCupOpacity = 0.62;

/// ---- Foam & overflow ----
///
/// Foam is tracked as a fraction of the cup's fillable height, sitting on
/// top of the liquid. Liquid + foam past the rim is an overflow.

/// Upper bound on the foam head, so it never swallows the whole cup.
const double kFoamMax = 0.25;

/// Foam generated per second while hold-pouring is
/// `fizziness * kFoamGenRate * flowRate^2` - squared so pouring hard
/// foams disproportionately more than pouring gently.
const double kFoamGenRate = 0.40;

/// Exponential settle rate (per second): the foam head shrinks by this
/// fraction of itself each second, so it collapses quickly at first and
/// then lingers as a thin head.
const double kFoamSettleRate = 1.1;

/// A tap pour lands as one splash, so its foam is added as a burst
/// ([kTapFoamBurst] x fizziness) that starts forming after
/// [kTapFoamDelay] (when the liquid has visually arrived) at
/// [kTapFoamFormRate] per second.
const double kTapFoamBurst = 0.12;
const Duration kTapFoamDelay = Duration(milliseconds: 350);
const double kTapFoamFormRate = 0.5;

/// How far liquid + foam may poke past the rim before it counts as a
/// spill (absorbs float noise right at the brim).
const double kSpillTolerance = 0.004;

/// Length of the spill animation (foam cap, drips, puddle).
const Duration kSpillDuration = Duration(milliseconds: 1600);

/// ---- Ice & straw ----

/// Ice cube side length as a fraction of the cup's bounding-box width
/// (the cup scales uniformly, so cubes stay proportional at every size).
const double kIceCubeSize = 0.17;

/// Cube height as a fraction of the fillable region's height - derived
/// from [kIceCubeSize] and the fill geometry for the square cup canvas.
const double kIceCubeHeightFraction = kIceCubeSize * kCupAspectRatio / (CupFillGeometry.bottomY - CupFillGeometry.topY);

/// Ice floats with this fraction of its height under the surface.
const double kIceSubmergedFraction = 0.88;

/// Liquid displaced by one fully floating cube, as a fraction of the
/// cup's capacity. Less liquid fits in a cup full of ice, and the
/// liquid line rises as each cube goes in.
const double kIceDisplacement = 0.045;

/// Fall + bounce animation for a cube dropped into the cup, and when in
/// that animation it first hits (bottom or surface) - used to time the
/// splash haptic and bubbles.
const Duration kIceDropDuration = Duration(milliseconds: 750);
const double kIceFirstContact = 0.36;

/// Horizontal shift (fraction of cup width) applied to the submerged
/// part of the straw - the "bent straw" refraction break at the surface.
const double kStrawRefractionShift = 0.045;
