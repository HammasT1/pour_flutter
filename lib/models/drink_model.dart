import 'package:flutter/material.dart';

class DrinkModel {
  final String id;
  final String name;
  final String assetPath;

  /// Color of the liquid itself - drives the cup fill, foam strip, pour
  /// stream, and the rim bubbles. Should match the real drink's color.
  final Color liquidColor;

  /// Highlight/foam color used alongside [liquidColor] for the liquid's
  /// surface sheen.
  final Color highlightColor;

  /// Brand color used for the full-screen wash + ambient bubbles. Usually
  /// the same as [liquidColor], but some brands (Pepsi) are visually
  /// associated with a color that isn't the drink's own color - the can
  /// is blue, the cola itself is near-black - so this is kept separate.
  final Color screenColor;

  /// 0..1 - how readily the drink foams. Scales foam generated while
  /// pouring (see `kFoamGenRate` / `kTapFoamBurst` in tunables.dart).
  final double fizziness;

  const DrinkModel({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.liquidColor,
    required this.highlightColor,
    required this.screenColor,
    required this.fizziness,
  });

  /// Foam head color: the drink's highlight washed toward white, so cola
  /// gets a tan head and the orange/green/grape drinks a pale tinted one.
  /// Hero tags shared by the carousel / nav bar and the drink showcase,
  /// so the bottle and name badge fly between the two screens.
  String get bottleHeroTag => 'bottle-$id';
  String get badgeHeroTag => 'badge-$id';

  Color get foamColor => Color.lerp(highlightColor, const Color(0xFFFFFFFF), 0.62)!;
}

/// The full drink lineup. Adding a 5th drink is a one-line addition here -
/// no other file needs to change.
const List<DrinkModel> kDrinks = [
  DrinkModel(
    id: 'fanta_orange',
    name: 'Fanta Orange',
    assetPath: 'assets/bottles/fanta.png',
    liquidColor: Color(0xFFFF7A1A),
    highlightColor: Color(0xFFFFB25C),
    screenColor: Color(0xFFFF7A1A),
    fizziness: 0.8,
  ),
  DrinkModel(
    id: 'pepsi',
    name: 'Pepsi',
    assetPath: 'assets/bottles/pepsi.png',
    // Real cola is a near-black brown, not the can's blue.
    liquidColor: Color(0xFF201007),
    highlightColor: Color(0xFF6B3A16),
    // ...but the screen wash keeps the iconic Pepsi blue from the can.
    screenColor: Color(0xFF0B3D91),
    // Cola foams the most.
    fizziness: 0.9,
  ),
  DrinkModel(
    id: 'mountain_dew',
    name: 'Mountain Dew',
    assetPath: 'assets/bottles/mountaindew.png',
    liquidColor: Color(0xFF7ED321),
    highlightColor: Color(0xFFB7EE6B),
    screenColor: Color(0xFF7ED321),
    fizziness: 0.75,
  ),
  DrinkModel(
    id: 'fanta_purple',
    name: 'Fanta Grape',
    assetPath: 'assets/bottles/fantapurple.png',
    liquidColor: Color(0xFF7B2D8E),
    highlightColor: Color(0xFFC384D6),
    screenColor: Color(0xFF7B2D8E),
    fizziness: 0.7,
  ),
];
