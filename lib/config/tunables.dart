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
const Duration kTiltDuration = Duration(milliseconds: 900);

/// Liquid poured per tap, in the same "units" as
/// CupSizeConfig.capacityUnits. Kept roughly constant per tap so a bigger
/// cup visibly needs more pours to fill.
const double kPourVolumeUnits = 90.0;

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
