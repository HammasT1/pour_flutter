import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/pour_screen.dart';

void main() {
  runApp(const ProviderScope(child: PourApp()));
}

/// Flutter's default [ScrollBehavior] only enables drag-to-scroll for
/// touch/stylus input, not mouse - so on web/desktop a mouse drag across
/// the bottle carousel does nothing out of the box. This adds mouse (and
/// trackpad) to the set of devices that can drag a scrollable.
class PourScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };
}

class PourApp extends StatelessWidget {
  const PourApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pour',
      debugShowCheckedModeBanner: false,
      scrollBehavior: PourScrollBehavior(),
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0D10),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF7A1A),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData(brightness: Brightness.dark).textTheme),
      ),
      home: const PourScreen(),
    );
  }
}
