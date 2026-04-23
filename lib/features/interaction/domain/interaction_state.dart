/// Neuralis — Interaction / Domain
/// Stato immutabile dell'InteractionController.
///
/// Posizione: lib/features/interaction/domain/interaction_state.dart
library;

import 'dart:ui' show Offset;

// ---------------------------------------------------------------------------
// InteractionState — stato immutabile del layer di interazione
// ---------------------------------------------------------------------------

/// Stato immutabile che rappresenta il risultato delle interazioni tattili
/// dell'utente sui pad dell'overlay LCARS.
///
/// Aggiornato dall'[InteractionController] e consumato da:
///   - [WavefrontUniforms.fromFFT()] → applica [bassGain] alle bande 0–7
///   - [WavefrontUniforms]           → usa [bending] per aberrazione cromatica
///
/// NOTA: [dart:ui.Offset] è l'unica dipendenza framework ammessa qui
/// poiché rappresenta una coppia matematica (dx, dy), non un widget.
class InteractionState {
  const InteractionState({
    required this.bassGain,
    required this.bending,
  });

  /// Moltiplicatore di guadagno per le bande FFT basse (0–7).
  ///
  /// Range: [0.5, 3.0]
  ///   - 0.5 → attenuazione massima del bass
  ///   - 1.0 → gain neutro (default)
  ///   - 3.0 → boost massimo del bass
  ///
  /// Controllato dal [BassPad]:
  ///   - Pressione continua → crescita esponenziale verso 3.0
  ///   - Rilascio → ritorno a 1.0 in 300ms con ease-out
  final double bassGain;

  /// Vettore di bending 2D dal NavPad.
  ///
  /// Entrambi gli assi in [-1.0, 1.0]:
  ///   - [Offset.dx] → swipe orizzontale → uniform uBending.x
  ///   - [Offset.dy] → swipe verticale   → uniform uBending.y
  ///
  /// Quando length([bending]) > ShaderParams.bendingThreshold (0.1):
  ///   → aberrazione cromatica attiva nello shader GLSL
  ///
  /// Controllato dal [NavPad]:
  ///   - Swipe → aggiornamento proporzionale normalizzato
  ///   - Rilascio → ritorno a Offset.zero in 500ms con ease-out
  final Offset bending;

  // -------------------------------------------------------------------------
  // Bounds e costanti
  // -------------------------------------------------------------------------

  /// Valore minimo di [bassGain].
  static const double bassGainMin = 0.5;

  /// Valore massimo di [bassGain].
  static const double bassGainMax = 3.0;

  /// Valore di default / neutro di [bassGain].
  static const double bassGainDefault = 1.0;

  /// Valore minimo per gli assi di [bending].
  static const double bendingMin = -1.0;

  /// Valore massimo per gli assi di [bending].
  static const double bendingMax = 1.0;

  // -------------------------------------------------------------------------
  // Factory constructors
  // -------------------------------------------------------------------------

  /// Stato iniziale: gain neutro, nessun bending.
  factory InteractionState.initial() => const InteractionState(
        bassGain: bassGainDefault,
        bending: Offset.zero,
      );

  // -------------------------------------------------------------------------
  // Metodi di utilità
  // -------------------------------------------------------------------------

  /// Crea una copia con i valori specificati sostituiti.
  /// Applica il clamping automatico per garantire i range corretti.
  InteractionState copyWith({
    double? bassGain,
    Offset? bending,
  }) {
    return InteractionState(
      bassGain: (bassGain ?? this.bassGain).clamp(bassGainMin, bassGainMax),
      bending: bending != null
          ? Offset(
              bending.dx.clamp(bendingMin, bendingMax),
              bending.dy.clamp(bendingMin, bendingMax),
            )
          : this.bending,
    );
  }

  /// Lunghezza del vettore di bending — usata per la soglia aberrazione cromatica.
  double get bendingLength => bending.distance;

  /// True se l'aberrazione cromatica è attiva (supera la soglia 0.1).
  bool get isChromaticAberrationActive => bendingLength > 0.1;

  /// True se il bass è amplificato oltre il valore neutro.
  bool get isBassActive => bassGain > bassGainDefault;

  /// Percentuale di attivazione del BassPad nell'intervallo [0.0, 1.0].
  /// 0.0 = gain minimo (0.5), 0.5 = neutro (1.0), 1.0 = boost massimo (3.0).
  double get bassGainNormalized =>
      (bassGain - bassGainMin) / (bassGainMax - bassGainMin);

  @override
  String toString() =>
      'InteractionState(bassGain: ${bassGain.toStringAsFixed(2)}, '
      'bending: (${bending.dx.toStringAsFixed(2)}, ${bending.dy.toStringAsFixed(2)}), '
      'chromaActive: $isChromaticAberrationActive)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InteractionState &&
          runtimeType == other.runtimeType &&
          bassGain == other.bassGain &&
          bending == other.bending;

  @override
  int get hashCode => Object.hash(bassGain, bending);
}
