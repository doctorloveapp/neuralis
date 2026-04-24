/// Neuralis — Shared Theme
/// ThemeData globale LCARS.
///
/// Posizione: lib/shared/theme/lcars_theme.dart
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'lcars_colors.dart';
import 'lcars_typography.dart';

/// Configurazione ThemeData globale per Neuralis LCARS.
/// Sostituisce il tema base provvisorio in [app.dart].
abstract final class LcarsTheme {
  /// Tema principale — dark, Antonio, palette LCARS.
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.antonioTextTheme(base.textTheme).copyWith(
      displayLarge:  LcarsTypography.displayLarge,
      displayMedium: LcarsTypography.displayMedium,
      headlineLarge: LcarsTypography.heading,
      titleLarge:    LcarsTypography.label,
      bodyLarge:     LcarsTypography.labelSmall,
      bodyMedium:    LcarsTypography.caption,
      labelLarge:    LcarsTypography.label,
    );

    return base.copyWith(
      scaffoldBackgroundColor: LcarsColors.darkBg,
      canvasColor:             LcarsColors.panelBg,
      textTheme:               textTheme,
      primaryTextTheme:        textTheme,

      colorScheme: const ColorScheme.dark(
        primary:    LcarsColors.atomic,
        secondary:  LcarsColors.blueGray,
        tertiary:   LcarsColors.purple,
        surface:    LcarsColors.panelBg,
        onPrimary:  LcarsColors.darkBg,
        onSecondary:LcarsColors.darkBg,
        onSurface:  LcarsColors.blueGray,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: LcarsColors.panelBg,
        foregroundColor: LcarsColors.atomic,
        elevation: 0,
        titleTextStyle: LcarsTypography.heading,
      ),

      dividerColor:     LcarsColors.withAlpha(LcarsColors.blueGray, 0.3),
      highlightColor:   LcarsColors.withAlpha(LcarsColors.atomic, 0.1),
      splashColor:      LcarsColors.withAlpha(LcarsColors.atomic, 0.15),
    );
  }
}
