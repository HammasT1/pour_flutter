import 'package:flutter/material.dart';

/// Renders an asset image, falling back to a labeled placeholder box if
/// the asset is missing - so the app runs and looks intentional even
/// before final art is dropped in.
class SafeAssetImage extends StatelessWidget {
  final String assetPath;
  final BoxFit fit;
  final Color fallbackColor;
  final IconData fallbackIcon;
  final String? fallbackLabel;

  const SafeAssetImage({
    super.key,
    required this.assetPath,
    this.fit = BoxFit.contain,
    this.fallbackColor = const Color(0xFF20242B),
    this.fallbackIcon = Icons.local_drink_outlined,
    this.fallbackLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      fit: fit,
      errorBuilder: (context, error, stack) => Container(
        decoration: BoxDecoration(
          color: fallbackColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white24),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(fallbackIcon, color: Colors.white54, size: 32),
            if (fallbackLabel != null) ...[
              const SizedBox(height: 6),
              Text(
                fallbackLabel!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
