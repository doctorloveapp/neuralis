/// Neuralis — Shared Widgets
/// LcarsElbow: angolo asimmetrico a "L" — pezzo iconico dell'interfaccia LCARS.
///
/// Posizione: lib/shared/widgets/lcars_elbow.dart
library;

import 'package:flutter/material.dart';

import '../theme/lcars_colors.dart';

// ---------------------------------------------------------------------------
// Orientamento dell'Elbow
// ---------------------------------------------------------------------------

/// I 4 orientamenti possibili dell'Elbow LCARS.
///
///   [topLeft]     → arco nell'angolo top-left, braccio orizzontale in alto,
///                   braccio verticale a sinistra.
///   [topRight]    → arco nell'angolo top-right, braccio orizzontale in alto,
///                   braccio verticale a destra.
///   [bottomLeft]  → arco nell'angolo bottom-left, braccio orizzontale in basso,
///                   braccio verticale a sinistra.
///   [bottomRight] → arco nell'angolo bottom-right, braccio orizzontale in basso,
///                   braccio verticale a destra.
enum LcarsElbowOrientation { topLeft, topRight, bottomLeft, bottomRight }

// ---------------------------------------------------------------------------
// LcarsElbow widget
// ---------------------------------------------------------------------------

/// Widget che disegna l'angolo asimmetrico "L" caratteristico dell'interfaccia LCARS.
///
/// Il widget espone:
///   - [orientation]          → quale angolo della bounding box viene occupato
///   - [horizontalThickness]  → altezza del braccio orizzontale
///   - [verticalThickness]    → larghezza del braccio verticale
///   - [cornerRadius]         → raggio dell'arco esterno (default 50)
///   - [color]                → colore di riempimento (default atomic)
///
/// Esempio:
/// ```dart
/// SizedBox(
///   width: 120,
///   height: 100,
///   child: LcarsElbow(
///     orientation: LcarsElbowOrientation.topLeft,
///     horizontalThickness: 40,
///     verticalThickness: 50,
///     cornerRadius: 50,
///     color: LcarsColors.atomic,
///   ),
/// )
/// ```
class LcarsElbow extends StatelessWidget {
  const LcarsElbow({
    super.key,
    required this.orientation,
    this.horizontalThickness = 40.0,
    this.verticalThickness   = 50.0,
    this.cornerRadius        = 50.0,
    this.color               = LcarsColors.atomic,
  });

  final LcarsElbowOrientation orientation;
  final double horizontalThickness;
  final double verticalThickness;
  final double cornerRadius;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _ElbowPainter(
          orientation:         orientation,
          horizontalThickness: horizontalThickness,
          verticalThickness:   verticalThickness,
          cornerRadius:        cornerRadius,
          color:               color,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ElbowPainter — CustomPainter
// ---------------------------------------------------------------------------

class _ElbowPainter extends CustomPainter {
  const _ElbowPainter({
    required this.orientation,
    required this.horizontalThickness,
    required this.verticalThickness,
    required this.cornerRadius,
    required this.color,
  });

  final LcarsElbowOrientation orientation;
  final double horizontalThickness;
  final double verticalThickness;
  final double cornerRadius;
  final Color  color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final path = _buildPath(size);
    canvas.drawPath(path, paint);
  }

  /// Costruisce il [Path] dell'Elbow in base all'orientamento.
  ///
  /// La geometria è un'L asimmetrica con:
  ///   - Arco esterno di raggio [cornerRadius] nell'angolo di orientamento
  ///   - Angolo interno NETTO (nessun arrotondamento) dove i due bracci si incontrano
  ///   - Il braccio orizzontale ha altezza [horizontalThickness]
  ///   - Il braccio verticale ha larghezza [verticalThickness]
  Path _buildPath(Size size) {
    switch (orientation) {
      case LcarsElbowOrientation.topRight:
        return _topRightPath(size);
      case LcarsElbowOrientation.topLeft:
        return _topLeftPath(size);
      case LcarsElbowOrientation.bottomRight:
        return _bottomRightPath(size);
      case LcarsElbowOrientation.bottomLeft:
        return _bottomLeftPath(size);
    }
  }

  // ── Top-Right ─────────────────────────────────────────────────────────
  // Arco nell'angolo top-right.
  // Braccio orizzontale in alto (altezza = H).
  // Braccio verticale a destra (larghezza = V).
  //
  // Path (senso orario):
  //  (0,0) ──► (W-R, 0) ──arc──► (W, R) ──► (W, Ht) ──► (W-V, Ht)
  //  ──► (W-V, H) ──► (0, H) ──► close
  //
  Path _topRightPath(Size size) {
    final w = size.width;
    final ht = size.height;
    final r = cornerRadius.clamp(0.0, w / 2).clamp(0.0, ht / 2);
    final h = horizontalThickness.clamp(0.0, ht);
    final v = verticalThickness.clamp(0.0, w);

    return Path()
      ..moveTo(0, 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r),
          radius: Radius.circular(r), clockwise: true)
      ..lineTo(w, ht)
      ..lineTo(w - v, ht)
      ..lineTo(w - v, h)
      ..lineTo(0, h)
      ..close();
  }

