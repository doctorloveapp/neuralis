/// Neuralis — Interaction / Domain
/// Controller astratto della logica di interazione tattile — dominio puro.
///
/// Posizione: lib/features/interaction/domain/interaction_controller.dart
library;

import 'dart:ui' show Offset;

import 'interaction_state.dart';

// ---------------------------------------------------------------------------
// InteractionController — contratto astratto (Domain Layer)
// ---------------------------------------------------------------------------

/// Contratto astratto per la gestione della logica di interazione tattile.
///
/// ⚠️ ZERO DIPENDENZE UI: questa classe è pura logica di dominio.
/// Nessun import da `package:flutter/`, nessun Widget, nessun BuildContext.
/// Testabile con unit test standard senza `flutter_test`.
///
/// Esposta nel layer Presentation tramite:
///   `StateNotifierProvider<InteractionController, InteractionState>`
///
/// I widget [BassPad] e [NavPad] chiamano i metodi di questa classe
/// in risposta agli eventi GestureDetector, senza conoscere la logica interna.
abstract class InteractionController {
  /// Stato corrente dell'interazione.
  InteractionState get state;

  // -------------------------------------------------------------------------
  // BassPad API
  // -------------------------------------------------------------------------

  /// Chiamato quando l'utente inizia a premere il [BassPad].
  ///
  /// Avvia la crescita esponenziale del [InteractionState.bassGain]
  /// verso [InteractionState.bassGainMax] (3.0).
  /// La curva è esponenziale: accelerazione graduale che si intensifica
  /// con la pressione continua.
  void onBassPadPressed();

  /// Chiamato ogni tick mentre il [BassPad] è tenuto premuto.
  ///
  /// [elapsed] → tempo trascorso dall'inizio della pressione.
  /// Usato per calcolare la posizione sulla curva esponenziale.
  void onBassPadHeld(Duration elapsed);

  /// Chiamato quando l'utente rilascia il [BassPad].
  ///
  /// Avvia il ritorno ease-out di [InteractionState.bassGain]
  /// verso [InteractionState.bassGainDefault] (1.0) in 300ms.
  void onBassPadReleased();

  /// Aggiorna direttamente il [InteractionState.bassGain] a un valore specifico.
  ///
  /// Il valore viene clampato automaticamente in [bassGainMin, bassGainMax].
  /// Usato internamente durante la curva di animazione.
  void updateBassGain(double gain);

  // -------------------------------------------------------------------------
  // NavPad API
  // -------------------------------------------------------------------------

  /// Chiamato da `GestureDetector.onPanStart` del [NavPad].
  ///
  /// Registra il punto di partenza per la normalizzazione del delta.
  void onNavPadPanStart(Offset localPosition);

  /// Chiamato da `GestureDetector.onPanUpdate` del [NavPad].
  ///
  /// [delta] → delta di spostamento dal frame precedente (in pixel logici).
  /// [padSize] → dimensioni del widget NavPad (per la normalizzazione).
  ///
  /// La normalizzazione calcola:
  ///   bending.dx = (totalDelta.dx / padSize.width).clamp(-1.0, 1.0)
  ///   bending.dy = (totalDelta.dy / padSize.height).clamp(-1.0, 1.0)
  void onNavPadPanUpdate(Offset delta, Offset padSize);

  /// Chiamato da `GestureDetector.onPanEnd` del [NavPad].
  ///
  /// Avvia il ritorno ease-out di [InteractionState.bending]
  /// verso [Offset.zero] in 500ms.
  void onNavPadPanEnd();

  /// Aggiorna direttamente il [InteractionState.bending] a un valore specifico.
  ///
  /// Gli assi vengono clampati automaticamente in [bendingMin, bendingMax].
  /// Usato internamente durante l'animazione di ritorno.
  void updateBending(Offset bending);

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  /// Reimposta lo stato a [InteractionState.initial()].
  ///
  /// Chiamato quando l'app va in background (AppLifecycleState.paused)
  /// per evitare stati residui al resume.
  void reset();

  /// Rilascia tutte le risorse (timer, animation controller interni).
  ///
  /// ⚠️ PRIMO nella dispose chain (ARCHITECTURE.md §6):
  /// chiamato prima di shaderRepository.dispose().
  void dispose();
}
