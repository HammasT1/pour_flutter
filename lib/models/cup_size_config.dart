import 'package:flutter/foundation.dart';

import '../config/tunables.dart';

enum CupSize { small, medium, large }

@immutable
class CupSizeConfig {
  final CupSize size;
  final String label;

  /// Display scale factor applied to [kCupBaseDisplayHeight] / cup.png.
  final double scale;

  /// How much liquid this size holds, in the same "units" that
  /// [kPourVolumeUnits] is measured in (e.g. millilitres).
  final double capacityUnits;

  /// How many ice cubes fit in this size.
  final int maxIceCubes;

  const CupSizeConfig({
    required this.size,
    required this.label,
    required this.scale,
    required this.capacityUnits,
    required this.maxIceCubes,
  });

  double get displayHeight => kCupBaseDisplayHeight * scale;

  double get displayWidth => displayHeight * kCupAspectRatio;

  /// On-screen pixel height of the fillable region inside the cup art,
  /// at this size's current scale.
  double get fillableRegionHeightPx =>
      (CupFillGeometry.bottomY - CupFillGeometry.topY) * displayHeight;
}

const Map<CupSize, CupSizeConfig> kCupSizes = {
  CupSize.small: CupSizeConfig(
    size: CupSize.small,
    label: 'S',
    scale: 0.75,
    capacityUnits: 150,
    maxIceCubes: 2,
  ),
  CupSize.medium: CupSizeConfig(
    size: CupSize.medium,
    label: 'M',
    scale: 1.0,
    capacityUnits: 250,
    maxIceCubes: 3,
  ),
  CupSize.large: CupSizeConfig(
    size: CupSize.large,
    label: 'L',
    scale: 1.3,
    capacityUnits: 400,
    maxIceCubes: 4,
  ),
};
