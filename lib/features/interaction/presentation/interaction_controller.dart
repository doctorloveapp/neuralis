/// Neuralis — Interaction / Presentation
/// InteractionController: logica BassPad + NavPad con ritorno elastico.
///
/// Posizione: lib/features/interaction/presentation/interaction_controller.dart
library;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../features/preset/domain/entities/neuralis_preset.dart';

// ─────────────────────────────────────────────────────────────────────────────
// InteractionState — stato immutabile dei pad interattivi
// ─────────────────────────────────────────────────────────────────────────────

/// Stato immutabile dell'interazione tattile.
///
/// Aggiornato ~60 volte al secondo dal Ticker interno.
class InteractionState {
  const InteractionState({
    this.bassGain = 1.0,
    this.bendingX = 0.0,
    this.bendingY = 0.0,
  });

  /// Moltiplicatore gain per le bande basse (0–7).
  /// Range: [1.0, 8.0] — default 1.0 (neutro). Valore 8.0 = esplosione visiva.
  final double bassGain;

  /// Componente X del bending per aberrazione cromatica.
  /// Range: [-1.0, 1.0]
  final double bendingX;

  /// Componente Y del bending per aberrazione cromatica.
  /// Range: [-1.0, 1.0]
  final double bendingY;

  /// True se il bassGain è sopra soglia visiva (per feedback colore).
  bool get isBassActive => bassGain > 1.05;

  /// True se il bending è sopra la soglia aberrazione shader (0.1).
  bool get isBending => (bendingX * bendingX + bendingY * bendingY) > 0.01;

  /// Restituisce la coppia (bendingX, bendingY) normalizzata per lo shader.
  (double, double) get bendingXY => (bendingX, bendingY);

  InteractionState copyWith({
    double? bassGain,
    double? bendingX,
    double? bendingY,
  }) =>
      InteractionState(
        bassGain: bassGain ?? this.bassGain,
        bendingX: bendingX ?? this.bendingX,
        bendingY: bendingY ?? this.bendingY,
      );

  @override
  String toString() =>
      'InteractionState(gain: ${bassGain.toStringAsFixed(2)}, '
      'bend: (${bendingX.toStringAsFixed(2)}, ${bendingY.toStringAsFixed(2)}))';
}

// ─────────────────────────────────────────────────────────────────────────────
// InteractionController — Notifier con Ticker frame-accurate
// ─────────────────────────────────────────────────────────────────────────────

/// Notifier che gestisce l'interazione fisica dei pad LCARS.
///
/// Usa un [Ticker] frame-accurate (SchedulerBinding) per:
///   - Bass boost: curva esponenziale verso 3.0 durante pressione,
///                 ease-out verso 1.0 in ~300ms al rilascio.
///   - Bending: accumulo normalizzato durante swipe,
///              ease-out verso (0,0) in ~450ms al rilascio.
///
/// Il bending viene instradato ogni frame a [ShaderNotifier.updateBending].
class InteractionController extends Notifier<InteractionState> {
  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;

  // ── Stato interno del boost ───────────────────────────────────────────────
  bool _isBoostActive = false;

  // ── Costanti di interpolazione (sostituite da preset in _onTick) ──────────

  /// Velocità salita bass (ease-in esponenziale): default SYNTHWAVE.
  static const double _bassRiseSpeed  = 7.0;

  /// Velocità discesa bass (ease-out): default SYNTHWAVE.
  static const double _bassDecaySpeed = 4.0;

  /// Velocità ritorno bending a zero (ease-out): default.
  static const double _bendingDecaySpeed = 3.5;

  /// Soglia sotto cui i valori vengono forzati a zero.
  static const double _epsilon = 0.002;

  // ──────────────────────────────────────────────────────────────────────────

  @override
  InteractionState build() {
    ref.onDispose(_cleanup);
    _startTicker();
    return const InteractionState();
  }

  // ─────────────────────────────────────────────────────────────────────
  // API pubblica — BassPad
  // ─────────────────────────────────────────────────────────────────────

  /// Chiamato al tocco iniziale del BassPad (onLongPressStart).
  void onBassPadPressed() {
    _isBoostActive = true;
    HapticFeedback.lightImpact();
  }

  /// Chiamato al rilascio del BassPad (onLongPressEnd / onTapUp).
  void onBassPadReleased() {
    _isBoostActive = false;
    HapticFeedback.lightImpact();
  }

  // ─────────────────────────────────────────────────────────────────────
  // API pubblica — NavPad
  // ─────────────────────────────────────────────────────────────────────

