/// Neuralis — Shared Theme
/// Palette colori LCARS.
///
/// Posizione: lib/shared/theme/lcars_colors.dart
library;

import 'package:flutter/material.dart';

/// Palette cromatica ufficiale di Neuralis LCARS.
/// Nessun colore generico Material — solo la palette concordata.
abstract final class LcarsColors {
  // ── Colori primari LCARS ──────────────────────────────────────────────
  static const Color atomic   = Color(0xFFFF9900); // Arancio primario
  static const Color tan      = Color(0xFFFFCC66); // Giallo-tan (warning)
  static const Color purple   = Color(0xFFCC99CC); // Lilla (accento)
  static const Color blueGray = Color(0xFF9999CC); // Blu-grigio (testo secondario)

  // ── Sfondi ───────────────────────────────────────────────────────────
  static const Color darkBg    = Color(0xFF000000); // Nero puro (overlay bg)
  static const Color panelBg   = Color(0xFF0A0A1A); // Blu notte (pannelli)
  static const Color surfaceBg = Color(0xFF111133); // Superficie pannello

  // ── Stato sistema ─────────────────────────────────────────────────────
  static const Color online  = atomic;              // Sistema attivo
  static const Color warning = tan;                 // DRM / attenzione
  static const Color danger  = Color(0xFFFF3333);  // Errore critico

  // ── Testo ─────────────────────────────────────────────────────────────
  static const Color textPrimary   = atomic;
  static const Color textSecondary = blueGray;
  static const Color textDim       = Color(0xFF554433);

  // ── Overlay ───────────────────────────────────────────────────────────
  /// Sfondo overlay semi-trasparente (80% opacità).
  static const Color overlayBg = Color(0xCC000000);

  // ── Helper ───────────────────────────────────────────────────────────
  static Color withAlpha(Color color, double opacity) =>
      color.withAlpha((opacity * 255).round());
}
