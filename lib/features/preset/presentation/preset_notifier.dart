/// Neuralis — Preset / Presentation
/// PresetNotifier: Riverpod Notifier per il ciclo dei 5 preset Multiverse.
///
/// Posizione: lib/features/preset/presentation/preset_notifier.dart
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/neuralis_preset.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PresetNotifier
// ─────────────────────────────────────────────────────────────────────────────

/// Notifier che gestisce il preset attivo del Multiverse System.
///
/// Espone:
///   - [state]    → [NeuralisPreset] corrente
///   - [next()]   → avanza al preset successivo (ciclo)
///   - [set()]    → imposta un preset specifico
///   - [current]  → [PresetData] del preset attivo
class PresetNotifier extends Notifier<NeuralisPreset> {
  @override
  NeuralisPreset build() => NeuralisPreset.synthwave;

  /// Avanza al preset successivo (ciclo infinito).
  void next() {
    final values = NeuralisPreset.values;
    final nextIdx = (values.indexOf(state) + 1) % values.length;
    state = values[nextIdx];
  }

  /// Imposta un preset specifico.
  void set(NeuralisPreset preset) => state = preset;

  /// [PresetData] del preset attivo corrente.
  PresetData get current => PresetLibrary.of(state);
}
