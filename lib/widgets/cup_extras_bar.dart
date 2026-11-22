import 'package:flutter/material.dart';

import 'pressable_scale.dart';

/// Two pills under the cup: "+ Ice" (with a cube counter, greyed out
/// once the cup holds its max) and a "Straw" toggle that lights up in
/// the drink's color while the straw is in.
class CupExtrasBar extends StatelessWidget {
  final int iceCubes;
  final int maxIceCubes;
  final bool hasStraw;
  final bool enabled;
  final Color accent;
  final VoidCallback onAddIce;
  final VoidCallback onToggleStraw;

  const CupExtrasBar({
    super.key,
    required this.iceCubes,
    required this.maxIceCubes,
    required this.hasStraw,
    required this.enabled,
    required this.accent,
    required this.onAddIce,
    required this.onToggleStraw,
  });

  @override
  Widget build(BuildContext context) {
    final canAddIce = enabled && iceCubes < maxIceCubes;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Pill(
          onTap: canAddIce ? onAddIce : null,
          active: iceCubes > 0,
          accent: const Color(0xFF9FD8FF),
          icon: Icons.ac_unit_rounded,
          label: iceCubes == 0 ? 'Ice' : 'Ice $iceCubes/$maxIceCubes',
          dimmed: !canAddIce,
        ),
        const SizedBox(width: 10),
        _Pill(
          onTap: enabled ? onToggleStraw : null,
          active: hasStraw,
          accent: accent,
          icon: Icons.local_drink_rounded,
          label: 'Straw',
          dimmed: !enabled,
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final VoidCallback? onTap;
  final bool active;
  final bool dimmed;
  final Color accent;
  final IconData icon;
  final String label;

  const _Pill({
    required this.onTap,
    required this.active,
    required this.dimmed,
    required this.accent,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? Colors.white : Colors.white70;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: dimmed ? 0.45 : 1,
      child: PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: active ? accent.withValues(alpha: 0.28) : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? accent.withValues(alpha: 0.9) : Colors.white24),
            boxShadow: active ? [BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 12)] : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