  /// Chiamato durante lo swipe sul NavPad.
  ///
  /// [normalizedDelta] è la variazione normalizzata rispetto alla size del pad:
  ///   dx = delta.dx / padWidth, dy = delta.dy / padHeight
  void onNavPadUpdate(double normalizedDx, double normalizedDy) {
    final current = state;
    // Sensibilità dal preset attivo (NEBULA=2.0, default=5.4, HYPER=6.0)
    double sensitivity = 5.4;
    try {
      final activePreset = ref.read(presetNotifierProvider);
      sensitivity = PresetLibrary.of(activePreset).navSensitivity;
    } catch (_) {}
    final newX = (current.bendingX + normalizedDx * sensitivity).clamp(-1.0, 1.0);
    final newY = (current.bendingY + normalizedDy * sensitivity).clamp(-1.0, 1.0);

    state = current.copyWith(bendingX: newX, bendingY: newY);
    HapticFeedback.selectionClick();
  }

  /// Chiamato al termine del pan (onPanEnd).
  /// Il ritorno elastico a (0,0) è gestito automaticamente dal Ticker.
  void onNavPadEnd() {
    // Il Ticker gestisce il decadimento — nessuna azione istantanea.
    HapticFeedback.lightImpact();
  }

  // ─────────────────────────────────────────────────────────────────────
  // Ticker interno
  // ─────────────────────────────────────────────────────────────────────

  void _startTicker() {
    _ticker = Ticker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastElapsed).inMicroseconds / 1_000_000.0;
    _lastElapsed = elapsed;

    // Protezione da dt anomali (primo frame, resume dopo background)
    if (dt <= 0 || dt > 0.5) return;

    final current = state;
    double newGain    = current.bassGain;
    double newBendX   = current.bendingX;
    double newBendY   = current.bendingY;
    bool   changed    = false;

    // ── Leggi fisica dal preset attivo ────────────────────────────────────
    PresetData? preset;
    try {
      final activePreset = ref.read(presetNotifierProvider);
      preset = PresetLibrary.of(activePreset);
    } catch (_) {
      // Preset non ancora inizializzato
    }
    final maxGain    = preset?.maxBassGain       ?? 8.0;
    final riseSpeed  = preset?.bassRiseSpeed      ?? _bassRiseSpeed;
    final decaySpeed = preset?.bassDecaySpeed     ?? _bassDecaySpeed;
    final bendDecay  = preset?.bendingDecaySpeed  ?? _bendingDecaySpeed;

    // ── Bass gain ─────────────────────────────────────────────────────
    if (_isBoostActive) {
      final next = newGain + (maxGain - newGain) * dt * riseSpeed;
      if ((next - newGain).abs() > _epsilon) {
        newGain = next.clamp(1.0, maxGain);
        changed = true;
      }
    } else if (newGain > 1.0 + _epsilon) {
      final next = newGain + (1.0 - newGain) * dt * decaySpeed;
      newGain = next < 1.0 + _epsilon ? 1.0 : next.clamp(1.0, maxGain);
      changed = true;
    }

    // ── Bending X ─────────────────────────────────────────────────────
    if (newBendX.abs() > _epsilon) {
      final next = newBendX + (0.0 - newBendX) * dt * bendDecay;
      newBendX = next.abs() < _epsilon ? 0.0 : next.clamp(-1.0, 1.0);
      changed = true;
    }

    // ── Bending Y ─────────────────────────────────────────────────────
    if (newBendY.abs() > _epsilon) {
      final next = newBendY + (0.0 - newBendY) * dt * bendDecay;
      newBendY = next.abs() < _epsilon ? 0.0 : next.clamp(-1.0, 1.0);
      changed = true;
    }

    if (!changed) return;

    state = InteractionState(
      bassGain: newGain,
      bendingX: newBendX,
      bendingY: newBendY,
    );

    // ── Routing → ShaderNotifier + AudioNotifier ────────────────────────────────
    try {
      final shaderNotifier = ref.read(shaderNotifierProvider.notifier);
      shaderNotifier.updateBending(Offset(newBendX, newBendY));
      final audioNotifier = ref.read(audioNotifierProvider.notifier);
      audioNotifier.setBassGain(newGain);
      // Aggiorna bassBands dal preset
      audioNotifier.setBassBands(preset?.bassBands ?? 8);
    } catch (_) {
      // Shader/Audio non ancora inizializzati — ignorare silenziosamente
    }
  }

  void _cleanup() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
  }
}
