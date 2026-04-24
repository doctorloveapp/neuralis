/// Neuralis — Shared Theme
/// Tipografia LCARS con font Antonio.
///
/// Posizione: lib/shared/theme/lcars_typography.dart
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'lcars_colors.dart';

/// Stili tipografici LCARS basati sul font Antonio (Google Fonts).
///
/// Convenzioni LCARS:
///   - Tutto il testo è MAIUSCOLO (applicato dai widget, non qui)
///   - Letter spacing ampio: 2.0–6.0
///   - Peso: w400 per testo normale, w700 per titoli e label
abstract final class LcarsTypography {
  // ── Interno: factory base ─────────────────────────────────────────────
  static TextStyle _a({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color color = LcarsColors.atomic,
    double spacing = 2.0,
  }) =>
      GoogleFonts.antonio(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: spacing,
      );

  // ── Scale tipografica ──────────────────────────────────────────────────
  /// Display grande: titolo app / branding. 48px, w700, spacing 6.
  static TextStyle get displayLarge =>
      _a(size: 48, weight: FontWeight.w700, spacing: 6.0);

  /// Display medio: header sezione. 32px, w700, spacing 4.
  static TextStyle get displayMedium =>
      _a(size: 32, weight: FontWeight.w700, spacing: 4.0);

  /// Heading: titolo pannello. 20px, w700, spacing 3.
  static TextStyle get heading =>
      _a(size: 20, weight: FontWeight.w700, spacing: 3.0);

  /// Label: pulsanti e status. 14px, w700, spacing 2.
  static TextStyle get label =>
      _a(size: 14, weight: FontWeight.w700, spacing: 2.0);

  /// Label piccola: metadati / secondaria. 11px, w400, blueGray.
  static TextStyle get labelSmall =>
      _a(size: 11, color: LcarsColors.blueGray, spacing: 2.0);

  /// Status: indicatori di stato. 12px, w400, spacing 3.
  static TextStyle get status =>
      _a(size: 12, spacing: 3.0);

  /// Warning: banner DRM. 13px, w700, tan, spacing 2.
  static TextStyle get warningLabel =>
      _a(size: 13, weight: FontWeight.w700, color: LcarsColors.tan, spacing: 2.0);

  /// Caption: note micro. 10px, w400, blueGray.
  static TextStyle get caption =>
      _a(size: 10, color: LcarsColors.blueGray, spacing: 1.5);

  /// Pad: label BassPad/NavPad. 16px, w700, spacing 2.
  static TextStyle get pad =>
      _a(size: 16, weight: FontWeight.w700, spacing: 2.0);
}
