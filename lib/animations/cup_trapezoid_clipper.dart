import 'package:flutter/widgets.dart';

import '../config/tunables.dart';

/// Clips liquid content to the tapered trapezoid shape of the fillable
/// region inside the cup art, using the fractional geometry constants in
/// [CupFillGeometry]. Re-tune those constants (not this file) once the
/// real cup.png is in place.
class CupTrapezoidClipper extends CustomClipper<Path> {
  const CupTrapezoidClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;

    final topY = CupFillGeometry.topY * h;
    final bottomY = CupFillGeometry.bottomY * h;
    final topLeft = CupFillGeometry.topInset * w;
    final topRight = w - topLeft;
    final bottomLeft = CupFillGeometry.bottomInset * w;
    final bottomRight = w - bottomLeft;

    return Path()
      ..moveTo(topLeft, topY)
      ..lineTo(topRight, topY)
      ..lineTo(bottomRight, bottomY)
      ..lineTo(bottomLeft, bottomY)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