  // ── Top-Left ──────────────────────────────────────────────────────────
  // Arco nell'angolo top-left.
  // Braccio orizzontale in alto (altezza = H).
  // Braccio verticale a sinistra (larghezza = V).
  //
  // Path (senso orario):
  //  (W,0) ──► (R, 0) ──arc──► (0, R) ──► (0, Ht) ──► (V, Ht)
  //  ──► (V, H) ──► (W, H) ──► close
  //
  Path _topLeftPath(Size size) {
    final w = size.width;
    final ht = size.height;
    final r = cornerRadius.clamp(0.0, w / 2).clamp(0.0, ht / 2);
    final h = horizontalThickness.clamp(0.0, ht);
    final v = verticalThickness.clamp(0.0, w);

    return Path()
      ..moveTo(w, 0)
      ..lineTo(r, 0)
      ..arcToPoint(Offset(0, r),
          radius: Radius.circular(r), clockwise: false)
      ..lineTo(0, ht)
      ..lineTo(v, ht)
      ..lineTo(v, h)
      ..lineTo(w, h)
      ..close();
  }

  // ── Bottom-Right ──────────────────────────────────────────────────────
  // Arco nell'angolo bottom-right.
  // Braccio orizzontale in basso (altezza = H dal basso).
  // Braccio verticale a destra (larghezza = V).
  //
  // Path (senso orario):
  //  (0,Ht) ──► (W-R, Ht) ──arc──► (W, Ht-R) ──► (W, 0)
  //  ──► (W-V, 0) ──► (W-V, Ht-H) ──► (0, Ht-H) ──► close
  //
  Path _bottomRightPath(Size size) {
    final w = size.width;
    final ht = size.height;
    final r = cornerRadius.clamp(0.0, w / 2).clamp(0.0, ht / 2);
    final h = horizontalThickness.clamp(0.0, ht);
    final v = verticalThickness.clamp(0.0, w);

    return Path()
      ..moveTo(0, ht)
      ..lineTo(w - r, ht)
      ..arcToPoint(Offset(w, ht - r),
          radius: Radius.circular(r), clockwise: false)
      ..lineTo(w, 0)
      ..lineTo(w - v, 0)
      ..lineTo(w - v, ht - h)
      ..lineTo(0, ht - h)
      ..close();
  }

  // ── Bottom-Left ───────────────────────────────────────────────────────
  // Arco nell'angolo bottom-left.
  // Braccio orizzontale in basso (altezza = H dal basso).
  // Braccio verticale a sinistra (larghezza = V).
  //
  // Path (senso orario):
  //  (W,Ht) ──► (R, Ht) ──arc──► (0, Ht-R) ──► (0, 0)
  //  ──► (V, 0) ──► (V, Ht-H) ──► (W, Ht-H) ──► close
  //
  Path _bottomLeftPath(Size size) {
    final w = size.width;
    final ht = size.height;
    final r = cornerRadius.clamp(0.0, w / 2).clamp(0.0, ht / 2);
    final h = horizontalThickness.clamp(0.0, ht);
    final v = verticalThickness.clamp(0.0, w);

    return Path()
      ..moveTo(w, ht)
      ..lineTo(r, ht)
      ..arcToPoint(Offset(0, ht - r),
          radius: Radius.circular(r), clockwise: true)
      ..lineTo(0, 0)
      ..lineTo(v, 0)
      ..lineTo(v, ht - h)
      ..lineTo(w, ht - h)
      ..close();
  }

  @override
  bool shouldRepaint(_ElbowPainter old) =>
      old.orientation != orientation ||
      old.horizontalThickness != horizontalThickness ||
      old.verticalThickness != verticalThickness ||
      old.cornerRadius != cornerRadius ||
      old.color != color;
}
