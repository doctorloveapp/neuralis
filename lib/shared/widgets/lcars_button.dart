/// Neuralis — Shared Widgets
/// LcarsButton: pulsante interattivo stile LCARS.
///
/// Posizione: lib/shared/widgets/lcars_button.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/lcars_colors.dart';
import '../theme/lcars_typography.dart';

/// Pulsante LCARS con un solo angolo arrotondato (raggio 20) e feedback aptico.
///
/// Il bordo arrotondato è sempre sull'angolo sinistro (top-left + bottom-left),
/// coerentemente con il design asimmetrico LCARS dove i pulsanti sono pannelli
/// rettangolari con un'estremità sinistra "pill" e l'estremità destra netta.
///
/// Feedback aptico: [HapticFeedback.lightImpact] ad ogni tap.
///
/// La label è SEMPRE maiuscola (trasformata nel widget, non nella stringa sorgente).
class LcarsButton extends StatelessWidget {
  const LcarsButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color          = LcarsColors.atomic,
    this.textColor      = LcarsColors.darkBg,
    this.width          = 80.0,
    this.height         = 36.0,
    this.cornerRadius   = 20.0,
    this.isActive       = false,
  });

  final String   label;
  final VoidCallback onTap;
  final Color    color;
  final Color    textColor;
  final double   width;
  final double   height;
  final double   cornerRadius;
  /// True → colore invertito (testo = [color], sfondo = trasparente + bordo).
  final bool     isActive;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width:  width,
        height: height,
        decoration: BoxDecoration(
          color:  isActive ? LcarsColors.darkBg : color,
          border: isActive ? Border.all(color: color, width: 2) : null,
          borderRadius: BorderRadius.only(
            topLeft:     Radius.circular(cornerRadius),
            bottomLeft:  Radius.circular(cornerRadius),
            topRight:    Radius.zero,
            bottomRight: Radius.zero,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label.toUpperCase(),
          style: LcarsTypography.label.copyWith(
            color: isActive ? color : textColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
